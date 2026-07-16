-- Phase G of the FOMRA HRMS security audit: a tamper-resistant audit trail.
--
-- Context: idea.txt asks for logging of login/logout/failed-login,
-- attendance, leave/permission requests, salary changes, activation,
-- offer letters, onboarding, Management approvals, and profile changes —
-- none of which were recorded anywhere before this. Rows can only be
-- created via the log_audit_event() RPC (which stamps the actor from the
-- caller's own JWT, so a client can't write an event claiming to be
-- someone else) or directly by a service_role caller (the login Edge
-- Function, for login/failed-login events, which happen before or exactly
-- as a session is established). Only HR/Management may read it.
--
-- NOT applied automatically — review and run this yourself, ideally
-- against a staging project first. Requires Phase A + B already applied.

create table if not exists audit_log (
  id bigserial primary key,
  occurred_at timestamptz not null default now(),
  actor_email text not null default '',
  actor_role text not null default '',
  action text not null,
  target_type text not null default '',
  target_id text not null default '',
  details jsonb not null default '{}'
);
create index if not exists idx_audit_log_occurred_at on audit_log (occurred_at desc);
create index if not exists idx_audit_log_actor on audit_log (actor_email);

alter table audit_log enable row level security;

drop policy if exists audit_log_select_staff on audit_log;
create policy audit_log_select_staff on audit_log for select to authenticated
  using (current_app_is_hr_or_mgmt());

-- Deliberately no insert/update/delete policy for anon/authenticated —
-- writes only happen via this SECURITY DEFINER RPC (which ignores
-- whatever actor the caller might try to pass — it's always derived from
-- their own JWT) or directly from a service_role caller, which bypasses
-- RLS entirely.
create or replace function log_audit_event(
  p_action text,
  p_target_type text default '',
  p_target_id text default '',
  p_details jsonb default '{}'
) returns void
language sql security definer set search_path = public as $$
  insert into audit_log (actor_email, actor_role, action, target_type, target_id, details)
  values (coalesce(current_app_email(), ''), coalesce(current_app_role(), ''), p_action, p_target_type, p_target_id, p_details);
$$;

revoke all on function log_audit_event(text, text, text, jsonb) from public;
grant execute on function log_audit_event(text, text, text, jsonb) to authenticated;
