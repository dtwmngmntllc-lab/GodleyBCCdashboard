-- V2 monthly_close_monitor: adds template auto-creation.
-- Existing behavior (overdue alerting) preserved verbatim.
-- New behavior: at the end of each run, ensure that template rows exist for
-- the current calendar month's period and the next calendar month's period,
-- using the agency's most recent existing period as the template. Per-doc
-- expected_by preserves day-of-month relative to the period start, clipped
-- to the last day of the destination month for edge cases (e.g. Jan 31 -> Feb 28).
-- If no existing rows are found for the agency, template seeding is skipped
-- (intake not yet completed).

CREATE OR REPLACE FUNCTION public.monthly_close_monitor(p_agency_id uuid, p_recipe_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_today          DATE := CURRENT_DATE;
  v_alert_count    INTEGER := 0;
  v_template_count INTEGER := 0;
  v_item           RECORD;
  v_tpl            RECORD;
  v_target         RECORD;
  v_template_year  INTEGER;
  v_template_month INTEGER;
  v_month_lag      INTEGER;
  v_tgt_exp_start  DATE;
  v_tgt_exp_end    DATE;
  v_tgt_day        INTEGER;
  v_tgt_exp        DATE;
BEGIN
  -- ============ 1. Overdue alerting (unchanged from V1) ============
  FOR v_item IN
    SELECT id, doc_category, doc_label, period_year, period_month, expected_by
    FROM public.monthly_close_checklist
    WHERE agency_id = p_agency_id
      AND status = 'expected'
      AND received_at IS NULL
      AND expected_by IS NOT NULL
      AND expected_by < v_today
  LOOP
    INSERT INTO public.alerts (
      agency_id, alert_type, severity, title, message, module_reference, is_read, is_resolved, created_at
    )
    SELECT p_agency_id, 'monthly_close_overdue', 'warning',
           'Overdue: ' || v_item.doc_label || ' (' || v_item.period_year || '-' || LPAD(v_item.period_month::text, 2, '0') || ')',
           'Expected by ' || v_item.expected_by || '. Still not received.',
           'monthly_close_monitor:' || v_item.id::text,
           false, false, NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM public.alerts
      WHERE agency_id = p_agency_id
        AND module_reference = 'monthly_close_monitor:' || v_item.id::text
        AND is_resolved = false
    );
    v_alert_count := v_alert_count + 1;
  END LOOP;

  -- ============ 2. Template auto-creation (V2) ============
  -- Find the agency's most recent period to use as the template.
  SELECT period_year, period_month
  INTO v_template_year, v_template_month
  FROM public.monthly_close_checklist
  WHERE agency_id = p_agency_id
  ORDER BY period_year DESC, period_month DESC
  LIMIT 1;

  IF v_template_year IS NOT NULL THEN
    -- Ensure both the current month's period and next month's period exist.
    FOR v_target IN
      SELECT
        EXTRACT(YEAR FROM target_first)::int  AS tgt_year,
        EXTRACT(MONTH FROM target_first)::int AS tgt_month
      FROM (
        SELECT date_trunc('month', v_today)::date AS target_first
        UNION ALL
        SELECT (date_trunc('month', v_today) + INTERVAL '1 month')::date
      ) t
    LOOP
      -- Skip if this target period already has rows
      IF EXISTS (
        SELECT 1 FROM public.monthly_close_checklist
        WHERE agency_id = p_agency_id
          AND period_year = v_target.tgt_year
          AND period_month = v_target.tgt_month
      ) THEN
        CONTINUE;
      END IF;

      -- Copy template rows for this target period, preserving doc_category,
      -- doc_label, month-lag of expected_by, and day-of-month.
      FOR v_tpl IN
        SELECT doc_category, doc_label, expected_by, period_year, period_month
        FROM public.monthly_close_checklist
        WHERE agency_id = p_agency_id
          AND period_year = v_template_year
          AND period_month = v_template_month
      LOOP
        v_tgt_exp := NULL;
        IF v_tpl.expected_by IS NOT NULL THEN
          -- Calendar-month difference between template period and template expected_by
          v_month_lag := (EXTRACT(YEAR FROM v_tpl.expected_by)::int * 12 + EXTRACT(MONTH FROM v_tpl.expected_by)::int)
                         - (v_tpl.period_year * 12 + v_tpl.period_month);
          -- Start-of-month for target's expected_by
          v_tgt_exp_start := (make_date(v_target.tgt_year, v_target.tgt_month, 1) + (v_month_lag || ' months')::interval)::date;
          -- Last day of that month
          v_tgt_exp_end := (v_tgt_exp_start + INTERVAL '1 month' - INTERVAL '1 day')::date;
          -- Clip day-of-month to last day of destination month (e.g. Jan 31 -> Feb 28)
          v_tgt_day := LEAST(
            EXTRACT(DAY FROM v_tpl.expected_by)::int,
            EXTRACT(DAY FROM v_tgt_exp_end)::int
          );
          v_tgt_exp := v_tgt_exp_start + (v_tgt_day - 1);
        END IF;

        INSERT INTO public.monthly_close_checklist (
          agency_id, period_year, period_month,
          doc_category, doc_label, expected_by, status, is_closed, notes
        ) VALUES (
          p_agency_id, v_target.tgt_year, v_target.tgt_month,
          v_tpl.doc_category, v_tpl.doc_label, v_tgt_exp,
          'expected', false,
          'auto-seeded from ' || v_tpl.period_year || '-' || LPAD(v_tpl.period_month::text, 2, '0') || ' template on ' || v_today
        );
        v_template_count := v_template_count + 1;
      END LOOP;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'records_processed', v_alert_count + v_template_count,
    'alerts_created', v_alert_count,
    'template_rows_created', v_template_count,
    'output_summary',
      v_alert_count || ' overdue close items flagged; '
      || v_template_count || ' template rows auto-created'
  );
END;
$function$;