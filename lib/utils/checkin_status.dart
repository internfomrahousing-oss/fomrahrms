import '../models/leave_store.dart';

/// Shared late-check-in threshold: 09:30 AM.
const int lateCutoffMinutes = 9 * 60 + 30;

enum CheckInStatus { none, onTime, permission, late }

class CheckInRowStatus {
  final CheckInStatus status;
  final int permMinutes;
  const CheckInRowStatus(this.status, this.permMinutes);
}

/// Minutes granted by an approved 'Permission' leave application for
/// [employeeName] covering [date]; 0 if none.
int approvedPermissionMinutesFor(
    List<LeaveApplication> leaveApps, String employeeName, DateTime date) {
  for (final a in leaveApps) {
    if (a.leaveType != 'Permission') continue;
    if (a.employeeName != employeeName) continue;
    if (a.managerStatus != LeaveApprovalStatus.approved) continue;
    if (a.from.year == date.year && a.from.month == date.month && a.from.day == date.day) {
      return LeaveStore.permMinutesFromReason(a.reason);
    }
  }
  return 0;
}

/// Determines whether [checkInTime] (a "HH:mm" string) on [date] for
/// [employeeName] is on time, late-but-covered-by-approved-permission, or
/// genuinely late, checking [leaveApps] for a same-day approved Permission.
CheckInRowStatus checkInStatusFor(String checkInTime, DateTime date, String employeeName,
    List<LeaveApplication> leaveApps) {
  if (checkInTime.isEmpty) return const CheckInRowStatus(CheckInStatus.none, 0);
  final parts = checkInTime.split(':');
  if (parts.length != 2) return const CheckInRowStatus(CheckInStatus.none, 0);
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return const CheckInRowStatus(CheckInStatus.none, 0);

  final minutes = h * 60 + m;
  if (minutes <= lateCutoffMinutes) return const CheckInRowStatus(CheckInStatus.onTime, 0);

  final permMinutes = approvedPermissionMinutesFor(leaveApps, employeeName, date);
  if (permMinutes > 0 && minutes <= lateCutoffMinutes + permMinutes) {
    return CheckInRowStatus(CheckInStatus.permission, permMinutes);
  }
  return const CheckInRowStatus(CheckInStatus.late, 0);
}

/// Parses a "dd/MM/yyyy" date string (the format used by [AttendanceRecord.date]).
DateTime? parseSlashDate(String s) {
  final p = s.split('/');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]), mo = int.tryParse(p[1]), y = int.tryParse(p[2]);
  if (d == null || mo == null || y == null) return null;
  return DateTime(y, mo, d);
}

String permLabel(int minutes) {
  switch (minutes) {
    case 30: return '30m';
    case 60: return '1h';
    case 90: return '1.5h';
    case 120: return '2h';
    default: return '${minutes}m';
  }
}
