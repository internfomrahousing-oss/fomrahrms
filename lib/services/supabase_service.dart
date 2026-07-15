// ignore_for_file: avoid_catches_without_on_clauses
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../models/appraisal_store.dart';
import '../models/attendance_store.dart';
import '../models/leave_store.dart';
import '../models/maintenance_store.dart';
import '../models/notification_store.dart';
import '../models/payslip_store.dart';
import '../models/profile_store.dart';
import '../models/employee_store.dart';
import '../models/kra_store.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';

/*
  Run the following SQL in your Supabase SQL Editor to create the tables:

  create table if not exists leave_applications (
    id text primary key,
    employee_name text not null,
    employee_id text default '',
    department text default '',
    leave_type text default '',
    from_date date not null,
    to_date date not null,
    days integer not null,
    reason text default '',
    applied_on timestamptz default now(),
    manager_status text default 'pending',
    decided_by text default '',
    rejection_comment text default '',
    is_half_day boolean default false
  );

  -- If the table already exists:
  alter table leave_applications add column if not exists decided_by text default '';
  alter table leave_applications add column if not exists rejection_comment text default '';
  alter table leave_applications add column if not exists is_half_day boolean default false;
  alter table leave_applications add column if not exists management_status text default 'pending';
  alter table leave_applications add column if not exists management_decided_by text default '';
  alter table leave_applications add column if not exists management_rejection_comment text default '';
  alter table leave_applications add column if not exists proof_url text default '';
  alter table leave_applications add column if not exists leave_bucket text default '';

  alter table onboarding_forms disable row level security;

  create table if not exists onboarding_forms (
    id uuid primary key default gen_random_uuid(),
    submitted_at timestamptz default now(),
    name text, phone_number text, father_name text, designation text,
    date_of_joining text, full_name text, date_of_birth text,
    postal_address text, permanent_address text,
    family_details jsonb default '[]',
    education jsonb default '[]',
    experience jsonb default '[]',
    last_reporting_name text, last_reporting_designation text,
    last_company text, reference1 text, reference2 text,
    esi_number text, pf_number text, languages_known text,
    hobbies text, interests text, related_to_employee text,
    professional_membership text, specialized_training text,
    other_information text, blood_group text, allergic_to text,
    major_illness text, emergency_contact_name text,
    emergency_contact_number text, emergency_contact_address text,
    aadhar_number text, declaration_date text, declaration_place text
  );

  create table if not exists lead_sources (
    id text primary key,
    name text not null,
    url text not null,
    created_at timestamptz default now()
  );

  create table if not exists maintenance_tickets (
    id text primary key,
    reported_by_role text not null,
    reported_by text not null,
    issue_for text not null default 'IT',
    issue_type text not null,
    description text not null,
    status text default 'open',
    sent_to_management boolean default false,
    management_reviewed boolean default false,
    resolution_note text,
    resolved_at timestamptz,
    created_at timestamptz default now()
  );
  -- If table already exists, add the newer columns:
  alter table maintenance_tickets add column if not exists sent_to_management boolean default false;
  alter table maintenance_tickets add column if not exists issue_for text not null default 'IT';
  alter table maintenance_tickets add column if not exists management_reviewed boolean default false;
  alter table maintenance_tickets add column if not exists resolution_note text;
  alter table maintenance_tickets add column if not exists resolved_at timestamptz;
  alter table maintenance_tickets add column if not exists priority text not null default 'Medium';

  create table if not exists app_settings (
    id text primary key default 'global',
    color_theme text default 'midnightBlue'
  );
  -- Empty banner_quote means "no Management override" — the app rotates
  -- through a built-in daily Mahatria Ra quote instead.
  alter table app_settings add column if not exists banner_quote text default '';
  alter table app_settings add column if not exists banner_quote_author text default '';

  create table if not exists payslip_requests (
    id text primary key,
    employee_id text default '',
    employee_name text default '',
    month_year text not null,
    status text default 'pending',
    requested_at timestamptz default now(),
    decided_at timestamptz,
    decided_by text default '',
    rejection_comment text default ''
  );
  alter table payslip_requests add column if not exists rejection_comment text default '';

  create table if not exists payslips (
    id text primary key,
    employee_id text default '',
    month_year text not null,
    emp_name text default '',
    department text default '',
    designation text default '',
    band text default '',
    date_of_joining text default '',
    working_days integer default 0,
    days_worked integer default 0,
    lop_days integer default 0,
    gross_pay numeric default 0,
    basic numeric default 0,
    hra numeric default 0,
    educational_allowance numeric default 0,
    lta numeric default 0,
    other_allowance numeric default 0,
    conveyance_allowance numeric default 0,
    special_allowance numeric default 0,
    epf numeric default 0,
    professional_tax numeric default 0,
    tds numeric default 0,
    late_deductions numeric default 0,
    excess_leave_deduction numeric default 0,
    cug numeric default 0,
    leave_details text default '[]',
    generated_at timestamptz default now(),
    generated_by text default ''
  );

  -- If the table already exists:
  alter table payslips add column if not exists excess_leave_deduction numeric default 0;

  create table if not exists employee_profiles (
    employee_id text primary key,
    full_name text default '',
    mobile text default '',
    email text default '',
    address text default '',
    department text default '',
    designation text default '',
    reporting_manager text default '',
    date_of_joining text default ''
  );

  create table if not exists employees (
    id text primary key,
    name text not null,
    department text default '',
    designation text default '',
    mobile text default '',
    email text default '',
    address text default '',
    blood_group text default '',
    manager text default '',
    joining_date text default '',
    salary text default '',
    emergency_name text default '',
    emergency_phone text default '',
    bank_account text default '',
    ifsc text default ''
  );

  create table if not exists candidate_applications (
    id uuid default gen_random_uuid() primary key,
    submitted_at timestamptz default now(),
    name text default '',
    mobile text default '',
    place text default '',
    dob text default '',
    nationality text default '',
    email text default '',
    gender text default '',
    marital_status text default '',
    age text default '',
    interview_date text default '',
    post_applied text default '',
    total_experience text default '',
    relevant_experience text default '',
    reason_for_change text default '',
    current_ctc text default '',
    expected_ctc text default '',
    notice_period text default '',
    source text default '',
    job_portal text default '',
    referred_by text default '',
    related_employee text default '',
    applied_before text default '',
    hr_status text default 'pending',
    hr_comment text default '',
    assigned_manager text default '',
    manager_status text default 'pending',
    manager_comment text default '',
    management_status text default 'pending',
    management_comment text default ''
  );

  -- If the table already exists, add the review columns:
  alter table candidate_applications add column if not exists hr_status text default 'pending';
  alter table candidate_applications add column if not exists hr_comment text default '';
  alter table candidate_applications add column if not exists assigned_manager text default '';
  alter table candidate_applications add column if not exists manager_status text default 'pending';
  alter table candidate_applications add column if not exists manager_comment text default '';
  alter table candidate_applications add column if not exists management_status text default 'pending';
  alter table candidate_applications add column if not exists management_comment text default '';
  alter table candidate_applications add column if not exists standing_arrears text default '';
  alter table candidate_applications add column if not exists education_history jsonb default '[]';
  alter table candidate_applications add column if not exists employment_history jsonb default '[]';
  alter table candidate_applications add column if not exists referrals jsonb default '[]';
  alter table candidate_applications add column if not exists address text default '';
  alter table candidate_applications add column if not exists declaration_name text default '';
  alter table candidate_applications add column if not exists signature_date text default '';
  alter table candidate_applications add column if not exists declaration_agreed boolean default false;
  alter table candidate_applications add column if not exists resume_url text default '';
  alter table candidate_applications add column if not exists custom_field_values jsonb default '{}';
  alter table candidate_applications add column if not exists pre_offer_sent boolean default false;
  alter table candidate_applications add column if not exists pre_offer_sent_at text default '';
  alter table candidate_applications add column if not exists department text default '';
  alter table candidate_applications add column if not exists designation text default '';

  create table if not exists app_users (
    email text primary key,
    name text default '',
    employee_id text default '',
    designation text default '',
    role text default 'Employee',
    active boolean default true,
    password text default '',
    leave_allocation integer default 21,
    reporting_manager text default '',
    mobile text default '',
    address text default '',
    date_of_joining text default ''
  );

  -- If the table already exists, add missing columns:
  alter table app_users add column if not exists password text default '';
  alter table app_users add column if not exists leave_allocation integer default 21;
  alter table app_users add column if not exists reporting_manager text default '';
  alter table app_users add column if not exists mobile text default '';
  alter table app_users add column if not exists address text default '';
  alter table app_users add column if not exists date_of_joining text default '';
  alter table app_users add column if not exists el_avail_requested_at text default '';
  alter table app_users add column if not exists el_last_availed_at text default '';
  alter table app_users add column if not exists gross_pay numeric default 0;
  alter table app_users add column if not exists onroll_requested_at text default '';
  alter table app_users add column if not exists onroll_hr_status text default 'pending';
  alter table app_users add column if not exists onroll_hr_comment text default '';
  alter table app_users add column if not exists onroll_hr_decided_at text default '';
  alter table app_users add column if not exists onroll_manager_status text default 'pending';
  alter table app_users add column if not exists onroll_manager_comment text default '';
  alter table app_users add column if not exists onroll_manager_decided_at text default '';
  alter table app_users add column if not exists onroll_management_status text default 'pending';
  alter table app_users add column if not exists onroll_management_comment text default '';
  alter table app_users add column if not exists onroll_management_decided_at text default '';
  alter table app_users add column if not exists work_location text default '';
  alter table app_users add column if not exists work_location_pending text default '';
  alter table app_users add column if not exists work_location_requested_at text default '';
  alter table app_users add column if not exists department text default '';
  alter table app_users add column if not exists reporting_manager_pending text default '';
  alter table app_users add column if not exists reporting_manager_requested_at text default '';
  alter table app_users add column if not exists is_reporting_manager boolean default false;
  alter table app_users add column if not exists is_reporting_manager_pending boolean default false;
  alter table app_users add column if not exists date_of_birth text default '';
  alter table app_users add column if not exists is_reporting_manager_requested_at text default '';

  -- Device Binding: one registered mobile device per employee, gates mobile
  -- app login/check-in-out (see DeviceBindingService). device_id empty = no
  -- device registered (never logged in from mobile, or HR reset it).
  alter table app_users add column if not exists device_id text default '';
  alter table app_users add column if not exists device_name text default '';
  alter table app_users add column if not exists device_platform text default '';
  alter table app_users add column if not exists device_registered_at text default '';
  alter table app_users add column if not exists device_last_login text default '';

  -- One-time backfill: existing Manager-role users must keep RM-dropdown
  -- eligibility now that eligibility is flag-based, not role-based.
  update app_users set is_reporting_manager = true where role = 'Manager' and is_reporting_manager = false;

  create table if not exists tasks (
    id text primary key,
    name text default '',
    description text default '',
    priority text default 'medium',
    start_date date not null,
    due_date date not null,
    weightage integer default 0,
    status text default 'assigned',
    assigned_employee text default '',
    team_members text default '',
    team_member_statuses text default '{}',
    department text default '',
    attachment text default ''
  );

  -- If the table already exists, add the new column:
  alter table tasks add column if not exists team_member_statuses text default '{}';

  create table if not exists onboarding_form_versions (
    id uuid default gen_random_uuid() primary key,
    created_at timestamptz default now(),
    created_by text default '',
    status text default 'pending',
    form_config jsonb not null default '{}',
    version_number integer default 1,
    approved_at timestamptz,
    approved_by text default '',
    rejection_note text default ''
  );
  alter table onboarding_form_versions disable row level security;
  alter table onboarding_forms add column if not exists mother_name text default '';
  alter table onboarding_forms add column if not exists aadhar_url text default '';
  alter table onboarding_forms add column if not exists attachments jsonb default '[]';
  alter table onboarding_forms add column if not exists mother_name text default '';

  -- Disable Row Level Security for development (enable and add policies for production)
  alter table leave_applications disable row level security;
  alter table maintenance_tickets disable row level security;
  alter table employee_profiles   disable row level security;
  alter table employees           disable row level security;
  alter table candidate_applications disable row level security;
  alter table app_users           disable row level security;
  alter table tasks               disable row level security;
  alter table app_settings        disable row level security;
  alter table payslip_requests    disable row level security;
  alter table payslips            disable row level security;

  -- Onboarding workflow columns (run if table already exists):
  alter table onboarding_forms add column if not exists status text default 'pending';
  alter table onboarding_forms add column if not exists hr_comment text default '';
  alter table onboarding_forms add column if not exists assigned_email text default '';
  alter table onboarding_forms add column if not exists assigned_emp_id text default '';
  alter table onboarding_forms add column if not exists assigned_manager text default '';
  alter table onboarding_forms add column if not exists assigned_department text default '';
  alter table onboarding_forms add column if not exists assigned_designation text default '';

  create table if not exists attendance_records (
    id text primary key,
    employee_name text not null,
    employee_id text default '',
    date text not null,
    check_in_time text default '',
    check_out_time text default '',
    created_at timestamptz default now()
  );
  alter table attendance_records disable row level security;
  alter table attendance_records add column if not exists check_in_note text default '';
  alter table attendance_records add column if not exists check_out_note text default '';

  create table if not exists form_versions (
    id uuid default gen_random_uuid() primary key,
    created_at timestamptz default now(),
    created_by text default '',
    status text default 'pending',
    form_config jsonb not null default '{}',
    version_number integer default 1,
    approved_at timestamptz,
    approved_by text default '',
    rejection_note text default ''
  );
  alter table form_versions disable row level security;

  create table if not exists notifications (
    id uuid default gen_random_uuid() primary key,
    created_at timestamptz default now(),
    type text not null,
    title text not null,
    body text default '',
    route text default '',
    target_email text default '',
    target_role text default '',
    target_reporting_manager text default '',
    source_id text default '',
    read_by jsonb default '[]'
  );
  alter table notifications disable row level security;
  create index if not exists idx_notifications_email on notifications(target_email);
  create index if not exists idx_notifications_role  on notifications(target_role);
  create index if not exists idx_notifications_rm    on notifications(target_reporting_manager);

  -- Retention: rows older than 20 days are pruned daily via pg_cron — the
  -- app's "All time" filter only ever shows what's still in the table, it
  -- doesn't assume full history is retained.
  create extension if not exists pg_cron with schema extensions;
  select cron.schedule(
    'delete-old-notifications',
    '0 3 * * *',
    $$ delete from notifications where created_at < now() - interval '20 days' $$
  );

  create table if not exists notification_preferences (
    email text primary key,
    muted_categories jsonb default '[]'
  );
  alter table notification_preferences disable row level security;

  -- Push notifications (FCM) — one row per signed-in device. Keyed by the
  -- token itself (not email+platform) so re-registering the same device
  -- after a login on a different account cleanly replaces the old owner.
  create table if not exists device_tokens (
    token text primary key,
    email text not null,
    platform text not null, -- 'android' | 'web'
    updated_at timestamptz default now()
  );
  alter table device_tokens disable row level security;

  -- Fires the send-push Edge Function on every new notification row, so
  -- every existing NotificationService._create() call site gets push for
  -- free without any code changes on the Flutter side.
  create extension if not exists pg_net with schema extensions;
  create or replace function notify_push() returns trigger as $$
  begin
    perform net.http_post(
      url := 'https://jjkijnmrtkkukdboajxu.functions.supabase.co/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impqa2lqbm1ydGtrdWtkYm9hanh1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMTE0NDMsImV4cCI6MjA5NzY4NzQ0M30.6I2swrTQDDT0phQvRqDkLFFo_BxtmxD3NE9R8lDbDeI'
      ),
      body := jsonb_build_object('record', row_to_json(new))
    );
    return new;
  end;
  $$ language plpgsql;

  drop trigger if exists notifications_push_trigger on notifications;
  create trigger notifications_push_trigger
    after insert on notifications
    for each row execute function notify_push();

  -- Employee performance appraisal forms (Task Management → Performance
  -- Management). One row per filled form per employee; history = every row
  -- for that employee_email, newest first.
  create table if not exists appraisal_forms (
    id text primary key,
    employee_email text not null,
    employee_id text default '',
    employee_name text default '',
    status text not null default 'draft', -- 'draft' | 'completed'
    moved_to_salary_hike boolean not null default false,
    data jsonb not null default '{}',
    created_by text default '',
    last_edited_by text default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );
  create index if not exists appraisal_forms_employee_idx on appraisal_forms (employee_email);
  alter table appraisal_forms disable row level security;

  -- KRA (Key Result Areas) documents HR or Management upload per employee.
  -- One row per uploaded file; history = every row for that employee_email,
  -- newest first. Files themselves live in the existing RESUME storage
  -- bucket under kra_uploads/.
  --
  -- HR uploads start 'pending' and only reach the employee once Management
  -- approves (see kra_approvals_page.dart); Management's own uploads are
  -- saved as 'approved' directly (no self-review needed).
  create table if not exists kra_documents (
    id text primary key,
    employee_email text not null,
    employee_name text default '',
    file_name text default '',
    file_url text default '',
    uploaded_by text default '',
    uploaded_at timestamptz not null default now(),
    status text not null default 'pending', -- 'pending' | 'approved' | 'rejected'
    decided_by text default '',
    decided_at timestamptz,
    review_note text default ''
  );
  create index if not exists kra_documents_employee_idx on kra_documents (employee_email);
  alter table kra_documents disable row level security;

  -- Run this instead if kra_documents already exists from before the approval workflow:
  -- alter table kra_documents add column if not exists status text not null default 'pending';
  -- alter table kra_documents add column if not exists decided_by text default '';
  -- alter table kra_documents add column if not exists decided_at timestamptz;
  -- alter table kra_documents add column if not exists review_note text default '';

  -- ── Post-approval recruitment email workflow ──────────────────────────
  -- Pre-Offer Letter (PDF + secure accept token) → Onboarding Form (secure
  -- token link) → HR field assignment (already existed) → Management
  -- approval → token-based account activation (no password emailed).

  alter table candidate_applications add column if not exists pre_offer_token text default '';
  alter table candidate_applications add column if not exists pre_offer_token_created_at text default '';
  alter table candidate_applications add column if not exists pre_offer_accepted boolean default false;
  alter table candidate_applications add column if not exists pre_offer_accepted_at text default '';
  alter table candidate_applications add column if not exists onboarding_token text default '';
  alter table candidate_applications add column if not exists onboarding_link_sent boolean default false;
  alter table candidate_applications add column if not exists onboarding_link_sent_at text default '';
  alter table candidate_applications add column if not exists onboarding_completed boolean default false;
  alter table candidate_applications add column if not exists onboarding_completed_at text default '';

  -- Nullable FK: token-based onboarding submissions set this; older
  -- anonymous submissions stay null and keep resolving via the existing
  -- fuzzy name/mobile match in employee_onboarding_page.dart.
  alter table onboarding_forms add column if not exists candidate_application_id uuid references candidate_applications(id);

  -- 24h expiring token for the "Set Your Password" activation link.
  alter table app_users add column if not exists activation_token text default '';
  alter table app_users add column if not exists activation_token_expires_at text default '';

  create table if not exists email_logs (
    id uuid default gen_random_uuid() primary key,
    template_name text not null,
    recipient text not null,
    subject text default '',
    html_body text default '',
    variables jsonb default '{}',
    attachments jsonb default '[]',
    status text default 'pending', -- 'pending' | 'sent' | 'failed'
    created_at timestamptz default now(),
    sent_at timestamptz,
    error_message text default '',
    retry_count integer default 0,
    related_candidate_id uuid,
    related_onboarding_id uuid
  );
  alter table email_logs disable row level security;
  create index if not exists idx_email_logs_recipient on email_logs(recipient);
  create index if not exists idx_email_logs_status on email_logs(status);

  -- Lets the HR portal reflect offer acceptance live without a manual refresh.
  alter publication supabase_realtime add table candidate_applications;
*/

