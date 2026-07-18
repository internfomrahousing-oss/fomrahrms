-- Designation-based working hours ("Office Timings"). Replaces the
-- hardcoded 9:30 AM / 6:30 PM schedule that used to be duplicated across
-- checkin_status.dart, check_in_page.dart, check_out_page.dart, and
-- attendance_shortcut_card.dart. HR/Management define named timings and
-- assign one to each designation; any designation with no explicit
-- assignment falls back to whichever row has is_default = true.

create table if not exists office_timings (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  check_in_time text not null,   -- "HH:mm"
  check_out_time text not null,  -- "HH:mm"
  grace_minutes integer not null default 10,
  working_hours numeric not null default 8,
  is_default boolean not null default false,
  created_at timestamptz default now()
);

-- designation is the primary key: assigning a designation to a new timing
-- is a plain upsert on conflict(designation), no need to strip it from
-- whatever timing it was on before.
create table if not exists designation_office_timings (
  designation text primary key,
  office_timing_id uuid not null references office_timings(id) on delete cascade
);

insert into office_timings (name, check_in_time, check_out_time, grace_minutes, working_hours, is_default)
select 'Standard Hours', '09:30', '18:30', 10, 8, true
where not exists (select 1 from office_timings where is_default);

-- Same read-all-authenticated / write-HR-or-Management shape as the other
-- reference/config tables (leave_form_configs, maintenance_form_configs) —
-- see the do-loop in 20260716000100_rls_policies.sql. Applied directly here
-- (not via that loop) since that migration hasn't been run wholesale.
alter table office_timings enable row level security;
drop policy if exists office_timings_select on office_timings;
create policy office_timings_select on office_timings for select to authenticated using (true);
drop policy if exists office_timings_write on office_timings;
create policy office_timings_write on office_timings for all to authenticated
  using (current_app_is_hr_or_mgmt()) with check (current_app_is_hr_or_mgmt());

alter table designation_office_timings enable row level security;
drop policy if exists designation_office_timings_select on designation_office_timings;
create policy designation_office_timings_select on designation_office_timings for select to authenticated using (true);
drop policy if exists designation_office_timings_write on designation_office_timings;
create policy designation_office_timings_write on designation_office_timings for all to authenticated
  using (current_app_is_hr_or_mgmt()) with check (current_app_is_hr_or_mgmt());
