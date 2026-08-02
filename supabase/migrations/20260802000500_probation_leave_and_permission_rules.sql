-- Leave entitlement depends on confirmation status.
--
--   CONFIRMED (onroll_confirmed_at set): CL, ML, EL and every other leave
--   type, plus the 120-minute permission allowance per attendance cycle.
--
--   PROBATION (onroll_confirmed_at empty): ONE leave per attendance cycle, of
--   any type, and NO permission at all.
--
-- Enforced in the database because RLS governs who may insert a row, not
-- whether they are entitled to it — the Dart checks alone are bypassable by
-- anything talking to PostgREST directly.

create or replace function public.is_employee_confirmed(p_employee_id text, p_employee_name text)
returns boolean language sql stable as $function$
  select coalesce(btrim(onroll_confirmed_at), '') <> ''
    from app_users
   where (coalesce(p_employee_id,'') <> '' and employee_id = p_employee_id)
      or (coalesce(p_employee_id,'') =  '' and lower(btrim(name)) = lower(btrim(p_employee_name)))
   limit 1;
$function$;

create or replace function public.enforce_probation_leave_rules()
returns trigger language plpgsql as $function$
declare v_confirmed boolean; v_used integer;
begin
  v_confirmed := coalesce(public.is_employee_confirmed(new.employee_id, new.employee_name), false);
  if v_confirmed then return new; end if;

  if new.leave_type = 'Permission' then
    raise exception
      'Permission is not available during probation. It becomes available once employment is confirmed.'
      using errcode = 'check_violation';
  end if;

  select count(*) into v_used from leave_applications
   where leave_type <> 'Permission' and id is distinct from new.id
     and coalesce(manager_status,'') <> 'denied'
     and public.attendance_cycle_start(from_date) = public.attendance_cycle_start(new.from_date)
     and ((coalesce(new.employee_id,'') <> '' and employee_id = new.employee_id)
       or (coalesce(new.employee_id,'') =  '' and lower(btrim(employee_name)) = lower(btrim(new.employee_name))));

  if v_used >= 1 then
    raise exception
      'Probation allows one leave per cycle (% to %), and one has already been taken. Further leave becomes available once employment is confirmed.',
      to_char(public.attendance_cycle_start(new.from_date),'DD Mon'),
      to_char(public.attendance_cycle_end(new.from_date),'DD Mon')
      using errcode = 'check_violation';
  end if;
  return new;
end; $function$;

drop trigger if exists trg_enforce_probation_leave on leave_applications;
create trigger trg_enforce_probation_leave
  before insert or update on leave_applications
  for each row execute function public.enforce_probation_leave_rules();

-- EL accrues only after confirmation. el_eligible_at had been set for everyone
-- earlier the same day, before this rule was known; clear it for anyone still
-- on probation.
alter table app_users disable trigger trg_protect_app_users;
update app_users set el_eligible_at = ''
 where coalesce(btrim(onroll_confirmed_at), '') = '';
alter table app_users enable trigger trg_protect_app_users;

-- On confirmation, start EL from the JOINING date so probation service still
-- counts, rather than restarting the clock at confirmation.
create or replace function public.start_el_on_confirmation()
returns trigger language plpgsql as $function$
begin
  if coalesce(btrim(new.onroll_confirmed_at),'') <> ''
     and coalesce(btrim(old.onroll_confirmed_at),'') = ''
     and coalesce(btrim(new.el_eligible_at),'') = '' then
    new.el_eligible_at := case
      when coalesce(new.date_of_joining,'') <> '' then new.date_of_joining
      else to_char(now(), 'YYYY-MM-DD')
    end;
  end if;
  return new;
end; $function$;

drop trigger if exists trg_start_el_on_confirmation on app_users;
create trigger trg_start_el_on_confirmation
  before update of onroll_confirmed_at on app_users
  for each row execute function public.start_el_on_confirmation();

-- ── Management is exempt from all of the above ──────────────────────────────
-- Management is an oversight / super-admin role, not an employee under HR
-- rules: no leave cycle, no payroll, no fixed hours, no fixed base, and never
-- "on probation". Sharad Fomra had a blank onroll_confirmed_at only because
-- the confirmation workflow was never run for him — which under the rules
-- above would have limited the MD to one leave per cycle and no permission.
--
-- Exempting by ROLE rather than by confirming him keeps the distinction
-- honest: he is not a confirmed employee, he is not an employee for these
-- purposes at all.
create or replace function public.is_management(p_employee_id text, p_employee_name text)
returns boolean language sql stable as $function$
  select coalesce(lower(btrim(role)), '') = 'management'
    from app_users
   where (coalesce(p_employee_id,'') <> '' and employee_id = p_employee_id)
      or (coalesce(p_employee_id,'') =  '' and lower(btrim(name)) = lower(btrim(p_employee_name)))
   limit 1;
$function$;

-- enforce_probation_leave_rules() and set_and_check_permission_minutes() both
-- return early for Management. See 20260802000600 for the full bodies.

-- Management is not on payroll. Flagged in the data rather than left to
-- convention, so a payroll run can exclude them by query.
create or replace view public.v_payroll_eligible_employees as
  select employee_id, name, email, department, designation, gross_pay,
         date_of_joining, onroll_confirmed_at
    from app_users
   where active
     and lower(btrim(coalesce(role,''))) <> 'management';

comment on view public.v_payroll_eligible_employees is
  'Employees who should appear in a payroll run. Management is an oversight role and is excluded — not on payroll, not on the leave cycle, no fixed hours.';
