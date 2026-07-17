-- Follow-up to 20260717050000: that migration widened
-- protect_app_users_sensitive_columns()'s bypass to
-- `current_user in ('service_role', 'postgres')`, reasoning that a
-- SECURITY DEFINER function's owner is 'postgres' on this project. It also
-- did a one-off `update app_users set active = true` for nishit, and
-- diagnosed the failure as "active got reverted, password_hash saved fine".
--
-- Reported again today: nishit logs in, already-completed password setup
-- is asked for again — i.e. password_hash is (still, or again) empty.
-- Both `active` and `password_hash` are pinned back together in the exact
-- same trigger branch, from the exact same single UPDATE statement inside
-- complete_account_activation() / complete_password_reset() /
-- set_password_if_unset() — there is no code path where one persists and
-- the other doesn't. Whatever role these SECURITY DEFINER functions
-- actually run as in production evidently still isn't matched by
-- `current_user in ('service_role', 'postgres')` (Supabase-managed
-- Postgres doesn't guarantee function owners from the SQL Editor/migration
-- runner are literally named 'postgres'), so the trigger has likely been
-- silently reverting *both* columns on every one of these calls all along
-- — the previous fix's one-off `active = true` repair masked the symptom
-- for exactly one account without fixing the mechanism.
--
-- Rather than guess another role name, these functions now set an
-- explicit, transaction-local flag before their UPDATE, and the trigger
-- trusts that flag instead of inferring trust from current_user. This
-- can't be set by an ordinary client call (set_config is only reachable
-- from inside the SECURITY DEFINER function body itself), so it doesn't
-- reopen the "anyone can rewrite their own role/pay" hole this trigger
-- exists to close.

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
         activation_token_expires_at = ''
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

-- Only succeeds if the account genuinely has no password yet — can't be
-- used to overwrite an existing password.
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

-- service_role-only sibling (not currently called by the client, but same
-- bug class — see 20260716000000_auth_foundation.sql).
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
