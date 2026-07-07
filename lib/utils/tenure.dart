/// Parses a date string that may be ISO ("YYYY-MM-DD...") or "DD/MM/YYYY" —
/// both formats are used for `AppUser.dateOfJoining` across the app.
DateTime? parseFlexibleDate(String value) {
  if (value.isEmpty) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;
  final parts = value.split('/');
  if (parts.length == 3) {
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d != null && m != null && y != null) {
      try {
        return DateTime(y, m, d);
      } catch (_) {}
    }
  }
  return null;
}

/// "X Years, Y Months, Z Days" tenure label from a date-of-joining string
/// through [asOf] (defaults to now). Returns '—' if the date can't be parsed
/// or is in the future.
String tenureLabel(String dateOfJoining, {DateTime? asOf}) {
  final start = parseFlexibleDate(dateOfJoining);
  if (start == null) return '—';
  final now = asOf ?? DateTime.now();
  if (start.isAfter(now)) return '—';

  var years = now.year - start.year;
  var months = now.month - start.month;
  var days = now.day - start.day;

  if (days < 0) {
    months -= 1;
    final prevMonthLastDay = DateTime(now.year, now.month, 0).day;
    days += prevMonthLastDay;
  }
  if (months < 0) {
    years -= 1;
    months += 12;
  }

  final parts = <String>[];
  if (years > 0) parts.add('$years ${years == 1 ? 'Year' : 'Years'}');
  if (months > 0) parts.add('$months ${months == 1 ? 'Month' : 'Months'}');
  if (days > 0 || parts.isEmpty) parts.add('$days ${days == 1 ? 'Day' : 'Days'}');
  return parts.join(', ');
}
