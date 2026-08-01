-- ── 1. FIX: reporting-manager validation was blocking unrelated edits ────────
-- validate_reporting_manager() ran on every write where reporting_manager
-- appeared in the SET list. The Flutter client upserts the WHOLE record, so it
-- always does. Jose (reporting_manager = 'ronak', who does not yet exist)
-- therefore could not be edited at all — changing his phone number raised
-- foreign_key_violation. Validate only when the value actually CHANGES, so
-- pre-existing references are grandfathered until someone edits them.
--
-- Ronak is joining Management and his record will be created later; his name
-- is intentionally left in place on Jose's row until then.
create or replace function public.validate_reporting_manager()
returns trigger language plpgsql as $function$
begin
  if tg_op = 'UPDATE' and new.reporting_manager is not distinct from old.reporting_manager then
    return new;
  end if;
  if coalesce(btrim(new.reporting_manager),'') = '' then return new; end if;
  if lower(btrim(new.reporting_manager)) = lower(btrim(new.name)) then
    raise exception 'An employee cannot report to themselves.' using errcode='check_violation';
  end if;
  if not exists (select 1 from app_users m
                  where lower(btrim(m.name)) = lower(btrim(new.reporting_manager))) then
    raise exception
      'No employee named "%" exists, so approvals would have no owner. Pick an existing employee as the reporting manager.',
      new.reporting_manager using errcode='foreign_key_violation';
  end if;
  return new;
end; $function$;

-- ── 2. Permission durations: 30, 60 and 120 minutes only ────────────────────
-- The 120-minute monthly allowance is availed as 4x30, 2x60 or 1x120.
-- 90 minutes is withdrawn; no other interval (10, 45, 180 ...) is permitted.
--
-- 90-minute phrasings are rejected BEFORE any substring test: '1 Hour 30
-- Minutes' contains '1 Hour', and the old Dart parser matched '30 Minutes'
-- first, so the Staff Portal's 1h30m option was charged 30 minutes — under-
-- spending quota while under-crediting the employee against lateness.
-- Rejecting outright is safer than rounding to a neighbouring slot.
create or replace function public.permission_minutes_from_text(p text)
returns integer language sql immutable as $function$
  select case
    when p is null             then null
    when p ilike '%1½%'        then null
    when p ilike '%1 1/2%'     then null
    when p ilike '%90%'        then null
    when p ilike '%1 Hour 30%' then null
    when p ilike '%1 Hr 30%'   then null
    when p ilike '%2 Hours%'   then 120
    when p ilike '%2 Hrs%'     then 120
    when p ilike '%120%'       then 120
    when p ilike '%1 Hour%'    then 60
    when p ilike '%1 Hr%'      then 60
    when p ilike '%60%'        then 60
    when p ilike '%30 Minutes%' then 30
    when p ilike '%30 Mins%'   then 30
    when p ilike '%30%'        then 30
    else null
  end;
$function$;

create or replace function public.set_and_check_permission_minutes()
returns trigger language plpgsql as $function$
declare v_quota integer; v_used integer;
begin
  if new.leave_type is distinct from 'Permission' then
    new.permission_minutes := null; return new;
  end if;

  if new.permission_minutes is null then
    new.permission_minutes :=
      public.permission_minutes_from_text(split_part(coalesce(new.reason,''), '|', 1));
  end if;

  if new.permission_minutes is null or new.permission_minutes not in (30,60,120) then
    raise exception
      'Permission must be 30, 60 or 120 minutes. The monthly allowance of 120 minutes can be taken as 4x30, 2x60 or 1x120.'
      using errcode='check_violation';
  end if;

  select coalesce(permission_minutes_quota,120) into v_quota from app_users
   where (coalesce(new.employee_id,'') <> '' and employee_id = new.employee_id)
      or (coalesce(new.employee_id,'') =  '' and lower(btrim(name)) = lower(btrim(new.employee_name)))
   limit 1;
  v_quota := coalesce(v_quota,120);

  select coalesce(sum(permission_minutes),0) into v_used from leave_applications
   where leave_type='Permission' and id is distinct from new.id
     and coalesce(manager_status,'') <> 'denied'
     and date_trunc('month', from_date) = date_trunc('month', new.from_date)
     and ((coalesce(new.employee_id,'') <> '' and employee_id = new.employee_id)
       or (coalesce(new.employee_id,'') =  '' and lower(btrim(employee_name)) = lower(btrim(new.employee_name))));

  if v_used + new.permission_minutes > v_quota then
    raise exception
      'Monthly permission quota exhausted: % of % minutes already used this month, and this request is a further %.',
      v_used, v_quota, new.permission_minutes using errcode='check_violation';
  end if;
  return new;
end; $function$;
