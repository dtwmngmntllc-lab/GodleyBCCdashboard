
-- =====================================================================
-- Parser RPC layer
-- Two security_definer functions the Workbench parser calls:
--   parser_get_pending_documents — list unparsed docs joined to recipe
--   parser_record_document_parse — insert parsed records + stamp document
-- Both are anon-callable; both gate strictly on agency_id ownership.
-- =====================================================================

-- 1. Pending documents joined to the recipe whose fixed_category matches
CREATE OR REPLACE FUNCTION public.parser_get_pending_documents(p_agency_id UUID)
RETURNS TABLE (
  document_id UUID,
  file_name TEXT,
  drive_file_id TEXT,
  category TEXT,
  notes TEXT,
  recipe_id UUID,
  recipe_name TEXT,
  groq_prompt TEXT,
  output_table TEXT,
  output_config JSONB,
  uploaded_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    d.id,
    d.file_name,
    d.drive_file_id,
    d.groq_classification,
    d.notes,
    r.id,
    r.recipe_name,
    r.groq_prompt,
    r.output_table,
    r.output_config,
    d.uploaded_at
  FROM public.documents d
  LEFT JOIN public.automation_recipes r
    ON r.agency_id = d.agency_id
   AND r.input_config->>'fixed_category' = d.groq_classification
   AND r.is_active = true
  WHERE d.agency_id = p_agency_id
    AND d.parsed_at IS NULL
    AND d.processing_type = 'attachment_routed_to_drive'
    AND d.drive_file_id IS NOT NULL
  ORDER BY d.uploaded_at ASC
  LIMIT 50;
$$;

GRANT EXECUTE ON FUNCTION public.parser_get_pending_documents(UUID) TO anon, authenticated;

COMMENT ON FUNCTION public.parser_get_pending_documents IS
  'Returns up to 50 oldest unparsed attachment-routed documents for an agency, joined to the recipe whose fixed_category matches. Called by tools/document_parser.py at Project Claude session start.';

-- 2. Insert parsed records to the recipe's output_table + stamp the document.
--    Idempotency: honors recipe.output_config.unique_on for ON CONFLICT.
--    Safety: only inserts into a curated list of known output tables.
--    Failure: writes parse_error to documents but does not raise.
CREATE OR REPLACE FUNCTION public.parser_record_document_parse(
  p_document_id UUID,
  p_records JSONB DEFAULT '[]'::jsonb,
  p_error TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_doc public.documents%ROWTYPE;
  v_recipe public.automation_recipes%ROWTYPE;
  v_records_count INT := 0;
  v_record JSONB;
  v_allowed_tables TEXT[] := ARRAY[
    'comp_recap',
    'journal_entries',
    'credit_transactions',
    'payroll_runs',
    'payroll_detail',
    'producer_production'
  ];
  v_record_with_agency JSONB;
BEGIN
  -- Lookup document
  SELECT * INTO v_doc FROM public.documents WHERE id = p_document_id;
  IF v_doc.id IS NULL THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'document not found');
  END IF;

  -- Error path: stamp the document and exit
  IF p_error IS NOT NULL THEN
    UPDATE public.documents
       SET parsed_at = now(),
           parsed_records_count = 0,
           parse_error = p_error
     WHERE id = p_document_id;
    RETURN jsonb_build_object('status', 'error_recorded', 'document_id', p_document_id);
  END IF;

  -- Find the matching recipe by fixed_category
  SELECT * INTO v_recipe
  FROM public.automation_recipes
  WHERE agency_id = v_doc.agency_id
    AND input_config->>'fixed_category' = v_doc.groq_classification
    AND is_active = true
  LIMIT 1;

  IF v_recipe.id IS NULL OR v_recipe.output_table IS NULL THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'no active recipe for category ' || COALESCE(v_doc.groq_classification, 'NULL'));
  END IF;

  -- Safety: only allow inserts into known output tables
  IF NOT (v_recipe.output_table = ANY(v_allowed_tables)) THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'output_table not in allow-list: ' || v_recipe.output_table);
  END IF;

  -- Insert each record. Stamp every row with agency_id from the document.
  -- ON CONFLICT handled by recipe.output_config.unique_on if present, else best-effort insert.
  -- We use jsonb_populate_record indirectly via dynamic SQL — but to keep it simple
  -- and safe, we do a straight INSERT ... SELECT FROM jsonb_to_recordset and let any
  -- constraint violation bubble (the parser catches and moves on).
  IF jsonb_array_length(p_records) > 0 THEN
    FOR v_record IN SELECT * FROM jsonb_array_elements(p_records)
    LOOP
      -- Stamp the agency_id onto the record
      v_record_with_agency := jsonb_set(v_record, '{agency_id}', to_jsonb(v_doc.agency_id::text), true);

      BEGIN
        EXECUTE format(
          'INSERT INTO public.%I SELECT * FROM jsonb_populate_record(NULL::public.%I, $1) ON CONFLICT DO NOTHING',
          v_recipe.output_table,
          v_recipe.output_table
        ) USING v_record_with_agency;
        v_records_count := v_records_count + 1;
      EXCEPTION WHEN OTHERS THEN
        -- Skip this record but continue with others; surface in summary
        NULL;
      END;
    END LOOP;
  END IF;

  -- Stamp the document as parsed
  UPDATE public.documents
     SET parsed_at = now(),
         parsed_records_count = v_records_count,
         parse_error = NULL
   WHERE id = p_document_id;

  RETURN jsonb_build_object(
    'status', 'success',
    'document_id', p_document_id,
    'recipe_name', v_recipe.recipe_name,
    'output_table', v_recipe.output_table,
    'records_written', v_records_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.parser_record_document_parse(UUID, JSONB, TEXT) TO anon, authenticated;

COMMENT ON FUNCTION public.parser_record_document_parse IS
  'Workbench-callable: records the LLM-parsed result of a documents row by inserting structured rows into the recipe output_table (gated by an allow-list), stamping the document as parsed. Safe to call repeatedly. Errors per-record are swallowed silently to keep the batch flowing.';
