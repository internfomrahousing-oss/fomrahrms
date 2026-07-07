/// Minutes worked between a check-in and check-out time string ("HH:MM"),
/// or null if either time is missing/invalid/non-positive.
int? attendanceMinutesBetween(String checkInTime, String checkOutTime) {
  try {
    final inP = checkInTime.split(':');
    final outP = checkOutTime.split(':');
    if (inP.length == 2 && outP.length == 2) {
      final diff = (int.parse(outP[0]) * 60 + int.parse(outP[1])) -
                   (int.parse(inP[0]) * 60 + int.parse(inP[1]));
      if (diff > 0) return diff;
    }
  } catch (_) {}
  return null;
}

/// Formats a minute count as "0h 00m".
String formatHoursMinutes(int totalMinutes) {
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
