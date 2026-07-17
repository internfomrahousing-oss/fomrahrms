-- Bug introduced by 20260717040000: the anti-escalation trigger added
-- there (protect_app_users_sensitive_columns) pins `active` back to its
-- old value unless current_user = 'service_role' or the caller is
-- HR/Management. But complete_account_activation() / complete_password_reset()
-- / set_password_if_unset() are called by a completely anonymous, logged-out
-- visitor (the public /set-password/{token} and /reset-password/{token}
-- pages) — there's no HR/Management session, and while these functions are
-- SECURITY DEFINER, current_user inside them becomes the function's OWNER
-- (whichever role ran `create function` in the SQL Editor — typically
-- `postgres`), not literally 'service_role'. So the trigger's bypass never
-- matched, and it silently reverted `active` back to false immediately
-- after these functions tried to set it true — the password saved fine,
-- but the account stayed deactivated, so login kept failing with
-- "not_activated".
--
-- Each of these three functions already re-verifies its own authorization
-- internally (token must match and not be expired, or the account must
-- genuinely have no password set yet) before touching a row — that's the
-- whole reason 20260716000500_password_flow_rpcs.sql exists instead of
-- letting the client call a raw update. So trusting `current_user =
-- 'postgres'` here (the owner every SQL-Editor-created function runs
-- as, never exposed to anon/authenticated PostgREST callers) is safe,
-- and matches the same trust level already given to service_role.

create or replace function protect_app_users_sensitive_columns() returns trigger
language plpgsql as $$
begin
  if current_user in ('service_role', 'postgres') or current_app_is_hr_or_mgmt() then
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

-- One-off repair: nishit's account already went through Set Your Password
-- successfully (the password itself saved fine) but got silently
-- deactivated again by the bug above. Re-activate it now that the trigger
-- is fixed, so login works without needing to redo activation.
update app_users set active = true where lower(email) = 'nishit@fomrahousing.in';