class SupabaseService {
  static SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ── Leave Applications ────────────────────────────────────────────────

  static Future<void> saveLeaveApplication(LeaveApplication app) async {
    // Core upsert — only columns that exist in the original schema
    try {
      await _db?.from('leave_applications').upsert({
        'id':             app.id,
        'employee_name':  app.employeeName,
        'department':     app.department,
        'leave_type':     app.leaveType,
        'from_date':      app.from.toIso8601String().substring(0, 10),
        'to_date':        app.to.toIso8601String().substring(0, 10),
        'days':           app.days,
        'reason':         app.reason,
        'applied_on':     app.appliedOn.toIso8601String(),
        'manager_status': app.managerStatus.name,
      });
    } catch (_) {}
    // is_half_day / proof_url / leave_bucket — added later; skipped silently if columns not yet in DB
    try {
      await _db?.from('leave_applications')
          .update({'is_half_day': app.isHalfDay})
          .eq('id', app.id);
    } catch (_) {}
    try {
      await _db?.from('leave_applications')
          .update({'proof_url': app.proofUrl})
          .eq('id', app.id);
    } catch (_) {}
    try {
      await _db?.from('leave_applications')
          .update({'leave_bucket': app.leaveBucket})
          .eq('id', app.id);
    } catch (_) {}
  }

