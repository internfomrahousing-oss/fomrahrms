-- attendance_records.date is text in dd/MM/yyyy. A full conversion to a date
-- column is NOT needed, and would be the riskier change:
--
--   * date_iso is a STORED GENERATED column derived from it, so the two cannot
--     drift apart. The lexical-sort bug that motivated it is already solved.
--   * All three queries against `date` are exact matches
--     (fetchAttendanceForDate, fetchAttendanceForDates, fetchCheckedInAttendance).
--     Nothing sorts or ranges on the text column.
--   * Converting it would break every one of those matches and the record id,
--     which is derived from the slash date — for no gain.
--
-- What was still missing is a guarantee that only a valid dd/MM/yyyy string can
-- be written. A malformed value would silently produce a NULL date_iso and
-- disappear from every date-based view and report.
alter table attendance_records drop constraint if exists attendance_date_format;
alter table attendance_records add constraint attendance_date_format
  check (date ~ '^\d{2}/\d{2}/\d{4}$');

alter table attendance_records drop constraint if exists attendance_date_iso_resolves;
alter table attendance_records add constraint attendance_date_iso_resolves
  check (date_iso is not null);

comment on column attendance_records.date is
  'Working date as dd/MM/yyyy. Kept as text because the app matches on it exactly and the record id is derived from it. Sorting and ranges must use date_iso, generated from this and unable to drift.';
