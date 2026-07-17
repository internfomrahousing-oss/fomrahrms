-- The pre-offer accept page (/pre-offer/{token}) and onboarding form page
-- (/onboarding-form/{token}) depend on these three functions to look
-- themselves up by their public, unguessable token — but they were only
-- ever defined inside 20260716000100_rls_policies.sql, a migration marked
-- "review before running" that was never actually applied to production.
-- That left every pre-offer/onboarding link permanently showing "Invalid
-- or Expired Link", even though the token itself was being saved to
-- candidate_applications correctly.
--
-- This migration adds just these three lookup functions on their own —
-- unlike 20260716000100_rls_policies.sql, it does NOT enable row level
-- security on any table, so it's safe to run immediately without the
-- wider review that full migration still needs. SECURITY DEFINER means
-- these bypass RLS regardless of whether/when that broader migration is
-- eventually applied, so there's no ordering dependency either way.

create or replace function candidate_application_by_pre_offer_token(p_token text)
returns setof candidate_applications
language sql stable security definer set search_path = public as $$
  select * from candidate_applications where pre_offer_token = p_token and p_token <> '';
$$;

create or replace function candidate_application_by_onboarding_token(p_token text)
returns setof candidate_applications
language sql stable security definer set search_path = public as $$
  select * from candidate_applications where onboarding_token = p_token and p_token <> '';
$$;

create or replace function has_onboarding_form_for_candidate(p_candidate_id text)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from onboarding_forms
    where candidate_application_id::text = p_candidate_id and p_candidate_id <> ''
  );
$$;

revoke all on function candidate_application_by_pre_offer_token(text) from public;
revoke all on function candidate_application_by_onboarding_token(text) from public;
revoke all on function has_onboarding_form_for_candidate(text) from public;
grant execute on function candidate_application_by_pre_offer_token(text) to anon, authenticated;
grant execute on function candidate_application_by_onboarding_token(text) to anon, authenticated;
grant execute on function has_onboarding_form_for_candidate(text) to anon, authenticated;
