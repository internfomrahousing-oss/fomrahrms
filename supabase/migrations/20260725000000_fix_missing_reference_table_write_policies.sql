-- Same root cause as 20260717040000_fix_missing_app_users_update_policy.sql:
-- when 20260716000100_rls_policies.sql was actually run against the live
-- database, not every policy in it landed. That file's do-block for the
-- "read-all-authenticated reference/config tables" (announcements,
-- holidays, birthdays, employee_of_month, hr_policy_versions,
-- form_versions, onboarding_form_versions, leave_form_configs,
-- maintenance_form_configs) creates both a `_select` and a `_write` policy
-- per table — only the `_select` ones actually made it. Reads work fine
-- (existing rows still show), but every insert/update/delete since RLS
-- went live on 2026-07-16 has been silently rejected — confirmed by HR
-- getting `new row violates row-level security policy for table
-- "employee_of_month"` when adding a winner, and Announcements/Holidays
-- both stuck on entries from before the 16th despite HR adding more since.
--
-- Re-creates the missing write policy for every table in that group.
-- Idempotent (drop-if-exists + create), safe to run even for tables whose
-- write policy did make it through.

do $$
declare
  t text;
begin
  foreach t in array array[
    'announcements', 'holidays', 'birthdays', 'employee_of_month',
    'hr_policy_versions', 'form_versions', 'onboarding_form_versions',
    'leave_form_configs', 'maintenance_form_configs'
  ]
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I_select on %I', t, t);
    execute format('create policy %I_select on %I for select to authenticated using (true)', t, t);
    execute format('drop policy if exists %I_write on %I', t, t);
    execute format(
      'create policy %I_write on %I for all to authenticated using (current_app_is_hr_or_mgmt()) with check (current_app_is_hr_or_mgmt())',
      t, t
    );
  end loop;
end $$;
