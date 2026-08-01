-- Row-level security was DISABLED on attendance_records, leave_applications,
-- payslips, payslip_requests, tasks, kra_documents and appraisal_forms, with
-- zero policies on any of them.
--
-- The policies below were written in 20260716000100_rls_policies.sql, but that
-- migration was never applied to this database. Confirmed by logging in as an
-- ordinary employee and reading every other employee's attendance — and, more
-- seriously, every other employee's PAYSLIP. Salary data was readable and
-- writable by all staff.
--
-- Verified persona-by-persona in rolled-back transactions before applying:
--   * employees see and write only their own rows
--   * HR and Management see everything
--   * an employee checking in AS another employee is refused
--   * an employee editing another employee's payslip is refused
--   * HR issuing a payslip, HR assigning a task, an employee checking in,
--     applying for permission, and updating their own task all still work

alter table attendance_records enable row level security;
drop policy if exists attendance_records_all on attendance_records;
create policy attendance_records_all on attendance_records for all to authenticated
  using (employee_id = current_app_employee_id() or app_manages(employee_name) or current_app_is_hr_or_mgmt())
  with check (employee_id = current_app_employee_id() or app_manages(employee_name) or current_app_is_hr_or_mgmt());

alter table leave_applications enable row level security;
drop policy if exists leave_applications_all on leave_applications;
create policy leave_applications_all on leave_applications for all to authenticated
  using (employee_id = current_app_employee_id() or app_manages(employee_name) or current_app_is_hr_or_mgmt())
  with check (employee_id = current_app_employee_id() or app_manages(employee_name) or current_app_is_hr_or_mgmt());

-- Salary: self and HR/Management only. Deliberately no reporting-manager
-- access, so a manager cannot see their own team's pay.
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

alter table tasks enable row level security;
drop policy if exists tasks_all on tasks;
create policy tasks_all on tasks for all to authenticated
  using (assigned_employee = current_app_name()
      or position(current_app_name() in coalesce(team_members,'')) > 0
      or current_app_is_hr_or_mgmt())
  with check (assigned_employee = current_app_name()
      or position(current_app_name() in coalesce(team_members,'')) > 0
      or current_app_is_hr_or_mgmt());

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
