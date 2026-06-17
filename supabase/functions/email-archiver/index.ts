// =========================================================================
// email-archiver  (BCC Master Template — multi-step Composio orchestration)
// =========================================================================
// PURPOSE: Archive older Gmail messages and log them to the documents table.
//   This is a multi-step workflow (fetch IDs -> modify labels -> log) that
//   can't be expressed in the generic automation-runner. Triggered by
//   public.dispatch_email_archiver, which is itself called by the
//   automation-runner via run_internal_recipe for the Email Archiver recipe.
//
// =========================================================================
// V1 SCOPE (default, input_config.route_attachments_to_drive = false):
//   1. Validate shared_secret against settings.automation_runner_cron_secret
//   2. Load recipe + input_config
//   3. Build (or accept) the gmail query — default archives mail older
//      than archive_older_than_days, optionally preserving starred mail
//   4. GMAIL_FETCH_EMAILS with ids_only=true to enumerate matches
