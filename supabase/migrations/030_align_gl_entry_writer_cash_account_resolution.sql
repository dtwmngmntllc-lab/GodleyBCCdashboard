-- Align gl_entry_writer cash account resolution to support both:
--   1) gl_default_cash_account_name (install blueprint key, lookup by account_name)
--   2) default_cash_account_code     (legacy key, lookup by account_code)
--   3) Fallback to account_code = '1010'
-- Rest of the function body is byte-identical to prior version.

CREATE OR REPLACE FUNCTION public.gl_entry_writer(p_agency_id uuid, p_recipe_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count           INTEGER := 0;
  v_unposted        RECORD;
  v_revenue_acct_id UUID;
  v_cash_acct_id    UUID;
  v_revenue_code    TEXT;
  v_cash_code       TEXT;
  v_cash_name       TEXT;
  v_entry_id        UUID;
  v_now             TIMESTAMPTZ := NOW();
BEGIN
  -- Cash account resolution: prefer blueprint key (by name), fall back to legacy key (by code), then '1010'.
  SELECT setting_value INTO v_cash_name
  FROM public.settings
  WHERE agency_id = p_agency_id
    AND setting_key = 'gl_default_cash_account_name'
  LIMIT 1;

  IF v_cash_name IS NOT NULL THEN
    SELECT id INTO v_cash_acct_id
    FROM public.chart_of_accounts
    WHERE agency_id = p_agency_id AND account_name = v_cash_name
    LIMIT 1;
  END IF;

  IF v_cash_acct_id IS NULL THEN
    SELECT setting_value INTO v_cash_code
    FROM public.settings
    WHERE agency_id = p_agency_id
      AND setting_key = 'default_cash_account_code'
    LIMIT 1;
    IF v_cash_code IS NULL THEN v_cash_code := '1010'; END IF;

    SELECT id INTO v_cash_acct_id
    FROM public.chart_of_accounts
    WHERE agency_id = p_agency_id AND account_code = v_cash_code
    LIMIT 1;
  END IF;

  IF v_cash_acct_id IS NULL THEN
    RETURN jsonb_build_object(
      'records_processed', 0,
      'output_summary', 'Skipped: no cash account resolvable from settings or 1010 fallback'
    );
  END IF;

  FOR v_unposted IN
    SELECT id, period_year, period_month, comp_type, comp_category, amount,
           description, is_aipp_eligible, is_scoreboard_eligible
    FROM public.comp_recap
    WHERE agency_id = p_agency_id
      AND posted_at IS NULL
      AND amount IS NOT NULL
      AND amount != 0
      AND period_year IS NOT NULL
      AND period_month IS NOT NULL
    ORDER BY period_year, period_month, id
    LIMIT 500
  LOOP
    v_revenue_code := CASE LOWER(COALESCE(v_unposted.comp_type, ''))
      WHEN 'new_business' THEN '4010'
      WHEN 'renewal'      THEN '4020'
      WHEN 'scoreboard'   THEN '4030'
      WHEN 'aipp'         THEN '4040'
      ELSE                     '4050'
    END;

    SELECT id INTO v_revenue_acct_id
    FROM public.chart_of_accounts
    WHERE agency_id = p_agency_id AND account_code = v_revenue_code
    LIMIT 1;

    IF v_revenue_acct_id IS NULL THEN
      CONTINUE;
    END IF;

    INSERT INTO public.journal_entries (
      agency_id, entry_date, entry_type, source, document_id, description, created_by, created_at
    ) VALUES (
      p_agency_id,
      MAKE_DATE(v_unposted.period_year, v_unposted.period_month, 1),
      'comp_revenue',
      'gl_entry_writer',
      NULL,
      COALESCE(v_unposted.description,
               COALESCE(v_unposted.comp_type, '') || ' ' || COALESCE(v_unposted.comp_category, '')),
      'gl_entry_writer',
      v_now
    )
    RETURNING id INTO v_entry_id;

    UPDATE public.journal_entries
    SET reference_number = 'comp_recap:' || v_unposted.id::text
    WHERE id = v_entry_id;

    INSERT INTO public.journal_lines (
      journal_entry_id, agency_id, account_id, debit, credit, description, created_at
    ) VALUES
      (v_entry_id, p_agency_id, v_cash_acct_id,    v_unposted.amount, 0,
       'Cash receipt: ' || COALESCE(v_unposted.comp_category, v_unposted.comp_type, ''), v_now),
      (v_entry_id, p_agency_id, v_revenue_acct_id, 0, v_unposted.amount,
       COALESCE(v_unposted.comp_category, v_unposted.comp_type, ''), v_now);

    UPDATE public.comp_recap SET posted_at = v_now WHERE id = v_unposted.id;

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'records_processed', v_count,
    'output_summary', v_count || ' journal entries written from comp_recap'
  );
END;
$function$;