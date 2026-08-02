import '../models/app_user.dart';
import '../models/leave_store.dart';
import 'weekly_off.dart';

/// Why an employee has no attendance record on a given date.
///
/// "No record" is not the same as "absent". Before this existed, the HR
/// attendance screen synthesised an Absent row for every active employee with
/// no record for the day — with no check for the weekly off, public holidays,
/// approved leave, or the attendance exemption. Sundays therefore showed five
/// people as absent, and the CEO appeared absent every day despite being
/// excluded from attendance entirely.
enum NonWorkingReason {
  /// A genuine unexplained absence.
  absent,
  weeklyOff,
  holiday,
  onLeave,
  /// Excluded from attendance altogether (the CEO).
  notTracked,
}

extension NonWorkingReasonLabel on NonWorkingReason {
  String get label => switch (this) {
        NonWorkingReason.absent => 'Absent',
        NonWorkingReason.weeklyOff => 'Weekly Off',
        NonWorkingReason.holiday => 'Holiday',
        NonWorkingReason.onLeave => 'On Leave',
        NonWorkingReason.notTracked => 'Not Tracked',
      };

  /// Only a true absence counts against anyone.
  bool get countsAsAbsent => this == NonWorkingReason.absent;
}

/// Classifies a date for an employee who has no attendance record on it.
///
/// [holidayDates] holds 'yyyy-MM-dd' strings; pass an empty set if the holiday
/// list has not loaded — the weekly-off and leave checks still apply, so the
/// result degrades to "slightly over-counts holidays" rather than being wrong
/// about everything.
NonWorkingReason classifyMissingAttendance({
  required AppUser employee,
  required DateTime date,
  required Set<String> holidayDates,
  required List<LeaveApplication> leaveApps,
}) {
  if (employee.exemptFromAttendance) return NonWorkingReason.notTracked;

  if (date.weekday == weeklyOffWeekdayFor(employee.effectiveWeeklyOffDay)) {
    return NonWorkingReason.weeklyOff;
  }

  final iso = '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  if (holidayDates.contains(iso)) return NonWorkingReason.holiday;

  final onLeave = leaveApps.any((a) =>
      a.employeeName.trim().toLowerCase() == employee.name.trim().toLowerCase() &&
      a.leaveType != 'Permission' &&
      a.managerStatus == LeaveApprovalStatus.approved &&
      !date.isBefore(DateTime(a.from.year, a.from.month, a.from.day)) &&
      !date.isAfter(DateTime(a.to.year, a.to.month, a.to.day)));
  if (onLeave) return NonWorkingReason.onLeave;

  return NonWorkingReason.absent;
}
