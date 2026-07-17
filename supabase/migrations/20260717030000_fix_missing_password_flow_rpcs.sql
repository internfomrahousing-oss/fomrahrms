-- Same root cause as the pre-offer/onboarding link fix: the "Set Your
-- Password" email link (/set-password/{token}) and the "Forgot Password"
-- link (/reset-password/{token}) both depend on functions that only ever
-- existed inside migration files marked "review before running yourself"
-- (20260716000100_rls_policies.sql and 20260716000500_password_flow_rpcs.sql)
-- — never actually applied to production. That's why the button in the
-- onboarding email does nothing useful: the page it links to can't look
-- the activation token up at all.
--
-- Adds, in one shot, both halves of the flow: the lookup used to load the
-- Set Password / Reset Password pages, and the RPCs that actually verify
-- the token and save the new password (crypt()/gen_salt() need the
-- extensions schema on Supabase, not public — already accounted for below).
-- No RLS changes, nothing else touched.

create or replace function app_user_by_activation_token(p_token text)
returns table(email text, name text, activation_token_expires_at text)
language sql stable security definer set search_path = public as $$
  select email, name, activation_token_expires_at
  from app_users
  where activation_token = p_token and p_token <> '';
$$;

create or replace function app_user_by_reset_token(p_token text)
returns table(email text, name text, reset_password_token_expires_at text)
language sql stable security definer set search_path = public as $$
  select email, name, reset_password_token_expires_at
  from app_users
  where reset_password_token = p_token and p_token <> '';
$$;

create or replace function complete_account_activation(p_token text, p_password text)
returns text -- the activated email, or null if the token is invalid/expired
language plpgsql security definer set search_path = public, extensions as $$
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
language plpgsql security definer set search_path = public, extensions as $$
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
-- used to overwrite an existing password.
create or replace function set_password_if_unset(p_email text, p_password text)
returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  update app_users
     set password_hash = crypt(p_password, gen_salt('bf')),
         password = ''
   where lower(email) = lower(p_email)
     and (password_hash is null or password_hash = '');
  return found;
end;
$$;

revoke all on function app_user_by_activation_token(text) from public;
revoke all on function app_user_by_reset_token(text) from public;
revoke all on function complete_account_activation(text, text) from public;
revoke all on function complete_password_reset(text, text) from public;
revoke all on function set_password_if_unset(text, text) from public;
grant execute on function app_user_by_activation_token(text) to anon, authenticated;
grant execute on function app_user_by_reset_token(text) to anon, authenticated;
grant execute on function complete_account_activation(text, text) to anon, authenticated;
grant execute on function complete_password_reset(text, text) to anon, authenticated;
grant execute on function set_password_if_unset(text, text) to anon, authenticated;
