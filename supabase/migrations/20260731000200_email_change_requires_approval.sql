-- Bring the login email under Management approval (Chain C).
--
-- Context: `email` is the credential verify_app_user_password() matches on,
-- and `company_email` is where password-reset links are sent. Neither was
-- approval-gated, so HR could repoint any employee's login address, trigger a
-- reset to an address they control, and sign in as that employee — in a
-- system holding payroll, appraisals and confirmation decisions.
--
-- IMPORTANT — this migration enforces the rule in the DATABASE, not just the
-- UI. The existing Chain C fields (gross_pay, work_location, …) are pinned by
-- protect_app_users_sensitive_columns(), but that trigger opens with:
--
--     if current_user = 'service_role' or current_app_is_hr_or_mgmt() then
--       return new;
--
-- so HR bypasses all of it. Those approval flows are a Flutter UI convention
-- (hr_employee_records_page.dart sets *Pending fields and Management clears
-- them) that any authenticated HR session can sidestep by writing to
-- PostgREST directly. The trigger below deliberately does NOT exempt HR.

begin;

-- ── 1. Pending columns, matching the existing Chain C shape ─────────────────
alter table app_users add column if not exists email_pending      text default '';
alter table app_users add column if not exists email_requested_at text default '';

-- ── 2. Block direct writes to the login email ───────────────────────────────
-- Allowed only for: service_role (the login Edge Function), or a caller
-- holding the one-shot flag set by approve_login_email_change() below.
create or replace function public.protect_login_email()
returns trigger
language plpgsql
as $function$
begin
  if new.email is distinct from old.email then
    if current_user = 'service_role'
       or coalesce(current_setting('app.allow_login_email_change', true), 'off') = 'on'
    then
      -- Authorised: an approved change is being committed. Force a re-link of
      -- the shadow auth.users row, which is keyed by the old address.
      new.auth_user_id := null;
    else
      raise exception
        'Login email changes require Management approval — use request_login_email_change() and approve_login_email_change().'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$function$;

-- Fires after trg_normalise_app_user_email (n < p alphabetically), so the
-- comparison above is made on already-normalised values and a mere change of
-- letter case is not mistaken for a real change.
drop trigger if exists trg_protect_login_email on app_users;
create trigger trg_protect_login_email
  before update of email on app_users
  for each row execute function public.protect_login_email();

-- ── 3. HR (or Management) proposes a change ─────────────────────────────────
create or replace function public.request_login_email_change(
  p_employee_email text,
  p_new_email      text
) returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_new text := lower(btrim(coalesce(p_new_email, '')));
begin
  if not current_app_is_hr_or_mgmt() then
    raise exception 'Only HR or Management can request a login email change.'
      using errcode = 'insufficient_privilege';
  end if;

  if v_new = '' or v_new !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'That does not look like a valid email address.'
      using errcode = 'check_violation';
  end if;

  if exists (select 1 from app_users where lower(email) = v_new) then
    raise exception 'Another account already uses that email address.'
      using errcode = 'unique_violation';
  end if;

  update app_users
     set email_pending      = v_new,
         email_requested_at = to_char(now() at time zone 'utc',
                                      'YYYY-MM-DD"T"HH24:MI:SS"Z"')
   where lower(email) = lower(btrim(p_employee_email));

  return found;
end;
$function$;

-- ── 4. Management alone commits it ──────────────────────────────────────────
create or replace function public.approve_login_email_change(p_employee_email text)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_old text;
  v_new text;
