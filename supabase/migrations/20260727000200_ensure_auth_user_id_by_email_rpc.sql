-- The original auth_user_id_by_email() RPC (20260716000700) was marked
-- "NOT applied automatically — review and run this yourself", so there's
-- no guarantee it actually shipped to every environment. The login Edge
-- Function's shadow auth.users provisioning (supabase/functions/login/
-- index.ts) depends on this RPC to avoid creating a duplicate auth.users
-- row for an email that already has one (e.g. a rehired employee, or an
-- app_users row whose auth_user_id link was lost) — without it, that
-- employee's login permanently fails with "Could not start session".
-- Re-running this (idempotent create-or-replace) through the normal
-- migration pipeline guarantees it's actually present.

create or replace function auth_user_id_by_email(p_email text)
returns uuid
language sql
security definer
set search_path = public, auth
as $$
  select id from auth.users where lower(email) = lower(p_email) limit 1;
$$;

revoke all on function auth_user_id_by_email(text) from public, anon, authenticated;
grant execute on function auth_user_id_by_email(text) to service_role;
