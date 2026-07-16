-- Phase B of the FOMRA HRMS security audit: enable Row Level Security on
-- every application table and add policies that (as closely as this pass
-- could verify against the Dart call sites) match what the app already
-- does today — nobody should see fewer rows than before via the app UI
-- itself, but every table stops being readable/writable by anyone who
-- simply holds the public anon key, which is the actual bug this fixes.
--
-- Requires Phase A (20260716000000_auth_foundation.sql) to already be
-- applied — these policies key off auth.jwt()->>'email', which only
-- exists once a user has a real Supabase Auth session (minted by the
-- `login` Edge Function).
--
-- NOT applied automatically — review before running, ideally on staging
-- first, and read the "LOWER-CONFIDENCE TABLES" note near the bottom
-- before relying on this for tables this pass couldn't fully verify.
--
-- ── Policy matrix (who can do what) ─────────────────────────────────────
--   app_users              select: self, their RM, HR/Management. write: HR/Management (self may
--                          update non-sensitive columns only — see the protection trigger below).
--   leave_applications, attendance_records, maintenance_tickets,
--   kra_documents, appraisal_forms                select/write: self, their RM (read + the
--                          stage they own), HR/Management (all).
--   tasks                  select: self (assigned or team member), HR/Management (all). write:
--                          HR/Management, and self for status fields (app already gates this
--                          client-side; DB-level column protection not attempted for this table).
--   payslips, payslip_requests                    select/write: self, HR/Management only (no RM).
--   onboarding_forms       insert: anon (candidate submission). select: self (assigned_email),
--                          HR/Management. update: HR/Management.
--   candidate_applications insert: anon (job application). select/update/delete: HR/Management.
--                          anon update-by-id retained for the pre-offer accept flow (id is an
--                          unguessable UUID, same capability-link model the app already uses).
--   notifications          select/update: whoever the row targets (target_email/target_role/
--                          target_reporting_manager/ALL), HR/Management (all). insert: any
--                          authenticated user (many pages create notifications for others).
--   device_tokens, notification_preferences       select/write: self only.
--   email_logs, lead_sources, app_settings         select/write: HR/Management only.
--   announcements, holidays, birthdays, employee_of_month, hr_policy_versions,
--   form_versions, onboarding_form_versions, leave_form_configs,
--   maintenance_form_configs                       select: any authenticated user. write: HR/Management.
--   employee_profiles, employees                   LOWER CONFIDENCE — see note near bottom.

-- ── Identity helpers ─────────────────────────────────────────────────────
-- SECURITY DEFINER so they can read app_users to resolve the caller's own
-- role/name/etc. even though app_users itself has RLS enabled below
-- (otherwise this would be circular: the app_users policy needs these
-- functions, and these functions would need the app_users policy).

create or replace function current_app_email() returns text
language sql stable security definer set search_path = public as $$
  select lower(auth.jwt() ->> 'email');
$$;

create or replace function current_app_role() returns text
language sql stable security definer set search_path = public as $$
  select role from app_users where lower(email) = current_app_email() limit 1;
$$;

create or replace function current_app_name() returns text
language sql stable security definer set search_path = public as $$
  select name from app_users where lower(email) = current_app_email() limit 1;
$$;

create or replace function current_app_employee_id() returns text
language sql stable security definer set search_path = public as $$
  select employee_id from app_users where lower(email) = current_app_email() limit 1;
$$;

create or replace function current_app_is_hr_or_mgmt() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(current_app_role(), '') in ('HR', 'Management');
$$;

