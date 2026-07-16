-- Follow-up to Phase C (20260716000200_document_buckets.sql): adds
-- server-side file-type and size enforcement to the RESUME and
-- 'onboarding attachments' buckets — idea.txt's File Upload Security
-- section asked for this, and the buckets migration only made them
-- private, it didn't cap what could be uploaded into them. Until now the
-- only enforcement was client-side (lib/widgets/app_file_picker.dart's
-- `accept` string, and onboarding_form_page.dart's 1MB post-compression
-- check) — trivially bypassed by anyone calling Storage directly with the
-- anon key, the same way the whole app used to.
--
-- Types allowed match every accept: string actually used across the app
-- (candidate_application_form_page.dart, employee_kra_page.dart,
-- onboarding_form_page.dart): PDF, Word, Excel, JPEG, PNG.
--
-- NOT applied automatically — review and run this yourself. Requires the
-- buckets to already exist (Phase C).

update storage.buckets
   set file_size_limit = 10 * 1024 * 1024, -- 10MB
       allowed_mime_types = array[
         'application/pdf',
         'application/msword',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
         'application/vnd.ms-excel',
         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
         'image/jpeg',
         'image/png'
       ]
 where id = 'RESUME';

update storage.buckets
   set file_size_limit = 2 * 1024 * 1024, -- 2MB — the app's own client-side target is 1MB after compression
       allowed_mime_types = array[
         'application/pdf',
         'application/msword',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
         'application/vnd.ms-excel',
         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
         'image/jpeg',
         'image/png'
       ]
 where id = 'onboarding attachments';