begin
  -- Deliberately Management-only: HR proposes, Management decides. HR is NOT
  -- accepted here, unlike current_app_is_hr_or_mgmt().
  if coalesce(current_app_role(), '') <> 'Management' then
    raise exception 'Only Management can approve a login email change.'
      using errcode = 'insufficient_privilege';
  end if;

  select email, nullif(btrim(email_pending), '')
    into v_old, v_new
    from app_users
   where lower(email) = lower(btrim(p_employee_email));

  if v_new is null then
    return null;                      -- nothing pending
  end if;

  if exists (select 1 from app_users where lower(email) = v_new) then
    raise exception 'Another account already uses that email address.'
      using errcode = 'unique_violation';
  end if;

  perform set_config('app.allow_login_email_change', 'on', true);
  perform set_config('app.bypass_sensitive_column_protection', 'on', true);

  update app_users
     set email              = v_new,
         company_email      = v_new,   -- the two are one concept in practice
         email_pending      = '',
         email_requested_at = '',
         -- Any outstanding tokens were issued to the old address.
         activation_token            = null,
         activation_token_expires_at = null,
         reset_password_token             = null,
         reset_password_token_expires_at  = null
   where lower(email) = lower(v_old);

  return v_new;
end;
$function$;

-- ── 5. …or rejects it ───────────────────────────────────────────────────────
create or replace function public.reject_login_email_change(p_employee_email text)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if coalesce(current_app_role(), '') <> 'Management' then
    raise exception 'Only Management can reject a login email change.'
      using errcode = 'insufficient_privilege';
  end if;

  update app_users
     set email_pending = '', email_requested_at = ''
   where lower(email) = lower(btrim(p_employee_email));

  return found;
end;
$function$;

-- ── 6. Grants ───────────────────────────────────────────────────────────────
revoke all on function public.request_login_email_change(text, text) from public, anon;
revoke all on function public.approve_login_email_change(text)       from public, anon;
revoke all on function public.reject_login_email_change(text)        from public, anon;

grant execute on function public.request_login_email_change(text, text) to authenticated, service_role;
grant execute on function public.approve_login_email_change(text)       to authenticated, service_role;
grant execute on function public.reject_login_email_change(text)        to authenticated, service_role;

-- ── 7. Also pin the pending columns for ordinary employees ──────────────────
-- So an employee's whole-record upsert can't invent an approved-looking
-- change. (HR/Management still bypass this older trigger — see the note at
-- the top; the real enforcement for `email` is trg_protect_login_email.)
create or replace function public.protect_app_users_sensitive_columns()
returns trigger
language plpgsql as $function$
begin
  if current_user = 'service_role' or current_app_is_hr_or_mgmt() then
    return new;
  end if;
  new.role := old.role;
  new.active := old.active;
  new.employee_id := old.employee_id;
  new.leave_allocation := old.leave_allocation;
  new.gross_pay := old.gross_pay;
  new.gross_pay_pending := old.gross_pay_pending;
  new.gross_pay_requested_at := old.gross_pay_requested_at;
  new.permission_minutes_quota := old.permission_minutes_quota;
  new.permission_minutes_quota_pending := old.permission_minutes_quota_pending;
  new.permission_minutes_quota_requested_at := old.permission_minutes_quota_requested_at;
  new.is_reporting_manager := old.is_reporting_manager;
  new.is_reporting_manager_pending := old.is_reporting_manager_pending;
  new.is_reporting_manager_requested_at := old.is_reporting_manager_requested_at;
  new.business_unit := old.business_unit;
  new.business_unit_pending := old.business_unit_pending;
  new.business_unit_requested_at := old.business_unit_requested_at;
  new.work_location := old.work_location;
  new.work_location_pending := old.work_location_pending;
  new.work_location_requested_at := old.work_location_requested_at;
  new.weekly_off_day := old.weekly_off_day;
  new.weekly_off_day_pending := old.weekly_off_day_pending;
  new.weekly_off_day_requested_at := old.weekly_off_day_requested_at;
  new.reporting_manager := old.reporting_manager;
  new.reporting_manager_pending := old.reporting_manager_pending;
  new.reporting_manager_requested_at := old.reporting_manager_requested_at;
  new.password_hash := old.password_hash;
  new.auth_user_id := old.auth_user_id;
  -- new in this migration:
  new.email := old.email;
  new.company_email := old.company_email;
  new.email_pending := old.email_pending;
  new.email_requested_at := old.email_requested_at;
  return new;
end;
$function$;

commit;
