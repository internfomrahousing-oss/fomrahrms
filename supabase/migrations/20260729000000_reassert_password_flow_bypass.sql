-- Recurring bug class in this project: every password-flow migration in
-- this directory since 20260716000500 has repeatedly needed a "fix_missing"
-- / "fix_still_blocked" follow-up because the previous fix was never
-- actually applied to production (several were explicitly marked "review
-- and run this yourself"). Reported again now: after an employee sets
-- their password via the welcome-mail /set-password/{token} link,
-- app_users.password_hash doesn't end up usable — login fails while it's
-- present, and only "works" (falls through to the needsPasswordSetup
-- re-prompt) once it's cleared. That is exactly the
-- protect_app_users_sensitive_columns() trigger silently reverting
-- password_hash (and active) back to their old values, same mechanism
-- 20260718000000 already fixed via the app.bypass_sensitive_column_protection
-- flag — meaning this production database most likely never received that
-- migration (or a later one) even though it's in this repo.
--
-- Rather than debug which exact migration is missing live, this
-- re-applies the current, correct, already-idempotent definitions of the
-- trigger and every password RPC that depends on its bypass flag, so the
-- database ends up correct regardless of which earlier migrations did or
-- didn't actually run.
--
-- IMPORTANT — this does not repair employees already stuck by this bug:
-- their activation_token was already cleared by the earlier failed
-- attempt (activation_token isn't a protected column, so that part of the
-- update always "succeeded"), which burns their original email link even
-- though password_hash/active never stuck. Anyone currently unable to log
-- in needs a fresh activation email resent (existing "resend activation"
-- action in administration_page.dart / employee_onboarding_page.dart
-- generates a brand-new token, so no manual SQL repair is needed for that
-- part) — do this after applying this migration.

create or replace function protect_app_users_sensitive_columns() returns trigger
language plpgsql as $$
begin
  if current_user in ('service_role', 'postgres')
     or current_app_is_hr_or_mgmt()
     or current_setting('app.bypass_sensitive_column_protection', true) = 'on'
  then
    return new;
  end if;
  new.role := old.role;
  new.active := old.active;
  new.employee_id := old.employee_id;
  new.leave_allocation := old.leave_allocation;
  new.gross_pay := old.gross_pay;
  new.gross_pay_pending := old.gross_pay_pending;
  new.gross_pay_requested_at := old.gross_pay_requested_at;
  new.permission_minutes_quota := old.permission_minutes_quota;
  new.permission_minutes_quota_pending := old.permission_minutes_quota_pending;
  new.permission_minutes_quota_requested_at := old.permission_minutes_quota_requested_at;
  new.is_reporting_manager := old.is_reporting_manager;
  new.is_reporting_manager_pending := old.is_reporting_manager_pending;
  new.is_reporting_manager_requested_at := old.is_reporting_manager_requested_at;
  new.business_unit := old.business_unit;
  new.business_unit_pending := old.business_unit_pending;
  new.business_unit_requested_at := old.business_unit_requested_at;
  new.work_location := old.work_location;
  new.work_location_pending := old.work_location_pending;
  new.work_location_requested_at := old.work_location_requested_at;
  new.weekly_off_day := old.weekly_off_day;
  new.weekly_off_day_pending := old.weekly_off_day_pending;
  new.weekly_off_day_requested_at := old.weekly_off_day_requested_at;
  new.reporting_manager := old.reporting_manager;
  new.reporting_manager_pending := old.reporting_manager_pending;
  new.reporting_manager_requested_at := old.reporting_manager_requested_at;
  new.password_hash := old.password_hash;
  new.auth_user_id := old.auth_user_id;
  return new;
end;
$$;

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

create or replace function complete_password_reset(p_token text, p_password text)
returns text -- the reset email, or null if the token is invalid/expired
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_email text;
begin
  select email into v_email from app_users
   where reset_password_token = p_token and p_token <> ''
     and (reset_password_token_expires_at = '' or reset_password_token_expires_at::timestamptz > now());
  if v_email is null then
    return null;
  end if;
  perform set_config('app.bypass_sensitive_column_protection', 'on', true);
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = '',
         reset_password_token = '',
         reset_password_token_expires_at = ''
   where email = v_email;
  return v_email;
end;
$$;

-- Only succeeds if the account genuinely has no password yet.
create or replace function set_password_if_unset(p_email text, p_password text)
returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform set_config('app.bypass_sensitive_column_protection', 'on', true);
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = ''
   where lower(email) = lower(p_email)
     and (password_hash is null or password_hash = '');
  return found;
end;
$$;

-- service_role-only sibling (not currently called by the client).
create or replace function set_app_user_password(p_email text, p_password text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform set_config('app.bypass_sensitive_column_protection', 'on', true);
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = ''
   where lower(email) = lower(p_email);
end;
$$;

revoke all on function complete_account_activation(text, text) from public;
revoke all on function complete_password_reset(text, text) from public;
revoke all on function set_password_if_unset(text, text) from public;
revoke all on function set_app_user_password(text, text) from public, anon, authenticated;
grant execute on function complete_account_activation(text, text) to anon, authenticated;
grant execute on function complete_password_reset(text, text) to anon, authenticated;
grant execute on function set_password_if_unset(text, text) to anon, authenticated;
grant execute on function set_app_user_password(text, text) to service_role;
