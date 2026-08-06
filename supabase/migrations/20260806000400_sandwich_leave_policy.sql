-- Sandwich Leave Policy (Help Center 4.4). Written down since the system was
-- built and never implemented — leave days were counted exactly as submitted.
--
--   Leave on BOTH sides of a weekly off or holiday -> that day counts as leave.
--   Leave on only one side -> it does not.
--   CL adjusts at most 2 days (4.3: "up to 2 days at a time"); the rest is LOP.
--   A sandwich is allowed once per cycle; a second in the same cycle makes the
--   whole request LOP.
--
-- "Once a month" is read as once per ATTENDANCE CYCLE (26th-25th), consistent
-- with the permission quota and every other periodic reset in the system.
alter table leave_applications
  add column if not exists sandwich_days int not null default 0,
  add column if not exists lop_days      int not null default 0;

comment on column leave_applications.sandwich_days is
  'Weekly-off or holiday days consumed because leave falls on both sides of them.';
comment on column leave_applications.lop_days is
  'Days treated as loss of pay: beyond the 2-day CL adjustment, or a repeat sandwich in the same cycle.';

create or replace function public.is_non_working_day(p_employee_name text, p_date date)
returns boolean language plpgsql stable as $function$
declare v_off text; v_weekday int;
begin
  if exists (select 1 from holidays where holiday_date = p_date) then return true; end if;
  select coalesce(nullif(btrim(weekly_off_day),''), 'Sunday') into v_off
    from app_users where lower(btrim(name)) = lower(btrim(p_employee_name)) limit 1;
  v_weekday := case lower(coalesce(v_off,'Sunday'))
    when 'monday' then 1 when 'tuesday' then 2 when 'wednesday' then 3
    when 'thursday' then 4 when 'friday' then 5 when 'saturday' then 6 else 7 end;
  return extract(isodow from p_date)::int = v_weekday;
end; $function$;

create or replace function public.has_leave_on(p_employee_name text, p_date date, p_exclude_id text)
returns boolean language sql stable as $function$
  select exists (select 1 from leave_applications
     where lower(btrim(employee_name)) = lower(btrim(p_employee_name))
       and leave_type <> 'Permission' and coalesce(manager_status,'') <> 'denied'
       and id is distinct from coalesce(p_exclude_id,'')
       and p_date between from_date and to_date);
$function$;

create or replace function public.apply_sandwich_policy()
returns trigger language plpgsql as $function$
declare d date; v_outside int := 0; v_inside int := 0; v_prior int; v_total int;
begin
  if new.leave_type = 'Permission' then return new; end if;
  if tg_op = 'UPDATE' and new.from_date = old.from_date and new.to_date = old.to_date then
    return new;   -- an approval decision, not a reschedule
  end if;

  d := new.from_date - 1;
  if public.is_non_working_day(new.employee_name, d)
     and public.has_leave_on(new.employee_name, d - 1, new.id) then
    v_outside := v_outside + 1;
  end if;
  d := new.to_date + 1;
  if public.is_non_working_day(new.employee_name, d)
     and public.has_leave_on(new.employee_name, d + 1, new.id) then
    v_outside := v_outside + 1;
  end if;

  -- Inside the span: bracketed by definition, but ALREADY counted in the span
  -- length. Adding them too made Fri-Mon come to 5 days instead of 4.
  d := new.from_date;
  while d <= new.to_date loop
    if public.is_non_working_day(new.employee_name, d) then v_inside := v_inside + 1; end if;
    d := d + 1;
  end loop;

  new.sandwich_days := v_outside + v_inside;
  v_total := (new.to_date - new.from_date) + 1 + v_outside;

  select coalesce(sum(sandwich_days), 0) into v_prior from leave_applications
   where lower(btrim(employee_name)) = lower(btrim(new.employee_name))
     and leave_type <> 'Permission' and coalesce(manager_status,'') <> 'denied'
     and id is distinct from new.id
     and public.attendance_cycle_start(from_date) = public.attendance_cycle_start(new.from_date);

  if new.sandwich_days > 0 and v_prior > 0 then
    new.lop_days := v_total;                     -- repeat sandwich: all LOP
  else
    new.lop_days := greatest(v_total - 2, 0);    -- CL adjusts at most 2 days
  end if;

  new.days := v_total;
  return new;
end; $function$;

drop trigger if exists trg_apply_sandwich_policy on leave_applications;
create trigger trg_apply_sandwich_policy
  before insert or update on leave_applications
  for each row execute function public.apply_sandwich_policy();
