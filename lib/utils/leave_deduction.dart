import '../models/app_user.dart';
import '../models/leave_store.dart';
import 'weekly_off.dart';

/// What a leave request will actually cost the employee.
class LeaveDeduction {
  /// Days that come off the balance, including any sandwiched weekly off.
  final double totalDays;

  /// Weekly-off days pulled in because leave falls on both sides of them.
  final int sandwichDays;

  /// Public holidays inside the range, which are NOT charged.
  final int holidaysExcluded;

  /// Days beyond the 2-day CL adjustment, treated as loss of pay.
  final int lopDays;

  const LeaveDeduction({
    required this.totalDays,
    required this.sandwichDays,
    required this.holidaysExcluded,
    required this.lopDays,
  });

  bool get hasSurprise => sandwichDays > 0 || holidaysExcluded > 0 || lopDays > 0;
}

/// Mirrors apply_sandwich_policy() in the database, so the employee sees the
/// real figure BEFORE submitting.
///
/// Without this the form showed plain calendar days: someone taking Saturday
/// and Monday saw "2 days" while the database deducted 3, having pulled in the
/// Sunday between them. The deduction was correct and completely unexplained.
///
/// This is a preview, not the authority — the database recomputes on write and
/// its answer governs. Kept deliberately in step with it; if the two ever
/// disagree, the server is right and this is the bug.
LeaveDeduction previewLeaveDeduction({
  required DateTime from,
  required DateTime to,
  required bool isHalfDay,
  required AppUser? employee,
  required Set<String> holidayIsoDates,
  required List<LeaveApplication> existingLeaves,
  String? excludeId,
}) {
  // A half day is 0.5 and only meaningful on a single date.
  if (isHalfDay && _sameDay(from, to)) {
    return const LeaveDeduction(
        totalDays: 0.5, sandwichDays: 0, holidaysExcluded: 0, lopDays: 0);
  }

  final offWeekday = weeklyOffWeekdayFor(employee?.effectiveWeeklyOffDay ?? 'Sunday');

  bool isHoliday(DateTime d) => holidayIsoDates.contains(_iso(d));
  bool isWeeklyOff(DateTime d) => d.weekday == offWeekday;
  bool isNonWorking(DateTime d) => isHoliday(d) || isWeeklyOff(d);

  bool hasLeaveOn(DateTime d) => existingLeaves.any((a) =>
      a.id != excludeId &&
      a.leaveType != 'Permission' &&
      a.managerStatus != LeaveApprovalStatus.denied &&
      !d.isBefore(DateTime(a.from.year, a.from.month, a.from.day)) &&
      !d.isAfter(DateTime(a.to.year, a.to.month, a.to.day)));

  var outside = 0;   // non-working days pulled in from OUTSIDE the range
  var inside = 0;    // weekly offs already within the range
  var holidays = 0;  // public holidays within the range — not charged

  // Immediately before the range, with leave on its far side.
  final before = from.subtract(const Duration(days: 1));
  if (isNonWorking(before) && hasLeaveOn(before.subtract(const Duration(days: 1)))) {
    outside++;
  }
  // Immediately after.
  final after = to.add(const Duration(days: 1));
  if (isNonWorking(after) && hasLeaveOn(after.add(const Duration(days: 1)))) {
    outside++;
  }

  for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
    if (isHoliday(d)) {
      holidays++;
    } else if (isWeeklyOff(d)) {
      inside++;
    }
  }

  // Days inside the range are already counted in its length; only days pulled
  // in from outside extend it.
  final span = to.difference(from).inDays + 1;
  var total = (span + outside - holidays).toDouble();
  if (total < 0) total = 0;

  return LeaveDeduction(
    totalDays: total,
    sandwichDays: outside + inside,
    holidaysExcluded: holidays,
    // CL adjusts at most 2 days; the rest is loss of pay.
    lopDays: total > 2 ? (total.ceil() - 2) : 0,
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
