import '../models/notification_store.dart';
import '../models/user_session.dart';
import '../utils/tenure.dart';
import 'supabase_service.dart';
import 'user_store.dart';

/// Creates notification rows for every event the app can raise, and keeps
/// the in-memory [NotificationStore] in sync so the bell badge / feed update
/// immediately instead of waiting for the next periodic refresh.
///
/// Every method takes its target explicitly (email / reporting-manager name)
/// rather than looking it up itself — callers already have the relevant
/// AppUser/employee record in scope wherever these are invoked.
class NotificationService {
  static Future<void> _create({
    required String type,
    required String title,
    String body = '',
    String route = '',
    String targetEmail = '',
    String targetRole = '',
    String targetReportingManager = '',
    String sourceId = '',
  }) async {
    await SupabaseService.insertNotification(
      type: type, title: title, body: body, route: route,
      targetEmail: targetEmail, targetRole: targetRole,
      targetReportingManager: targetReportingManager, sourceId: sourceId,
    );
    NotificationStore.all.insert(0, AppNotification(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      type: type, title: title, body: body, route: route,
      targetEmail: targetEmail, targetRole: targetRole,
      targetReportingManager: targetReportingManager, sourceId: sourceId,
    ));
    NotificationStore.recomputeUnread();
  }

  static Future<void> markRead(AppNotification n) async {
    if (n.isReadBy(UserSession.email)) return;
    n.readBy.add(UserSession.email);
    NotificationStore.recomputeUnread();
    await SupabaseService.markNotificationRead(n.id, n.readBy);
  }

  static Future<void> markAllRead(List<AppNotification> notifications) async {
    for (final n in notifications) {
      if (!n.isReadBy(UserSession.email)) {
        n.readBy.add(UserSession.email);
        await SupabaseService.markNotificationRead(n.id, n.readBy);
      }
    }
    NotificationStore.recomputeUnread();
  }

  // ── Leave & attendance ───────────────────────────────────────────────

  // Notifies the employee's Reporting Manager (existing), plus HR and
  // Management (broadcast) — the RM approves it, but HR/Management still
  // want visibility into every request as it comes in.
  static Future<void> leaveSubmitted({
    required String employeeName,
    required String leaveType,
    required String reportingManagerName,
  }) async {
    if (reportingManagerName.isNotEmpty) {
      await _create(
        type: 'leave_submitted',
        title: 'New leave request',
        body: '$employeeName requested $leaveType',
        route: '/manager/leave/team-approvals',
        targetReportingManager: reportingManagerName,
      );
    }
    await _create(
      type: 'leave_submitted',
      title: 'New leave request',
      body: '$employeeName requested $leaveType',
      route: '/leave-management',
      targetRole: 'HR',
    );
    await _create(
      type: 'leave_submitted',
      title: 'New leave request',
      body: '$employeeName requested $leaveType',
      route: '/management/leave-management',
      targetRole: 'Management',
    );
  }

  static Future<void> leaveDecided({
    required String employeeEmail,
    required String leaveType,
    required bool approved,
    required String employeeRoutePrefix, // '', '/employee', '/manager', '/management'
  }) async {
    await _create(
      type: 'leave_decided',
      title: approved ? 'Leave approved' : 'Leave rejected',
      body: leaveType,
      route: '$employeeRoutePrefix/attendance-leaves',
      targetEmail: employeeEmail,
    );
    // Management-wide visibility into who approved/rejected what — the
    // decider is whoever's signed in when this fires.
    if (UserSession.name.isNotEmpty) {
      await _create(
        type: 'leave_decided',
        title: 'Leave ${approved ? 'approved' : 'rejected'} by ${UserSession.name}',
        body: leaveType,
        route: '/management/leave-management',
        targetRole: 'Management',
      );
    }
  }

  static Future<void> attendanceRegularized({
    required String employeeEmail,
    required bool approved,
    required String employeeRoutePrefix,
  }) => _create(
        type: 'attendance_regularized',
        title: approved ? 'Attendance regularization approved' : 'Attendance regularization rejected',
        route: '$employeeRoutePrefix/attendance-leaves',
        targetEmail: employeeEmail,
      );

  // ── On-roll confirmation (3-stage) ──────────────────────────────────

