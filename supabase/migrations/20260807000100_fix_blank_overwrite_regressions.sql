-- Two regressions found in end-to-end verification. Both are the same shape as
-- the employee_id renumbering bug: the client upserts the WHOLE record, a field
-- it did not carry arrives blank, and blank was written as a real value rather
-- than treated as "unchanged".

-- 1. weekly_off_day silently wiped.
--    Sijo was set to Tuesday on 2 Aug and was blank again by 7 Aug. Blank reads
--    as Sunday, and Sales WORKS Sundays — so his working day was marked as his
--    off day and his real off day as working.
--
--    '' is a legitimate value meaning Sunday, so it cannot be rejected outright.
--    But going from a set value BACK to blank is almost always an upsert that
--    did not carry the field. Preserve the old value; setting Sunday
--    deliberately still works by sending 'Sunday'.
create or replace function public.preserve_blank_weekly_off()
returns trigger language plpgsql as $function$
begin
  if tg_op = 'UPDATE'
     and coalesce(btrim(new.weekly_off_day), '') = ''
     and coalesce(btrim(old.weekly_off_day), '') <> '' then
    new.weekly_off_day := old.weekly_off_day;
  end if;
  return new;
end; $function$;

drop trigger if exists trg_preserve_blank_weekly_off on app_users;
create trigger trg_preserve_blank_weekly_off
  before update of weekly_off_day on app_users
  for each row execute function public.preserve_blank_weekly_off();

-- 2. date_of_joining written as dd/MM/yyyy again.
--    Normalising the rows was a one-off data fix; the client keeps writing
--    slash format, so newer employees drifted back while older ones stayed
--    ISO. Mixed formats in one column break sorting and any direct query.
--    Normalise on write instead of after the fact.
create or replace function public.normalise_employee_dates()
returns trigger language plpgsql as $function$
begin
  if new.date_of_joining ~ '^\d{2}/\d{2}/\d{4}$' then
    new.date_of_joining := substr(new.date_of_joining,7,4)||'-'||
                           substr(new.date_of_joining,4,2)||'-'||
                           substr(new.date_of_joining,1,2);
  end if;
  if new.date_of_birth ~ '^\d{2}/\d{2}/\d{4}$' then
    new.date_of_birth := substr(new.date_of_birth,7,4)||'-'||
                         substr(new.date_of_birth,4,2)||'-'||
                         substr(new.date_of_birth,1,2);
  end if;
  return new;
end; $function$;

drop trigger if exists trg_normalise_employee_dates on app_users;
create trigger trg_normalise_employee_dates
  before insert or update of date_of_joining, date_of_birth on app_users
  for each row execute function public.normalise_employee_dates();

alter table app_users disable trigger trg_protect_app_users;
update app_users set date_of_joining = substr(date_of_joining,7,4)||'-'||substr(date_of_joining,4,2)||'-'||substr(date_of_joining,1,2)
 where date_of_joining ~ '^\d{2}/\d{2}/\d{4}$';
update app_users set date_of_birth = substr(date_of_birth,7,4)||'-'||substr(date_of_birth,4,2)||'-'||substr(date_of_birth,1,2)
 where date_of_birth ~ '^\d{2}/\d{2}/\d{4}$';
update app_users set weekly_off_day = 'Tuesday' where employee_id = 'FHIPL-03';
alter table app_users enable trigger trg_protect_app_users;
