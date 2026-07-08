import 'package:flutter/material.dart';

/// Groups the fine-grained `AppNotification.type` strings (e.g. 'leave_decided',
/// 'onroll_stage_decided') into user-facing buckets — used both for the
/// "view only this kind" filter and the "mute this kind" preference toggle
/// on the Notifications page.
class NotificationCategory {
  final String id;
  final String label;
  final IconData icon;
  final List<String> typePrefixes;
  const NotificationCategory(this.id, this.label, this.icon, this.typePrefixes);
}

const List<NotificationCategory> notificationCategories = [
  NotificationCategory('leave', 'Leave & Attendance',
      Icons.event_available_rounded, ['leave_', 'attendance_']),
  NotificationCategory('onroll', 'On-roll Confirmation',
      Icons.how_to_reg_rounded, ['onroll_']),
  NotificationCategory('task', 'Tasks',
      Icons.task_alt_rounded, ['task_']),
  NotificationCategory('maintenance', 'Maintenance',
      Icons.build_rounded, ['maintenance_']),
  NotificationCategory('candidate', 'Recruitment',
      Icons.record_voice_over_rounded, ['candidate_']),
  NotificationCategory('onboarding', 'Onboarding',
      Icons.assignment_ind_rounded, ['onboarding_']),
  NotificationCategory('form_edit', 'Form Edits',
      Icons.edit_note_rounded, ['form_edit_']),
  NotificationCategory('payslip', 'Payroll',
      Icons.account_balance_wallet_rounded, ['payslip_']),
  NotificationCategory('el', 'Earned Leave',
      Icons.savings_rounded, ['el_']),
  NotificationCategory('milestone', 'Milestones',
      Icons.emoji_events_rounded, ['tenure_']),
  NotificationCategory('lead', 'Leads',
      Icons.leaderboard_rounded, ['lead_']),
  NotificationCategory('announcement', 'Announcements',
      Icons.campaign_rounded, ['announcement_']),
];

const _other = NotificationCategory('other', 'Other', Icons.notifications_rounded, []);

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
    'Employee': {'candidate', 'onboarding', 'form_edit', 'lead'},
    'Manager': {'onboarding', 'form_edit', 'lead'},
    'Management': <String>{},
    'HR': <String>{},
  };
  final excluded = excludedByRole[roleLabel] ?? const <String>{};
  return notificationCategories.where((c) => !excluded.contains(c.id)).toList();
}
