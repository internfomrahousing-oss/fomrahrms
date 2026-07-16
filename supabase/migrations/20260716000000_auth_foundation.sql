-- Phase A of the FOMRA HRMS security audit: move password verification
-- server-side and stop shipping plaintext passwords to every client.
--
-- Context: app_users.password was stored in plaintext and returned to the
-- browser on every fetchAppUsers() call (the whole employee roster, to
-- every logged-in user) so the Flutter client could compare it locally at
-- login. This migration adds a bcrypt-hashed column, backfills it from the
-- existing plaintext values, and adds two SECURITY DEFINER functions that
-- only the service_role (i.e. the new `login` Edge Function) can call —
-- the plaintext `password` column itself is left in place for one release
-- as a rollback safety net, but nothing should read or write it after this
-- migration ships; see the follow-up migration that drops it.
--
-- NOT applied automatically — review and run this yourself (Supabase SQL
-- Editor or `supabase db push`), ideally against a staging project first.

create extension if not exists pgcrypto;

alter table app_users add column if not exists password_hash text;
alter table app_users add column if not exists auth_user_id uuid;

-- Lets every existing client keep asking "does this user have a password
-- yet?" (previously `password.isEmpty`) without ever being able to read the
-- hash itself — the boolean is computed by Postgres, never selected as a
-- secret value.
alter table app_users add column if not exists has_password boolean
  generated always as (password_hash is not null and password_hash <> '') stored;

update app_users
   set password_hash = crypt(password, gen_salt('bf'))
 where password_hash is null
   and coalesce(password, '') <> '';

-- Only the service_role (the login Edge Function, using
-- SUPABASE_SERVICE_ROLE_KEY) may call these — anon/authenticated clients
-- must never be able to check or set a password directly against the
-- table, since that would recreate the exact vulnerability this migration
-- fixes.
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
language sql
security definer
set search_path = public, extensions
as $$
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = ''
   where lower(email) = lower(p_email);
$$;

revoke all on function verify_app_user_password(text, text) from public, anon, authenticated;
revoke all on function set_app_user_password(text, text) from public, anon, authenticated;
grant execute on function verify_app_user_password(text, text) to service_role;
grant execute on function set_app_user_password(text, text) to service_role;