  static Future<void> updateLeaveManagerStatus(
      String id, LeaveApprovalStatus status,
      {String decidedBy = '', String rejectionComment = ''}) async {
    try {
      await _db?.from('leave_applications').update({
        'manager_status':    status.name,
        'decided_by':        decidedBy,
        'rejection_comment': rejectionComment,
      }).eq('id', id);
    } catch (_) {}
  }

  /// Called when management (HR/admin) approves or denies — writes to the
  /// separate management columns so the manager's decision is never overwritten.
  static Future<void> updateLeaveManagementStatus(
      String id, LeaveApprovalStatus status,
      {String decidedBy = '', String rejectionComment = ''}) async {
    try {
      await _db?.from('leave_applications').update({
        'management_status':            status.name,
        'management_decided_by':        decidedBy,
        'management_rejection_comment': rejectionComment,
      }).eq('id', id);
    } catch (_) {}
  }

  static Future<List<LeaveApplication>> fetchLeaveApplications() async {
    try {
      final data = await _db
          ?.from('leave_applications')
          .select()
          .order('applied_on', ascending: false);
      if (data == null) return [];
      final list = (data as List).map((row) {
        final app = LeaveApplication(
          id:           row['id'] as String,
          employeeName: row['employee_name'] as String,
          department:   (row['department'] as String?) ?? '',
          leaveType:    (row['leave_type'] as String?) ?? '',
          from:         DateTime.parse(row['from_date'] as String),
          to:           DateTime.parse(row['to_date'] as String),
          days:         row['days'] as int,
          reason:       (row['reason'] as String?) ?? '',
          appliedOn:    DateTime.parse(row['applied_on'] as String),
        );
        // Prefer management_status if set — it overrides manager decision and locks manager controls
        final mgmtStatus = _parseStatus(row['management_status']);
        if (mgmtStatus != LeaveApprovalStatus.pending) {
          app.managementDecided = true;
          app.managerStatus    = mgmtStatus;
          app.decidedBy        = (row['management_decided_by']        as String?) ?? '';
          app.rejectionComment = (row['management_rejection_comment'] as String?) ?? '';
        } else {
          app.managerStatus    = _parseStatus(row['manager_status']);
          app.decidedBy        = (row['decided_by']        as String?) ?? '';
          app.rejectionComment = (row['rejection_comment'] as String?) ?? '';
        }
        app.isHalfDay   = (row['is_half_day'] as bool?) ?? false;
        app.proofUrl    = (row['proof_url']  as String?) ?? '';
        app.leaveBucket = (row['leave_bucket'] as String?) ?? '';
        return app;
      }).toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  static LeaveApprovalStatus _parseStatus(dynamic val) =>
      LeaveApprovalStatus.values.firstWhere(
        (s) => s.name == ((val as String?) ?? 'pending'),
        orElse: () => LeaveApprovalStatus.pending,
      );

  // ── Maintenance Tickets ───────────────────────────────────────────────

  static Future<String?> saveMaintenanceTicket(MaintenanceTicket ticket) async {
    try {
      await _db?.from('maintenance_tickets').upsert({
        'id':                   ticket.id,
        'reported_by_role':     ticket.reportedByRole.name,
        'reported_by':          ticket.reportedBy,
        'issue_for':            ticket.issueFor,
        'issue_type':           ticket.issueType,
        'description':          ticket.description,
        'priority':             ticket.priority,
        'status':               ticket.status.name,
        'sent_to_management':   ticket.sentToManagement,
        'management_reviewed':  ticket.managementReviewed,
        'send_to_management_note': ticket.sendToManagementNote,
        'resolution_note':      ticket.resolutionNote,
        'resolved_at':          ticket.resolvedAt?.toIso8601String(),
        'created_at':           ticket.createdAt.toIso8601String(),
        'attachment_url':       ticket.attachmentUrl,
        'attachment_name':      ticket.attachmentName,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Sending (or re-sending) to Management always resets management_reviewed
  // to false, so the ticket lands back in Management's "awaiting review"
  // queue rather than being mistaken for one they've already sent back.
  static Future<void> updateTicketSentToManagement(String id, bool sent, {String? note}) async {
    try {
      final payload = <String, dynamic>{'sent_to_management': sent};
      if (sent) {
        payload['management_reviewed'] = false;
        payload['send_to_management_note'] = note;
      }
      await _db?.from('maintenance_tickets')
          .update(payload)
          .eq('id', id);
    } catch (_) {}
  }

  static Future<void> updateTicketStatus(
      String id, MaintenanceStatus status) async {
    try {
      await _db
          ?.from('maintenance_tickets')
          .update({'status': status.name})
          .eq('id', id);
    } catch (_) {}
  }

  static Future<void> updateTicketManagementReviewed(String id, bool reviewed) async {
    try {
      await _db?.from('maintenance_tickets')
          .update({'management_reviewed': reviewed})
          .eq('id', id);
    } catch (_) {}
  }

  static Future<void> updateTicketResolution(
      String id, String note, DateTime resolvedAt) async {
    try {
      await _db?.from('maintenance_tickets').update({
        'status':          MaintenanceStatus.resolved.name,
        'resolution_note': note,
        'resolved_at':     resolvedAt.toIso8601String(),
      }).eq('id', id);
    } catch (_) {}
  }

  static Future<List<MaintenanceTicket>> fetchMaintenanceTickets() async {
    try {
      final data = await _db
          ?.from('maintenance_tickets')
          .select()
          .order('created_at', ascending: false);
      if (data == null) return [];
      return (data as List).map((row) {
        final roleStr = (row['reported_by_role'] as String?) ?? 'employee';
        final role = UserRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => UserRole.employee,
        );
        final statusStr = (row['status'] as String?) ?? 'open';
        final status = MaintenanceStatus.values.firstWhere(
          (s) => s.name == statusStr,
          orElse: () => MaintenanceStatus.open,
        );
        return MaintenanceTicket(
          id:                 row['id'] as String,
          reportedByRole:     role,
          reportedBy:         row['reported_by'] as String,
          issueFor:           (row['issue_for'] as String?) ?? 'IT',
          issueType:          row['issue_type'] as String,
          description:        row['description'] as String,
          priority:           (row['priority'] as String?) ?? 'Medium',
          status:             status,
          sentToManagement:   (row['sent_to_management'] as bool?) ?? false,
          managementReviewed: (row['management_reviewed'] as bool?) ?? false,
          sendToManagementNote: row['send_to_management_note'] as String?,
          resolutionNote:     row['resolution_note'] as String?,
          resolvedAt:         row['resolved_at'] != null
              ? DateTime.parse(row['resolved_at'] as String)
              : null,
          createdAt:          DateTime.parse(row['created_at'] as String),
          attachmentUrl:      row['attachment_url'] as String?,
          attachmentName:     row['attachment_name'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Employee Profiles ─────────────────────────────────────────────────

  static Future<void> saveProfile(ProfileData data) async {
    try {
      await _db?.from('employee_profiles').upsert({
        'employee_id':       data.employeeId,
        'full_name':         data.fullName,
        'mobile':            data.mobile,
        'email':             data.email,
        'address':           data.address,
        'department':        data.department,
        'designation':       data.designation,
        'reporting_manager': data.reportingManager,
        'date_of_joining':   data.dateOfJoining,
      });
    } catch (_) {}
  }

  static Future<List<ProfileData>> fetchProfiles() async {
    try {
      final data = await _db?.from('employee_profiles').select();
      if (data == null) return [];
      return (data as List).map((row) => ProfileData(
        employeeId:       (row['employee_id'] as String?) ?? '',
        fullName:         (row['full_name'] as String?) ?? '',
        mobile:           (row['mobile'] as String?) ?? '',
        email:            (row['email'] as String?) ?? '',
        address:          (row['address'] as String?) ?? '',
        department:       (row['department'] as String?) ?? '',
        designation:      (row['designation'] as String?) ?? '',
        reportingManager: (row['reporting_manager'] as String?) ?? '',
        dateOfJoining:    (row['date_of_joining'] as String?) ?? '',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Employees ─────────────────────────────────────────────────────────

  static Future<void> saveEmployee(Employee emp) async {
    try {
      await _db?.from('employees').upsert({
        'id':              emp.id,
        'name':            emp.name,
        'department':      emp.department,
        'designation':     emp.designation,
        'mobile':          emp.mobile,
        'email':           emp.email,
        'address':         emp.address,
        'blood_group':     emp.bloodGroup,
        'manager':         emp.manager,
        'joining_date':    emp.joiningDate,
        'salary':          emp.salary,
        'emergency_name':  emp.emergencyName,
        'emergency_phone': emp.emergencyPhone,
        'bank_account':    emp.bankAccount,
        'ifsc':            emp.ifsc,
      });
    } catch (_) {}
  }

  static Future<List<Employee>> fetchEmployees() async {
    try {
      final data = await _db?.from('employees').select().order('name');
      if (data == null) return [];
      return (data as List).map((row) => Employee(
        id:            row['id'] as String,
        name:          row['name'] as String,
        department:    (row['department'] as String?) ?? '',
        designation:   (row['designation'] as String?) ?? '',
        mobile:        (row['mobile'] as String?) ?? '',
        email:         (row['email'] as String?) ?? '',
        address:       (row['address'] as String?) ?? '',
        bloodGroup:    (row['blood_group'] as String?) ?? '',
        manager:       (row['manager'] as String?) ?? '',
        joiningDate:   (row['joining_date'] as String?) ?? '',
        salary:        (row['salary'] as String?) ?? '',
        emergencyName: (row['emergency_name'] as String?) ?? '',
        emergencyPhone:(row['emergency_phone'] as String?) ?? '',
        bankAccount:   (row['bank_account'] as String?) ?? '',
        ifsc:          (row['ifsc'] as String?) ?? '',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Resume Upload ─────────────────────────────────────────────────────

  // Throws on failure so callers can surface the error to the user.
  static Future<String> uploadResume(
      Uint8List bytes, String fileName, String mimeType) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _db!.storage.from('RESUME').uploadBinary(
      path, bytes,
      fileOptions: FileOptions(
          contentType: mimeType.isNotEmpty ? mimeType : 'application/octet-stream'),
    );
    return _db!.storage.from('RESUME').getPublicUrl(path);
  }

  // Custom field file uploads (PDF / image) — stored in the RESUME bucket under custom_uploads/.
  // Throws on failure so callers can surface the error to the user.
  static Future<String> uploadFile(
      Uint8List bytes, String fileName, String mimeType) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = 'custom_uploads/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _db!.storage.from('RESUME').uploadBinary(
      path, bytes,
      fileOptions: FileOptions(
          contentType: mimeType.isNotEmpty ? mimeType : 'application/octet-stream'),
    );
    return _db!.storage.from('RESUME').getPublicUrl(path);
  }

  // ── Candidate Applications ────────────────────────────────────────────

  static Future<void> saveCandidateApplication(Map<String, dynamic> data) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized. Please refresh and try again.');
    await db.from('candidate_applications').insert(data);
  }

  static Future<List<Map<String, dynamic>>> fetchCandidateApplications() async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized.');
    final data = await db
        .from('candidate_applications')
        .select()
        .order('submitted_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<void> updateCandidateStatus(
      String id, Map<String, dynamic> fields) async {
    final db = _db;
    if (db == null) return;
    await db.from('candidate_applications').update(fields).eq('id', id);
  }

  static Future<void> deleteCandidateApplication(String id) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized.');
    await db.from('candidate_applications').delete().eq('id', id);
  }

  // ── App Users (Administration) ────────────────────────────────────────

  static Future<List<AppUser>> fetchAppUsers() async {
    try {
      final data = await _db?.from('app_users').select().order('name');
      if (data == null) return [];
      return (data as List).map((row) => AppUser(
        name:                 (row['name']                    as String?) ?? '',
        email:                (row['email']                   as String?) ?? '',
        employeeId:           (row['employee_id']             as String?) ?? '',
        designation:          (row['designation']             as String?) ?? '',
        department:           (row['department']              as String?) ?? '',
        role:                 (row['role']                    as String?) ?? 'Employee',
        active:               (row['active']                  as bool?)   ?? true,
        password:             (row['password']                as String?) ?? '',
        leaveAllocation:      (row['leave_allocation']        as int?)    ?? 21,
        reportingManager:     (row['reporting_manager']       as String?) ?? '',
        reportingManagerPending:     (row['reporting_manager_pending']       as String?) ?? '',
        reportingManagerRequestedAt: (row['reporting_manager_requested_at']  as String?) ?? '',
        isReportingManager:            (row['is_reporting_manager']            as bool?)   ?? false,
        isReportingManagerPending:     (row['is_reporting_manager_pending']    as bool?)   ?? false,
        isReportingManagerRequestedAt: (row['is_reporting_manager_requested_at'] as String?) ?? '',
        mobile:               (row['mobile']                  as String?) ?? '',
        address:              (row['address']                 as String?) ?? '',
        dateOfBirth:          (row['date_of_birth']           as String?) ?? '',
        dateOfJoining:        (row['date_of_joining']         as String?) ?? '',
        onrollConfirmedAt:    (row['onroll_confirmed_at']     as String?) ?? '',
        onrollRequestedAt:    (row['onroll_requested_at']     as String?) ?? '',
        onrollHrStatus:            (row['onroll_hr_status']            as String?) ?? 'pending',
        onrollHrComment:           (row['onroll_hr_comment']           as String?) ?? '',
        onrollHrDecidedAt:         (row['onroll_hr_decided_at']         as String?) ?? '',
        onrollManagerStatus:       (row['onroll_manager_status']       as String?) ?? 'pending',
        onrollManagerComment:      (row['onroll_manager_comment']      as String?) ?? '',
        onrollManagerDecidedAt:    (row['onroll_manager_decided_at']    as String?) ?? '',
        onrollManagementStatus:    (row['onroll_management_status']    as String?) ?? 'pending',
        onrollManagementComment:   (row['onroll_management_comment']   as String?) ?? '',
        onrollManagementDecidedAt: (row['onroll_management_decided_at'] as String?) ?? '',
        elEligibleAt:         (row['el_eligible_at']          as String?) ?? '',
        elAvailRequestedAt:   (row['el_avail_requested_at']   as String?) ?? '',
        elLastAvailedAt:      (row['el_last_availed_at']      as String?) ?? '',
        grossPay:             (row['gross_pay'] as num?)?.toDouble() ?? 0,
        grossPayPending:      (row['gross_pay_pending'] as num?)?.toDouble() ?? 0,
        grossPayRequestedAt:  (row['gross_pay_requested_at'] as String?) ?? '',
        workLocation:            (row['work_location']             as String?) ?? '',
        workLocationPending:     (row['work_location_pending']     as String?) ?? '',
        workLocationRequestedAt: (row['work_location_requested_at'] as String?) ?? '',
        deviceId:             (row['device_id']               as String?) ?? '',
        deviceName:           (row['device_name']             as String?) ?? '',
        devicePlatform:       (row['device_platform']         as String?) ?? '',
        deviceRegisteredAt:   (row['device_registered_at']    as String?) ?? '',
        deviceLastLogin:      (row['device_last_login']       as String?) ?? '',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> upsertAppUser(AppUser u) async {
    await _db?.from('app_users').upsert({
      'email':                    u.email,
      'name':                     u.name,
      'employee_id':              u.employeeId,
      'designation':              u.designation,
      'department':               u.department,
      'role':                     u.role,
      'active':                   u.active,
      'password':                 u.password,
      'leave_allocation':         u.leaveAllocation,
      'reporting_manager':        u.reportingManager,
      'reporting_manager_pending':        u.reportingManagerPending,
      'reporting_manager_requested_at':   u.reportingManagerRequestedAt,
      'is_reporting_manager':             u.isReportingManager,
      'is_reporting_manager_pending':     u.isReportingManagerPending,
      'is_reporting_manager_requested_at': u.isReportingManagerRequestedAt,
      'mobile':                   u.mobile,
      'address':                  u.address,
      'date_of_birth':            u.dateOfBirth,
      'date_of_joining':          u.dateOfJoining,
      'onroll_confirmed_at':      u.onrollConfirmedAt,
      'onroll_requested_at':      u.onrollRequestedAt,
      'onroll_hr_status':             u.onrollHrStatus,
      'onroll_hr_comment':            u.onrollHrComment,
      'onroll_hr_decided_at':         u.onrollHrDecidedAt,
      'onroll_manager_status':        u.onrollManagerStatus,
      'onroll_manager_comment':       u.onrollManagerComment,
      'onroll_manager_decided_at':    u.onrollManagerDecidedAt,
      'onroll_management_status':    u.onrollManagementStatus,
      'onroll_management_comment':   u.onrollManagementComment,
      'onroll_management_decided_at': u.onrollManagementDecidedAt,
      'el_eligible_at':           u.elEligibleAt,
      'el_avail_requested_at':    u.elAvailRequestedAt,
      'el_last_availed_at':       u.elLastAvailedAt,
      'gross_pay':                u.grossPay,
      'gross_pay_pending':        u.grossPayPending,
      'gross_pay_requested_at':   u.grossPayRequestedAt,
      'work_location':            u.workLocation,
      'work_location_pending':    u.workLocationPending,
      'work_location_requested_at': u.workLocationRequestedAt,
      'device_id':                u.deviceId,
      'device_name':              u.deviceName,
      'device_platform':          u.devicePlatform,
      'device_registered_at':     u.deviceRegisteredAt,
      'device_last_login':        u.deviceLastLogin,
    });
  }

  static Future<void> requestElAvail(String email) async {
    try {
      await _db?.from('app_users').update({
        'el_avail_requested_at': DateTime.now().toIso8601String(),
      }).eq('email', email);
    } catch (_) {}
  }

  static Future<void> confirmElAvail(String email) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _db?.from('app_users').update({
        'el_last_availed_at':    now,
        'el_avail_requested_at': '',
      }).eq('email', email);
    } catch (_) {}
  }

  static Future<void> deleteAppUser(String email) async {
    try {
      await _db?.from('app_users').delete().eq('email', email);
    } catch (_) {}
  }

  // ── Tasks ─────────────────────────────────────────────────────────────

  static Future<void> saveTask(Task task) async {
    try {
      await _db?.from('tasks').upsert(task.toJson());
    } catch (_) {}
  }

  static Future<void> deleteTask(String id) async {
    try {
      await _db?.from('tasks').delete().eq('id', id);
    } catch (_) {}
  }

  // [note] is the reason given for completing a task after it went Delayed
  // (see MyTasksPage._onDone) — written to the completion_note column.
  // Falls back to a plain status update if that column doesn't exist yet
  // on this database, so completing a task never silently fails outright.
  static Future<void> updateTaskStatus(String id, TaskStatus status, {String? note}) async {
    if (note != null && note.isNotEmpty) {
      try {
        await _db?.from('tasks').update({
          'status': status.name,
          'completion_note': note,
        }).eq('id', id);
        return;
      } catch (_) {}
    }
    try {
      await _db?.from('tasks').update({'status': status.name}).eq('id', id);
    } catch (_) {}
  }

  static Future<void> updateTaskReceived(String id, DateTime receivedAt) async {
    try {
      await _db?.from('tasks').update({
        'status': TaskStatus.inProgress.name,
        'received_at': receivedAt.toIso8601String(),
      }).eq('id', id);
    } catch (_) {}
  }

  // Updates one team member's status; if allCompleted, also flips overall
  // status. [note] is that member's reason for completing late (see
  // MyTasksPage._onGroupDone) — same completion_note column and fallback
  // as updateTaskStatus, since there's no per-member notes column.
  static Future<void> updateTeamMemberStatus(
      String taskId, Map<String, String> statuses, bool allCompleted, {String? note}) async {
    final update = <String, dynamic>{
      'team_member_statuses': jsonEncode(statuses),
    };
    if (allCompleted) update['status'] = TaskStatus.completed.name;
    if (note != null && note.isNotEmpty) {
      try {
        await _db?.from('tasks')
            .update({...update, 'completion_note': note}).eq('id', taskId);
        return;
      } catch (_) {}
    }
    try {
      await _db?.from('tasks').update(update).eq('id', taskId);
    } catch (_) {}
  }

  static Future<List<Task>> fetchTasks() async {
    try {
      final data = await _db?.from('tasks').select().order('id');
      if (data == null) return [];
      return (data as List)
          .map((row) => Task.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Appraisal Forms ──────────────────────────────────────────────────

  // Unlike most save*() methods here, this one does NOT swallow errors —
  // the appraisal form editor needs to tell the user a save actually failed
  // (e.g. RLS misconfiguration) instead of showing a false "Draft saved".
  static Future<void> saveAppraisalForm(AppraisalForm form) async {
    await _db?.from('appraisal_forms').upsert(form.toRow());
  }

  static Future<List<AppraisalForm>> fetchAppraisalForms() async {
    try {
      final data = await _db?.from('appraisal_forms').select().order('created_at', ascending: false);
      if (data == null) return [];
      return (data as List)
          .map((row) => AppraisalForm.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── KRA Documents ─────────────────────────────────────────────────────

  // Throws on failure so callers can surface the error to the user.
  static Future<String> uploadKraFile(
      Uint8List bytes, String fileName, String mimeType) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = 'kra_uploads/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _db!.storage.from('RESUME').uploadBinary(
      path, bytes,
      fileOptions: FileOptions(
          contentType: mimeType.isNotEmpty ? mimeType : 'application/octet-stream'),
    );
    return _db!.storage.from('RESUME').getPublicUrl(path);
  }

  static Future<void> saveKraDocument(KraDocument doc) async {
    await _db?.from('kra_documents').upsert(doc.toRow());
  }

  static Future<List<KraDocument>> fetchKraDocuments() async {
    try {
      final data = await _db?.from('kra_documents').select().order('uploaded_at', ascending: false);
      if (data == null) return [];
      return (data as List)
          .map((row) => KraDocument.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> deleteKraDocument(String id) async {
    await _db?.from('kra_documents').delete().eq('id', id);
  }

  static Future<void> updateKraStatus(
    String id,
    String status, {
    String decidedBy = '',
    String reviewNote = '',
  }) async {
    await _db?.from('kra_documents').update({
      'status': status,
      'decided_by': decidedBy,
      'decided_at': DateTime.now().toIso8601String(),
      'review_note': reviewNote,
    }).eq('id', id);
  }

  // ── Form Versions ─────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchFormVersions() async {
    final db = _db;
    if (db == null) return [];
    try {
      final data = await db
          .from('form_versions')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchActiveFormVersion() async {
    final db = _db;
    if (db == null) return null;
    try {
      final data = await db
          .from('form_versions')
          .select()
          .eq('status', 'approved')
          .order('approved_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchFormVersionById(
      String id) async {
    final db = _db;
    if (db == null) return null;
    try {
      final data = await db
          .from('form_versions')
          .select()
          .eq('id', id)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchFormVersionByNumber(
      int versionNumber) async {
    final db = _db;
    if (db == null) return null;
    try {
      final data = await db
          .from('form_versions')
          .select()
          .eq('version_number', versionNumber)
          .eq('status', 'approved')
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveFormVersion(Map<String, dynamic> data) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized.');
    await db.from('form_versions').insert(data);
  }

  static Future<void> updateFormVersionStatus(
    String id,
    String status, {
    String decidedBy = '',
    String note = '',
  }) async {
    final db = _db;
    if (db == null) return;
    final update = <String, dynamic>{'status': status};
    if (status == 'approved') {
      update['approved_at'] =
          DateTime.now().toUtc().toIso8601String();
      update['approved_by'] = decidedBy;
    }
    if (note.isNotEmpty) update['rejection_note'] = note;
    await db.from('form_versions').update(update).eq('id', id);
  }

  static Future<int> getNextFormVersionNumber() async {
    final db = _db;
    if (db == null) return 1;
    try {
      final data = await db
          .from('form_versions')
          .select('version_number')
          .order('version_number', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      if (list.isEmpty) return 1;
      return ((list.first['version_number'] as int?) ?? 0) + 1;
    } catch (_) {
      return 1;
    }
  }

  // ── Onboarding Form Versions ─────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchOnboardingFormVersions() async {
    final db = _db;
    if (db == null) return [];
    try {
      final data = await db
          .from('onboarding_form_versions')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchActiveOnboardingFormVersion() async {
    final db = _db;
    if (db == null) return null;
    try {
      final data = await db
          .from('onboarding_form_versions')
          .select()
          .eq('status', 'approved')
          .order('approved_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveOnboardingFormVersion(
      Map<String, dynamic> data) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized.');
    await db.from('onboarding_form_versions').insert(data);
  }

  static Future<void> updateOnboardingFormVersionStatus(
    String id,
    String status, {
    String decidedBy = '',
    String note = '',
  }) async {
    final db = _db;
    if (db == null) return;
    final update = <String, dynamic>{'status': status};
    if (status == 'approved') {
      update['approved_at'] = DateTime.now().toUtc().toIso8601String();
      update['approved_by'] = decidedBy;
    }
    if (note.isNotEmpty) update['rejection_note'] = note;
    await db.from('onboarding_form_versions').update(update).eq('id', id);
  }

  static Future<int> getNextOnboardingFormVersionNumber() async {
    final db = _db;
    if (db == null) return 1;
    try {
      final data = await db
          .from('onboarding_form_versions')
          .select('version_number')
          .order('version_number', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      if (list.isEmpty) return 1;
      return ((list.first['version_number'] as int?) ?? 0) + 1;
    } catch (_) {
      return 1;
    }
  }

  // ── Leave Form Configs ────────────────────────────────────────────────
  /*
    create table if not exists leave_form_configs (
      id uuid default gen_random_uuid() primary key,
      created_at timestamptz default now(),
      created_by text default '',
      status text default 'pending',
      form_config jsonb not null default '{}',
      version_number integer default 1,
      approved_at timestamptz,
      approved_by text default '',
      rejection_note text default ''
    );
    alter table leave_form_configs disable row level security;
  */

  static Future<List<Map<String, dynamic>>> fetchLeaveFormVersions() async {
    final db = _db;
    if (db == null) return [];
    try {
      final data = await db
          .from('leave_form_configs')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchActiveLeaveFormConfig() async {
    final db = _db;
    if (db == null) return null;
    try {
      final data = await db
          .from('leave_form_configs')
          .select()
          .eq('status', 'approved')
          .order('approved_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLeaveFormVersion(Map<String, dynamic> data) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized.');
    await db.from('leave_form_configs').insert(data);
  }

  static Future<void> updateLeaveFormVersionStatus(
    String id,
    String status, {
    String decidedBy = '',
    String note = '',
  }) async {
    final db = _db;
    if (db == null) return;
    final update = <String, dynamic>{'status': status};
    if (status == 'approved') {
      update['approved_at'] = DateTime.now().toUtc().toIso8601String();
      update['approved_by'] = decidedBy;
    }
    if (note.isNotEmpty) update['rejection_note'] = note;
    await db.from('leave_form_configs').update(update).eq('id', id);
  }

  static Future<int> getNextLeaveFormVersionNumber() async {
    final db = _db;
    if (db == null) return 1;
    try {
      final data = await db
          .from('leave_form_configs')
          .select('version_number')
          .order('version_number', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      if (list.isEmpty) return 1;
      return ((list.first['version_number'] as int?) ?? 0) + 1;
    } catch (_) {
      return 1;
    }
  }

  // ── Maintenance Form Configs ────────────────────────────────────────────
  /*
    create table if not exists maintenance_form_configs (
      id uuid default gen_random_uuid() primary key,
      created_at timestamptz default now(),
      created_by text default '',
      status text default 'pending',
      form_config jsonb not null default '{}',
      version_number integer default 1,
      approved_at timestamptz,
      approved_by text default '',
      rejection_note text default ''
    );
    alter table maintenance_form_configs disable row level security;
  */

  static Future<List<Map<String, dynamic>>> fetchMaintenanceFormVersions() async {
    final db = _db;
    if (db == null) return [];
    try {
      final data = await db
          .from('maintenance_form_configs')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchActiveMaintenanceFormConfig() async {
    final db = _db;
    if (db == null) return null;
    try {
      final data = await db
          .from('maintenance_form_configs')
          .select()
          .eq('status', 'approved')
          .order('approved_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveMaintenanceFormVersion(Map<String, dynamic> data) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized.');
    await db.from('maintenance_form_configs').insert(data);
  }

  static Future<void> updateMaintenanceFormVersionStatus(
    String id,
    String status, {
    String decidedBy = '',
    String note = '',
  }) async {
    final db = _db;
    if (db == null) return;
    final update = <String, dynamic>{'status': status};
    if (status == 'approved') {
      update['approved_at'] = DateTime.now().toUtc().toIso8601String();
      update['approved_by'] = decidedBy;
    }
    if (note.isNotEmpty) update['rejection_note'] = note;
    await db.from('maintenance_form_configs').update(update).eq('id', id);
  }

  static Future<int> getNextMaintenanceFormVersionNumber() async {
    final db = _db;
    if (db == null) return 1;
    try {
      final data = await db
          .from('maintenance_form_configs')
          .select('version_number')
          .order('version_number', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      if (list.isEmpty) return 1;
      return ((list.first['version_number'] as int?) ?? 0) + 1;
    } catch (_) {
      return 1;
    }
  }

  // ── Attendance Records ────────────────────────────────────────────────

  static String _attendanceId(String employeeId, String date) =>
      '${employeeId.isNotEmpty ? employeeId : 'emp'}_${date.replaceAll('/', '-')}';

  static Future<String?> saveCheckIn({
    required String employeeName,
    required String employeeId,
    required String date,
    required String time,
    String location = '',
    String note = '',
  }) async {
    try {
      if (_db == null) return 'Database not connected';
      await _db!.from('attendance_records').upsert({
        'id':             _attendanceId(employeeId, date),
        'employee_name':  employeeName,
        'employee_id':    employeeId,
        'date':           date,
        'check_in_time':  time,
        'check_out_time': '',
        'location':       location,
        'check_in_note':  note,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> updateLocation({
    required String employeeId,
    required String date,
    required String location,
  }) async {
    try {
      await _db
          ?.from('attendance_records')
          .update({'location': location})
          .eq('id', _attendanceId(employeeId, date));
    } catch (_) {}
  }

  static Future<void> updateGpsPoints({
    required String employeeId,
    required String date,
    required List<List<double>> points,
  }) async {
    try {
      await _db
          ?.from('attendance_records')
          .update({'gps_points': points})
          .eq('id', _attendanceId(employeeId, date));
    } catch (_) {}
  }

  static Future<List<List<double>>> fetchGpsPoints({
    required String employeeId,
    required String date,
  }) async {
    try {
      final data = await _db
          ?.from('attendance_records')
          .select('gps_points')
          .eq('id', _attendanceId(employeeId, date))
          .limit(1);
      if (data == null || (data as List).isEmpty) return [];
      return _parseGpsPoints((data as List).first['gps_points']);
    } catch (_) {
      return [];
    }
  }

  static List<List<double>> _parseGpsPoints(dynamic raw) {
    if (raw == null) return [];
    try {
      return (raw as List).map<List<double>>((p) {
        if (p is List && p.length >= 2) {
          return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
        }
        return [];
      }).where((p) => p.length == 2).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCheckOut({
    required String employeeId,
    required String date,
    required String time,
    String note = '',
  }) async {
    try {
      await _db
          ?.from('attendance_records')
          .update({'check_out_time': time, 'check_out_note': note})
          .eq('id', _attendanceId(employeeId, date));
    } catch (_) {}
  }

  static Future<List<AttendanceRecord>> fetchAttendanceForDate(String date) async {
    try {
      final data = await _db
          ?.from('attendance_records')
          .select()
          .eq('date', date)
          .order('created_at', ascending: true);
      if (data == null) return [];
      return (data as List).map((row) => AttendanceRecord(
        id:           row['id'] as String,
        employeeName: row['employee_name'] as String,
        employeeId:   (row['employee_id']    as String?) ?? '',
        date:         row['date'] as String,
        checkInTime:  (row['check_in_time']  as String?) ?? '',
        checkOutTime: (row['check_out_time'] as String?) ?? '',
        location:     (row['location']        as String?) ?? '',
        gpsPoints:    _parseGpsPoints(row['gps_points']),
        checkInNote:  (row['check_in_note']  as String?) ?? '',
        checkOutNote: (row['check_out_note'] as String?) ?? '',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  /// Attendance records for several dates ("dd/MM/yyyy" strings) in one
  /// query — used to build the attendance summary's day-over-day trend.
  static Future<List<AttendanceRecord>> fetchAttendanceForDates(List<String> dates) async {
    if (dates.isEmpty) return [];
    try {
      final data = await _db
          ?.from('attendance_records')
          .select()
          .inFilter('date', dates)
          .order('created_at', ascending: true);
      if (data == null) return [];
      return (data as List).map((row) => AttendanceRecord(
        id:           row['id'] as String,
        employeeName: row['employee_name'] as String,
        employeeId:   (row['employee_id']    as String?) ?? '',
        date:         row['date'] as String,
        checkInTime:  (row['check_in_time']  as String?) ?? '',
        checkOutTime: (row['check_out_time'] as String?) ?? '',
        location:     (row['location']        as String?) ?? '',
        gpsPoints:    _parseGpsPoints(row['gps_points']),
        checkInNote:  (row['check_in_note']  as String?) ?? '',
        checkOutNote: (row['check_out_note'] as String?) ?? '',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<AttendanceRecord?> fetchTodayAttendance(String employeeId) async {
    if (employeeId.isEmpty) return null;
    final today = DateTime.now();
    final date =
        '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';
    try {
      final data = await _db
          ?.from('attendance_records')
          .select()
          .eq('id', _attendanceId(employeeId, date))
          .limit(1);
      if (data == null || (data as List).isEmpty) return null;
      final row = (data as List).first as Map<String, dynamic>;
      return AttendanceRecord(
        id:           row['id'] as String,
        employeeName: row['employee_name'] as String,
        employeeId:   (row['employee_id']  as String?) ?? '',
        date:         row['date'] as String,
        checkInTime:  (row['check_in_time']  as String?) ?? '',
        checkOutTime: (row['check_out_time'] as String?) ?? '',
        location:     (row['location']        as String?) ?? '',
        gpsPoints:    _parseGpsPoints(row['gps_points']),
        checkInNote:  (row['check_in_note']  as String?) ?? '',
        checkOutNote: (row['check_out_note'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<AttendanceRecord>> fetchAttendanceForMonth(
      String employeeId, int year, int month) async {
    if (employeeId.isEmpty) return [];
    final monthStr = '${month.toString().padLeft(2, '0')}/$year';
    try {
      final data = await _db
          ?.from('attendance_records')
          .select()
          .eq('employee_id', employeeId)
          .like('date', '%/$monthStr');
      if (data == null) return [];
      return (data as List).map((row) => AttendanceRecord(
        id:           row['id']           as String,
        employeeName: (row['employee_name'] as String?) ?? '',
        employeeId:   (row['employee_id']   as String?) ?? '',
        date:         (row['date']          as String?) ?? '',
        checkInTime:  (row['check_in_time'] as String?) ?? '',
        checkOutTime: (row['check_out_time'] as String?) ?? '',
        location:     (row['location']       as String?) ?? '',
        gpsPoints:    _parseGpsPoints(row['gps_points']),
        checkInNote:  (row['check_in_note']  as String?) ?? '',
        checkOutNote: (row['check_out_note'] as String?) ?? '',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<AttendanceRecord>> fetchEmployeeRecentAttendance(String employeeId, {int limit = 30}) async {
    if (employeeId.isEmpty) return [];
    try {
      final data = await _db
          ?.from('attendance_records')
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false)
          .limit(limit);
      if (data == null) return [];
      return (data as List).map((row) => AttendanceRecord(
        id:           row['id'] as String,
        employeeName: (row['employee_name'] as String?) ?? '',
        employeeId:   (row['employee_id']   as String?) ?? '',
        date:         (row['date']           as String?) ?? '',
        checkInTime:  (row['check_in_time']  as String?) ?? '',
        checkOutTime: (row['check_out_time'] as String?) ?? '',
        location:     (row['location']       as String?) ?? '',
        gpsPoints:    _parseGpsPoints(row['gps_points']),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  // Sets AttendanceStore.isCheckedIn based on today's Supabase record.
  static Future<void> restoreCheckInState() async {
    if (!UserSession.loggedIn || UserSession.employeeId.isEmpty) return;
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    try {
      final data = await _db
          ?.from('attendance_records')
          .select()
          .eq('id', _attendanceId(UserSession.employeeId, date))
          .limit(1);
      if (data == null || (data as List).isEmpty) return;
      final row = (data as List).first as Map<String, dynamic>;
      final checkIn  = (row['check_in_time']  as String?) ?? '';
      final checkOut = (row['check_out_time'] as String?) ?? '';
      AttendanceStore.isCheckedIn = checkIn.isNotEmpty && checkOut.isEmpty;
    } catch (_) {}
  }

  // ── Announcements ─────────────────────────────────────────────────────────
  /*
    create table if not exists announcements (
      id uuid default gen_random_uuid() primary key,
      text text not null,
      announced_on date not null default current_date,
      created_at timestamptz default now()
    );
    alter table announcements disable row level security;

    create table if not exists holidays (
      id uuid default gen_random_uuid() primary key,
      name text not null,
      holiday_date date not null,
      created_at timestamptz default now()
    );
    alter table holidays disable row level security;

    create table if not exists birthdays (
      id uuid default gen_random_uuid() primary key,
      name text not null,
      birthday_date date not null,
      created_at timestamptz default now()
    );
    alter table birthdays disable row level security;
  */

  static Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    try {
      final data = await _db
          ?.from('announcements')
          .select()
          .order('announced_on', ascending: false)
          .limit(200);
      if (data == null) return [];
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  static Future<String?> addAnnouncement(
    String text,
    DateTime date, {
    String? targetEmployeeId,
    String? targetEmployeeName,
  }) async {
    try {
      await _db?.from('announcements').insert({
        'text': text,
        'announced_on': date.toIso8601String().substring(0, 10),
        'target_employee_id': targetEmployeeId,
        'target_employee_name': targetEmployeeName,
      });
      return null; // null = success
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> deleteAnnouncement(String id) async {
    try {
      await _db?.from('announcements').delete().eq('id', id);
    } catch (_) {}
  }

  // ── Holidays ───────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchHolidays(int year) async {
    try {
      final data = await _db
          ?.from('holidays')
          .select()
          .gte('holiday_date', '$year-01-01')
          .lte('holiday_date', '$year-12-31')
          .order('holiday_date', ascending: true);
      if (data == null) return [];
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> addHoliday(String name, DateTime date) async {
    try {
      await _db?.from('holidays').insert({
        'name': name,
        'holiday_date': date.toIso8601String().substring(0, 10),
      });
    } catch (_) {}
  }

  static Future<void> deleteHoliday(String id) async {
    try {
      await _db?.from('holidays').delete().eq('id', id);
    } catch (_) {}
  }

  // ── Birthdays ──────────────────────────────────────────────────────────────
  // Auto-derived from the Date of Birth candidates fill in on the onboarding
  // form (form_data->>'date_of_birth', format dd/MM/yyyy), for whichever
  // submission resulted in an actual employee account (status =
  // 'access_granted'). The manual 'birthdays' table remains as a fallback for
  // employees hired before onboarding captured DOB, or missed by name-matching.

  static DateTime? _parseOnboardingDob(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final parts = t.split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        try {
          return DateTime(y, m, d);
        } catch (_) {
          return null;
        }
      }
    }
    return DateTime.tryParse(t);
  }

  static Future<List<Map<String, dynamic>>> fetchOnboardingBirthdaysForMonth(
      int month) async {
    try {
      final data = await _db
          ?.from('onboarding_forms')
          .select('name, form_data, assigned_emp_id, status, submitted_at')
          .eq('status', 'access_granted')
          .order('submitted_at', ascending: false);
      if (data == null) return [];
      final rows = List<Map<String, dynamic>>.from(data as List);
      final seenEmpIds = <String>{};
      final result = <Map<String, dynamic>>[];
      for (final row in rows) {
        final empId = (row['assigned_emp_id'] as String? ?? '').trim();
        // One entry per employee — keep only their most recent submission.
        if (empId.isEmpty || !seenEmpIds.add(empId)) continue;
        final name = (row['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final fd = row['form_data'];
        final dobRaw = fd is Map ? (fd['date_of_birth'] as String? ?? '') : '';
        final dob = _parseOnboardingDob(dobRaw);
        if (dob == null || dob.month != month) continue;
        result.add({
          'name': name,
          'birthday_date': dob.toIso8601String().substring(0, 10),
        });
      }
      result.sort((a, b) =>
          (DateTime.tryParse(a['birthday_date'] as String) ?? DateTime.now())
              .day
              .compareTo((DateTime.tryParse(b['birthday_date'] as String) ??
                      DateTime.now())
                  .day));
      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchBirthdaysForMonth(
      int month) async {
    final auto = await fetchOnboardingBirthdaysForMonth(month);
    try {
      final data = await _db
          ?.from('birthdays')
          .select()
          .order('birthday_date', ascending: true);
      if (data == null) return auto;
      final manual = List<Map<String, dynamic>>.from(data as List).where((row) {
        final d = DateTime.tryParse(row['birthday_date'] as String? ?? '');
        return d != null && d.month == month;
      });
      final autoNames =
          auto.map((r) => (r['name'] as String).trim().toLowerCase()).toSet();
      final merged = [
        ...auto,
        ...manual.where((r) =>
            !autoNames.contains((r['name'] as String? ?? '').trim().toLowerCase())),
      ];
      merged.sort((a, b) =>
          (DateTime.tryParse(a['birthday_date'] as String? ?? '') ?? DateTime.now())
              .day
              .compareTo((DateTime.tryParse(b['birthday_date'] as String? ?? '') ??
                      DateTime.now())
                  .day));
      return merged;
    } catch (_) {
      return auto;
    }
  }

  static Future<void> addBirthday(String name, DateTime date) async {
    try {
      await _db?.from('birthdays').insert({
        'name': name,
        'birthday_date': date.toIso8601String().substring(0, 10),
      });
    } catch (_) {}
  }

  static Future<void> deleteBirthday(String id) async {
    try {
      await _db?.from('birthdays').delete().eq('id', id);
    } catch (_) {}
  }

  // ── Employee of the Month ──────────────────────────────────────────────────
  // Multiple employees can share a single month's announcement — every row
  // for the most recently announced month_year is a co-winner, not just one.

  static Future<List<Map<String, dynamic>>> fetchEmployeesOfMonth() async {
    try {
      final all = await _db
          ?.from('employee_of_month')
          .select()
          .order('month_year', ascending: false);
      if (all == null || all.isEmpty) return [];
      final latestMonth = all.first['month_year'] as String?;
      return List<Map<String, dynamic>>.from(
          all.where((r) => r['month_year'] == latestMonth));
    } catch (_) {
      return [];
    }
  }

  /// Reconciles [monthYear]'s winners to exactly [names]: adds any new
  /// names (or updates their reason if already present), and removes any
  /// existing winner for that month who isn't in [names] anymore — so the
  /// dialog's checkbox selection is the single source of truth per save.
  static Future<String?> saveEmployeesOfMonth(
      List<String> names, String reason, String monthYear) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final existing = await _db
              ?.from('employee_of_month')
              .select('id, employee_name')
              .eq('month_year', monthYear) ??
          [];

      final toRemove = existing.where((r) => !names.contains(r['employee_name']));
      for (final r in toRemove) {
        await _db?.from('employee_of_month').delete().eq('id', r['id']);
      }

      for (final name in names) {
        final match = existing.where((r) => r['employee_name'] == name);
        if (match.isNotEmpty) {
          await _db?.from('employee_of_month').update({
            'reason': reason,
            'announced_date': today,
          }).eq('id', match.first['id']);
        } else {
          await _db?.from('employee_of_month').insert({
            'employee_name': name,
            'reason': reason,
            'month_year': monthYear,
            'announced_date': today,
          });
        }
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── App settings (global color theme) ───────────────────────────────────────

  static Future<String?> fetchColorTheme() async {
    try {
      final data = await _db
          ?.from('app_settings')
          .select('color_theme')
          .eq('id', 'global')
          .maybeSingle();
      return data?['color_theme'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setColorTheme(String themeKey) async {
    try {
      await _db?.from('app_settings').upsert({
        'id': 'global',
        'color_theme': themeKey,
      });
    } catch (_) {}
  }

  // ── App settings (global welcome-banner quote) ───────────────────────────────

  static Future<Map<String, String>?> fetchBannerQuote() async {
    try {
      final data = await _db
          ?.from('app_settings')
          .select('banner_quote, banner_quote_author')
          .eq('id', 'global')
          .maybeSingle();
      if (data == null) return null;
      return {
        'quote': (data['banner_quote'] as String?) ?? '',
        'author': (data['banner_quote_author'] as String?) ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> setBannerQuote(String quote, String author) async {
    try {
      await _db?.from('app_settings').upsert({
        'id': 'global',
        'banner_quote': quote,
        'banner_quote_author': author,
      });
    } catch (_) {}
  }

  // ── Payslip requests ─────────────────────────────────────────────────────

  static Future<List<PayslipRequest>> fetchPayslipRequests() async {
    try {
      final data = await _db
          ?.from('payslip_requests')
          .select()
          .order('requested_at', ascending: false);
      if (data == null) return [];
      return (data as List)
          .map((row) => PayslipRequest.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<PayslipRequest>> fetchPayslipRequestsFor(String employeeId) async {
    try {
      final data = await _db
          ?.from('payslip_requests')
          .select()
          .eq('employee_id', employeeId)
          .order('requested_at', ascending: false);
      if (data == null) return [];
      return (data as List)
          .map((row) => PayslipRequest.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> requestPayslip(PayslipRequest req) async {
    try {
      await _db?.from('payslip_requests').upsert(req.toJson());
    } catch (_) {}
  }

  static Future<void> decidePayslipRequest(
      String id, PayslipRequestStatus status, String decidedBy,
      {String rejectionComment = ''}) async {
    try {
      await _db?.from('payslip_requests').update({
        'status': status.name,
        'decided_at': DateTime.now().toIso8601String(),
        'decided_by': decidedBy,
        'rejection_comment': rejectionComment,
      }).eq('id', id);
    } catch (_) {}
  }

  // ── Payslips ──────────────────────────────────────────────────────────────

  static Future<List<Payslip>> fetchPayslips(String employeeId) async {
    try {
      final data = await _db
          ?.from('payslips')
          .select()
          .eq('employee_id', employeeId)
          .order('month_year', ascending: false);
      if (data == null) return [];
      return (data as List)
          .map((row) => Payslip.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePayslip(Payslip p) async {
    try {
      await _db?.from('payslips').upsert(p.toJson());
    } catch (_) {}
  }

  // ── Notifications ─────────────────────────────────────────────────────

  static Future<List<AppNotification>> fetchNotifications() async {
    try {
      final data = await _db
          ?.from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(500);
      if (data == null) return [];
      return (data as List).map((row) => AppNotification(
        id:                     row['id'] as String,
        createdAt:              DateTime.parse(row['created_at'] as String),
        type:                   (row['type']  as String?) ?? '',
        title:                  (row['title'] as String?) ?? '',
        body:                   (row['body']  as String?) ?? '',
        route:                  (row['route'] as String?) ?? '',
        targetEmail:            (row['target_email']             as String?) ?? '',
        targetRole:             (row['target_role']               as String?) ?? '',
        targetReportingManager: (row['target_reporting_manager'] as String?) ?? '',
        sourceId:               (row['source_id']                as String?) ?? '',
        readBy: row['read_by'] is List
            ? List<String>.from(row['read_by'] as List)
            : [],
      )).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> insertNotification({
    required String type,
    required String title,
    String body = '',
    String route = '',
    String targetEmail = '',
    String targetRole = '',
    String targetReportingManager = '',
    String sourceId = '',
  }) async {
    try {
      await _db?.from('notifications').insert({
        'type':                     type,
        'title':                    title,
        'body':                     body,
        'route':                    route,
        'target_email':             targetEmail,
        'target_role':              targetRole,
        'target_reporting_manager': targetReportingManager,
        'source_id':                sourceId,
      });
    } catch (_) {}
  }

  static Future<void> markNotificationRead(String id, List<String> readBy) async {
    try {
      await _db?.from('notifications').update({'read_by': readBy}).eq('id', id);
    } catch (_) {}
  }

  // ── Push notification device tokens ─────────────────────────────────────

  static Future<void> upsertDeviceToken({
    required String token,
    required String email,
    required String platform,
  }) async {
    try {
      await _db?.from('device_tokens').upsert({
        'token':      token,
        'email':      email,
        'platform':   platform,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> deleteDeviceToken(String token) async {
    try {
      await _db?.from('device_tokens').delete().eq('token', token);
    } catch (_) {}
  }

  // ── Transactional email (Zoho SMTP via the send-email Edge Function) ────

  /// Returns null on success, or an error message on failure — callers show
  /// the message directly (e.g. in a SnackBar) rather than throwing, since
  /// a failed send is an expected, user-facing outcome (bad address, SMTP
  /// hiccup), not a bug.
  ///
  /// [html] and [attachments] are optional additions used by EmailService —
  /// existing plain-text callers are unaffected.
  static Future<String?> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? html,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final res = await _db?.functions.invoke('send-email', body: {
        'to': to,
        'subject': subject,
        'body': body,
        if (html != null) 'html': html,
        if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
      });
      if (res == null) return 'Not connected';
      if (res.status != 200) {
        final data = res.data;
        final err = data is Map ? data['error'] : null;
        return err?.toString() ?? 'Failed to send (status ${res.status})';
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Pre-Offer PDF upload (same RESUME bucket every other upload uses) ──

  // upsert:true was the actual cause of the 403 — Postgres RLS requires an
  // UPDATE policy for any ON CONFLICT DO UPDATE statement even when the row
  // doesn't exist yet, and the RESUME bucket only has INSERT/SELECT
  // policies for anon (no UPDATE), so upsert always failed regardless of
  // folder path. A plain insert satisfies the existing INSERT policy; a
  // resend for the same candidate hits "Duplicate" (409) instead, which we
  // treat as success since the object (and its PDF) is already there.
  static Future<String> uploadPreOfferPdf(String candidateId, Uint8List bytes) async {
    final path = 'custom_uploads/pre-offer-letter-$candidateId.pdf';
    try {
      await _db!.storage.from('RESUME').uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(contentType: 'application/pdf'),
      );
    } on StorageException catch (e) {
      final isDuplicate = e.statusCode == '409' ||
          e.error?.toLowerCase() == 'duplicate' ||
          e.message.toLowerCase().contains('already exists');
      if (!isDuplicate) rethrow;
    }
    return _db!.storage.from('RESUME').getPublicUrl(path);
  }

  /// Deterministic public URL for a candidate's Pre-Offer Letter PDF — no
  /// extra DB column needed since the storage path is derived from the id.
  static String preOfferPdfUrl(String candidateId) => _db!.storage
      .from('RESUME')
      .getPublicUrl('custom_uploads/pre-offer-letter-$candidateId.pdf');

  // ── Candidate token lookups (public pre-offer / onboarding-form pages) ──

  static Future<Map<String, dynamic>?> fetchCandidateByPreOfferToken(String token) async {
    if (token.isEmpty) return null;
    final data = await _db
        ?.from('candidate_applications')
        .select()
        .eq('pre_offer_token', token)
        .maybeSingle();
    return data;
  }

  static Future<Map<String, dynamic>?> fetchCandidateByOnboardingToken(String token) async {
    if (token.isEmpty) return null;
    final data = await _db
        ?.from('candidate_applications')
        .select()
        .eq('onboarding_token', token)
        .maybeSingle();
    return data;
  }

  /// The personal email a new employee's activation link must go to — their
  /// freshly-assigned @fomrahousing.in address is just a login username at
  /// this point and almost certainly isn't a provisioned mailbox yet, so
  /// sending there looks successful (SMTP accepts it) but nothing arrives.
  /// Prefers the real FK; falls back to the same fuzzy name/mobile match
  /// used elsewhere for older, token-less onboarding submissions.
  static Future<String?> fetchCandidatePersonalEmail({
    String? candidateApplicationId,
    required String name,
    required String mobile,
  }) async {
    try {
      if (candidateApplicationId != null && candidateApplicationId.isNotEmpty) {
        final row = await _db
            ?.from('candidate_applications')
            .select('email')
            .eq('id', candidateApplicationId)
            .maybeSingle();
        final email = (row?['email'] as String?)?.trim();
        if (email != null && email.isNotEmpty) return email;
      }
      if (name.isEmpty) return null;
      final results = await _db
          ?.from('candidate_applications')
          .select('email')
          .or('name.ilike.%$name%${mobile.isNotEmpty ? ",mobile.eq.$mobile" : ""}')
          .limit(1);
      if (results != null && results.isNotEmpty) {
        final email = (results.first['email'] as String?)?.trim();
        if (email != null && email.isNotEmpty) return email;
      }
    } catch (_) {}
    return null;
  }

  /// Used to block duplicate onboarding submissions for the same candidate —
  /// a token-based link can otherwise be resubmitted any number of times.
  static Future<bool> hasOnboardingFormForCandidate(String candidateId) async {
    if (candidateId.isEmpty) return false;
    final data = await _db
        ?.from('onboarding_forms')
        .select('id')
        .eq('candidate_application_id', candidateId)
        .limit(1)
        .maybeSingle();
    return data != null;
  }

  // ── Email Logs ───────────────────────────────────────────────────────

  static Future<String?> insertEmailLog(Map<String, dynamic> fields) async {
    final data = await _db
        ?.from('email_logs')
        .insert(fields)
        .select('id')
        .maybeSingle();
    return data?['id'] as String?;
  }

  static Future<void> updateEmailLog(String id, Map<String, dynamic> fields) async {
    await _db?.from('email_logs').update(fields).eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> fetchEmailLogs() async {
    final data = await _db
        ?.from('email_logs')
        .select()
        .order('created_at', ascending: false);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<Map<String, dynamic>?> fetchEmailLog(String id) async {
    final data = await _db?.from('email_logs').select().eq('id', id).maybeSingle();
    return data;
  }

  // ── Account activation tokens (Set Your Password flow) ─────────────────

  static Future<void> setAppUserActivationToken(
    String email, {
    required String token,
    required String expiresAt,
  }) async {
    await _db?.from('app_users').update({
      'activation_token': token,
      'activation_token_expires_at': expiresAt,
      'active': false,
    }).eq('email', email);
  }

  static Future<Map<String, dynamic>?> fetchAppUserByActivationToken(String token) async {
    if (token.isEmpty) return null;
    final data = await _db
        ?.from('app_users')
        .select()
        .eq('activation_token', token)
        .maybeSingle();
    return data;
  }

  static Future<void> completeAccountActivation(String email, {required String password}) async {
    await _db?.from('app_users').update({
      'password': password,
      'active': true,
      'activation_token': '',
      'activation_token_expires_at': '',
    }).eq('email', email);
  }

  // ── Notification preferences (muted categories) ─────────────────────────

  static Future<List<String>> fetchMutedCategories(String email) async {
    if (email.isEmpty) return [];
    try {
      final data = await _db
          ?.from('notification_preferences')
          .select('muted_categories')
          .eq('email', email)
          .maybeSingle();
      final raw = data?['muted_categories'];
      return raw is List ? List<String>.from(raw) : [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> setMutedCategories(String email, List<String> categoryIds) async {
    if (email.isEmpty) return;
    try {
      await _db?.from('notification_preferences').upsert({
        'email': email,
        'muted_categories': categoryIds,
      });
    } catch (_) {}
  }

  // ── Initial load on app start ─────────────────────────────────────────

  static Future<void> loadAll() async {
    await Future.wait([
      _loadLeave(),
      _loadMaintenance(),
      _loadProfiles(),
      _loadEmployees(),
      _loadTasks(),
      _loadNotifications(),
      _loadNotificationPreferences(),
    ]);
  }

  static Future<void> _loadNotificationPreferences() async {
    if (UserSession.email.isEmpty) return;
    final muted = await fetchMutedCategories(UserSession.email);
    NotificationStore.mutedCategories = muted.toSet();
    NotificationStore.recomputeUnread();
  }

  static Future<void> _loadNotifications() async {
    final list = await fetchNotifications();
    // Seeds the new-arrival baseline before anything else touches it, so
    // existing history never pops up as if it just arrived.
    NotificationStore.diffNewArrivals(list);
    NotificationStore.all
      ..clear()
      ..addAll(list);
    NotificationStore.recomputeUnread();
  }

  static Future<void> _loadLeave() async {
    final list = await fetchLeaveApplications();
    LeaveStore.applications
      ..clear()
      ..addAll(list);
    LeaveStore.syncCounter();
  }

  static Future<void> _loadMaintenance() async {
    final list = await fetchMaintenanceTickets();
    MaintenanceStore.tickets
      ..clear()
      ..addAll(list);
    MaintenanceStore.syncCounter();
  }

  static Future<void> _loadProfiles() async {
    final list = await fetchProfiles();
    for (final p in list) {
      ProfileStore.saveByHr(p);
    }
  }

  static Future<void> _loadEmployees() async {
    final list = await fetchEmployees();
    EmployeeStore.employees
      ..clear()
      ..addAll(list);
  }

  static Future<void> _loadTasks() async {
    final list = await fetchTasks();
    TaskStore.tasks
      ..clear()
      ..addAll(list);
  }

  // ── Profile photo ─────────────────────────────────────────────────────────
  // Looks up the onboarding form for the given employee ID and returns the
  // URL of the first image attachment (Passport Photo / photo_upload type).
  static Future<String?> fetchCurrentUserPhotoUrl(String employeeId) async {
    final db = _db;
    if (db == null || employeeId.isEmpty) return null;
    try {
      final rows = await db
          .from('onboarding_forms')
          .select('attachments, form_data')
          .eq('assigned_emp_id', employeeId)
          .order('submitted_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isEmpty) return null;
      final row = list.first;
      // Manually-uploaded photos (via updateCurrentUserPhoto) live in the
      // top-level 'attachments' column; the passport photo submitted with
      // the original onboarding form lives nested inside 'form_data'
      // (only name/phone/designation are ever written top-level on submit).
      // Check the manual upload first so it takes precedence if both exist.
      final formData = row['form_data'];
      final attachments = [
        ...(row['attachments'] is List ? row['attachments'] as List : const []),
        ...(formData is Map && formData['attachments'] is List
            ? formData['attachments'] as List
            : const []),
      ];
      for (final item in attachments) {
        final docType = (item['doc_type'] ?? '').toString().toLowerCase();
        final url = (item['url'] ?? '').toString();
        if (url.isNotEmpty &&
            (docType.contains('photo') || docType.contains('passport'))) {
          return url;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Uploads a new profile photo and stores it as the current user's attachment
  // on their latest onboarding form (the same place fetchCurrentUserPhotoUrl
  // reads from). Returns the new public URL, or null on failure.
  static Future<String?> updateCurrentUserPhoto(
      String employeeId, Uint8List bytes, String fileName, String mimeType) async {
    final db = _db;
    if (db == null || employeeId.isEmpty) return null;
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path =
        'profile_photos/${employeeId}_${DateTime.now().millisecondsSinceEpoch}_$safe';
    final String url;
    try {
      await db.storage.from('RESUME').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(
            contentType: mimeType.isNotEmpty ? mimeType : 'image/jpeg'),
      );
      url = db.storage.from('RESUME').getPublicUrl(path);
    } catch (_) {
      return null;
    }

    try {
      final rows = await db
          .from('onboarding_forms')
          .select('id, attachments')
          .eq('assigned_emp_id', employeeId)
          .order('submitted_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isNotEmpty) {
        final row = list.first;
        final attachments = row['attachments'] is List
            ? List<Map<String, dynamic>>.from(row['attachments'])
            : <Map<String, dynamic>>[];
        attachments.removeWhere((a) {
          final docType = (a['doc_type'] ?? '').toString().toLowerCase();
          return docType.contains('photo') || docType.contains('passport');
        });
        attachments.insert(
            0, {'doc_type': 'photo_upload', 'url': url, 'file_name': fileName});
        await db
            .from('onboarding_forms')
            .update({'attachments': attachments}).eq('id', row['id']);
      }
    } catch (_) {}

    return url;
  }

  // Removes the current user's manually-uploaded profile photo from their
  // latest onboarding form's 'attachments' column. Returns true on success.
  static Future<bool> deleteCurrentUserPhoto(String employeeId) async {
    final db = _db;
    if (db == null || employeeId.isEmpty) return false;
    try {
      final rows = await db
          .from('onboarding_forms')
          .select('id, attachments')
          .eq('assigned_emp_id', employeeId)
          .order('submitted_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isEmpty) return false;
      final row = list.first;
      final attachments = row['attachments'] is List
          ? List<Map<String, dynamic>>.from(row['attachments'])
          : <Map<String, dynamic>>[];
      attachments.removeWhere((a) {
        final docType = (a['doc_type'] ?? '').toString().toLowerCase();
        return docType.contains('photo') || docType.contains('passport');
      });
      await db
          .from('onboarding_forms')
          .update({'attachments': attachments}).eq('id', row['id']);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── HR Policy (versioned, approval workflow) ──────────────────────────────
  // Returns the content of the latest approved version, or null if none.
  static Future<String?> fetchHRPolicy() async {
    final db = _db;
    if (db == null) return null;
    try {
      final data = await db
          .from('hr_policy_versions')
          .select('content')
          .eq('status', 'approved')
          .order('approved_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.isEmpty ? null : list.first['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  // Returns all versions (pending / approved / rejected) for the approvals page.
  static Future<List<Map<String, dynamic>>> fetchHRPolicyVersions() async {
    final db = _db;
    if (db == null) return [];
    try {
      final data = await db
          .from('hr_policy_versions')
          .select()
          .order('version_number', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  // Returns the next version number.
  static Future<int> getNextHRPolicyVersionNumber() async {
    final db = _db;
    if (db == null) return 1;
    try {
      final data = await db
          .from('hr_policy_versions')
          .select('version_number')
          .order('version_number', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      if (list.isEmpty) return 1;
      return ((list.first['version_number'] as int?) ?? 0) + 1;
    } catch (_) {
      return 1;
    }
  }

  // HR submits a new pending policy version for Management approval.
  static Future<void> submitHRPolicyForApproval(
      String content, String createdBy) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized.');
    final version = await getNextHRPolicyVersionNumber();
    await db.from('hr_policy_versions').insert({
      'version_number': version,
      'content': content,
      'status': 'pending',
      'created_by': createdBy,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // Management approves or rejects a pending version.
  static Future<void> updateHRPolicyVersionStatus(
    String id,
    String status, {
    String decidedBy = '',
    String note = '',
  }) async {
    final db = _db;
    if (db == null) return;
    final update = <String, dynamic>{'status': status};
    if (status == 'approved') {
      update['approved_at'] = DateTime.now().toUtc().toIso8601String();
      update['approved_by'] = decidedBy;
    }
    if (note.isNotEmpty) update['rejection_note'] = note;
    await db.from('hr_policy_versions').update(update).eq('id', id);
  }

  // Returns any pending HR policy version (for showing HR a "pending" banner).
  static Future<Map<String, dynamic>?> fetchPendingHRPolicyVersion() async {
    final db = _db;
    if (db == null) return null;
    try {
      final data = await db
          .from('hr_policy_versions')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }
}
