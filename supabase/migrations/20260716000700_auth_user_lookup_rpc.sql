-- Fixes a bug caught running Phase A's login function against production:
-- supabase/functions/login/index.ts called `auth.admin.getUserByEmail(...)`
-- to check whether a shadow auth.users row already exists for an employee
-- before creating one — that method doesn't actually exist on the
-- supabase-js v2 Admin API (it errored with a TypeError on every login
-- that needed it). This RPC replaces that check with a direct, guaranteed-
-- correct lookup against auth.users itself.
--
-- NOT applied automatically — review and run this yourself. Requires
-- Phase A already applied. Run this before redeploying the updated
-- supabase/functions/login/index.ts.

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
