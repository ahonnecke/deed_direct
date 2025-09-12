-- ====================================================================
-- Loan Types Migration
-- - Creates custom ENUM types for loan system
-- ====================================================================

BEGIN;

-- ------------------------------------------------
-- Types
-- ------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'loan_party_role') THEN
    CREATE TYPE loan_party_role AS ENUM ('buyer','seller','cosigner','guarantor','servicer');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interest_method_type') THEN
    CREATE TYPE interest_method_type AS ENUM ('fixed','compounding');
  END IF;
END$$;

COMMIT;
