// =========================================================================
// email-archiver  (BCC Master Template — multi-step Composio orchestration)
// =========================================================================
// PURPOSE: Archive older Gmail messages and log them to the documents table.
//   This is a multi-step workflow (fetch IDs -> modify labels -> log) that
//   can't be expressed in the generic automation-runner. Triggered by
//   public.dispatch_email_archiver, which is itself called by the
//   automation-runner via run_internal_recipe for the Email Archiver recipe.
//
//   Flow per invocation:
//     1. Validate shared_secret against settings.automation_runner_cron_secret
//     2. Load recipe + input_config
//     3. Build (or accept) the gmail query — default archives mail older
//        than archive_older_than_days, optionally preserving starred mail
//     4. GMAIL_FETCH_EMAILS with ids_only=true to enumerate matches
//     5. GMAIL_BATCH_MODIFY_MESSAGES to remove INBOX label (= Gmail archive)
//        plus any add_archive_label_id specified
//     6. INSERT one row into public.documents per archived message
//     7. INSERT a single automation_run_log row with the real outcome
//     8. UPDATE automation_recipes.last_run_status
//
// V1 SCOPE: archive (label modify) + documents-table logging.
// DEFERRED to V2: attachment extraction, Drive folder routing
//   (BCC/Documents/YYYY-MM/<category>/), groq_classification.
//   See docs/DRIVE_FOLDER_SETUP.md for the canonical Drive structure.
//
// AUTH: verify_jwt = false; the function validates shared_secret in body.
// =========================================================================

// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const COMPOSIO_BASE = "https://backend.composio.dev/api/v3/tools/execute";

