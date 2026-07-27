-- Grants Management-level access (app_users.role = 'Management') to the
-- management@fomrahousing.in account, the same role gate used throughout
-- the app for HR/Management-only pages and RLS policies (see
-- lib/pages/hr_employee_records_page.dart, rls_policies.sql).

do $$
declare
  updated_count int;
begin
  update app_users
     set role = 'Management'
   where lower(email) = lower('management@fomrahousing.in');

  get diagnostics updated_count = row_count;

  if updated_count = 0 then
    raise exception 'No app_users row found for management@fomrahousing.in — create the account first.';
  end if;
end $$;
