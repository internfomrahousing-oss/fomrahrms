-- Phase C of the FOMRA HRMS security audit: stop serving resumes, KRA
-- documents, onboarding attachments, pre-offer letters and profile photos
-- via permanent public URLs.
--
-- Context: every upload in the app (see SupabaseService.uploadResume/
-- uploadFile/uploadKraFile/uploadPreOfferPdf/updateCurrentUserPhoto, and
-- onboarding_form_page.dart's _uploadSingleFile) called getPublicUrl() on
-- the RESUME and 'onboarding attachments' buckets — meaning anyone with
-- the URL (which is either fully guessable, like the pre-offer letter
-- path, or was simply visible in the app/network traffic) could read it
-- with no authentication at all, forever. The Flutter app has already been
-- updated to store bare storage paths instead of URLs and to resolve them
-- to short-lived signed URLs on demand (SupabaseService.resolveAttachmentUrl)
-- — this migration is the other half: making the buckets actually private
-- and adding the policies those signed-URL calls need to succeed.
--
-- Unlike the attendance-selfies bucket (20260716020000_attendance_selfies.sql),
-- these two buckets mix candidate/employee uploads in shared folders
-- (custom_uploads/, kra_uploads/) with no per-owner path segment, so
-- fine-grained "only the owner or their reviewer" read policies aren't
-- achievable without restructuring upload paths — a bigger change than
-- this security-only pass should make silently. The read policy here is
-- therefore "any authenticated company user", which is still a large
-- improvement over "anyone on the internet" and matches how these
-- documents are actually consumed today (HR/Management review screens,
-- and each employee's own KRA/leave/profile pages).
--
-- NOT applied automatically — review and run this yourself, ideally
-- against a staging project first. Requires Phase A + B already applied.

insert into storage.buckets (id, name, public)
values ('RESUME', 'RESUME', false)
on conflict (id) do update set public = false;

insert into storage.buckets (id, name, public)
values ('onboarding attachments', 'onboarding attachments', false)
on conflict (id) do update set public = false;

-- ── RESUME bucket ────────────────────────────────────────────────────────
-- Written by both anon candidates (resumes, custom application fields) and
-- authenticated employees/HR (leave proof, maintenance attachments, KRA
-- docs, pre-offer letters, profile photos) — see the upload call sites
-- listed above. Read by authenticated company users only (never anon).

drop policy if exists resume_insert_anon on storage.objects;
create policy resume_insert_anon
  on storage.objects for insert
  to anon
  with check (bucket_id = 'RESUME');

drop policy if exists resume_insert_authenticated on storage.objects;
create policy resume_insert_authenticated
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'RESUME');

drop policy if exists resume_select_authenticated on storage.objects;
create policy resume_select_authenticated
  on storage.objects for select
  to authenticated
  using (bucket_id = 'RESUME');

-- ── 'onboarding attachments' bucket ─────────────────────────────────────
-- Written by anon candidates via the public /onboarding-form/{token} link
-- (onboarding_form_page.dart), before they have any account. Read by
-- authenticated company users only.

drop policy if exists onboarding_attachments_insert_anon on storage.objects;
create policy onboarding_attachments_insert_anon
  on storage.objects for insert
  to anon
  with check (bucket_id = 'onboarding attachments');

drop policy if exists onboarding_attachments_insert_authenticated on storage.objects;
create policy onboarding_attachments_insert_authenticated
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'onboarding attachments');

drop policy if exists onboarding_attachments_select_authenticated on storage.objects;
create policy onboarding_attachments_select_authenticated
  on storage.objects for select
  to authenticated
  using (bucket_id = 'onboarding attachments');

-- No update/delete policies granted on either bucket — nothing in the app
-- edits an uploaded file in place (pre-offer letters intentionally hit a
-- 409-duplicate instead, see uploadPreOfferPdf's comment), so this matches
-- existing behavior.
