-- ====================================================================
-- Loan Views Migration
-- - Creates convenience views for loan participants
-- ====================================================================

BEGIN;

-- ------------------------------------------------
-- Convenience views (query like separate role tables)
-- ------------------------------------------------
CREATE OR REPLACE VIEW loan_buyers AS
SELECT
  lp.id         AS loan_party_id,
  lp.loan_id,
  lp.contact_id,
  lp.is_primary,
  c.name,
  c.address,
  c.city,
  c.state,
  c.zip,
  c.phone,
  c.email,
  c.created_at AS contact_created_at,
  c.updated_at AS contact_updated_at
FROM loan_parties lp
JOIN contacts c ON c.id = lp.contact_id
WHERE lp.role = 'buyer';

CREATE OR REPLACE VIEW loan_sellers AS
SELECT
  lp.id         AS loan_party_id,
  lp.loan_id,
  lp.contact_id,
  lp.is_primary,
  c.name,
  c.address,
  c.city,
  c.state,
  c.zip,
  c.phone,
  c.email,
  c.created_at AS contact_created_at,
  c.updated_at AS contact_updated_at
FROM loan_parties lp
JOIN contacts c ON c.id = lp.contact_id
WHERE lp.role = 'seller';

-- ------------------------------------------------
-- Helpful comments (schema-level guidance)
-- ------------------------------------------------
COMMENT ON VIEW loan_buyers  IS 'Convenience view for buyers (role-filtered join of loan_parties and contacts).';
COMMENT ON VIEW loan_sellers IS 'Convenience view for sellers (role-filtered join of loan_parties and contacts).';

COMMIT;
