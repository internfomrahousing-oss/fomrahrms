-- Office Timings switches from per-designation to per-department
-- assignment, matching how Location Management already assigns attendance
-- policies (see 20260718030000_location_management.sql's
-- attendance_policies, keyed on department). The office_timings table
-- itself (the named schedules: check-in/out, grace, working hours) is
-- unchanged — only what an assignment is keyed on changes.
--
-- designation_office_timings is dropped rather than migrated: a
-- designation ("Manager") doesn't map onto a department ("Sales") in any
-- mechanical way, so there's no sound way to carry old assignments over.
-- Every department starts back on the default timing until HR reassigns.

create table if not exists department_office_timings (
  department text primary key,
  office_timing_id uuid not null references office_timings(id) on delete cascade
);

alter table department_office_timings enable row level security;
drop policy if exists department_office_timings_select on department_office_timings;
create policy department_office_timings_select on department_office_timings for select to authenticated using (true);
drop policy if exists department_office_timings_write on department_office_timings;
create policy department_office_timings_write on department_office_timings for all to authenticated
  using (current_app_is_hr_or_mgmt()) with check (current_app_is_hr_or_mgmt());

drop table if exists designation_office_timings;