  static Future<void> onrollRequested({
    required String employeeName,
    required String reportingManagerName,
  }) async {
    await _create(
      type: 'onroll_hr_pending',
      title: 'On-roll confirmation pending',
      body: '$employeeName requested on-roll confirmation',
      route: '/employee-management',
      targetRole: 'HR',
    );
    await _create(
      type: 'onroll_manager_pending',
      title: 'On-roll confirmation pending',
      body: '$employeeName requested on-roll confirmation',
      route: '/manager/employee-management',
      targetReportingManager: reportingManagerName,
    );
  }

  static Future<void> onrollStageDecided({
    required String employeeEmail,
    required String stage, // 'HR' | 'Manager'
    required bool accepted,
  }) => _create(
        type: 'onroll_stage_decided',
        title: '$stage ${accepted ? 'accepted' : 'denied'} your on-roll request',
        route: '/employee/profile',
        targetEmail: employeeEmail,
      );

  static Future<void> onrollReachedManagement({required String employeeName}) => _create(
        type: 'onroll_management_pending',
        title: 'On-roll confirmation awaiting final approval',
        body: '$employeeName — HR and Manager both accepted',
        route: '/management/onroll-approvals',
        targetRole: 'Management',
      );

  static Future<void> onrollFinalDecided({
    required String employeeEmail,
    required bool approved,
  }) => _create(
        type: 'onroll_final_decided',
        title: approved ? 'On-roll confirmation approved' : 'On-roll confirmation denied',
        route: '/employee/profile',
        targetEmail: employeeEmail,
      );

  // ── Tasks ────────────────────────────────────────────────────────────

  // Notifies the assignee (existing), plus HR and Management (broadcast) —
  // they want visibility into every task handed out, not just their own.
  static Future<void> taskAssigned({
    required String taskName,
    required String assigneeEmail,
    required String assigneeRoutePrefix,
  }) async {
    await _create(
      type: 'task_assigned',
      title: 'New task assigned',
      body: taskName,
      route: '$assigneeRoutePrefix/my-tasks',
      targetEmail: assigneeEmail,
    );
    await _create(
      type: 'task_assigned',
      title: 'New task assigned',
      body: taskName,
      route: '/task-management',
      targetRole: 'HR',
    );
    await _create(
      type: 'task_assigned',
      title: 'New task assigned',
      body: taskName,
      route: '/management/task-management',
      targetRole: 'Management',
    );
  }

  static Future<void> taskCompleted({
    required String taskName,
    required String reportingManagerName,
  }) => _create(
        type: 'task_completed',
        title: 'Task completed',
        body: taskName,
        route: '/manager/task-management',
        targetReportingManager: reportingManagerName,
      );

  /// HR/Management-wide visibility into every task status change (not just
  /// completion), distinct from [taskCompleted] which only tells the
  /// reporting manager.
  static Future<void> taskStatusChanged({
    required String taskName,
    required String status,
    required String changedBy,
  }) async {
    await _create(
      type: 'task_status_changed',
      title: 'Task status updated to $status',
      body: '$taskName · by $changedBy',
      route: '/task-management',
      targetRole: 'HR',
    );
    await _create(
      type: 'task_status_changed',
      title: 'Task status updated to $status',
      body: '$taskName · by $changedBy',
      route: '/management/task-management',
      targetRole: 'Management',
    );
  }

  // ── Maintenance ──────────────────────────────────────────────────────

  static Future<void> maintenanceSubmitted({
    required String issueType,
    required String reportedBy,
    required bool sentToManagement,
    bool reportedByHr = false,
  }) async {
    await _create(
      type: 'maintenance_submitted',
      title: 'New maintenance issue',
      body: '$reportedBy · $issueType',
      route: '/maintenance-management',
      targetRole: 'HR',
    );
    // Management sees it if it's been explicitly escalated, OR if HR is the
    // one reporting it — HR raising an issue is itself worth Management's
    // attention even before anyone flags it as escalated.
    if (sentToManagement || reportedByHr) {
      await _create(
        type: 'maintenance_submitted',
        title: 'New maintenance issue',
        body: '$reportedBy · $issueType',
        route: '/management/maintenance-management',
        targetRole: 'Management',
      );
    }
  }

  static Future<void> maintenanceStatusChanged({
    required String reporterEmail,
    required String issueType,
    required String status,
    required String reporterRoutePrefix,
  }) => _create(
        type: 'maintenance_status_changed',
        title: 'Maintenance issue $status',
        body: issueType,
        route: '$reporterRoutePrefix/maintenance-management',
        targetEmail: reporterEmail,
      );

  // ── Candidates / interviews ──────────────────────────────────────────

