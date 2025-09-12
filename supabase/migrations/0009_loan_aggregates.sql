-- ====================================================================
-- Loan Aggregates Migration
-- - Creates triggers and functions for maintaining loan aggregates
-- ====================================================================

BEGIN;

-- ------------------------------------------------
-- Aggregates & due dates: keep loans.* in sync with loan_payments
-- ------------------------------------------------

-- DEFAULT behavior: only count installments *you have checked off* (is_received=TRUE)
-- toward loans.total_amount_received. This fits a "checklist" workflow.
CREATE OR REPLACE FUNCTION recompute_loan_aggregates()
RETURNS TRIGGER AS $$
DECLARE
  v_loan_id BIGINT;
BEGIN
  v_loan_id := COALESCE(NEW.loan_id, OLD.loan_id);

  UPDATE loans l
  SET
    total_amount_received = COALESCE((
      SELECT SUM(lp.received_amount)
      FROM loan_payments lp
      WHERE lp.loan_id = v_loan_id AND lp.is_received = TRUE
    ), 0),
    next_payment_due = (
      SELECT MIN(lp.due_date)
      FROM loan_payments lp
      WHERE lp.loan_id = v_loan_id AND lp.is_received = FALSE
    ),
    expected_last_payment = (
      SELECT MAX(lp.due_date)
      FROM loan_payments lp
      WHERE lp.loan_id = v_loan_id
    ),
    last_updated = CURRENT_DATE,
    updated_at = now()
  WHERE l.id = v_loan_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to recompute loan aggregates
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_loan_payments_recompute_aggregates') THEN
    CREATE TRIGGER trg_loan_payments_recompute_aggregates
    AFTER INSERT OR UPDATE OR DELETE ON loan_payments
    FOR EACH ROW EXECUTE FUNCTION recompute_loan_aggregates();
  END IF;
END$$;

-- ALT behavior (COMMENTED OUT): count ALL cash received (including partials)
-- To use this instead, uncomment, run, and replace the trigger function above.
/*
CREATE OR REPLACE FUNCTION recompute_loan_aggregates_alt()
RETURNS TRIGGER AS $$
DECLARE
  v_loan_id BIGINT;
BEGIN
  v_loan_id := COALESCE(NEW.loan_id, OLD.loan_id);

  UPDATE loans l
  SET
    total_amount_received = COALESCE((
      SELECT SUM(COALESCE(lp.received_amount,0))
      FROM loan_payments lp
      WHERE lp.loan_id = v_loan_id
    ), 0),
    next_payment_due = (
      SELECT MIN(lp.due_date)
      FROM loan_payments lp
      WHERE lp.loan_id = v_loan_id AND lp.is_received = FALSE
    ),
    expected_last_payment = (
      SELECT MAX(lp.due_date)
      FROM loan_payments lp
      WHERE lp.loan_id = v_loan_id
    ),
    last_updated = CURRENT_DATE,
    updated_at = now()
  WHERE l.id = v_loan_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
*/

COMMIT;
