-- Root cause of the activation-token save failing silently (and by
-- extension, anything else that updates app_users, e.g. deleting a
-- Staff Portal user): RLS is enabled on app_users, but only 2 of the 4
-- policies from 20260716000100_rls_policies.sql actually got created —
-- app_users_select and app_users_insert exist; app_users_update and
-- app_users_delete do not. With no UPDATE policy at all, every update
-- (regardless of who runs it) is silently blocked by RLS's default-deny —
-- confirmed via:
--   select policyname, cmd from pg_policies where tablename = 'app_users';
-- returning only app_users_insert and app_users_select.
--
-- This adds just the two missing policies plus the trigger that's
-- supposed to accompany the update policy — without it, self-updates
-- (lower(email) = current_app_email()) would let an employee rewrite
-- their own role/pay/leave-allocation/etc in the same call the app
-- already makes for harmless self-service edits (see
-- SupabaseService.upsertAppUser, which always upserts the whole record).

drop policy if exists app_users_delete on app_users;
create policy app_users_delete on app_users for delete to authenticated
  using (current_app_is_hr_or_mgmt());

drop policy if exists app_users_update on app_users;
create policy app_users_update on app_users for update to authenticated
  using (lower(email) = current_app_email() or current_app_is_hr_or_mgmt())
  with check (lower(email) = current_app_email() or current_app_is_hr_or_mgmt());

create or replace function protect_app_users_sensitive_columns() returns trigger
language plpgsql as $$
begin
  if current_user = 'service_role' or current_app_is_hr_or_mgmt() then
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

drop trigger if exists trg_protect_app_users on app_users;
create trigger trg_protect_app_users
  before update on app_users
  for each row execute function protect_app_users_sensitive_columns();