  static Future<void> candidateSubmitted({required String candidateName}) async {
    await _create(
      type: 'candidate_hr_review',
      title: 'New candidate application',
      body: candidateName,
      route: '/interview-process',
      targetRole: 'HR',
    );
    await _create(
      type: 'candidate_hr_review',
      title: 'New candidate application',
      body: candidateName,
      route: '/management/interview-process',
      targetRole: 'Management',
    );
  }

  static Future<void> candidateAssignedToManager({
    required String candidateName,
    required String managerName,
  }) => _create(
        type: 'candidate_assigned_manager',
        title: 'Candidate assigned for review',
        body: candidateName,
        route: '/manager/interview-review',
        targetReportingManager: managerName,
      );

  static Future<void> candidateReadyForManagement({required String candidateName}) => _create(
        type: 'candidate_management_review',
        title: 'Candidate ready for final review',
        body: candidateName,
        route: '/management/interview-review',
        targetRole: 'Management',
      );

  // ── Onboarding ───────────────────────────────────────────────────────

  static Future<void> onboardingFormSubmitted({required String name}) async {
    await _create(
      type: 'onboarding_form_submitted',
      title: 'New onboarding form submitted',
      body: name,
      route: '/employee-onboarding',
      targetRole: 'HR',
    );
    await _create(
      type: 'onboarding_form_submitted',
      title: 'New onboarding form submitted',
      body: name,
      route: '/management/employee-onboarding',
      targetRole: 'Management',
    );
  }

  // ── Form-edit approvals (leave / onboarding / maintenance / interview) ─

  static Future<void> formEditSubmitted({required String formName}) => _create(
        type: 'form_edit_submitted',
        title: 'Form edit awaiting approval',
        body: formName,
        route: '/management/form-approvals',
        targetRole: 'Management',
      );

  static Future<void> formEditDecided({
    required String formName,
    required bool approved,
  }) => _create(
        type: 'form_edit_decided',
        title: approved ? 'Form edit approved' : 'Form edit rejected',
        body: formName,
        route: '/edit-form',
        targetRole: 'HR',
      );

  // ── Payroll ──────────────────────────────────────────────────────────

  static Future<void> payslipReady({
    required String employeeEmail,
    required String monthYear,
    required String employeeRoutePrefix,
  }) => _create(
        type: 'payslip_ready',
        title: 'New payslip available',
        body: monthYear,
        route: '$employeeRoutePrefix/my-payslips',
        targetEmail: employeeEmail,
      );

  static Future<void> payslipRequested({
    required String employeeName,
    required String monthYear,
  }) async {
    await _create(
      type: 'payslip_requested',
      title: 'Payslip requested',
      body: '$employeeName · $monthYear',
      route: '/payroll-management',
      targetRole: 'HR',
    );
    await _create(
      type: 'payslip_requested',
      title: 'Payslip requested',
      body: '$employeeName · $monthYear',
      route: '/management/payroll-management',
      targetRole: 'Management',
    );
  }

  // ── Earned Leave (eligibility + encashment) ─────────────────────────

  static Future<void> elEncashmentRequested({required String employeeName}) async {
    await _create(
      type: 'el_encashment_requested',
      title: 'EL encashment requested',
      body: employeeName,
      route: '/payroll-management',
      targetRole: 'HR',
    );
    await _create(
      type: 'el_encashment_requested',
      title: 'EL encashment requested',
      body: employeeName,
      route: '/management/payroll-management',
      targetRole: 'Management',
    );
  }

  /// Fired once, on the exact day an on-roll employee crosses the
  /// 1-year-since-on-roll mark — a reminder to go confirm EL eligibility,
  /// which stays a manual HR/Management action either way.
  static Future<void> elEligibilityDue({
    required String employeeName,
    required String sourceId,
  }) async {
    await _create(
      type: 'el_eligibility_due',
      title: 'EL eligibility review due',
      body: '$employeeName — 1 year on-roll',
      route: '/employee-management',
      targetRole: 'HR',
      sourceId: sourceId,
    );
    await _create(
      type: 'el_eligibility_due',
      title: 'EL eligibility review due',
      body: '$employeeName — 1 year on-roll',
      route: '/management/employee-management',
      targetRole: 'Management',
      sourceId: sourceId,
    );
  }

