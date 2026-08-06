-- The CEO is an approving authority, not a tracked employee: no daily
-- check-in/out, no attendance history, no payroll. The flags already said so
-- (exempt_from_attendance, payroll_eligible false, oversight_only), but a
-- record written BEFORE those flags existed was still in the history and
-- still appearing in attendance views.
--
-- Archived rather than dropped, consistent with employee deletion: an
-- attendance row removed by mistake cannot be reconstructed.
insert into deleted_employee_archive (employee_id, employee_name, email, source_table, row_data)
select a.employee_id, a.employee_name,
       (select email from app_users u where u.employee_id = a.employee_id),
       'attendance_records (CEO exempt)', to_jsonb(a)
  from attendance_records a
  join app_users u on u.employee_id = a.employee_id
 where u.exempt_from_attendance;

delete from attendance_records a
 using app_users u
 where u.employee_id = a.employee_id and u.exempt_from_attendance;

-- Keep it that way. The UI hides the check-in button for exempt users, but a
-- hidden button is not a boundary — a stale client or a direct API call would
-- still write the row.
create or replace function public.block_exempt_attendance()
returns trigger language plpgsql as $function$
begin
  if exists (select 1 from app_users
              where employee_id = new.employee_id
                and coalesce(exempt_from_attendance, false)) then
    raise exception
      'This account is not tracked for attendance and cannot check in or out.'
      using errcode = 'check_violation';
  end if;
  return new;
end; $function$;

drop trigger if exists trg_block_exempt_attendance on attendance_records;
create trigger trg_block_exempt_attendance
  before insert or update on attendance_records
  for each row execute function public.block_exempt_attendance();
