-- Management has no department and no fixed working hours.
--
-- Sharad Fomra had a blank department, which fell through to the 09:30
-- default — so Management was silently being measured against Standard Hours
-- and could be flagged late.
--
-- Modelled as an explicit property of a TIMING rather than a special-case
-- department. Keying off a blank department would silently exempt any future
-- employee whose department simply had not been filled in yet, and the flag
-- is visible in the admin UI this way.
alter table office_timings
  add column if not exists no_fixed_timing boolean not null default false;

insert into office_timings (name, check_in_time, check_out_time, grace_minutes, working_hours, is_default, no_fixed_timing)
select 'Management — No Fixed Timing', '00:00', '23:59', 0, '0', false, true
where not exists (select 1 from office_timings where no_fixed_timing);

comment on column office_timings.no_fixed_timing is
  'When true, check-ins against this timing are never assessed for lateness. Used for Management, who have no fixed hours.';

-- Management has no fixed base either. Remove the head-office geofence and
-- put Sharad on the unrestricted policy — otherwise every check-in from a
-- site visit or an outside meeting would demand a written reason.
delete from employee_locations where employee_id = 'FHIPL-01';

insert into attendance_policy_employee_overrides (employee_id, policy_id)
select 'FHIPL-01', id from attendance_policies where name = 'Unrestricted Check-in'
on conflict (employee_id) do update set policy_id = excluded.policy_id;

-- Surya (Accounts) had no location assigned but resolves to a
-- location-requiring policy. locationsForEmployee() returns an empty list for
-- an unassigned employee once ANY location exists, and the geofence reads an
-- empty list as "outside everywhere" — so she would have been asked for a
-- written reason on every single check-in. Accounts is head-office based.
insert into employee_locations (employee_id, location_id)
select 'FHIPL-09', id from locations where name = 'Fomra Housing Head Office'
where not exists (
  select 1 from employee_locations where employee_id = 'FHIPL-09'
);
