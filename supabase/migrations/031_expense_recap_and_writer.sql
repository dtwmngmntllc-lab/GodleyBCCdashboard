-- Migration 031: Receipts/Invoices processing chain
-- ===================================================
-- Adds the parallel chain for outflows (expenses) that mirrors
-- comp_recap + gl_entry_writer for SF compensation inflows.
--
-- New objects:
--   1. public.expense_recap table - parsed receipt/invoice header rows
--   2. public.expense_entry_writer(uuid, uuid) function - turns
--      unposted expense_recap rows into balanced journal_entries +
--      journal_lines (same pattern as gl_entry_writer)
--   3. public.parser_record_document_parse - re-created to add
--      expense_recap to the output-table allow-list AND to auto-inject
--      document_id alongside agency_id when the target table has it
--
-- Recipe rows are install-specific (hardcoded agency_id) and live in
-- a separate _godley file. This migration is portable.
--
-- Companion install file:
--   supabase/migrations/031_seed_receipts_recipes_godley.sql

-- ---------------------------------------------------------------
-- 1. expense_recap table
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.expense_recap (
  id                    uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  agency_id             uuid NOT NULL REFERENCES public.agency(id),
  document_id           uuid REFERENCES public.documents(id),
  vendor_name           text,
  entry_date            date,
  amount                numeric(12,2),
  currency              text DEFAULT 'USD',
  expense_account_code  text,
  payment_method        text,
  payment_account_code  text,
  description           text,
  memo                  text,
  raw_parse             jsonb,
  posted_at             timestamptz,
  created_at            timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expense_recap_agency_unposted
  ON public.expense_recap (agency_id) WHERE posted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_expense_recap_document
  ON public.expense_recap (document_id);

GRANT SELECT ON public.expense_recap TO anon, authenticated;
GRANT INSERT, UPDATE ON public.expense_recap TO authenticated;

-- ---------------------------------------------------------------
-- 2. expense_entry_writer
-- ---------------------------------------------------------------
-- Reads unposted expense_recap rows. For each row:
--   - Resolves the expense account by code (account_code -> id)
--   - Resolves the payment account by code, falling back to the
--     default cash account (gl_default_cash_account_name OR
--     default_cash_account_code OR '1010')
--   - Writes a balanced journal_entry (Dr expense, Cr payment)
--   - Stamps reference_number = 'expense_recap:<id>' for traceability
--   - Stamps expense_recap.posted_at to prevent reprocessing
--
-- Mirrors the structure of gl_entry_writer for inflows.
CREATE OR REPLACE FUNCTION public.expense_entry_writer(
  p_agency_id uuid,
  p_recipe_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_count        INTEGER := 0;
  v_skipped      INTEGER := 0;
  v_unposted     RECORD;
  v_expense_acct UUID;
  v_payment_acct UUID;
  v_entry_id     UUID;
  v_now          TIMESTAMPTZ := NOW();
  v_default_cash UUID;
  v_default_cash_code TEXT;
  v_default_cash_name TEXT;
BEGIN
  SELECT setting_value INTO v_default_cash_name
  FROM public.settings
  WHERE agency_id = p_agency_id AND setting_key = 'gl_default_cash_account_name'
  LIMIT 1;

  IF v_default_cash_name IS NOT NULL THEN
    SELECT id INTO v_default_cash
    FROM public.chart_of_accounts
    WHERE agency_id = p_agency_id AND account_name = v_default_cash_name
    LIMIT 1;
  END IF;

  IF v_default_cash IS NULL THEN
    SELECT setting_value INTO v_default_cash_code
    FROM public.settings
    WHERE agency_id = p_agency_id AND setting_key = 'default_cash_account_code'
    LIMIT 1;
    IF v_default_cash_code IS NULL THEN v_default_cash_code := '1010'; END IF;
    SELECT id INTO v_default_cash
    FROM public.chart_of_accounts
    WHERE agency_id = p_agency_id AND account_code = v_default_cash_code
    LIMIT 1;
  END IF;

  IF v_default_cash IS NULL THEN
    RETURN jsonb_build_object(
      'records_processed', 0,
      'output_summary', 'Skipped: no default cash account resolvable'
    );
  END IF;

  FOR v_unposted IN
    SELECT id, document_id, vendor_name, entry_date, amount,
           expense_account_code, payment_account_code, payment_method,
           description, memo
    FROM public.expense_recap
    WHERE agency_id = p_agency_id
      AND posted_at IS NULL
      AND amount IS NOT NULL
      AND amount != 0
      AND entry_date IS NOT NULL
      AND expense_account_code IS NOT NULL
    ORDER BY entry_date, id
    LIMIT 500
  LOOP
    SELECT id INTO v_expense_acct
    FROM public.chart_of_accounts
    WHERE agency_id = p_agency_id
      AND account_code = v_unposted.expense_account_code
      AND is_active = true
    LIMIT 1;

    IF v_expense_acct IS NULL THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    v_payment_acct := NULL;
    IF v_unposted.payment_account_code IS NOT NULL THEN
      SELECT id INTO v_payment_acct
      FROM public.chart_of_accounts
      WHERE agency_id = p_agency_id
        AND account_code = v_unposted.payment_account_code
        AND is_active = true
      LIMIT 1;
    END IF;
    IF v_payment_acct IS NULL THEN
      v_payment_acct := v_default_cash;
    END IF;

    INSERT INTO public.journal_entries (
      agency_id, entry_date, entry_type, source, document_id,
      description, memo, created_by, created_at
    ) VALUES (
      p_agency_id,
      v_unposted.entry_date,
      'expense',
      'expense_entry_writer',
      v_unposted.document_id,
      COALESCE(v_unposted.description,
               COALESCE(v_unposted.vendor_name, '') || ' expense'),
      v_unposted.memo,
      'expense_entry_writer',
      v_now
    )
    RETURNING id INTO v_entry_id;

    UPDATE public.journal_entries
       SET reference_number = 'expense_recap:' || v_unposted.id::text
     WHERE id = v_entry_id;

    INSERT INTO public.journal_lines (
      journal_entry_id, agency_id, account_id, debit, credit, description, created_at
    ) VALUES
      (v_entry_id, p_agency_id, v_expense_acct, v_unposted.amount, 0,
       COALESCE(v_unposted.vendor_name, 'Vendor') || ' - expense', v_now),
      (v_entry_id, p_agency_id, v_payment_acct, 0, v_unposted.amount,
       COALESCE(v_unposted.payment_method, 'cash') || ' payment', v_now);

    UPDATE public.expense_recap SET posted_at = v_now WHERE id = v_unposted.id;

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'records_processed', v_count,
    'records_skipped',   v_skipped,
    'output_summary',    v_count || ' expense journal entries written'
                        || CASE WHEN v_skipped > 0
                                THEN ' (' || v_skipped || ' skipped - expense account code not found)'
                                ELSE '' END
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.expense_entry_writer(uuid, uuid) TO anon, authenticated;

-- ---------------------------------------------------------------
-- 3. parser_record_document_parse - extend allow-list + auto-inject document_id
-- ---------------------------------------------------------------
-- Original (migration 029) had p_error as a required parameter without DEFAULT.
-- Adding DEFAULT NULL requires DROP+CREATE (Postgres rejects param-default
-- changes via CREATE OR REPLACE). DROP is safe - no policies/triggers depend
-- on this function; only the document_parser.py tool calls it via REST RPC
-- with the same arg names.

DROP FUNCTION IF EXISTS public.parser_record_document_parse(uuid, jsonb, text);

CREATE FUNCTION public.parser_record_document_parse(
  p_document_id uuid,
  p_records     jsonb,
  p_error       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_doc public.documents%ROWTYPE;
  v_recipe public.automation_recipes%ROWTYPE;
  v_records_count INT := 0;
  v_record_errors INT := 0;
  v_first_record_error TEXT := NULL;
  v_record JSONB;
  v_allowed_tables TEXT[] := ARRAY[
    'comp_recap','journal_entries','credit_transactions',
    'payroll_runs','payroll_detail','producer_production',
    'expense_recap'
  ];
  v_record_enriched JSONB;
  v_insert_columns TEXT;
  v_has_document_id BOOLEAN;
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

  SELECT string_agg(quote_ident(column_name), ',')
    INTO v_insert_columns
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name = v_recipe.output_table
     AND column_name NOT IN ('id','created_at');

  IF v_insert_columns IS NULL THEN
    RETURN jsonb_build_object('status','error','message','could not introspect columns for ' || v_recipe.output_table);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = v_recipe.output_table
       AND column_name = 'document_id'
  ) INTO v_has_document_id;

  IF jsonb_array_length(p_records) > 0 THEN
    FOR v_record IN SELECT * FROM jsonb_array_elements(p_records)
    LOOP
      v_record_enriched := jsonb_set(v_record, '{agency_id}', to_jsonb(v_doc.agency_id::text), true);
      IF v_has_document_id THEN
        v_record_enriched := jsonb_set(v_record_enriched, '{document_id}', to_jsonb(p_document_id::text), true);
      END IF;

      BEGIN
        EXECUTE format(
          'INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1) ON CONFLICT DO NOTHING',
          v_recipe.output_table,
          v_insert_columns,
          v_insert_columns,
          v_recipe.output_table
        ) USING v_record_enriched;

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
$function$;

GRANT EXECUTE ON FUNCTION public.parser_record_document_parse(uuid, jsonb, text) TO anon, authenticated;