function jsonResponse(body: any, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function getSetting(agencyId: string, key: string): Promise<string | null> {
  const { data, error } = await sb.rpc("get_setting", {
    p_agency_id: agencyId,
    p_setting_key: key,
  });
  if (error) {
    throw new Error(`get_setting RPC failed for agency ${agencyId} key ${key}: ${error.message}`);
  }
  return (data as string | null) ?? null;
}

async function callComposio(opts: {
  apiKey: string;
  userId: string;
  connectedAccountId: string;
  toolSlug: string;
  toolArguments: Record<string, any>;
}): Promise<{ ok: boolean; data: any; error: string | null; httpStatus: number; raw: string }> {
  const res = await fetch(`${COMPOSIO_BASE}/${opts.toolSlug}`, {
    method: "POST",
    headers: { "x-api-key": opts.apiKey, "Content-Type": "application/json" },
    body: JSON.stringify({
      user_id: opts.userId,
      connected_account_id: opts.connectedAccountId,
      arguments: opts.toolArguments,
    }),
  });
  const text = await res.text();
  let parsed: any = {};
  try { parsed = JSON.parse(text); } catch { parsed = { raw: text }; }
  const ok = res.ok && !!parsed?.successful;
  const data = parsed?.data?.response_data ?? parsed?.data ?? null;
  const error = ok
    ? null
    : (parsed?.error?.message || parsed?.error || text.slice(0, 400));
  return { ok, data, error, httpStatus: res.status, raw: text.slice(0, 600) };
}

function buildDefaultArchiveQuery(opts: { olderThanDays: number; preserveStarred: boolean }): string {
  const parts: string[] = [
    "in:inbox",
    "-in:trash",
    "-in:spam",
    `older_than:${opts.olderThanDays}d`,
  ];
  if (opts.preserveStarred) parts.push("-is:starred");
  return parts.join(" ");
}

Deno.serve(async (req: Request) => {
  const started = Date.now();

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed. Use POST." }, 405);
  }

  let body: any = {};
  try {
    const text = await req.text();
    body = text ? JSON.parse(text) : {};
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const recipeId: string | undefined = body.recipe_id;
  const sharedSecret: string | undefined = body.shared_secret;

  if (!recipeId) return jsonResponse({ error: "Missing recipe_id" }, 400);
  if (!sharedSecret) return jsonResponse({ error: "Missing shared_secret" }, 401);

  // Load recipe to resolve agency
  const { data: recipe, error: recipeErr } = await sb
    .from("automation_recipes")
    .select("*")
    .eq("id", recipeId)
    .maybeSingle();

  if (recipeErr || !recipe) {
    return jsonResponse({ error: `Recipe ${recipeId} not found: ${recipeErr?.message || "no row"}` }, 404);
  }
  if (!recipe.agency_id) {
    return jsonResponse({ error: `Recipe ${recipeId} has no agency_id` }, 500);
  }

  const agencyId = recipe.agency_id as string;

  // Auth
  let expectedSecret: string | null;
  try {
    expectedSecret = await getSetting(agencyId, "automation_runner_cron_secret");
  } catch (err) {
    return jsonResponse({ error: `Auth lookup failed: ${(err as Error).message}` }, 500);
  }
  if (!expectedSecret || sharedSecret !== expectedSecret) {
    return jsonResponse({ error: "Unauthorized: invalid shared_secret" }, 401);
  }

  // Helper to write the run log + recipe status, always once at the end
  async function writeOutcome(status: "success" | "failed", recordsProcessed: number, summary: string, errorMessage: string | null) {
    const durationSec = Math.round((Date.now() - started) / 1000);
    await sb.from("automation_run_log").insert({
      agency_id: agencyId,
      recipe_id: recipeId,
      status,
      records_processed: recordsProcessed,
      error_message: errorMessage,
      duration_seconds: durationSec,
      output_summary: summary,
    });
    await sb.from("automation_recipes").update({ last_run_status: status }).eq("id", recipeId);
  }

  try {
    // Read input_config defaults
    const ic = (recipe.input_config || {}) as Record<string, any>;
    const olderThanDays = Number(ic.archive_older_than_days ?? 30);
    const preserveStarred = ic.preserve_starred !== false; // default true
    const maxPerRun = Math.min(Math.max(Number(ic.max_per_run ?? 100), 1), 500);
    const archiveQuery: string = typeof ic.archive_query === "string" && ic.archive_query.trim()
      ? ic.archive_query.trim()
      : buildDefaultArchiveQuery({ olderThanDays, preserveStarred });
    const addArchiveLabelId: string | null = typeof ic.add_archive_label_id === "string" && ic.add_archive_label_id.trim()
      ? ic.add_archive_label_id.trim()
      : null;

    // Credentials
    const composioApiKey = await getSetting(agencyId, "composio_api_key");
    if (!composioApiKey) throw new Error(`Missing composio_api_key in Vault/settings for agency ${agencyId}`);
    const composioUserId = await getSetting(agencyId, "composio_user_id");
    if (!composioUserId) throw new Error(`Missing composio_user_id for agency ${agencyId}`);
    const gmailAccountId = await getSetting(agencyId, "composio_gmail_account_id");
    if (!gmailAccountId) throw new Error(`Missing composio_gmail_account_id for agency ${agencyId}`);

    // --- Step 1: fetch matching message IDs (ids_only=true for speed) ---
    const fetchResult = await callComposio({
      apiKey: composioApiKey,
      userId: composioUserId,
      connectedAccountId: gmailAccountId,
      toolSlug: "GMAIL_FETCH_EMAILS",
      toolArguments: {
        query: archiveQuery,
        max_results: maxPerRun,
        ids_only: true,
        verbose: false,
        include_payload: false,
      },
    });

    if (!fetchResult.ok) {
      throw new Error(`GMAIL_FETCH_EMAILS failed (http=${fetchResult.httpStatus}): ${fetchResult.error}`);
    }

    // Response shape — messages array under data; each item has messageId
    const messages: any[] = Array.isArray(fetchResult.data?.messages) ? fetchResult.data.messages : [];

    if (messages.length === 0) {
      const summary = `0 emails match archive query "${archiveQuery}". Nothing to archive.`;
      await writeOutcome("success", 0, summary, null);
      return jsonResponse({
        ok: true,
        recipe_id: recipeId,
        recipe_name: recipe.recipe_name,
        status: "success",
        records_processed: 0,
        archive_query: archiveQuery,
        output_summary: summary,
      }, 200);
    }

    const messageIds: string[] = messages
      .map((m: any) => m?.messageId || m?.id)
      .filter((id: any) => typeof id === "string" && id.length > 0);

    if (messageIds.length === 0) {
      throw new Error(`GMAIL_FETCH_EMAILS returned ${messages.length} messages but none had a messageId field. Sample: ${JSON.stringify(messages[0]).slice(0, 200)}`);
    }

    // --- Step 2: archive (modify labels) ---
    const addLabels: string[] = addArchiveLabelId ? [addArchiveLabelId] : [];
    const removeLabels: string[] = ["INBOX"];

    const modifyResult = await callComposio({
      apiKey: composioApiKey,
      userId: composioUserId,
      connectedAccountId: gmailAccountId,
      toolSlug: "GMAIL_BATCH_MODIFY_MESSAGES",
      toolArguments: {
        messageIds,
        addLabelIds: addLabels,
        removeLabelIds: removeLabels,
      },
    });

    if (!modifyResult.ok) {
      throw new Error(`GMAIL_BATCH_MODIFY_MESSAGES failed (http=${modifyResult.httpStatus}): ${modifyResult.error}`);
    }

    // --- Step 3: log each archived message to documents ---
    const now = new Date().toISOString();
    const docRows = messages.map((m: any) => {
      const msgId = m?.messageId || m?.id || "unknown";
      const subject = (typeof m?.subject === "string" && m.subject.length > 0) ? m.subject : `(no subject) ${msgId}`;
      const notes = JSON.stringify({
        gmail_message_id: msgId,
        gmail_thread_id: m?.threadId || null,
        from: m?.from || m?.sender || null,
        date: m?.date || m?.internalDate || null,
        archive_query: archiveQuery,
        added_labels: addLabels,
        removed_labels: removeLabels,
      });
      return {
        agency_id: agencyId,
        file_name: subject.slice(0, 300),
        file_type: "email",
        upload_source: "email_archiver",
        processing_status: "archived",
        processing_type: "label_modification",
        uploaded_by: "email_archiver_edge_fn",
        uploaded_at: now,
        processed_at: now,
        notes,
      };
    });

    let docsInserted = 0;
    if (docRows.length > 0) {
      const { data: insertedDocs, error: docErr } = await sb
        .from("documents")
        .insert(docRows)
        .select("id");
      if (docErr) {
        // Don't fail the whole run if documents logging fails — the archive happened.
        // Just include this in the summary.
        const partial = `Archived ${messageIds.length} emails; documents log INSERT failed: ${docErr.message}`;
        await writeOutcome("success", messageIds.length, partial, null);
        return jsonResponse({
          ok: true,
          recipe_id: recipeId,
          recipe_name: recipe.recipe_name,
          status: "success",
          records_processed: messageIds.length,
          documents_inserted: 0,
          documents_insert_error: docErr.message,
          archive_query: archiveQuery,
          output_summary: partial,
        }, 200);
      }
      docsInserted = (insertedDocs?.length ?? 0);
    }

    const summary = `Archived ${messageIds.length} emails matching "${archiveQuery}"; ${docsInserted} rows logged to documents.`;
    await writeOutcome("success", messageIds.length, summary, null);

    return jsonResponse({
      ok: true,
      recipe_id: recipeId,
      recipe_name: recipe.recipe_name,
      status: "success",
      records_processed: messageIds.length,
      documents_inserted: docsInserted,
      archive_query: archiveQuery,
      output_summary: summary,
    }, 200);

  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    await writeOutcome("failed", 0, `Failed: ${msg.slice(0, 200)}`, msg);
    return jsonResponse({ ok: false, error: msg }, 500);
  }
});
