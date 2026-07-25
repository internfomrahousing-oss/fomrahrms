-- The 20260725010000 backfill for app_users.date_of_joining relied on
-- onboarding_forms.password_created_at, but that column is null for some
-- employees who activated before it was reliably populated (e.g. nishit,
-- jose jenin jeevi — both activated mid-July 2026). Their date_of_joining
-- is still blank, which breaks the attendance calendar's "don't mark days
-- before joining as absent" logic (lib/pages/employee_attendance_calendar_page.dart,
-- lib/pages/my_attendance_page.dart) — it falls back to treating every past
-- day as absent when the joining date can't be parsed.
--
-- audit_log's 'account_activated' event (logged at the end of
-- complete_account_activation()) is a reliable independent record of the
-- same moment, so use it as a second-pass backfill source for anyone
-- onboarding_forms didn't catch.

with latest_activation as (
  select distinct on (lower(target_id))
    lower(target_id) as email_lower,
    occurred_at
  from audit_log
  where action = 'account_activated'
    and target_id is not null and target_id <> ''
  order by lower(target_id), occurred_at desc
)
update app_users
   set date_of_joining = to_char(latest_activation.occurred_at, 'YYYY-MM-DD')
  from latest_activation
 where lower(app_users.email) = latest_activation.email_lower
   and (app_users.date_of_joining is null or app_users.date_of_joining = '');
