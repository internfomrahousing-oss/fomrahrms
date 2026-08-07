-- Policy section 4: clubbing, comp-off, approval limits, medical certificate.
--
-- Applies to NEW submissions and NEW approvals only. Leave already approved is
-- left alone: each trigger returns early when the relevant value is unchanged,
-- so re-saving an old row does not re-validate it.
alter table leave_applications
  add column if not exists needs_medical_certificate    boolean not null default false,
  add column if not exists requires_management_approval boolean not null default false;

comment on column leave_applications.needs_medical_certificate is
  'Medical leave beyond 3 consecutive days. Policy: certificate required, else LOP. Flagged for HR, not blocked.';
comment on column leave_applications.requires_management_approval is
  'Beyond the reporting manager''s day limit, or a comp-off clubbed with other leave.';

create or replace function public.enforce_leave_clubbing()
returns trigger language plpgsql as $function$
declare v_clash record; v_days int;
begin
  if new.leave_type = 'Permission' then return new; end if;
  if tg_op = 'UPDATE' and new.from_date = old.from_date
     and new.to_date = old.to_date and new.leave_type = old.leave_type then
    return new;   -- an approval decision, not a new request
  end if;

  v_days := (new.to_date - new.from_date) + 1;
  new.needs_medical_certificate :=
    (new.leave_type ilike '%Medical%' or new.leave_type ilike '%Sick%') and v_days > 3;

  -- Adjacent or overlapping: clubbing means taken as one stretch, not two
  -- isolated days in the same month.
  select * into v_clash from leave_applications l
   where l.id is distinct from new.id and l.leave_type <> 'Permission'
     and coalesce(l.manager_status,'') <> 'denied'
     and lower(btrim(l.employee_name)) = lower(btrim(new.employee_name))
     and l.from_date <= (new.to_date + 1) and l.to_date >= (new.from_date - 1)
   limit 1;
  if v_clash.id is null then return new; end if;

  -- Comp Off may be clubbed with anything, but needs Management sign-off.
  if new.leave_type ilike '%Comp%' or v_clash.leave_type ilike '%Comp%' then
    new.requires_management_approval := true;
    return new;
  end if;

  if new.leave_type <> v_clash.leave_type then
    raise exception
      'CL, ML and EL cannot be combined. This request is % and runs next to an existing % leave (% to %). Take them separately, or use Comp Off, which can be combined.',
      new.leave_type, v_clash.leave_type,
      to_char(v_clash.from_date,'DD Mon'), to_char(v_clash.to_date,'DD Mon')
      using errcode = 'check_violation';
  end if;
  return new;
end; $function$;

drop trigger if exists trg_enforce_leave_clubbing on leave_applications;
create trigger trg_enforce_leave_clubbing
  before insert or update on leave_applications
  for each row execute function public.enforce_leave_clubbing();

-- Reporting Manager: up to 2 days; Sales up to 1. Beyond that, and for a
-- clubbed comp-off, Management decides.
create or replace function public.enforce_approval_limits()
returns trigger language plpgsql as $function$
declare v_days int; v_limit int; v_dept text;
begin
  if new.leave_type = 'Permission' then return new; end if;
  if coalesce(new.manager_status,'') <> 'approved' then return new; end if;
  if tg_op = 'UPDATE' and coalesce(old.manager_status,'') = 'approved' then
    return new;   -- already approved: grandfathered
  end if;
  if public.is_management_authority(coalesce(current_app_role(), '')) then
    return new;
  end if;

  v_days := (new.to_date - new.from_date) + 1;
  select department into v_dept from app_users
   where lower(btrim(name)) = lower(btrim(new.employee_name)) limit 1;
  v_limit := case when coalesce(v_dept,'') = 'Sales' then 1 else 2 end;

  if new.requires_management_approval then
    raise exception 'This request needs Management approval: a Comp Off combined with other leave.'
      using errcode = 'insufficient_privilege';
  end if;
  if v_days > v_limit then
    raise exception
      'A Reporting Manager can approve up to % day(s)%. This request is % days and needs MD and Head of Operations approval.',
      v_limit, case when coalesce(v_dept,'') = 'Sales' then ' for Sales' else '' end, v_days
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end; $function$;

drop trigger if exists trg_enforce_approval_limits on leave_applications;
create trigger trg_enforce_approval_limits
  before insert or update on leave_applications
  for each row execute function public.enforce_approval_limits();