  /// Fired once, on the exact day an employee hits a tenure milestone
  /// (6 months, or a yearly anniversary) — see [milestoneLabelForToday].
  static Future<void> tenureMilestone({
    required String employeeName,
    required String milestoneLabel,
    required String sourceId,
  }) async {
    await _create(
      type: 'tenure_milestone',
      title: '$employeeName reached $milestoneLabel',
      route: '/employee-management',
      targetRole: 'HR',
      sourceId: sourceId,
    );
    await _create(
      type: 'tenure_milestone',
      title: '$employeeName reached $milestoneLabel',
      route: '/management/employee-management',
      targetRole: 'Management',
      sourceId: sourceId,
    );
  }

  // ── Leads ────────────────────────────────────────────────────────────

  static Future<void> leadAdded({required String leadName}) async {
    await _create(
      type: 'lead_added',
      title: 'New lead added',
      body: leadName,
      route: '/lead-management',
      targetRole: 'HR',
    );
    await _create(
      type: 'lead_added',
      title: 'New lead added',
      body: leadName,
      route: '/management/lead-management',
      targetRole: 'Management',
    );
  }

  // ── Interview outcome (back to HR) ──────────────────────────────────

  static Future<void> interviewDecided({
    required String candidateName,
    required String stage, // 'Manager' | 'Management'
    required bool accepted,
  }) async {
    await _create(
      type: 'candidate_decided',
      title: 'Interview $stage decision: ${accepted ? 'Accepted' : 'Rejected'}',
      body: candidateName,
      route: '/interview-process',
      targetRole: 'HR',
    );
    // Management cares most about the Manager stage — that's the review
    // "received from" a Manager "for" a candidate, before it ever reaches
    // Management's own queue. Their own decisions are self-evident, but
    // broadcasting those too keeps every Management user in sync.
    await _create(
      type: 'candidate_decided',
      title: 'Interview $stage decision: ${accepted ? 'Accepted' : 'Rejected'}',
      body: candidateName,
      route: '/management/interview-review',
      targetRole: 'Management',
    );
  }

  // ── Maintenance addressed by Management ─────────────────────────────

  static Future<void> maintenanceAddressedByManagement({
    required String issueType,
    required String reportedBy,
  }) => _create(
        type: 'maintenance_addressed',
        title: 'Escalated maintenance issue addressed',
        body: '$issueType · reported by $reportedBy',
        route: '/maintenance-management',
        targetRole: 'HR',
      );

  // ── Announcements ────────────────────────────────────────────────────

  static Future<void> announcementPosted({required String text}) => _create(
        type: 'announcement_posted',
        title: 'New announcement',
        body: text,
        route: '/dashboard',
        targetRole: 'ALL',
      );

  // ── Daily HR/Management reminders (date-crossed, not user actions) ──

  static DateTime? _lastDailyCheck;
  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static bool _alreadyNotified(String sourceId) =>
      NotificationStore.all.any((n) => n.sourceId == sourceId);

  /// Scans every active employee for tenure-milestone and EL-eligibility
  /// anniversaries that land on today, and notifies HR + Management once
  /// per employee per day (deduped via sourceId, since this can be called
  /// repeatedly). Cheap to call often — the actual scan only runs once per
  /// calendar day; either an HR or a Management session can trigger it
  /// (whichever logs in / polls first that day), since tenureMilestone and
  /// elEligibilityDue each write both roles' rows in one pass.
  static Future<void> checkDailyReminders() async {
    if (UserSession.role != UserRole.hr && UserSession.role != UserRole.management) return;
    final today = DateTime.now();
    if (_lastDailyCheck != null && _sameDate(_lastDailyCheck!, today)) return;
    _lastDailyCheck = today;

    final users = await UserStore.load();
    for (final u in users) {
      if (!u.active) continue;

      final milestone = milestoneLabelForToday(u.dateOfJoining, today: today);
      if (milestone != null) {
        final sourceId = '${u.employeeId}_tenure_${_dateKey(today)}';
        if (!_alreadyNotified(sourceId)) {
          await tenureMilestone(
              employeeName: u.name, milestoneLabel: milestone, sourceId: sourceId);
        }
      }

      if (u.isOnroll && !u.isElEligible && u.onrollConfirmedAt.isNotEmpty) {
        final onrollDate = DateTime.tryParse(u.onrollConfirmedAt);
        if (onrollDate != null) {
          final oneYearMark = DateTime(onrollDate.year + 1, onrollDate.month, onrollDate.day);
          if (_sameDate(oneYearMark, today)) {
            final sourceId = '${u.employeeId}_el_eligible_${_dateKey(today)}';
            if (!_alreadyNotified(sourceId)) {
              await elEligibilityDue(employeeName: u.name, sourceId: sourceId);
            }
          }
        }
      }
    }
  }
}
