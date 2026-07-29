-- The activation row itself turned out healthy after the last fix
-- (active = true, password_hash a real 60-char bcrypt hash, token
-- cleared) — so the *set* side of the password flow works. Login still
-- failed for that password, and only "worked" once password_hash was
-- cleared (falling through to the needsPasswordSetup re-prompt instead of
-- ever reaching verification). That points at verify_app_user_password()
-- itself: it was defined in 20260716000000_auth_foundation.sql, which —
-- like the migrations already fixed in 20260729000000 — was explicitly
-- marked "NOT applied automatically — review and run this yourself".
-- If it was never applied, supabase.rpc("verify_app_user_password", ...)
-- in the login Edge Function (supabase/functions/login/index.ts) errors
-- out (function does not exist), and that function treats any RPC error
-- as "wrong password" — so login fails for every account that actually
-- has a password_hash, exactly as reported.
--
-- Re-applying (idempotent) so this no longer depends on whether that
-- original migration made it to production.

create extension if not exists pgcrypto;

create or replace function verify_app_user_password(p_email text, p_password text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from app_users
     where lower(email) = lower(p_email)
       and password_hash is not null
       and password_hash = crypt(p_password, password_hash)
  );
$$;

create or replace function set_app_user_password(p_email text, p_password text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform set_config('app.bypass_sensitive_column_protection', 'on', true);
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = ''
   where lower(email) = lower(p_email);
end;
$$;

revoke all on function verify_app_user_password(text, text) from public, anon, authenticated;
revoke all on function set_app_user_password(text, text) from public, anon, authenticated;
grant execute on function verify_app_user_password(text, text) to service_role;
grant execute on function set_app_user_password(text, text) to service_role;
