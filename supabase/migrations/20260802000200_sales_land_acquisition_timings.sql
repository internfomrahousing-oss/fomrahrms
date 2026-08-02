-- Sales works EVERY Sunday and starts at 09:30.
-- Land Acquisition does NOT work Sundays and starts at 09:00.
--
-- Neither department was in department_office_timings, so both silently
-- inherited the 09:30 default. For Land Acquisition that flagged a 09:00
-- arrival as late every single day.

-- Sales maps to Standard Hours (09:30) explicitly rather than by fallback, so
-- the intent is visible and a later change to the default cannot silently move
-- Sales with it.
insert into department_office_timings (department, office_timing_id)
select 'Sales', id from office_timings where name = 'Standard Hours'
on conflict (department) do update set office_timing_id = excluded.office_timing_id;

-- Land Acquisition gets its own 09:00 row. 'housekeeping employee hours' is
-- already 09:00-18:00, but Land Acquisition finishes at 18:30 and reusing the
-- row would couple the two groups anyway — editing
-- housekeeping hours would move Land Acquisition too.
insert into office_timings (name, check_in_time, check_out_time, grace_minutes, working_hours, is_default)
select 'Land Acquisition Hours', '09:00', '18:30', 10, '9.5', false
where not exists (select 1 from office_timings where name = 'Land Acquisition Hours');

insert into department_office_timings (department, office_timing_id)
select 'Land Acquisition', id from office_timings where name = 'Land Acquisition Hours'
on conflict (department) do update set office_timing_id = excluded.office_timing_id;

-- weekly_off_day uses '' as a sentinel meaning Sunday. Land Acquisition keeps
-- that. Sales must NOT: Sunday is a working day for them, so '' marks their
-- working day as an off day and leaves their real off day as working.
--
-- The off day is a per-person decision made by the reporting manager and HR,
-- so it is surfaced rather than guessed.
create or replace view public.v_sales_missing_weekly_off as
  select name, employee_id, department, reporting_manager,
         'Sunday is a working day for Sales — an explicit weekly off day must be set by the reporting manager and HR'
           as action_required
    from app_users
   where department = 'Sales'
     and coalesce(btrim(weekly_off_day), '') = '';

-- Warn rather than block: blocking would stop HR creating a Sales employee
-- before their off day has been agreed, which is the normal order of events.
create or replace function public.warn_sales_sunday_off()
returns trigger language plpgsql as $function$
begin
  if new.department = 'Sales' and coalesce(btrim(new.weekly_off_day),'') = '' then
    begin
      insert into audit_log (action, actor_email, actor_role, target_type, target_id, details)
      values ('sales_weekly_off_unset',
              coalesce(current_app_email(), current_user),
              coalesce(current_app_role(), ''),
              'app_users', new.email,
              jsonb_build_object('note','Sales works Sundays; weekly off day still unset'));
    exception when others then null; end;
  end if;
  return new;
end; $function$;

drop trigger if exists trg_warn_sales_sunday_off on app_users;
create trigger trg_warn_sales_sunday_off
  after insert or update of department, weekly_off_day on app_users
  for each row execute function public.warn_sales_sunday_off();
