-- Two things were conflated in the single 'Management' role: AUTHORITY (who
-- can approve) and RULE APPLICABILITY (which HR rules bind you). They are
-- orthogonal, and two real people need different combinations:
--
--   CEO                — full authority. No attendance (excluded from
--                        reporting entirely), no leave rules, no payroll, no
--                        fixed timing, no geofence.
--   Head of Operations — full authority, part of management, BUT leave and
--                        salary DO apply. Only timing and geofence do not.
--
-- Authority therefore stays with the role; applicability moves to explicit
-- per-employee flags. Deriving exemptions from the role string cannot express
-- the difference between these two.

create or replace function public.is_management_authority(p_role text)
returns boolean language sql immutable as $function$
  select coalesce(btrim(p_role), '') in ('Management', 'CEO');
$function$;

create or replace function public.current_app_is_hr_or_mgmt()
returns boolean language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(current_app_role(), '') in ('HR', 'Management', 'CEO');
$function$;

alter table app_users add column if not exists exempt_from_timing      boolean not null default false;
alter table app_users add column if not exists exempt_from_geofence    boolean not null default false;
alter table app_users add column if not exists exempt_from_leave_rules boolean not null default false;
alter table app_users add column if not exists exempt_from_attendance  boolean not null default false;
alter table app_users add column if not exists payroll_eligible        boolean not null default true;

comment on column app_users.exempt_from_timing      is 'No fixed working hours — never assessed for lateness or early departure.';
comment on column app_users.exempt_from_geofence    is 'No fixed base — check-in never assessed against an office radius.';
comment on column app_users.exempt_from_leave_rules is 'Not on the leave cycle: no probation cap, no permission quota or duration limits.';
comment on column app_users.exempt_from_attendance  is 'Excluded from attendance entirely, including dashboards and reports.';
comment on column app_users.payroll_eligible        is 'Appears in payroll runs.';

alter table app_users disable trigger trg_protect_app_users;
update app_users
   set role = 'CEO',
       exempt_from_timing = true, exempt_from_geofence = true,
       exempt_from_leave_rules = true, exempt_from_attendance = true,
       payroll_eligible = false
 where employee_id = 'FHIPL-01';
alter table app_users enable trigger trg_protect_app_users;

create or replace function public.is_exempt_from_leave_rules(p_employee_id text, p_employee_name text)
returns boolean language sql stable as $function$
  select coalesce(exempt_from_leave_rules, false) from app_users
   where (coalesce(p_employee_id,'') <> '' and employee_id = p_employee_id)
      or (coalesce(p_employee_id,'') =  '' and lower(btrim(name)) = lower(btrim(p_employee_name)))
   limit 1;
$function$;

create or replace view public.v_payroll_eligible_employees as
  select employee_id, name, email, department, designation, gross_pay,
         date_of_joining, onroll_confirmed_at
    from app_users where active and coalesce(payroll_eligible, true);

create or replace view public.v_attendance_tracked_employees as
  select employee_id, name, email, department, designation, role
    from app_users where active and not coalesce(exempt_from_attendance, false);

comment on view public.v_attendance_tracked_employees is
  'Employees who should appear in attendance dashboards and reports. The CEO is excluded.';

-- Renaming the role silently removed the CEO's ability to approve login email
-- changes (approve_/reject_ tested current_app_role() <> 'Management'
-- literally) and his access to attendance selfies (the storage policy
-- enumerated ARRAY['HR','Management']). Both verified broken, then routed
-- through is_management_authority() so a future management-tier role cannot
-- quietly lose powers the same way. Full bodies in 20260802000700.
