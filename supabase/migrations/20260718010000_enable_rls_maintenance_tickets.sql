-- maintenance_tickets had RLS disabled with full grants to anon/authenticated
-- (part of the broader gap the draft 20260716000100_rls_policies.sql
-- describes but was never applied for this table). Any holder of the public
-- anon key could read or edit every employee's maintenance tickets, and the
-- app's own "My Reported Issues" list only filtered by role, not identity,
-- so any two employees with the same role saw each other's history too.
--
-- This applies just the maintenance_tickets policy from that draft: self,
-- their reporting manager (if flagged), or HR/Management can see/write a
-- ticket. The helper functions are already live (used by app_users' policy).

alter table maintenance_tickets enable row level security;

drop policy if exists maintenance_tickets_all on maintenance_tickets;
create policy maintenance_tickets_all on maintenance_tickets for all to authenticated
  using (reported_by = current_app_name() or app_manages(reported_by) or current_app_is_hr_or_mgmt())
  with check (reported_by = current_app_name() or app_manages(reported_by) or current_app_is_hr_or_mgmt());
