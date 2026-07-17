-- Tightens the attendance selfie feature per follow-up request:
-- retention moved from 30 to 45 days, and the storage size cap tightened
-- from a 300KB backstop down to a hard 200KB (the client already only ever
-- uploads compressed selfies targeting 200KB — see
-- lib/utils/image_compress_native.dart / image_compress_web.dart — this
-- just removes the slack in the server-side backstop to match).
--
-- NOT applied automatically — review and run this yourself (Supabase SQL
-- Editor or `supabase db push`). After running this, redeploy
-- purge-attendance-selfies (RETENTION_DAYS is now 45 there too) — the
-- existing pg_cron schedule from the previous migration doesn't need to
-- change, it just calls the redeployed function.

update storage.buckets
   set file_size_limit = 204800 -- 200 KB
 where id = 'attendance-selfies';

-- Defense in depth: even if the daily purge job hasn't run yet, HR/
-- Management can never generate a signed URL for (or otherwise read) a
-- selfie older than 45 days. Uses attendance_records.created_at rather
-- than storage.objects.created_at, since that's the timestamp the purge
-- function itself keys off of.
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
    and exists (
      select 1 from attendance_records ar
       where ar.created_at > now() - interval '45 days'
         and (ar.check_in_selfie_path = storage.objects.name
              or ar.check_out_selfie_path = storage.objects.name)
    )
  );
