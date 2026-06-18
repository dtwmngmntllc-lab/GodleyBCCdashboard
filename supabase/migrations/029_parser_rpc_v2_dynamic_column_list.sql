
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
  v_record_errors INT := 0;
  v_first_record_error TEXT := NULL;
  v_record JSONB;
  v_allowed_tables TEXT[] := ARRAY[
    'comp_recap','journal_entries','credit_transactions',
    'payroll_runs','payroll_detail','producer_production'
  ];
  v_record_with_agency JSONB;
  v_insert_columns TEXT;
BEGIN
  SELECT * INTO v_doc FROM public.documents WHERE id = p_document_id;
  IF v_doc.id IS NULL THEN
    RETURN jsonb_build_object('status','error','message','document not found');
  END IF;

  IF p_error IS NOT NULL THEN
    UPDATE public.documents
       SET parsed_at = now(), parsed_records_count = 0, parse_error = p_error
     WHERE id = p_document_id;
    RETURN jsonb_build_object('status','error_recorded','document_id',p_document_id);
  END IF;

  SELECT * INTO v_recipe
  FROM public.automation_recipes
  WHERE agency_id = v_doc.agency_id
    AND input_config->>'fixed_category' = v_doc.groq_classification
    AND is_active = true
  LIMIT 1;

  IF v_recipe.id IS NULL OR v_recipe.output_table IS NULL THEN
    RETURN jsonb_build_object('status','error','message','no active recipe for category ' || COALESCE(v_doc.groq_classification,'NULL'));
  END IF;

  IF NOT (v_recipe.output_table = ANY(v_allowed_tables)) THEN
    RETURN jsonb_build_object('status','error','message','output_table not in allow-list: ' || v_recipe.output_table);
  END IF;

  -- Build the column list once: every column on the output table EXCEPT id and created_at
  -- so defaults fire for them. agency_id is always supplied (stamped from the document).
  SELECT string_agg(quote_ident(column_name), ',')
    INTO v_insert_columns
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name = v_recipe.output_table
     AND column_name NOT IN ('id','created_at');

  IF v_insert_columns IS NULL THEN
    RETURN jsonb_build_object('status','error','message','could not introspect columns for ' || v_recipe.output_table);
  END IF;

  IF jsonb_array_length(p_records) > 0 THEN
    FOR v_record IN SELECT * FROM jsonb_array_elements(p_records)
    LOOP
      v_record_with_agency := jsonb_set(v_record, '{agency_id}', to_jsonb(v_doc.agency_id::text), true);

      BEGIN
        EXECUTE format(
          'INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1) ON CONFLICT DO NOTHING',
          v_recipe.output_table,
          v_insert_columns,
          v_insert_columns,
          v_recipe.output_table
        ) USING v_record_with_agency;

        IF FOUND THEN
          v_records_count := v_records_count + 1;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        v_record_errors := v_record_errors + 1;
        IF v_first_record_error IS NULL THEN
          v_first_record_error := SQLERRM;
        END IF;
      END;
    END LOOP;
  END IF;

  UPDATE public.documents
     SET parsed_at = now(),
         parsed_records_count = v_records_count,
         parse_error = CASE
           WHEN v_record_errors > 0 AND v_records_count = 0 THEN
             format('all %s records failed; first error: %s', v_record_errors, v_first_record_error)
           WHEN v_record_errors > 0 THEN
             format('%s of %s records failed; first error: %s', v_record_errors, v_record_errors + v_records_count, v_first_record_error)
           ELSE NULL
         END
   WHERE id = p_document_id;

  RETURN jsonb_build_object(
    'status','success',
    'document_id',p_document_id,
    'recipe_name',v_recipe.recipe_name,
    'output_table',v_recipe.output_table,
    'records_written',v_records_count,
    'records_failed',v_record_errors,
    'first_error',v_first_record_error
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.parser_record_document_parse(UUID, JSONB, TEXT) TO anon, authenticated;
