-- attendance_records.date is TEXT in dd/MM/yyyy, so it sorts lexically:
-- '01/08/2026' sorts BEFORE '30/07/2026'. Any report, export or query ordered
-- by that column misorders across a month boundary. Verified on production:
-- an 01/08 row lands at text position 1 and correct position 6.
--
-- Converting the column outright would require changing the Flutter app's
-- storage-key sites in the same release. Doing the DB half alone makes the
-- app's .eq('date', '31/07/2026') lookups miss, so today's check-in would not
-- be found and duplicate rows would be created. ~77 call sites build slash
-- dates and most are display-only, so telling them apart is a change that
-- wants tests and a compiler behind it, not a blind edit.
--
-- This adds a STORED GENERATED column instead: a real DATE, derived
-- automatically, always in step, zero app changes required. Reports and
-- exports order by date_iso; the app keeps using `date` exactly as before.
-- The full conversion can then happen calmly, later, behind tests.
--
-- Note: to_date()/::date are only STABLE (they depend on the DateStyle GUC),
-- so a generated column cannot use them — Postgres rejects it with
-- "generation expression is not immutable". make_date() over extracted
-- integer parts is genuinely immutable.

create or replace function public.slash_date_to_date(p text)
returns date
language sql
immutable
returns null on null input
as $function$
  select case
    when p ~ '^\d{2}/\d{2}/\d{4}$'
      then make_date(substr(p,7,4)::int, substr(p,4,2)::int, substr(p,1,2)::int)
    when p ~ '^\d{4}-\d{2}-\d{2}$'
      then make_date(substr(p,1,4)::int, substr(p,6,2)::int, substr(p,9,2)::int)
    else null
  end;
$function$;

alter table attendance_records drop column if exists date_iso;

alter table attendance_records
  add column date_iso date
  generated always as (public.slash_date_to_date(date)) stored;

create index if not exists attendance_records_date_iso_idx
  on attendance_records (date_iso);

create index if not exists attendance_records_emp_date_iso_idx
  on attendance_records (employee_id, date_iso);
