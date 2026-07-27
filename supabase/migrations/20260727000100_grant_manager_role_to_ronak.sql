-- Grants Manager-level access (app_users.role = 'Manager') to
-- ronak@fomrahousing.in. Note: role = 'Manager' is independent from
-- is_reporting_manager (that flag now drives the reporting-manager
-- picker separately, see hr_employee_records_page.dart) — this migration
-- only changes the role gate, not reporting-manager status.

do $$
declare
  updated_count int;
begin
  update app_users
     set role = 'Manager'
   where lower(email) = lower('ronak@fomrahousing.in');

  get diagnostics updated_count = row_count;

  if updated_count = 0 then
    raise exception 'No app_users row found for ronak@fomrahousing.in — create the account first.';
  end if;
end $$;
