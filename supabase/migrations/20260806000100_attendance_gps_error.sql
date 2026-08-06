-- GPS is null on 100% of attendance records, still, after three attempts:
-- skipping the unreliable web service-check, adding diagnostics, and
-- reordering the request ahead of the store loads. Each was a plausible
-- hypothesis and none was verifiable, because the reason lives in
-- GpsTrackingService.lastLocationError and was never persisted — it existed
-- only in the browser of whoever checked in.
--
-- Record it instead of guessing a fourth time. One check-in then says exactly
-- which it is: services disabled, permission denied, permission blocked,
-- timeout, or an exception with its message.
alter table attendance_records
  add column if not exists check_in_gps_error  text default '',
  add column if not exists check_out_gps_error text default '';

comment on column attendance_records.check_in_gps_error is
  'Why the location fix failed at check-in, empty when it succeeded. Diagnostic only — never shown to the employee.';
