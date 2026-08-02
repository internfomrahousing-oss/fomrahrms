import '../models/app_user.dart';
import 'tenure.dart';

/// Earned-leave accrual.
///
/// This logic previously existed as four separate, byte-identical copies in
/// my_leave_balance_page, employee_leave_page, my_payslips_page and
/// payroll_management_page. Two of those feed payroll and two feed the
/// employee's own balance display, so the day one copy was updated and the
/// others were not, an employee's leave balance and their payslip would have
/// disagreed with each other, silently.
///
/// One definition, one place to change it, one place to test it.
int elAccruedFor(AppUser? user, {DateTime? asOf}) {
  if (user == null) return 0;

  // Accrual restarts from the last time EL was availed; before any has been
  // taken it runs from the eligibility date HR set.
  final refStr =
      user.elLastAvailedAt.isNotEmpty ? user.elLastAvailedAt : user.elEligibleAt;
  if (refStr.isEmpty) return 0;

  // parseFlexibleDate rather than DateTime.tryParse: these columns hold ISO
  // for some employees and dd/MM/yyyy for others, and tryParse returns null on
  // the latter, which would silently zero someone's accrual.
  final ref = parseFlexibleDate(refStr);
  if (ref == null) return 0;

  final now = asOf ?? DateTime.now();
  if (now.isBefore(ref)) return 0;

  final months = _wholeMonthsBetween(ref, now);
  return (months * user.monthlyEl).clamp(0, 9999);
}

/// Whole calendar months elapsed, counting a month only once the day-of-month
/// has actually come round.
///
/// The previous arithmetic was a bare
///
///     (now.year - ref.year) * 12 + (now.month - ref.month)
///
/// which counts a month the instant the month NUMBER changes, regardless of
/// the day. Someone made eligible on 31 January had accrued a full month by
/// 1 February — one day later — while someone made eligible on 1 January had
/// accrued nothing by 31 January, thirty days later. Up to a month of leave
/// turned on which date HR happened to click.
int _wholeMonthsBetween(DateTime ref, DateTime now) {
  var months = (now.year - ref.year) * 12 + (now.month - ref.month);

  // The final month has not completed until the anniversary day is reached.
  // Clamp the reference day to the length of the current month so that a
  // reference of the 31st still completes in a 30-day month, on its last day,
  // rather than being pushed into the following month.
  final lastDayOfNowMonth = DateTime(now.year, now.month + 1, 0).day;
  final effectiveRefDay = ref.day > lastDayOfNowMonth ? lastDayOfNowMonth : ref.day;
  if (now.day < effectiveRefDay) months -= 1;

  return months < 0 ? 0 : months;
}
