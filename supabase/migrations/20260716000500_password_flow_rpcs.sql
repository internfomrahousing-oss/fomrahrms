-- Fixes a real bug in Phase A (20260716000000_auth_foundation.sql):
-- set_app_user_password(email, password) was deliberately restricted to
-- service_role only, so it can't be called from the Flutter client at all
-- (the client always connects as anon or authenticated). But three client
-- call sites need to set a password themselves:
--   - completeAccountActivation (set_password_page.dart, anon — reached via
--     a public /set-password/{token} link)
--   - completePasswordReset (reset_password_page.dart, anon — public
--     /reset-password/{token} link)
--   - setInitialUserPassword (login_page.dart's "first login, no password
--     yet" in-app flow — also reached before any session exists)
--
-- These three functions replace those calls. Each re-verifies its own
-- authorization condition (the token matches and hasn't expired, or the
-- account genuinely has no password set yet) *inside* the SECURITY DEFINER
-- function itself — never trusting the caller — so they're safe to grant to
-- anon/authenticated without recreating the "anyone can set anyone's
-- password" hole set_app_user_password was locked down to prevent.
--
-- NOT applied automatically — review and run this yourself. Requires
-- Phase A already applied. Run this before (or together with) deploying
-- the updated set_password_page.dart / reset_password_page.dart / login_page.dart.

create or replace function complete_account_activation(p_token text, p_password text)
returns text -- the activated email, or null if the token is invalid/expired
language plpgsql security definer set search_path = public as $$
declare
  v_email text;
begin
  select email into v_email from app_users
   where activation_token = p_token and p_token <> ''
     and (activation_token_expires_at = '' or activation_token_expires_at::timestamptz > now());
  if v_email is null then
    return null;
  end if;
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = '',
         active = true,
         activation_token = '',
         activation_token_expires_at = ''
   where email = v_email;
  return v_email;
end;
$$;

create or replace function complete_password_reset(p_token text, p_password text)
returns text -- the reset email, or null if the token is invalid/expired
language plpgsql security definer set search_path = public as $$
declare
  v_email text;
begin
  select email into v_email from app_users
   where reset_password_token = p_token and p_token <> ''
     and (reset_password_token_expires_at = '' or reset_password_token_expires_at::timestamptz > now());
  if v_email is null then
    return null;
  end if;
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = '',
         reset_password_token = '',
         reset_password_token_expires_at = ''
   where email = v_email;
  return v_email;
end;
$$;

-- Only succeeds if the account genuinely has no password yet — can't be
-- used to overwrite an existing password (that's what complete_password_reset
-- and the login-token-gated flows are for).
create or replace function set_password_if_unset(p_email text, p_password text)
returns boolean
language plpgsql security definer set search_path = public as $$
begin
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = ''
   where lower(email) = lower(p_email)
     and (password_hash is null or password_hash = '');
  return found;
end;
$$;

revoke all on function complete_account_activation(text, text) from public;
revoke all on function complete_password_reset(text, text) from public;
revoke all on function set_password_if_unset(text, text) from public;
grant execute on function complete_account_activation(text, text) to anon, authenticated;
grant execute on function complete_password_reset(text, text) to anon, authenticated;
grant execute on function set_password_if_unset(text, text) to anon, authenticated;
