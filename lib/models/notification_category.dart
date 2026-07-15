import 'package:flutter/material.dart';

/// One specific notification `type` string inside a [NotificationCategory],
/// with its human-readable label — lets the preferences sheet offer a
/// per-type toggle underneath the category's own master toggle.
typedef NotificationSubType = ({String type, String label});

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

const List<NotificationCategory> notificationCategories = [
  NotificationCategory('leave', 'Leave & Attendance',
      Icons.event_available_rounded, ['leave_', 'attendance_'], [
    (type: 'leave_submitted', label: 'New Leave Request'),
    (type: 'leave_decided', label: 'Leave Decision'),
    (type: 'attendance_regularized', label: 'Attendance Regularized'),
    (type: 'attendance_checkin', label: 'Check-in Recorded'),
    (type: 'attendance_checkout', label: 'Check-out Recorded'),
    (type: 'attendance_checkin_late', label: 'Late Check-in / Permission Exceeded'),
  ]),
  NotificationCategory('onroll', 'On-roll Confirmation',
      Icons.how_to_reg_rounded, ['onroll_'], [
    (type: 'onroll_hr_pending', label: 'On-roll Pending (HR)'),
    (type: 'onroll_manager_pending', label: 'On-roll Pending (Manager)'),
    (type: 'onroll_stage_decided', label: 'On-roll Stage Decision'),
    (type: 'onroll_management_pending', label: 'On-roll Awaiting Management'),
    (type: 'onroll_eligible', label: 'Eligible for On-roll'),
    (type: 'onroll_final_decided', label: 'On-roll Final Decision'),
  ]),
  NotificationCategory('task', 'Tasks',
      Icons.task_alt_rounded, ['task_'], [
    (type: 'task_assigned', label: 'Task Assigned'),
    (type: 'task_completed', label: 'Task Completed'),
    (type: 'task_status_changed', label: 'Task Status Changed'),
    (type: 'task_pending_reminder', label: 'Task Pending Reminder'),
    (type: 'task_due_soon', label: 'Task Due Soon'),
  ]),
  NotificationCategory('maintenance', 'Maintenance',
      Icons.build_rounded, ['maintenance_'], [
    (type: 'maintenance_submitted', label: 'New Maintenance Issue'),
    (type: 'maintenance_status_changed', label: 'Maintenance Status Changed'),
    (type: 'maintenance_addressed', label: 'Escalated Issue Addressed'),
  ]),
  NotificationCategory('candidate', 'Recruitment',
      Icons.record_voice_over_rounded, ['candidate_'], [
    (type: 'candidate_hr_review', label: 'New Candidate Application'),
    (type: 'candidate_assigned_manager', label: 'Candidate Assigned for Review'),
    (type: 'candidate_management_review', label: 'Candidate Ready for Final Review'),
    (type: 'candidate_decided', label: 'Interview Decision'),
  ]),
  NotificationCategory('onboarding', 'Onboarding',
      Icons.assignment_ind_rounded, ['onboarding_'], [
    (type: 'onboarding_form_submitted', label: 'Onboarding Form Submitted'),
  ]),
  NotificationCategory('form_edit', 'Form Edits',
      Icons.edit_note_rounded, ['form_edit_'], [
    (type: 'form_edit_submitted', label: 'Form Edit Awaiting Approval'),
    (type: 'form_edit_decided', label: 'Form Edit Decision'),
  ]),
  NotificationCategory('payslip', 'Payroll',
      Icons.account_balance_wallet_rounded, ['payslip_'], [
    (type: 'payslip_ready', label: 'Payslip Ready'),
    (type: 'payslip_requested', label: 'Payslip Requested'),
    (type: 'payslip_request_denied', label: 'Payslip Request Denied'),
  ]),
  NotificationCategory('el', 'Earned Leave',
      Icons.savings_rounded, ['el_'], [
    (type: 'el_marked_eligible', label: 'EL Eligibility Confirmed'),
    (type: 'el_encashment_requested', label: 'EL Encashment Requested'),
    (type: 'el_eligibility_due', label: 'EL Eligibility Review Due'),
  ]),
  NotificationCategory('milestone', 'Milestones',
      Icons.emoji_events_rounded, ['tenure_'], [
    (type: 'tenure_milestone', label: 'Tenure Milestone'),
  ]),
  NotificationCategory('lead', 'Leads',
      Icons.leaderboard_rounded, ['lead_'], [
    (type: 'lead_added', label: 'New Lead Added'),
  ]),
  NotificationCategory('performance', 'Performance & KRA',
      Icons.trending_up_rounded, ['appraisal_', 'kra_'], [
    (type: 'appraisal_started', label: 'Appraisal Form Started'),
    (type: 'kra_uploaded', label: 'KRA Document Uploaded'),
    (type: 'kra_decided', label: 'KRA Decision'),
  ]),
  NotificationCategory('announcement', 'Announcements',
      Icons.campaign_rounded, ['announcement_'], [
    (type: 'announcement_posted', label: 'New Announcement'),
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
