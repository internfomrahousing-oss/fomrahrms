-- Ronak — Head of Operations. Management authority, so he approves at the
-- final stage alongside the CEO. Unlike the CEO, leave and salary DO apply;
-- only fixed timing and geofencing do not.
--
-- Management has no department, so it is left blank deliberately — the timing
-- exemption means it is never used to resolve office hours anyway.
--
-- Joined 07/04/2007, so long past probation: onroll_confirmed_at is set to the
-- joining date and EL accrues from then (start_el_on_confirmation only fires
-- on UPDATE, so it is set explicitly here).
--
-- employee_id left blank so assign_employee_id() generates the next one.
-- active is false: he sets his own password via the activation email, sent by
-- HR from Administration -> Resend Activation Email.
insert into app_users (
  name, email, company_email, role, designation, department,
  date_of_joining, onroll_confirmed_at, el_eligible_at,
  employee_id, active, password_hash,
  exempt_from_timing, exempt_from_geofence,
  exempt_from_leave_rules, exempt_from_attendance, payroll_eligible,
  leave_allocation, permission_minutes_quota, weekly_off_day,
  business_unit, reporting_manager, is_reporting_manager)
select 'Ronak', 'ronak@fomrahousing.in', 'ronak@fomrahousing.in',
  'Management', 'Head of Operations', '',
  '2007-04-07', '2007-04-07', '2007-04-07',
  '', false, null,
  true, true,          -- exempt: fixed timing, geofence
  false, false, true,  -- leave rules, attendance and payroll all APPLY
  21, 120, '', 'FOMRA Housing', '', true
where not exists (select 1 from app_users where lower(email) = 'ronak@fomrahousing.in');

-- Jose reported to "ronak", who did not exist, so his approvals had no owner.
-- Now the reference resolves; align spelling because app_manages() joins on name.
alter table app_users disable trigger trg_protect_app_users;
update app_users set reporting_manager = 'Ronak'
 where lower(btrim(reporting_manager)) = 'ronak';

-- Saurabh has been on the Unrestricted policy since the geofences were set up
-- (he moves between sites), but exempt_from_geofence defaulted to false, so
-- intent and behaviour disagreed. Align the flag to the policy in force.
update app_users set exempt_from_geofence = true where employee_id = 'FD-01';
alter table app_users enable trigger trg_protect_app_users;

-- exempt_from_geofence is the intent; the running check still reads
-- attendance_policy_employee_overrides. Keep them in step — an exempt employee
-- with no location assigned is otherwise read as "outside everywhere", which
-- demands a written reason on every check-in.
insert into attendance_policy_employee_overrides (employee_id, policy_id)
select u.employee_id, p.id from app_users u
  cross join attendance_policies p
 where p.name = 'Unrestricted Check-in' and u.exempt_from_geofence
on conflict (employee_id) do update set policy_id = excluded.policy_id;
