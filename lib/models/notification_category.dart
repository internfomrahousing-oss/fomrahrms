import 'package:flutter/material.dart';

/// One specific notification `type` string inside a [NotificationCategory],
/// with its human-readable label — lets the preferences sheet offer a
/// per-type toggle underneath the category's own master toggle.
/// [roles] lists which of 'Employee' | 'Manager' | 'HR' | 'Management' this
/// particular type is ever actually sent to, per the targeting in
/// NotificationService (self-only types never reach Management, since it
/// has no personal attendance/leave/payslip; broadcast types like
/// `targetRole: 'HR'` only reach that one role) — null means every role
/// that can see the category at all can receive it.
typedef NotificationSubType = ({String type, String label, List<String>? roles});

/// Groups the fine-grained `AppNotification.type` strings (e.g. 'leave_decided',
/// 'onroll_stage_decided') into user-facing buckets — used both for the
/// "view only this kind" filter and the "mute this kind" preference toggle
/// on the Notifications page.
class NotificationCategory {
  final String id;
  final String label;
  final IconData icon;
  final List<String> typePrefixes;
  final List<NotificationSubType> subTypes;
  const NotificationCategory(this.id, this.label, this.icon, this.typePrefixes, this.subTypes);
}

const _selfNoManagement = ['Employee', 'Manager', 'HR'];

const List<NotificationCategory> notificationCategories = [
  NotificationCategory('leave', 'Leave & Attendance',
      Icons.event_available_rounded, ['leave_', 'attendance_'], [
    (type: 'leave_submitted', label: 'New Leave Request', roles: ['Manager', 'HR', 'Management']),
    (type: 'leave_decided', label: 'Leave Decision', roles: null),
    (type: 'attendance_regularized', label: 'Attendance Regularized', roles: _selfNoManagement),
    (type: 'attendance_checkin', label: 'Check-in Recorded', roles: _selfNoManagement),
    (type: 'attendance_checkout', label: 'Check-out Recorded', roles: _selfNoManagement),
    (type: 'attendance_checkin_late', label: 'Late Check-in / Permission Exceeded', roles: ['HR']),
  ]),
  NotificationCategory('onroll', 'On-roll Confirmation',
      Icons.how_to_reg_rounded, ['onroll_'], [
    (type: 'onroll_hr_pending', label: 'On-roll Pending (HR)', roles: ['HR']),
    (type: 'onroll_manager_pending', label: 'On-roll Pending (Manager)', roles: ['Manager']),
    (type: 'onroll_stage_decided', label: 'On-roll Stage Decision', roles: _selfNoManagement),
    (type: 'onroll_management_pending', label: 'On-roll Awaiting Management', roles: ['Management']),
    (type: 'onroll_eligible', label: 'Eligible for On-roll', roles: _selfNoManagement),
    (type: 'onroll_final_decided', label: 'On-roll Final Decision', roles: _selfNoManagement),
  ]),
  NotificationCategory('task', 'Tasks',
      Icons.task_alt_rounded, ['task_'], [
    (type: 'task_assigned', label: 'Task Assigned', roles: null),
    (type: 'task_completed', label: 'Task Completed', roles: ['Manager']),
    (type: 'task_status_changed', label: 'Task Status Changed', roles: ['HR', 'Management']),
    (type: 'task_pending_reminder', label: 'Task Pending Reminder', roles: null),
    (type: 'task_due_soon', label: 'Task Due Soon', roles: null),
  ]),
  NotificationCategory('maintenance', 'Maintenance',
      Icons.build_rounded, ['maintenance_'], [
    (type: 'maintenance_submitted', label: 'New Maintenance Issue', roles: ['HR', 'Management']),
    (type: 'maintenance_status_changed', label: 'Maintenance Status Changed', roles: null),
    (type: 'maintenance_addressed', label: 'Escalated Issue Addressed', roles: ['HR']),
  ]),
  NotificationCategory('candidate', 'Recruitment',
      Icons.record_voice_over_rounded, ['candidate_'], [
    (type: 'candidate_hr_review', label: 'New Candidate Application', roles: ['HR', 'Management']),
    (type: 'candidate_assigned_manager', label: 'Candidate Assigned for Review', roles: ['Manager']),
    (type: 'candidate_management_review', label: 'Candidate Ready for Final Review', roles: ['Management']),
    (type: 'candidate_decided', label: 'Interview Decision', roles: ['HR', 'Management']),
  ]),
  NotificationCategory('onboarding', 'Onboarding',
      Icons.assignment_ind_rounded, ['onboarding_'], [
    (type: 'onboarding_form_submitted', label: 'Onboarding Form Submitted', roles: ['HR', 'Management']),
  ]),
  NotificationCategory('form_edit', 'Form Edits',
      Icons.edit_note_rounded, ['form_edit_'], [
    (type: 'form_edit_submitted', label: 'Form Edit Awaiting Approval', roles: ['Management']),
    (type: 'form_edit_decided', label: 'Form Edit Decision', roles: ['HR']),
  ]),
  NotificationCategory('payslip', 'Payroll',
      Icons.account_balance_wallet_rounded, ['payslip_'], [
    (type: 'payslip_ready', label: 'Payslip Ready', roles: _selfNoManagement),
    (type: 'payslip_requested', label: 'Payslip Requested', roles: ['HR', 'Management']),
    (type: 'payslip_request_denied', label: 'Payslip Request Denied', roles: _selfNoManagement),
  ]),
  NotificationCategory('el', 'Earned Leave',
      Icons.savings_rounded, ['el_'], [
    (type: 'el_marked_eligible', label: 'EL Eligibility Confirmed', roles: _selfNoManagement),
    (type: 'el_encashment_requested', label: 'EL Encashment Requested', roles: ['HR', 'Management']),
    (type: 'el_eligibility_due', label: 'EL Eligibility Review Due', roles: ['HR', 'Management']),
  ]),
  NotificationCategory('milestone', 'Milestones',
      Icons.emoji_events_rounded, ['tenure_'], [
    (type: 'tenure_milestone', label: 'Tenure Milestone', roles: null),
  ]),
  NotificationCategory('lead', 'Leads',
      Icons.leaderboard_rounded, ['lead_'], [
    (type: 'lead_added', label: 'New Lead Added', roles: ['HR', 'Management']),
  ]),
  NotificationCategory('performance', 'Performance & KRA',
      Icons.trending_up_rounded, ['appraisal_', 'kra_'], [
    (type: 'appraisal_started', label: 'Appraisal Form Started', roles: ['Manager', 'HR']),
    (type: 'kra_uploaded', label: 'KRA Document Uploaded', roles: ['Management']),
    (type: 'kra_decided', label: 'KRA Decision', roles: ['HR']),
  ]),
  NotificationCategory('announcement', 'Announcements',
      Icons.campaign_rounded, ['announcement_'], [
    (type: 'announcement_posted', label: 'New Announcement', roles: null),
  ]),
];

