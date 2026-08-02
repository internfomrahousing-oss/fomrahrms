-- REVERT of the role='CEO' change in 20260802000600.
--
-- Setting role = 'CEO' in the database broke the CEO's access in the LIVE app.
-- The deployed build's userRoleFor() had no 'ceo' case and fell through to
--   default: return UserRole.employee;
-- so the CEO was logged in as an ordinary EMPLOYEE — no Administration, no
-- Employee Management, no Add Employee, and the employee shell's own
-- My Attendance / My Leave pages instead.
--
-- The database was changed ahead of the code that understood it.
--
-- The 'CEO' role string is not needed for behaviour. Every CEO-specific rule
-- hangs off explicit columns — oversight_only, exempt_from_attendance,
-- exempt_from_timing, exempt_from_geofence, exempt_from_leave_rules,
-- payroll_eligible — which work regardless of the role string. Role carries
-- AUTHORITY; the flags carry APPLICABILITY. The designation says "Chief
-- Executive Officer", which displays correctly and cannot break a role guard.
--
-- userRoleFor() now maps 'ceo' -> UserRole.management, so the string is safe
-- to use once that build is deployed. There is no functional need to.
alter table app_users disable trigger trg_protect_app_users;

update app_users
   set role        = 'Management',
       designation = 'Chief Executive Officer'
 where oversight_only and role = 'CEO';

-- Ronak (Head of Operations) had no reporting manager, so his own leave would
-- have had no approver — app_manages() joins on reporting_manager and an empty
-- value matches nobody. The CEO approves his leave.
--
-- Approving someone else's leave is oversight, so this does not conflict with
-- oversight_only: that blocks the CEO's OWN self-service pages, not the
-- approval queues.
update app_users
   set reporting_manager = 'Sharad Fomra'
 where employee_id = 'FHIPL-10'
   and coalesce(btrim(reporting_manager),'') = '';

alter table app_users enable trigger trg_protect_app_users;
