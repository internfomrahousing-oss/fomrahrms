/// The company attendance cycle runs from the **26th of one month to the 25th
/// of the next**, not from the 1st to the end of the calendar month.
///
/// A cycle is labelled by the month it ENDS in, so 26 Jul – 25 Aug is the
/// "August" cycle. That matches how the period is referred to and how it is
/// paid.
///
/// Everything that resets or accumulates "per month" — the permission
/// allowance, the Staff Portal holiday allowance, leave-taken-this-period
/// counters, attendance summaries — must use this, not `DateTime.month`.
/// Comparing calendar months puts 26 July and 3 August in different windows
/// when they are in the same cycle, which let an employee spend a full
/// allowance twice in eleven days.
///
/// Mirrors the SQL functions attendance_cycle_start / _end / _label, so the
/// client and the database agree on the boundary.
library;

/// First day of the cycle containing [d] — the 26th of [d]'s month if [d] is
/// on or after the 26th, otherwise the 26th of the previous month.
DateTime attendanceCycleStart(DateTime d) {
  if (d.day >= 26) return DateTime(d.year, d.month, 26);
  return DateTime(d.year, d.month - 1, 26); // DateTime normalises month 0 -> Dec of previous year
}

/// Last day of the cycle containing [d] — the 25th of the following month.
DateTime attendanceCycleEnd(DateTime d) {
  final s = attendanceCycleStart(d);
  return DateTime(s.year, s.month + 1, 25);
}

/// True when both dates fall in the same attendance cycle.
bool sameAttendanceCycle(DateTime a, DateTime b) {
  final sa = attendanceCycleStart(a);
  final sb = attendanceCycleStart(b);
  return sa.year == sb.year && sa.month == sb.month;
}

/// True when [d] is in the cycle we are currently in.
bool isInCurrentCycle(DateTime d, {DateTime? now}) =>
    sameAttendanceCycle(d, now ?? DateTime.now());

/// 'YYYY-MM' of the month the cycle ends in — the cycle's label.
String attendanceCycleLabel(DateTime d) {
  final e = attendanceCycleEnd(d);
  return '${e.year.toString().padLeft(4, '0')}-${e.month.toString().padLeft(2, '0')}';
}

/// Human-readable range, e.g. '26 Jul – 25 Aug'.
String attendanceCycleRange(DateTime d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final s = attendanceCycleStart(d);
  final e = attendanceCycleEnd(d);
  return '${s.day} ${m[s.month - 1]} – ${e.day} ${m[e.month - 1]}';
}
