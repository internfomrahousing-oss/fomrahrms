// ignore_for_file: avoid_catches_without_on_clauses
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../models/maintenance_store.dart';
import '../models/profile_store.dart';
import '../models/employee_store.dart';
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
    decided_by text default ''
  );

  -- If the table already exists:
  alter table leave_applications add column if not exists decided_by text default '';

  create table if not exists maintenance_tickets (
    id text primary key,
    reported_by_role text not null,
    reported_by text not null,
    issue_type text not null,
    description text not null,
    status text default 'open',
    created_at timestamptz default now()
  );

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

  -- Disable Row Level Security for development (enable and add policies for production)
  alter table leave_applications disable row level security;
  alter table maintenance_tickets disable row level security;
  alter table employee_profiles   disable row level security;
  alter table employees           disable row level security;
  alter table candidate_applications disable row level security;
  alter table app_users           disable row level security;
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
    try {
      await _db?.from('leave_applications').upsert({
        'id':            app.id,
        'employee_name': app.employeeName,
        'department':    app.department,
        'leave_type':    app.leaveType,
        'from_date':     app.from.toIso8601String().substring(0, 10),
        'to_date':       app.to.toIso8601String().substring(0, 10),
        'days':          app.days,
        'reason':        app.reason,
        'applied_on':    app.appliedOn.toIso8601String(),
        'manager_status': app.managerStatus.name,
      });
    } catch (_) {}
  }

  static Future<void> updateLeaveManagerStatus(
      String id, LeaveApprovalStatus status, {String decidedBy = ''}) async {
    // Update status first — always works even if decided_by column doesn't exist yet
    try {
      await _db
          ?.from('leave_applications')
          .update({'manager_status': status.name})
          .eq('id', id);
    } catch (_) {}
    // Update decided_by separately — silently skipped if column not yet added
    try {
      await _db
          ?.from('leave_applications')
          .update({'decided_by': decidedBy})
          .eq('id', id);
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
        final ms = (row['manager_status'] as String?) ?? 'pending';
        app.managerStatus = LeaveApprovalStatus.values.firstWhere(
          (s) => s.name == ms,
          orElse: () => LeaveApprovalStatus.pending,
        );
        app.decidedBy = (row['decided_by'] as String?) ?? '';
        return app;
      }).toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  // ── Maintenance Tickets ───────────────────────────────────────────────

  static Future<void> saveMaintenanceTicket(MaintenanceTicket ticket) async {
    try {
      await _db?.from('maintenance_tickets').upsert({
        'id':               ticket.id,
        'reported_by_role': ticket.reportedByRole.name,
        'reported_by':      ticket.reportedBy,
        'issue_type':       ticket.issueType,
        'description':      ticket.description,
        'status':           ticket.status.name,
        'created_at':       ticket.createdAt.toIso8601String(),
      });
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
          id:             row['id'] as String,
          reportedByRole: role,
          reportedBy:     row['reported_by'] as String,
          issueType:      row['issue_type'] as String,
          description:    row['description'] as String,
          status:         status,
          createdAt:      DateTime.parse(row['created_at'] as String),
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

  static Future<String?> uploadResume(
      Uint8List bytes, String fileName, String mimeType) async {
    try {
      final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _db?.storage.from('resumes').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(contentType: mimeType.isNotEmpty ? mimeType : 'application/octet-stream'),
      );
      return _db?.storage.from('resumes').getPublicUrl(path);
    } catch (_) {
      return null;
    }
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

  // ── App Users (Administration) ────────────────────────────────────────

  static Future<List<AppUser>> fetchAppUsers() async {
    try {
      final data = await _db?.from('app_users').select().order('name');
      if (data == null) return [];
      return (data as List).map((row) => AppUser(
        name:              (row['name']               as String?) ?? '',
        email:             (row['email']              as String?) ?? '',
        employeeId:        (row['employee_id']        as String?) ?? '',
        designation:       (row['designation']        as String?) ?? '',
        role:              (row['role']               as String?) ?? 'Employee',
        active:            (row['active']             as bool?)   ?? true,
        password:          (row['password']           as String?) ?? '',
        leaveAllocation:   (row['leave_allocation']   as int?)    ?? 21,
        reportingManager:  (row['reporting_manager']  as String?) ?? '',
        mobile:            (row['mobile']             as String?) ?? '',
        address:           (row['address']            as String?) ?? '',
        dateOfJoining:     (row['date_of_joining']    as String?) ?? '',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> upsertAppUser(AppUser u) async {
    try {
      await _db?.from('app_users').upsert({
        'email':              u.email,
        'name':               u.name,
        'employee_id':        u.employeeId,
        'designation':        u.designation,
        'role':               u.role,
        'active':             u.active,
        'password':           u.password,
        'leave_allocation':   u.leaveAllocation,
        'reporting_manager':  u.reportingManager,
        'mobile':             u.mobile,
        'address':            u.address,
        'date_of_joining':    u.dateOfJoining,
      });
    } catch (_) {}
  }

  static Future<void> deleteAppUser(String email) async {
    try {
      await _db?.from('app_users').delete().eq('email', email);
    } catch (_) {}
  }

  // ── Initial load on app start ─────────────────────────────────────────

  static Future<void> loadAll() async {
    await Future.wait([
      _loadLeave(),
      _loadMaintenance(),
      _loadProfiles(),
      _loadEmployees(),
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
}
