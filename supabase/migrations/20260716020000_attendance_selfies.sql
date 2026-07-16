-- Selfie check-in/check-out: adds the storage bucket + columns + access
-- policies backing the mandatory attendance selfie feature.
--
-- Context: check-in/check-out now requires the employee to take an
-- in-app camera photo (never a gallery upload) with the date/day/time/GPS
-- coordinates burned into the image before it's uploaded. The photo must
-- never be visible to the employee themselves — only HR and Management —
-- and must be purged automatically after 30 days. This relies on the real
-- Supabase Auth session minted by supabase/functions/login/index.ts (see
-- 20260716000000_auth_foundation.sql): every request after login carries a
-- JWT with auth.uid() mapped to app_users.auth_user_id, which is what lets
-- the storage policies below tell an employee's own upload apart from an
-- HR/Management read.
--
-- NOT applied automatically — review and run this yourself (Supabase SQL
-- Editor or `supabase db push`), ideally against a staging project first.
-- After running this, deploy the purge function and schedule the cron job
-- described at the bottom of this file (also manual — see that section).

alter table attendance_records add column if not exists check_in_selfie_path text default '';
alter table attendance_records add column if not exists check_out_selfie_path text default '';

-- Private bucket — never served via getPublicUrl(). HR/Management pages
-- exchange a stored path for a short-lived signed URL on demand
-- (SupabaseService.attendanceSelfieUrl). 300KB hard cap on the server as a
-- backstop behind the app's own 200KB client-side compression target.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('attendance-selfies', 'attendance-selfies', false, 307200, array['image/jpeg'])
on conflict (id) do update
  set public = false,
      file_size_limit = 307200,
      allowed_mime_types = array['image/jpeg'];

-- An employee may only upload into the folder matching their own
-- employee_id — object paths are '{employee_id}/{date}_{checkin|checkout}_
-- {timestamp}.jpg', enforced by requiring the first path segment
-- (storage.foldername(name))[1] to equal their own employee_id.
drop policy if exists attendance_selfies_insert_own on storage.objects;
create policy attendance_selfies_insert_own
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'attendance-selfies'
    and (storage.foldername(name))[1] = (
      select employee_id from app_users where auth_user_id = auth.uid()
    )
  );

-- Only HR/Management may read (i.e. generate a signed URL for) any selfie —
-- deliberately not the uploading employee themselves, and not other roles.
drop policy if exists attendance_selfies_select_hr_management on storage.objects;
create policy attendance_selfies_select_hr_management
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'attendance-selfies'
    and exists (
      select 1 from app_users
       where auth_user_id = auth.uid()
         and role in ('HR', 'Management')
    )
  );

-- No update/delete policy is granted to authenticated users on purpose —
-- selfies are immutable from the app's point of view. Only the service_role
-- key (used by the purge-attendance-selfies Edge Function below, which
-- bypasses RLS entirely) can remove them.

-- ── Retention: delete selfies older than 30 days ────────────────────────
--
-- Deleting storage objects has to go through the Storage API (not a plain
-- SQL delete on storage.objects), so the actual purge logic lives in the
-- supabase/functions/purge-attendance-selfies Edge Function using the
-- service role key. This just schedules a daily call to it via pg_cron +
-- pg_net. One-time manual setup required after deploying that function:
--
--   1. In the Supabase dashboard: Database → Extensions → enable
--      "pg_cron" and "pg_net" if not already enabled.
--   2. Store your service role key in Vault (SQL Editor, run once,
--      substitute your real key — do NOT commit the real key to git):
--        select vault.create_secret('<your-service-role-key>', 'service_role_key');
--   3. Deploy the function: `supabase functions deploy purge-attendance-selfies`
--   4. Run the cron.schedule call below (edit the project ref first).
--
-- select cron.schedule(
--   'purge-attendance-selfies-daily',
--   '0 3 * * *', -- 03:00 UTC daily
--   $$
--   select net.http_post(
--     url := 'https://<your-project-ref>.supabase.co/functions/v1/purge-attendance-selfies',
--     headers := jsonb_build_object(
--       'Authorization', 'Bearer ' || (
--         select decrypted_secret from vault.decrypted_secrets
--          where name = 'service_role_key'
--       ),
--       'Content-Type', 'application/json'
--     ),
--     body := '{}'::jsonb
--   );
--   $$
-- );
