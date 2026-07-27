-- Reverts 20260727000200_ensure_auth_user_id_by_email_rpc.sql.
--
-- That migration (and the matching login/index.ts change) added a
-- fallback so login didn't permanently fail for an employee whose email
-- already had an orphaned auth.users row. This drops the function again
-- per request.
--
-- NOTE: the *original* login Edge Function (pre-dating that fix) also
-- calls auth_user_id_by_email() as part of its normal shadow auth.users
-- provisioning on first login. If this function isn't already defined
-- some other way in this database (e.g. it was never actually applied
-- from 20260716000700_auth_user_lookup_rpc.sql, which was itself marked
-- "review and run this yourself"), dropping it here will make every
-- brand-new employee's first login fail, not just the rehire/orphaned-row
-- edge case this was fixing. Confirm auth_user_id_by_email(text) already
-- exists in this database before running this.

drop function if exists auth_user_id_by_email(text);
