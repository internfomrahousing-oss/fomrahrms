-- app_users.date_of_joining was being stamped client-side (see
-- lib/pages/employee_onboarding_page.dart and administration_page.dart) at
-- the moment HR/Management approved an onboarding submission and the
-- activation email went out — not when the employee actually set their
-- password and got real access. Those two moments can be days apart, which
-- throws off everything that reads AppUser.dateOfJoining: tenure display,
-- the 6-month on-roll eligibility gate, leave-anniversary milestones.
--
-- Fix has two parts:
--   1. complete_account_activation() now stamps date_of_joining itself, in
--      the same SECURITY DEFINER update that already sets active/password —
--      this is the actual "employee got in" moment. Only fires if the
--      column is still blank, so it never clobbers a real historical date
--      someone entered by hand (e.g. the direct-add-user flow in
--      administration_page.dart, which never touches this RPC at all).
--   2. One-off backfill below for employees who already activated in the
--      past under the old (wrong) stamping — corrects them to their real
--      password_created_at, which onboarding_forms already recorded.

create or replace function complete_account_activation(p_token text, p_password text)
returns text -- the activated email, or null if the token is invalid/expired
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_email text;
begin
  select email into v_email from app_users
   where activation_token = p_token and p_token <> ''
     and (activation_token_expires_at = '' or activation_token_expires_at::timestamptz > now());
  if v_email is null then
    return null;
  end if;
  perform set_config('app.bypass_sensitive_column_protection', 'on', true);
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = '',
         active = true,
         activation_token = '',
         activation_token_expires_at = '',
         date_of_joining = case
           when date_of_joining is null or date_of_joining = ''
             then to_char(now(), 'YYYY-MM-DD')
           else date_of_joining
         end
   where email = v_email;
  return v_email;
end;
$$;

-- Backfill: correct employees who already activated under the old (wrong)
-- stamping, using the real activation timestamp onboarding_forms already
-- has. Most-recent onboarding_forms row per email wins, in case someone was
-- re-onboarded.
with latest_activation as (
  select distinct on (lower(assigned_email))
    lower(assigned_email) as email_lower,
    password_created_at
  from onboarding_forms
  where assigned_email is not null
    and password_created_at is not null
  order by lower(assigned_email), password_created_at desc
)
update app_users
   set date_of_joining = to_char(latest_activation.password_created_at, 'YYYY-MM-DD')
  from latest_activation
 where lower(app_users.email) = latest_activation.email_lower;
