"""
BCC Document Parser — runs in Composio Workbench at session start
==================================================================

Catches up any documents that landed in the BCC's Drive folder but
haven't yet been parsed into structured rows. Idempotent and safe to
run multiple times.

WHY THIS LIVES HERE (not in an Edge Function):
  The free Composio invoke_llm helper is only reachable from inside a
  Workbench Python session. Edge Functions can't call it over HTTP
  (workbench gates on the MCP tool-router protocol). So PDF/email
  parsing runs at the start of each Project Claude session — driven
  by the system prompt — rather than on a pg_cron tick.

DATA FLOW:
  1. pg_cron + Edge Functions route emails/attachments into Drive
     and write `documents` metadata rows (this already runs unattended)
  2. THIS SCRIPT picks up rows with parsed_at IS NULL, parses them
     via invoke_llm using each row's matching recipe groq_prompt,
     and inserts structured rows into the recipe's output_table

USAGE (from a Workbench cell):
  exec(open('document_parser.py').read())
  run_parser(agency_id='0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c')

OUTPUT:
  A single-line summary string the system prompt instructs Project
  Claude to surface as part of its session-start greeting. Silent
  if nothing was pending.
"""

import json
import urllib.request
import urllib.parse


# ----------------------------------------------------------------------
# Tiny Supabase REST client (anon — RPCs are security_definer)
# ----------------------------------------------------------------------

def _supabase_rpc(supabase_url, anon_key, fn_name, params):
    """Call a Supabase RPC function. Returns parsed JSON or raises."""
    url = f"{supabase_url}/rest/v1/rpc/{fn_name}"
    req = urllib.request.Request(
        url,
        method="POST",
        headers={
            "apikey": anon_key,
            "Authorization": f"Bearer {anon_key}",
            "Content-Type": "application/json",
        },
        data=json.dumps(params).encode("utf-8"),
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = resp.read().decode("utf-8")
        return json.loads(body) if body else None


# ----------------------------------------------------------------------
# LLM response cleanup
# ----------------------------------------------------------------------

def _strip_json_fences(text):
    """Strip ```json / ``` fences and stray prose from an LLM response."""
    s = text.strip()
    if s.startswith("```"):
        nl = s.find("\n")
        s = s[nl + 1:] if nl != -1 else s[3:]
        if s.endswith("```"):
            s = s[:-3]
    return s.strip()


def _extract_records(llm_response):
    """Parse the LLM's response into a list of record dicts."""
    cleaned = _strip_json_fences(llm_response)
    parsed = json.loads(cleaned)
    if isinstance(parsed, list):
        return parsed
    if isinstance(parsed, dict):
        recs = parsed.get("records")
        if isinstance(recs, list):
            return recs
        return [parsed]
    return []


# ----------------------------------------------------------------------
# Per-document processing
# ----------------------------------------------------------------------

def _download_and_extract(drive_file_id, file_name):
    """Download a file from Drive into the sandbox and extract its text."""
    _run_composio_tool = globals().get("run_composio_tool")
    _smart_file_extract = globals().get("smart_file_extract")
    if _run_composio_tool is None or _smart_file_extract is None:
        return None, "Workbench helpers not available (run inside Composio Workbench)"

    dl_result, dl_err = _run_composio_tool(
        "GOOGLEDRIVE_DOWNLOAD_FILE",
        {"file_id": drive_file_id},
    )
    if dl_err:
        return None, f"Drive download: {dl_err}"

    sandbox_path = None
    data = dl_result.get("data", {}) if isinstance(dl_result, dict) else {}
    for key in ("file_path", "local_path", "path", "downloaded_file"):
        if data.get(key):
            sandbox_path = data[key]
            break
    if not sandbox_path:
        return None, f"Drive download succeeded but no local path returned (raw={str(dl_result)[:200]})"

    text, ext_err = _smart_file_extract(sandbox_path, show_preview=False)
    if ext_err:
        return None, f"Text extract: {ext_err}"
    return text, None


def _parse_one(doc):
    """Parse a single document. Returns (records, error)."""
    _invoke_llm = globals().get("invoke_llm")
    if _invoke_llm is None:
        return None, "invoke_llm not available (run inside Composio Workbench)"

    text, dl_err = _download_and_extract(doc["drive_file_id"], doc["file_name"])
    if dl_err:
        return None, dl_err

    truncated = text[:60000] if text else ""

    prompt = (
        f"{doc['groq_prompt']}\n\n"
        "Return ONLY a JSON object of shape "
        '{"records": [...]} where each record is a row ready to insert. '
        'Return {"records": []} if nothing applicable. '
        "No prose, no markdown fences.\n\n"
        f"Document content:\n{truncated}"
    )

    response, llm_err = _invoke_llm(prompt)
    if llm_err:
        return None, f"LLM: {llm_err}"

    try:
        records = _extract_records(response)
    except Exception as e:
        return None, f"JSON parse: {str(e)[:200]}"

    return records, None


# ----------------------------------------------------------------------
# Public entry point
# ----------------------------------------------------------------------

def run_parser(
    agency_id,
    supabase_url="https://vhcgxwkkgfvxgrksfote.supabase.co",
    anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoY2d4d2trZ2Z2eGdya3Nmb3RlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyMDg1MzMsImV4cCI6MjA5Njc4NDUzM30.pI_XVaOnKLuBseCM7DqgVVIl_IVp9SSZhza8U6hb_RE",
    verbose=False,
):
    """Parse all pending documents for the agency."""
    pending = _supabase_rpc(
        supabase_url, anon_key,
        "parser_get_pending_documents",
        {"p_agency_id": agency_id},
    )

    if not pending:
        return "Document parser: nothing pending."

    parsed_ok = 0
    rows_written = 0
    failed = 0
    no_recipe = 0

    for doc in pending:
        if not doc.get("recipe_id"):
            no_recipe += 1
            if verbose:
                print(f"  skip (no recipe for category={doc['category']}): {doc['file_name']}")
            continue

        records, err = _parse_one(doc)

        if err:
            failed += 1
            if verbose:
                print(f"  FAIL: {doc['file_name']} — {err}")
            try:
                _supabase_rpc(
                    supabase_url, anon_key,
                    "parser_record_document_parse",
                    {
                        "p_document_id": doc["document_id"],
                        "p_records": [],
                        "p_error": err[:500],
                    },
                )
            except Exception:
                pass
            continue

        try:
            result = _supabase_rpc(
                supabase_url, anon_key,
                "parser_record_document_parse",
                {
                    "p_document_id": doc["document_id"],
                    "p_records": records,
                },
            )
            written = (result or {}).get("records_written", 0)
            parsed_ok += 1
            rows_written += written
            if verbose:
                print(f"  OK: {doc['file_name']} → {written} rows in {result.get('output_table')}")
        except Exception as e:
            failed += 1
            if verbose:
                print(f"  WRITE FAIL: {doc['file_name']} — {e}")

    parts = []
    if parsed_ok:
        parts.append(f"Parsed {parsed_ok} document(s) — {rows_written} new row(s) written")
    if no_recipe:
        parts.append(f"{no_recipe} document(s) had no matching active recipe")
    if failed:
        parts.append(f"{failed} document(s) failed (will retry next session)")
    if not parts:
        return "Document parser: nothing pending."
    return "Document parser: " + "; ".join(parts) + "."
