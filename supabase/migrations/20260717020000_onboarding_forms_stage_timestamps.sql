-- The Employee Onboarding pipeline (Onboarding Received -> Forwarded to
-- Mgmt -> Mgmt Approved -> Password Created) stamps a timestamp column on
-- onboarding_forms each time a row reaches a new stage. These columns were
-- added to the app's reference schema (see the big comment block in
-- lib/services/supabase_service.dart) but never actually run against
-- production, so "Send to Management" failed with:
--   Could not find the 'forwarded_at' column of 'onboarding_forms'
-- Adding all five stage-timestamp columns at once (idempotent) so the next
-- stage doesn't hit the same wall as soon as it's reached.

alter table onboarding_forms add column if not exists forwarded_at timestamptz;
alter table onboarding_forms add column if not exists mgmt_approved_at timestamptz;
alter table onboarding_forms add column if not exists activation_sent_at timestamptz;
alter table onboarding_forms add column if not exists password_created_at timestamptz;
alter table onboarding_forms add column if not exists account_active_at timestamptz;
