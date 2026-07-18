-- Dynamic, role-based attendance location policy. Replaces the single
-- hardcoded office point/radius that used to live in
-- lib/utils/office_geofence.dart (13.085027778, 80.222750000, 30m,
-- applied only when work_location = 'Office') with HR-managed Locations
-- and Attendance Policies, resolved per employee the same way Office
-- Timings resolves a working-hours schedule (see 20260718020000_office_timings.sql
-- and lib/models/office_timing.dart) — explicit employee override →
-- department assignment → work_location fallback → hardcoded safety net.

create table if not exists locations (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  address text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  radius_meters integer not null default 30,
  type text not null default 'Office',   -- Office | Branch | Client Site | Other (free text)
  active boolean not null default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists attendance_policies (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  policy_type text not null check (policy_type in ('single_location', 'multi_location', 'unrestricted')),
  note_required_outside_radius boolean not null default true,
  created_at timestamptz default now()
);

-- One row per work_location value ('Office' | 'Onsite') — the policy used
-- when an employee has no department assignment or individual override.
create table if not exists attendance_policy_fallbacks (
  work_location text primary key,
  policy_id uuid not null references attendance_policies(id) on delete restrict
);

-- department is the primary key: reassigning a department to a new policy
-- is a plain upsert on conflict(department).
create table if not exists attendance_policy_department_assignments (
  department text primary key,
  policy_id uuid not null references attendance_policies(id) on delete restrict
);

-- Highest-priority override for one specific employee, independent of
-- their department's assignment.
create table if not exists attendance_policy_employee_overrides (
  employee_id text primary key,
  policy_id uuid not null references attendance_policies(id) on delete restrict
);

-- Which Locations an employee may check in/out from. One row for a
-- Single-Location (Office) employee, several rows for a Multi-Location
-- (Sales) employee. Unrestricted-policy employees need no rows here.
create table if not exists employee_locations (
  id uuid default gen_random_uuid() primary key,
  employee_id text not null,
  location_id uuid not null references locations(id) on delete cascade,
  created_at timestamptz default now(),
  unique (employee_id, location_id)
);

-- Structured GPS + policy-outcome columns alongside the existing free-text
-- `location` ("lat,lng") column, which stays untouched for backward
-- compatibility with existing readers (route map, reports). check_in_*
-- and check_out_* are separate because a single shared `location` column
-- would otherwise be overwritten at check-out, losing the check-in point.
alter table attendance_records add column if not exists check_in_lat double precision;
alter table attendance_records add column if not exists check_in_lng double precision;
alter table attendance_records add column if not exists check_in_within_radius boolean;
alter table attendance_records add column if not exists check_out_lat double precision;
alter table attendance_records add column if not exists check_out_lng double precision;
alter table attendance_records add column if not exists check_out_within_radius boolean;
alter table attendance_records add column if not exists location_policy_name text default '';

-- Same read-all-authenticated / write-HR-or-Management shape as
-- office_timings / designation_office_timings.
do $$
declare
  t text;
begin
  foreach t in array array['locations', 'attendance_policies', 'attendance_policy_fallbacks',
      'attendance_policy_department_assignments', 'attendance_policy_employee_overrides',
      'employee_locations']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I_select on %I', t, t);
    execute format('create policy %I_select on %I for select to authenticated using (true)', t, t);
    execute format('drop policy if exists %I_write on %I', t, t);
    execute format(
      'create policy %I_write on %I for all to authenticated using (current_app_is_hr_or_mgmt()) with check (current_app_is_hr_or_mgmt())',
      t, t);
  end loop;
end $$;

-- ── Seed data: preserves today's real behavior exactly, so rollout is a
-- no-op until HR customizes anything. ──────────────────────────────────────

insert into locations (name, address, latitude, longitude, radius_meters, type)
select 'Head Office', '', 13.085027778, 80.222750000, 30, 'Office'
where not exists (select 1 from locations where name = 'Head Office');

insert into attendance_policies (name, policy_type, note_required_outside_radius)
select 'Standard Office', 'single_location', true
where not exists (select 1 from attendance_policies where name = 'Standard Office');

insert into attendance_policies (name, policy_type, note_required_outside_radius)
select 'Sales Field Staff', 'multi_location', true
where not exists (select 1 from attendance_policies where name = 'Sales Field Staff');

insert into attendance_policies (name, policy_type, note_required_outside_radius)
select 'Unrestricted Field Staff', 'unrestricted', false
where not exists (select 1 from attendance_policies where name = 'Unrestricted Field Staff');

insert into attendance_policy_fallbacks (work_location, policy_id)
select 'Office', id from attendance_policies where name = 'Standard Office'
on conflict (work_location) do nothing;

insert into attendance_policy_fallbacks (work_location, policy_id)
select 'Onsite', id from attendance_policies where name = 'Unrestricted Field Staff'
on conflict (work_location) do nothing;

insert into attendance_policy_department_assignments (department, policy_id)
select 'Sales', id from attendance_policies where name = 'Sales Field Staff'
on conflict (department) do nothing;

insert into attendance_policy_department_assignments (department, policy_id)
select 'Land Acquisition', id from attendance_policies where name = 'Unrestricted Field Staff'
on conflict (department) do nothing;

insert into attendance_policy_department_assignments (department, policy_id)
select 'Projects', id from attendance_policies where name = 'Unrestricted Field Staff'
on conflict (department) do nothing;

-- Every currently-active Office employee is assigned to Head Office, so
-- nobody's check-in flow changes on the day this ships.
insert into employee_locations (employee_id, location_id)
select u.employee_id, l.id
from app_users u, locations l
where u.work_location = 'Office' and u.active = true
  and u.employee_id is not null and u.employee_id <> ''
  and l.name = 'Head Office'
on conflict (employee_id, location_id) do nothing;