const _other = NotificationCategory('other', 'Other', Icons.notifications_rounded, [], []);

NotificationCategory categoryFor(String type) {
  for (final c in notificationCategories) {
    if (c.typePrefixes.any((p) => type.startsWith(p))) return c;
  }
  return _other;
}

/// Which categories a role can actually be targeted by, per the trigger
/// methods in NotificationService — e.g. Employee is never targeted by
/// candidateSubmitted/onboardingFormSubmitted/formEditSubmitted (recruitment,
/// onboarding, form-edit approvals are HR/Management-side only), so showing
/// a mute toggle for those to an Employee would be pure clutter.
/// HR and Management are targeted by every category.
// 'el' (EL eligibility) and 'milestone' (tenure anniversaries) now also
// reach every employee directly (elMarkedEligible, tenureMilestone), not
// just HR/Management, so they're no longer excluded for Employee/Manager.
List<NotificationCategory> categoriesForRole(String roleLabel) {
  const excludedByRole = {
    'Employee': {'candidate', 'onboarding', 'form_edit', 'lead', 'performance'},
    'Manager': {'onboarding', 'form_edit', 'lead'},
    'Management': <String>{},
    'HR': <String>{},
  };
  final excluded = excludedByRole[roleLabel] ?? const <String>{};
  return notificationCategories.where((c) => !excluded.contains(c.id)).toList();
}

/// Narrows a category's sub-types down to the ones [roleLabel] can actually
/// receive (see [NotificationSubType.roles]) — e.g. HR sees every Leave &
/// Attendance sub-type, while Management only sees the two it's broadcast
/// (leave_submitted, leave_decided), not the personal check-in/out ones it
/// never gets since it has no attendance of its own.
List<NotificationSubType> subTypesForRole(NotificationCategory category, String roleLabel) =>
    category.subTypes.where((st) => st.roles == null || st.roles!.contains(roleLabel)).toList();
