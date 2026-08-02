-- The CEO holds every administrative right, but has no personal HR record:
-- no check-in/out, no leave or permission requests of his own, no payslips,
-- no personal tasks. Reports, data, analysis, and adding or removing things —
-- nothing else.
--
-- An explicit flag rather than inferring it from the other exemptions.
-- "exempt from attendance AND leave rules AND payroll" is true of the CEO
-- today, but only as a coincidence of three unrelated settings; a future
-- auditor or consultant could match that pattern without being oversight-only.
alter table app_users
  add column if not exists oversight_only boolean not null default false;

comment on column app_users.oversight_only is
  'Full administrative rights, but no personal HR record: no check-in/out, no own leave or permission, no payslips or personal tasks. Reports, data, analysis and configuration only. True for the CEO.';

alter table app_users disable trigger trg_protect_app_users;
update app_users set oversight_only = true where role = 'CEO';
alter table app_users enable trigger trg_protect_app_users;

-- protect_app_users_sensitive_columns() extended to pin oversight_only and the
-- five exempt*/payroll flags, so an ordinary employee's whole-record upsert
-- cannot grant itself an exemption. Full body applied in this migration's
-- companion; see 20260802000600 for the pattern.
