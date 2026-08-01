-- P1 hardening: referential integrity for reporting_manager, real storage for
-- permission duration, and server-side quota enforcement.

-- ── 1. reporting_manager must point at a real employee ──────────────────────
-- The relationship is matched by NAME (app_manages joins
-- teammate.reporting_manager = me.name), so a typo yields an approval chain
-- pointing at nobody. Jose Jenin Jeevi J reports to "ronak", who does not
-- exist, so his submissions land in a queue with no owner.
--
-- This validates FUTURE writes only. The existing row is left alone: who Jose
-- reports to is an organisational decision, not something to guess in a
-- migration. v_dangling_reporting_managers surfaces it for HR.
create or replace function public.validate_reporting_manager()
returns trigger language plpgsql as $function$
begin
  if coalesce(btrim(new.reporting_manager), '') = '' then return new; end if;
  if new.reporting_manager = new.name then
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

drop trigger if exists trg_validate_reporting_manager on app_users;
create trigger trg_validate_reporting_manager
  before insert or update of reporting_manager, name on app_users
  for each row execute function public.validate_reporting_manager();

create or replace view public.v_dangling_reporting_managers as
  select u.name, u.employee_id, u.role, u.reporting_manager from app_users u
   where coalesce(btrim(u.reporting_manager),'') <> ''
     and not exists (select 1 from app_users m
                      where lower(btrim(m.name)) = lower(btrim(u.reporting_manager)));

-- ── 2. Store permission duration; stop parsing it out of prose ──────────────
alter table leave_applications add column if not exists permission_minutes integer;

-- Fallback only, for rows written by an app build that does not yet populate
-- the column. Ordered longest-match-first so '1 Hour 30 Minutes' is not read
-- as '1 Hour' — which the Dart version gets wrong.
create or replace function public.permission_minutes_from_text(p text)
returns integer language sql immutable as $function$
  select case
    when p is null                     then 60
    when p ilike '%1½ Hours%'          then 90
    when p ilike '%1 Hour 30 Minutes%' then 90
    when p ilike '%2 Hours%'           then 120
    when p ilike '%1 Hour%'            then 60
    when p ilike '%30 Minutes%'        then 30
    else 60
  end;
$function$;

-- ── 3. Derive the charge and enforce the quota, in ONE trigger ──────────────
-- Split across two BEFORE triggers this did not work: Postgres fires
-- same-timing triggers in NAME order, so the quota check ran before the
-- minutes were set, read NULL, added 0, and let everything through.
create or replace function public.set_and_check_permission_minutes()
returns trigger language plpgsql as $function$
declare v_quota integer; v_used integer;
begin
  if new.leave_type is distinct from 'Permission' then
    new.permission_minutes := null; return new;
  end if;

  -- Duration segment only — the text before the first '|' — so the employee's
  -- own description cannot steer the charge.
  if new.permission_minutes is null then
    new.permission_minutes :=
      public.permission_minutes_from_text(split_part(coalesce(new.reason,''), '|', 1));
  end if;

  select coalesce(permission_minutes_quota, 120) into v_quota from app_users
   where (coalesce(new.employee_id,'') <> '' and employee_id = new.employee_id)
      or (coalesce(new.employee_id,'') =  '' and lower(btrim(name)) = lower(btrim(new.employee_name)))
   limit 1;
  v_quota := coalesce(v_quota, 120);

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

drop trigger if exists trg_set_permission_minutes   on leave_applications;
drop trigger if exists trg_enforce_permission_quota on leave_applications;
drop trigger if exists trg_permission_minutes       on leave_applications;
create trigger trg_permission_minutes
  before insert or update on leave_applications
  for each row execute function public.set_and_check_permission_minutes();
