-- Daily task-update log: an employee with an active (not-yet-Completed)
-- task must post a short comment on it each working day, checked by the
-- new logout gate (see lib/services/task_logout_gate.dart) before they're
-- allowed to sign out. This table is the append-only log those comments
-- land in — one row per comment, not one row per day, so an employee can
-- post more than once and still see full history; "did they update today"
-- is just "does a row exist for (task_id, employee_name, today)".

create table if not exists task_updates (
  id bigserial primary key,
  task_id text not null references tasks(id) on delete cascade,
  employee_name text not null default '',
  update_date date not null default current_date,
  comment text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists idx_task_updates_task on task_updates(task_id);
create index if not exists idx_task_updates_employee_date on task_updates(employee_name, update_date);

alter table task_updates enable row level security;

-- select: the employee who wrote them, anyone assigned to (or on the team
-- of) the task itself, and HR/Management. insert: only as yourself.
drop policy if exists task_updates_select on task_updates;
create policy task_updates_select on task_updates for select to authenticated
  using (
    employee_name = current_app_name()
    or exists (
      select 1 from tasks t where t.id = task_updates.task_id
        and (t.assigned_employee = current_app_name()
             or position(current_app_name() in coalesce(t.team_members, '')) > 0)
    )
    or current_app_is_hr_or_mgmt()
  );

drop policy if exists task_updates_insert on task_updates;
create policy task_updates_insert on task_updates for insert to authenticated
  with check (employee_name = current_app_name());