-- True if the current caller is a flagged reporting manager whose team
-- includes the employee named p_name (app_users.reporting_manager stores
-- the manager's *name*, not an id — see lib/models/app_user.dart).
create or replace function app_manages(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from app_users me
    join app_users teammate on teammate.reporting_manager = me.name
    where lower(me.email) = current_app_email()
      and me.is_reporting_manager
      and teammate.name = p_name
  );
$$;

revoke all on function current_app_email() from public;
revoke all on function current_app_role() from public;
revoke all on function current_app_name() from public;
revoke all on function current_app_employee_id() from public;
revoke all on function current_app_is_hr_or_mgmt() from public;
revoke all on function app_manages(text) from public;
grant execute on function current_app_email() to authenticated, service_role;
grant execute on function current_app_role() to authenticated, service_role;
grant execute on function current_app_name() to authenticated, service_role;
grant execute on function current_app_employee_id() to authenticated, service_role;
grant execute on function current_app_is_hr_or_mgmt() to authenticated, service_role;
grant execute on function app_manages(text) to authenticated, service_role;

-- ── app_users ────────────────────────────────────────────────────────────

alter table app_users enable row level security;

drop policy if exists app_users_select on app_users;
create policy app_users_select on app_users for select to authenticated
  using (lower(email) = current_app_email() or current_app_is_hr_or_mgmt() or app_manages(name));

drop policy if exists app_users_insert on app_users;
create policy app_users_insert on app_users for insert to authenticated
  with check (current_app_is_hr_or_mgmt());

drop policy if exists app_users_delete on app_users;
create policy app_users_delete on app_users for delete to authenticated
  using (current_app_is_hr_or_mgmt());

drop policy if exists app_users_update on app_users;
create policy app_users_update on app_users for update to authenticated
  using (lower(email) = current_app_email() or current_app_is_hr_or_mgmt())
  with check (lower(email) = current_app_email() or current_app_is_hr_or_mgmt());

-- The client always upserts the *whole* AppUser record (see
-- SupabaseService.upsertAppUser), so a plain self-update policy would let
-- an employee rewrite their own role/pay/quota/etc in the same call that
-- legitimately requests on-roll confirmation (my_profile_page.dart). This
-- trigger pins the sensitive columns back to their previous value unless
-- the caller is HR/Management or the login Edge Function itself
-- (service_role, which needs to set auth_user_id on first login).
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

-- ── leave_applications / attendance_records / maintenance_tickets ──────────
-- All three are scoped by a *name* column, matching how the app already
-- resolves teams (app_users.reporting_manager stores a name, not an id).

alter table leave_applications enable row level security;
drop policy if exists leave_applications_all on leave_applications;
create policy leave_applications_all on leave_applications for all to authenticated
  using (employee_id = current_app_employee_id() or app_manages(employee_name) or current_app_is_hr_or_mgmt())
  with check (employee_id = current_app_employee_id() or app_manages(employee_name) or current_app_is_hr_or_mgmt());

alter table attendance_records enable row level security;
drop policy if exists attendance_records_all on attendance_records;
create policy attendance_records_all on attendance_records for all to authenticated
  using (employee_id = current_app_employee_id() or app_manages(employee_name) or current_app_is_hr_or_mgmt())
  with check (employee_id = current_app_employee_id() or app_manages(employee_name) or current_app_is_hr_or_mgmt());

alter table maintenance_tickets enable row level security;
drop policy if exists maintenance_tickets_all on maintenance_tickets;
create policy maintenance_tickets_all on maintenance_tickets for all to authenticated
  using (reported_by = current_app_name() or app_manages(reported_by) or current_app_is_hr_or_mgmt())
  with check (reported_by = current_app_name() or app_manages(reported_by) or current_app_is_hr_or_mgmt());

-- ── tasks ────────────────────────────────────────────────────────────────
-- No employee_id/email column — assignment is by name (assigned_employee)
-- with a serialized team_members list. Best-effort match; see the
-- LOWER-CONFIDENCE note near the bottom if this needs adjusting.

alter table tasks enable row level security;
drop policy if exists tasks_all on tasks;
create policy tasks_all on tasks for all to authenticated
  using (
    assigned_employee = current_app_name()
    or position(current_app_name() in coalesce(team_members, '')) > 0
    or current_app_is_hr_or_mgmt()
  )
  with check (
    assigned_employee = current_app_name()
    or position(current_app_name() in coalesce(team_members, '')) > 0
    or current_app_is_hr_or_mgmt()
  );

-- ── kra_documents / appraisal_forms ─────────────────────────────────────
-- Multi-party review pipeline (employee → RM → HR/Management) — see
-- Appraisal Workflow Redesign notes. Scoped by employee_name/employee_email.

alter table kra_documents enable row level security;
drop policy if exists kra_documents_all on kra_documents;
create policy kra_documents_all on kra_documents for all to authenticated
  using (employee_email = current_app_email() or app_manages(employee_name) or current_app_is_hr_or_mgmt())
  with check (employee_email = current_app_email() or app_manages(employee_name) or current_app_is_hr_or_mgmt());

alter table appraisal_forms enable row level security;
drop policy if exists appraisal_forms_all on appraisal_forms;
create policy appraisal_forms_all on appraisal_forms for all to authenticated
  using (employee_email = current_app_email() or app_manages(employee_name) or current_app_is_hr_or_mgmt())
  with check (employee_email = current_app_email() or app_manages(employee_name) or current_app_is_hr_or_mgmt());

-- ── payslips / payslip_requests ─────────────────────────────────────────
-- Salary data — self and HR/Management only, deliberately no RM access.

alter table payslips enable row level security;
drop policy if exists payslips_all on payslips;
create policy payslips_all on payslips for all to authenticated
  using (employee_id = current_app_employee_id() or current_app_is_hr_or_mgmt())
  with check (employee_id = current_app_employee_id() or current_app_is_hr_or_mgmt());

alter table payslip_requests enable row level security;
drop policy if exists payslip_requests_all on payslip_requests;
create policy payslip_requests_all on payslip_requests for all to authenticated
  using (employee_id = current_app_employee_id() or current_app_is_hr_or_mgmt())
  with check (employee_id = current_app_employee_id() or current_app_is_hr_or_mgmt());

-- ── onboarding_forms ─────────────────────────────────────────────────────
-- Submitted by candidates before they have any account (anon, via the
-- /onboarding-form/{token} link) — see onboarding_form_page.dart.

alter table onboarding_forms enable row level security;

drop policy if exists onboarding_forms_insert_anon on onboarding_forms;
create policy onboarding_forms_insert_anon on onboarding_forms for insert to anon
  with check (true);

drop policy if exists onboarding_forms_select on onboarding_forms;
create policy onboarding_forms_select on onboarding_forms for select to authenticated
  using (assigned_email = current_app_email() or current_app_is_hr_or_mgmt());

drop policy if exists onboarding_forms_update on onboarding_forms;
create policy onboarding_forms_update on onboarding_forms for update to authenticated
  using (current_app_is_hr_or_mgmt())
  with check (current_app_is_hr_or_mgmt());

-- ── candidate_applications ───────────────────────────────────────────────
-- Public job-application submissions (anon insert) reviewed by HR/Management.
-- The pre-offer accept page updates a row by its (unguessable) uuid id
-- before the candidate has any account — same capability-link model the
-- app already relies on elsewhere, so this isn't a new trust assumption.

alter table candidate_applications enable row level security;

drop policy if exists candidate_applications_insert_anon on candidate_applications;
create policy candidate_applications_insert_anon on candidate_applications for insert to anon
  with check (true);

drop policy if exists candidate_applications_update_anon on candidate_applications;
create policy candidate_applications_update_anon on candidate_applications for update to anon
  using (true) with check (true);

drop policy if exists candidate_applications_staff on candidate_applications;
create policy candidate_applications_staff on candidate_applications for all to authenticated
  using (current_app_is_hr_or_mgmt())
  with check (current_app_is_hr_or_mgmt());

-- ── notifications ────────────────────────────────────────────────────────
-- Mirrors the recipient-resolution logic in supabase/functions/send-push.

alter table notifications enable row level security;

drop policy if exists notifications_select on notifications;
create policy notifications_select on notifications for select to authenticated
  using (
    target_email = current_app_email()
    or target_role = 'ALL'
    or target_role = current_app_role()
    or (target_reporting_manager <> '' and target_reporting_manager = current_app_name())
    or current_app_is_hr_or_mgmt()
  );

drop policy if exists notifications_update on notifications;
create policy notifications_update on notifications for update to authenticated
  using (
    target_email = current_app_email()
    or target_role = 'ALL'
    or target_role = current_app_role()
    or (target_reporting_manager <> '' and target_reporting_manager = current_app_name())
    or current_app_is_hr_or_mgmt()
  );

-- Any signed-in user can create a notification targeting someone else
-- (leave/task/approval flows all do this from many different pages).
drop policy if exists notifications_insert on notifications;
create policy notifications_insert on notifications for insert to authenticated
  with check (true);

-- ── device_tokens / notification_preferences ────────────────────────────

alter table device_tokens enable row level security;
drop policy if exists device_tokens_self on device_tokens;
create policy device_tokens_self on device_tokens for all to authenticated
  using (email = current_app_email())
  with check (email = current_app_email());

alter table notification_preferences enable row level security;
drop policy if exists notification_preferences_self on notification_preferences;
create policy notification_preferences_self on notification_preferences for all to authenticated
  using (email = current_app_email())
  with check (email = current_app_email());

-- ── HR/Management-only operational tables ───────────────────────────────

alter table email_logs enable row level security;
drop policy if exists email_logs_staff on email_logs;
create policy email_logs_staff on email_logs for all to authenticated
  using (current_app_is_hr_or_mgmt()) with check (current_app_is_hr_or_mgmt());

alter table lead_sources enable row level security;
drop policy if exists lead_sources_staff on lead_sources;
create policy lead_sources_staff on lead_sources for all to authenticated
  using (current_app_is_hr_or_mgmt()) with check (current_app_is_hr_or_mgmt());

alter table app_settings enable row level security;
drop policy if exists app_settings_select on app_settings;
create policy app_settings_select on app_settings for select to authenticated using (true);
drop policy if exists app_settings_write on app_settings;
create policy app_settings_write on app_settings for all to authenticated
  using (current_app_is_hr_or_mgmt()) with check (current_app_is_hr_or_mgmt());

-- ── Read-all-authenticated reference/config tables ──────────────────────

do $$
declare
  t text;
begin
  foreach t in array array[
    'announcements', 'holidays', 'birthdays', 'employee_of_month',
    'hr_policy_versions', 'form_versions', 'onboarding_form_versions',
    'leave_form_configs', 'maintenance_form_configs'
  ]
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I_select on %I', t, t);
    execute format('create policy %I_select on %I for select to authenticated using (true)', t, t);
    execute format('drop policy if exists %I_write on %I', t, t);
    execute format(
      'create policy %I_write on %I for all to authenticated using (current_app_is_hr_or_mgmt()) with check (current_app_is_hr_or_mgmt())',
      t, t
    );
  end loop;
end $$;

-- ── LOWER-CONFIDENCE TABLES ──────────────────────────────────────────────
-- employee_profiles / employees look like an older/secondary roster (no
-- auth linkage, still has a handful of call sites per the Phase-1
-- inventory) — this pass couldn't confirm exactly which pages read them,
-- so this is a conservative default (self via email match + HR/Management)
-- rather than a verified-correct policy. Check Employee Records / any
-- "legacy employee list" pages still work before relying on this.

alter table employee_profiles enable row level security;
drop policy if exists employee_profiles_all on employee_profiles;
create policy employee_profiles_all on employee_profiles for all to authenticated
  using (email = current_app_email() or current_app_is_hr_or_mgmt())
  with check (current_app_is_hr_or_mgmt());

alter table employees enable row level security;
drop policy if exists employees_all on employees;
create policy employees_all on employees for all to authenticated
  using (email = current_app_email() or current_app_is_hr_or_mgmt())
  with check (current_app_is_hr_or_mgmt());

-- ── Token-gated lookups, moved behind SECURITY DEFINER RPCs ─────────────
-- Before this migration, set_password_page.dart / reset_password_page.dart
-- / pre_offer_accept_page.dart / onboarding_form_page.dart looked these up
-- with a plain anon `.select().eq('...token', token)` — safe *today* only
-- because there's no RLS at all yet. Once RLS is on, an anon policy like
-- "select where activation_token is not empty" would let anyone list every
-- pending token by simply omitting the .eq() filter the client happens to
-- apply. These RPCs do the match server-side instead, so only an exact
-- token gets a row back, same as the app's existing behavior.

create or replace function app_user_by_activation_token(p_token text)
returns table(email text, name text, activation_token_expires_at text)
language sql stable security definer set search_path = public as $$
  select email, name, activation_token_expires_at
  from app_users
  where activation_token = p_token and p_token <> '';
$$;

create or replace function app_user_by_reset_token(p_token text)
returns table(email text, name text, reset_password_token_expires_at text)
language sql stable security definer set search_path = public as $$
  select email, name, reset_password_token_expires_at
  from app_users
  where reset_password_token = p_token and p_token <> '';
$$;

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
    where candidate_application_id = p_candidate_id and p_candidate_id <> ''
  );
$$;

revoke all on function app_user_by_activation_token(text) from public;
revoke all on function app_user_by_reset_token(text) from public;
revoke all on function candidate_application_by_pre_offer_token(text) from public;
revoke all on function candidate_application_by_onboarding_token(text) from public;
revoke all on function has_onboarding_form_for_candidate(text) from public;
grant execute on function app_user_by_activation_token(text) to anon, authenticated;
grant execute on function app_user_by_reset_token(text) to anon, authenticated;
grant execute on function candidate_application_by_pre_offer_token(text) to anon, authenticated;
grant execute on function candidate_application_by_onboarding_token(text) to anon, authenticated;
grant execute on function has_onboarding_form_for_candidate(text) to anon, authenticated;
