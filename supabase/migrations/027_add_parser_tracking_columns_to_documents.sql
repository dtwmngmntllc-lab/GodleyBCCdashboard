
-- Track which documents have been parsed by the workbench parser so the
-- parser can idempotently catch up on whatever's pending at session start.
ALTER TABLE public.documents
  ADD COLUMN IF NOT EXISTS parsed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS parsed_records_count INTEGER,
  ADD COLUMN IF NOT EXISTS parse_error TEXT;

-- Index supports the parser's primary query: "give me unparsed attachment rows
-- with a category I know how to handle, oldest first."
CREATE INDEX IF NOT EXISTS documents_parser_pending_idx
  ON public.documents (agency_id, groq_classification, uploaded_at)
  WHERE parsed_at IS NULL
    AND processing_type = 'attachment_routed_to_drive';

COMMENT ON COLUMN public.documents.parsed_at IS 'Set by tools/document_parser.py when the document has been LLM-parsed into its recipe output_table. NULL = pending parse.';
COMMENT ON COLUMN public.documents.parsed_records_count IS 'Number of structured rows the parser wrote to output_table for this document.';
COMMENT ON COLUMN public.documents.parse_error IS 'If non-null, the parser tried this document and failed; will retry on next run unless cleared.';
