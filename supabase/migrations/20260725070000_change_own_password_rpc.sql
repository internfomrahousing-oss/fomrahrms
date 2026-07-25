-- Self-service "change password" for an already-logged-in user (distinct
-- from the token-gated activation/reset flows in
-- 20260716000500_password_flow_rpcs.sql, which run before any session
-- exists). Verifies the caller's current password server-side before
-- setting the new one — current_app_email() is derived from their own JWT,
-- so this can only ever change the caller's own password, never anyone
-- else's. Same protect_app_users_sensitive_columns() bypass flag pattern
-- as the other password RPCs (see 20260718000000_fix_password_rpcs_still_blocked_by_protect_trigger.sql)
-- so the write isn't silently reverted by that trigger.

create or replace function change_own_password(p_current_password text, p_new_password text)
returns boolean -- true if changed, false if the current password didn't match
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_email text := current_app_email();
  v_matches boolean;
begin
  if v_email is null or v_email = '' then
    return false;
  end if;

  select (password_hash is not null and password_hash = crypt(p_current_password, password_hash))
    into v_matches
    from app_users where lower(email) = v_email;

  if not coalesce(v_matches, false) then
    return false;
  end if;

  perform set_config('app.bypass_sensitive_column_protection', 'on', true);
  update app_users
     set password_hash = crypt(p_new_password, gen_salt('bf')),
         password = ''
   where lower(email) = v_email;
  return true;
end;
$$;

revoke all on function change_own_password(text, text) from public;
grant execute on function change_own_password(text, text) to authenticated;
