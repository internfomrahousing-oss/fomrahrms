-- Phase D of the FOMRA HRMS security audit: close the two gaps in
-- supabase/functions/send-email and supabase/functions/send-push.
--
-- Context:
--   - send-email had no auth check and no rate limit at all — anyone
--     holding the public anon key (which ships inside the app bundle,
--     so effectively anyone) could use it as an open relay to send
--     arbitrary email as "Fomra Housing & Infrastructure". The function
--     now identifies the caller (signed-in email, or IP for the one
--     legitimate anon case — Forgot Password) and rate-limits either way,
--     backed by the email_rate_limits table this migration creates.
--   - send-push was "protected" by requiring the public anon key as a
--     bearer token — since that key isn't actually secret, this was no
--     protection at all. The notify_push() trigger below is replaced to
--     send a real shared secret instead (stored in Vault, never in git),
--     which the function now requires.
--
-- NOT applied automatically — review and run this yourself, ideally
-- against a staging project first. After running this:
--   1. Generate a random secret, e.g. `openssl rand -base64 32`.
--   2. Store it in Vault (SQL Editor, run once — do not commit the real
--      value to git):
--        select vault.create_secret('<your-random-secret>', 'push_trigger_secret');
--   3. Set the same value as an Edge Function secret:
--        supabase secrets set PUSH_TRIGGER_SECRET=<your-random-secret>
--   4. Redeploy: `supabase functions deploy send-push` and
--      `supabase functions deploy send-email`.

create table if not exists email_rate_limits (
  id bigserial primary key,
  caller_email text not null,
  sent_at timestamptz not null default now()
);
create index if not exists idx_email_rate_limits_caller_sent
  on email_rate_limits (caller_email, sent_at);

-- Only the send-email function (via its service_role key, which bypasses
-- RLS) ever reads or writes this table — no policies granted to anon or
-- authenticated, so it's unreadable/unwritable by the app itself.
alter table email_rate_limits enable row level security;

-- Replaces the version of this trigger embedded as a SQL comment in
-- lib/services/supabase_service.dart, which sent the public anon key as
-- its "Authorization" header — not a real credential, since that key ships
-- in the client bundle. Requires the PUSH_TRIGGER_SECRET manual setup
-- above; until that's done, this trigger will call send-push with an empty
-- secret and every push will be rejected (fails safe, no pushes sent,
-- rather than falling back to the old unauthenticated behavior).
create or replace function notify_push() returns trigger as $$
begin
  perform net.http_post(
    url := 'https://jjkijnmrtkkukdboajxu.functions.supabase.co/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', coalesce(
        (select decrypted_secret from vault.decrypted_secrets where name = 'push_trigger_secret'),
        ''
      )
    ),
    body := jsonb_build_object('record', row_to_json(new))
  );
  return new;
end;
$$ language plpgsql security definer set search_path = public, vault;

drop trigger if exists notifications_push_trigger on notifications;
create trigger notifications_push_trigger
  after insert on notifications
  for each row execute function notify_push();
