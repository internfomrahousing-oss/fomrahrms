// ignore_for_file: avoid_catches_without_on_clauses
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../models/attendance_store.dart';
import '../models/leave_store.dart';
import '../models/maintenance_store.dart';
import '../models/profile_store.dart';
import '../models/employee_store.dart';
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
    issue_type text not null,
    description text not null,
    status text default 'open',
    sent_to_management boolean default false,
    created_at timestamptz default now()
  );
  -- If table already exists without sent_to_management:
  alter table maintenance_tickets add column if not exists sent_to_management boolean default false;

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

  -- Onboarding workflow columns (run if table already exists):
  alter table onboarding_forms add column if not exists status text default 'pending';
  alter table onboarding_forms add column if not exists hr_comment text default '';
  alter table onboarding_forms add column if not exists assigned_email text default '';
  alter table onboarding_forms add column if not exists assigned_emp_id text default '';
  alter table onboarding_forms add column if not exists assigned_manager text default '';

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
    // is_half_day — added later; skipped silently if column not yet in DB
    try {
      await _db?.from('leave_applications')
          .update({'is_half_day': app.isHalfDay})
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
        app.isHalfDay = (row['is_half_day'] as bool?) ?? false;
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
        'issue_type':           ticket.issueType,
        'description':          ticket.description,
        'status':               ticket.status.name,
        'sent_to_management':   ticket.sentToManagement,
        'created_at':           ticket.createdAt.toIso8601String(),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> updateTicketSentToManagement(String id, bool sent) async {
    try {
      await _db?.from('maintenance_tickets')
          .update({'sent_to_management': sent})
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
          issueType:          row['issue_type'] as String,
          description:        row['description'] as String,
          status:             status,
          sentToManagement:   (row['sent_to_management'] as bool?) ?? false,
          createdAt:          DateTime.parse(row['created_at'] as String),
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
        role:                 (row['role']                    as String?) ?? 'Employee',
        active:               (row['active']                  as bool?)   ?? true,
        password:             (row['password']                as String?) ?? '',
        leaveAllocation:      (row['leave_allocation']        as int?)    ?? 21,
        reportingManager:     (row['reporting_manager']       as String?) ?? '',
        mobile:               (row['mobile']                  as String?) ?? '',
        address:              (row['address']                 as String?) ?? '',
        dateOfJoining:        (row['date_of_joining']         as String?) ?? '',
        onrollConfirmedAt:    (row['onroll_confirmed_at']     as String?) ?? '',
        elEligibleAt:         (row['el_eligible_at']          as String?) ?? '',
        biometricId:          (row['biometric_id']            as String?) ?? '',
        elAvailRequestedAt:   (row['el_avail_requested_at']   as String?) ?? '',
        elLastAvailedAt:      (row['el_last_availed_at']      as String?) ?? '',
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
      'role':                     u.role,
      'active':                   u.active,
      'password':                 u.password,
      'leave_allocation':         u.leaveAllocation,
      'reporting_manager':        u.reportingManager,
      'mobile':                   u.mobile,
      'address':                  u.address,
      'date_of_joining':          u.dateOfJoining,
      'onroll_confirmed_at':      u.onrollConfirmedAt,
      'el_eligible_at':           u.elEligibleAt,
      'biometric_id':             u.biometricId,
      'el_avail_requested_at':    u.elAvailRequestedAt,
      'el_last_availed_at':       u.elLastAvailedAt,
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

  static Future<void> updateTaskStatus(String id, TaskStatus status) async {
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

  // Updates one team member's status; if allCompleted, also flips overall status.
  static Future<void> updateTeamMemberStatus(
      String taskId, Map<String, String> statuses, bool allCompleted) async {
    try {
      final update = <String, dynamic>{
        'team_member_statuses': jsonEncode(statuses),
      };
      if (allCompleted) update['status'] = TaskStatus.completed.name;
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

  // ── Attendance Records ────────────────────────────────────────────────

  static String _attendanceId(String employeeId, String date) =>
      '${employeeId.isNotEmpty ? employeeId : 'emp'}_${date.replaceAll('/', '-')}';

  static Future<String?> saveCheckIn({
    required String employeeName,
    required String employeeId,
    required String date,
    required String time,
    String location = '',
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
  }) async {
    try {
      await _db
          ?.from('attendance_records')
          .update({'check_out_time': time})
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
          .limit(20);
      if (data == null) return [];
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  static Future<String?> addAnnouncement(String text, DateTime date) async {
    try {
      await _db?.from('announcements').insert({
        'text': text,
        'announced_on': date.toIso8601String().substring(0, 10),
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

  static Future<List<Map<String, dynamic>>> fetchBirthdaysForMonth(
      int month) async {
    try {
      final data = await _db
          ?.from('birthdays')
          .select()
          .order('birthday_date', ascending: true);
      if (data == null) return [];
      final all = List<Map<String, dynamic>>.from(data as List);
      return all.where((row) {
        final d = DateTime.tryParse(row['birthday_date'] as String? ?? '');
        return d != null && d.month == month;
      }).toList();
    } catch (_) {
      return [];
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

  // ── Initial load on app start ─────────────────────────────────────────

  static Future<void> loadAll() async {
    await Future.wait([
      _loadLeave(),
      _loadMaintenance(),
      _loadProfiles(),
      _loadEmployees(),
      _loadTasks(),
    ]);
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
          .select('attachments')
          .eq('assigned_emp_id', employeeId)
          .order('submitted_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isEmpty) return null;
      final attachments = list.first['attachments'];
      if (attachments is! List) return null;
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
