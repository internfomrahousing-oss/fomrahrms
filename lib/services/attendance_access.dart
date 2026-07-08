import '../models/emergency_attendance_notifier.dart';
import '../models/user_session.dart';
import 'user_store.dart';

/// Whether the current logged-in user should see app-based Check In / Check
/// Out. Office employees are tracked via the biometric device instead —
/// unless HR has granted emergency app access for that employee, or has
/// switched on the company-wide emergency override for everyone.
class AttendanceAccess {
  static Future<bool> canCheckInOut() async {
    if (emergencyAttendanceNotifier.value) return true;
    try {
      final users = await UserStore.load();
      for (final u in users) {
        if (u.name == UserSession.name) return u.usesAppAttendance;
      }
    } catch (_) {}
    return true; // no record found / lookup failed — don't lock anyone out
  }
}
