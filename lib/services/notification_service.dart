import '../models/notification_store.dart';
import '../models/user_session.dart';
import 'supabase_service.dart';

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

  static Future<void> leaveSubmitted({
    required String employeeName,
    required String leaveType,
    required String reportingManagerName,
  }) => _create(
        type: 'leave_submitted',
        title: 'New leave request',
        body: '$employeeName requested $leaveType',
        route: '/manager/leave/team-approvals',
        targetReportingManager: reportingManagerName,
      );

  static Future<void> leaveDecided({
    required String employeeEmail,
    required String leaveType,
    required bool approved,
    required String employeeRoutePrefix, // '', '/employee', '/manager', '/management'
  }) => _create(
        type: 'leave_decided',
        title: approved ? 'Leave approved' : 'Leave rejected',
        body: leaveType,
        route: '$employeeRoutePrefix/attendance-leaves',
        targetEmail: employeeEmail,
      );

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

  static Future<void> taskAssigned({
    required String taskName,
    required String assigneeEmail,
    required String assigneeRoutePrefix,
  }) => _create(
        type: 'task_assigned',
        title: 'New task assigned',
        body: taskName,
        route: '$assigneeRoutePrefix/my-tasks',
        targetEmail: assigneeEmail,
      );

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

  // ── Maintenance ──────────────────────────────────────────────────────

  static Future<void> maintenanceSubmitted({
    required String issueType,
    required String reportedBy,
    required bool sentToManagement,
  }) async {
    await _create(
      type: 'maintenance_submitted',
      title: 'New maintenance issue',
      body: '$reportedBy · $issueType',
      route: '/maintenance-management',
      targetRole: 'HR',
    );
    if (sentToManagement) {
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

  static Future<void> candidateSubmitted({required String candidateName}) => _create(
        type: 'candidate_hr_review',
        title: 'New candidate application',
        body: candidateName,
        route: '/interview-process',
        targetRole: 'HR',
      );

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

  static Future<void> onboardingFormSubmitted({required String name}) => _create(
        type: 'onboarding_form_submitted',
        title: 'New onboarding form submitted',
        body: name,
        route: '/employee-onboarding',
        targetRole: 'HR',
      );

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

  // ── Announcements ────────────────────────────────────────────────────

  static Future<void> announcementPosted({required String text}) => _create(
        type: 'announcement_posted',
        title: 'New announcement',
        body: text,
        route: '/dashboard',
        targetRole: 'ALL',
      );
}
