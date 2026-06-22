-- Migration 031 (install-specific, Godley): seed Receipts Processor + Expense Entry Writer recipes
-- ===============================================================================================
-- Run ONLY on the Godley install. Insert order:
--   1. Receipts Processor - parser-driven (no cron), fires when a document
--      lands in the queue with groq_classification='receipts'. Writes to
--      expense_recap via parser_record_document_parse.
--   2. Expense Entry Writer - internal cron recipe, runs daily at 17:00 UTC
--      (one hour after the canonical GL Entry Writer). Reads unposted
--      expense_recap rows and writes balanced journal_entries + journal_lines.
--
-- For other installs: copy this template, replace the agency_id, ship as a
-- new "<NN>_seed_receipts_recipes_<client>.sql" migration.

INSERT INTO public.automation_recipes (
  agency_id, recipe_name, recipe_description,
  trigger_type, cron_expression,
  composio_action, composio_connection,
  groq_prompt,
  input_config, output_table, output_config,
  internal_handler, is_active
)
SELECT
  '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::uuid,
  'Receipts Processor',
  'Parses receipt and invoice PDFs from the documents queue into expense_recap. Triggered by the session-startup parser when a document arrives classified as receipts.',
  'parser_only',
  NULL,
  'INTERNAL',
  NULL,
  E'You are parsing a single receipt or invoice PDF for a State Farm insurance agency. Extract structured expense data.\n\nReturn a JSON array with a SINGLE record (one receipt = one expense entry). The record must follow this schema EXACTLY:\n\n{\n  "vendor_name":         "<merchant or payee name>",\n  "entry_date":          "YYYY-MM-DD",\n  "amount":              <numeric total in USD, positive number>,\n  "currency":            "USD",\n  "expense_account_code": "<code from chart of accounts - see list below>",\n  "payment_method":      "<one of: cash, credit_card, check, bank_transfer, unknown>",\n  "payment_account_code": "<account code OR null - see rules below>",\n  "description":         "<short, human-readable, e.g. ''''Office Depot - Q3 paper supplies''''>",\n  "memo":                "<line items or itemization if available, else null>",\n  "raw_parse":           { "notes": "any extra detail useful for audit" }\n}\n\nEXPENSE ACCOUNT SELECTION - pick the BEST single code from this list. If nothing fits, use 6950 (Miscellaneous Expense):\n\n  6210 Rent / Lease\n  6220 Utilities\n  6240 Repairs and Maintenance\n  6310 Software Subscriptions - SaaS\n  6311 Claude.ai Subscription\n  6312 Supabase\n  6313 Composio\n  6314 Agency Management System\n  6315 Other Software\n  6320 Phone & Internet\n  6330 Computer Equipment\n  6340 IT Support\n  6410 Digital Advertising\n  6420 Print Advertising\n  6430 Promotional Items / Giveaways\n  6440 Sponsorships & Donations\n  6450 Client Events & Entertainment\n  6460 Social Media & Content Tools\n  6470 Website Hosting & Domain\n  6510 Accounting & Bookkeeping\n  6520 Legal Fees\n  6530 Consulting Fees\n  6540 Payroll Processing Fees\n  6610 E&O Insurance\n  6620 General Liability Insurance\n  6710 License Renewal Fees\n  6720 Continuing Education\n  6730 Training & Development\n  6740 SF Conference & Travel\n  6750 Books & Publications\n  6810 Mileage Reimbursement\n  6830 Vehicle Insurance\n  6840 Fuel & Maintenance\n  6850 Business Travel\n  6860 Meals & Entertainment\n  6910 Office Supplies\n  6920 Postage & Shipping\n  6930 Printing & Copying\n  6940 Bank Fees & Charges\n  6950 Miscellaneous Expense\n\nPAYMENT METHOD / ACCOUNT RULES:\n- If the receipt explicitly says PAID BY VISA/MC/AMEX/CARD or shows a credit card transaction -> payment_method="credit_card", payment_account_code=null (writer defaults to the agency cash account if no card account matches).\n- If receipt says PAID BY CHECK or shows a check number -> payment_method="check", payment_account_code=null.\n- If receipt shows ACH/WIRE/EFT -> payment_method="bank_transfer", payment_account_code=null.\n- If cash or unclear -> payment_method="cash" or "unknown", payment_account_code=null.\n\nGUARDRAILS:\n- Output ONE record per document, not multiple line items.\n- amount must be the receipt TOTAL (including tax, shipping), as a positive number.\n- Do not invent dates or amounts. If you cannot confidently extract entry_date or amount, return an empty array []. NO partial records.\n- Return ONLY the JSON array. No prose, no markdown fences.',
  '{"fixed_category":"receipts"}'::jsonb,
  'expense_recap',
  '{"unique_on":["agency_id","document_id"],"on_conflict":"skip"}'::jsonb,
  NULL,
  true
WHERE NOT EXISTS (
  SELECT 1 FROM public.automation_recipes
  WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::uuid
    AND recipe_name = 'Receipts Processor'
);

INSERT INTO public.automation_recipes (
  agency_id, recipe_name, recipe_description,
  trigger_type, cron_expression,
  composio_action, composio_connection,
  groq_prompt,
  input_config, output_table, output_config,
  internal_handler, is_active
)
SELECT
  '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::uuid,
  'Expense Entry Writer',
  'Reads unposted expense_recap rows, resolves expense and payment accounts from chart_of_accounts, writes balanced journal_entries + journal_lines, stamps posted_at. Runs daily after GL Entry Writer.',
  'cron',
  '0 17 * * *',
  'INTERNAL',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  'expense_entry_writer',
  true
WHERE NOT EXISTS (
  SELECT 1 FROM public.automation_recipes
  WHERE agency_id = '0b8a0268-6b30-4e77-a40a-bc8ee77b5a6c'::uuid
    AND recipe_name = 'Expense Entry Writer'
);
