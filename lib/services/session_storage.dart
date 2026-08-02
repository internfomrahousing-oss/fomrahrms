import '../models/user_session.dart';
import '../utils/kv_store.dart';

class SessionStorage {
  static const _kRole             = 'fomra_role';
  static const _kName             = 'fomra_name';
  static const _kEmployeeId       = 'fomra_employee_id';
  static const _kEmail            = 'fomra_email';
  static const _kExpiry           = 'fomra_expiry';
  static const _kDesignation      = 'fomra_designation';
  static const _kDepartment       = 'fomra_department';
  static const _kReportingManager = 'fomra_reporting_manager';
  static const _kIsReportingManager = 'fomra_is_reporting_manager';
  static const _kWorkLocation     = 'fomra_work_location';
  static const _kPermissionQuota  = 'fomra_permission_minutes_quota';
  static const _kIsOnroll         = 'fomra_is_onroll';
  static const _kExemptAttendance = 'fomra_exempt_attendance';

  static const _duration = Duration(hours: 10);
  // Housekeeping/Support Staff stay logged in far longer — they share
  // devices and re-entering credentials each shift is impractical.
  static const _staffPortalDuration = Duration(days: 180);

  static Future<void> save() async {
    await kvSetString(_kRole, UserSession.role.name);
    await kvSetString(_kName, UserSession.name);
    await kvSetString(_kEmployeeId, UserSession.employeeId);
    await kvSetString(_kEmail, UserSession.email);
    await kvSetString(_kDesignation, UserSession.designation);
    await kvSetString(_kDepartment, UserSession.department);
    await kvSetString(_kReportingManager, UserSession.reportingManager);
    await kvSetString(_kIsReportingManager, UserSession.isReportingManager ? '1' : '0');
    await kvSetString(_kWorkLocation, UserSession.workLocation);
    await kvSetString(_kPermissionQuota, UserSession.permissionMinutesQuota.toString());
    await kvSetString(_kIsOnroll, UserSession.isOnroll ? '1' : '0');
    await kvSetString(_kExemptAttendance, UserSession.exemptFromAttendance ? '1' : '0');
    final duration =
        UserSession.isStaffPortal ? _staffPortalDuration : _duration;
    await kvSetString(_kExpiry,
        DateTime.now().add(duration).millisecondsSinceEpoch.toString());
  }

  static Future<bool> restore() async {
    try {
      final expiryStr = await kvGetString(_kExpiry);
      if (expiryStr == null) return false;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      if (DateTime.now().isAfter(expiry)) {
        await clear();
        return false;
      }
      final roleName = await kvGetString(_kRole);
      if (roleName == null) return false;
      final role = UserRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => UserRole.employee,
      );
      UserSession.loggedIn         = true;
      UserSession.role             = role;
      UserSession.name             = await kvGetString(_kName) ?? '';
      UserSession.employeeId       = await kvGetString(_kEmployeeId) ?? '';
      UserSession.email            = await kvGetString(_kEmail) ?? '';
      UserSession.designation      = await kvGetString(_kDesignation) ?? '';
      UserSession.department       = await kvGetString(_kDepartment) ?? '';
      UserSession.reportingManager = await kvGetString(_kReportingManager) ?? '';
      UserSession.isReportingManager = (await kvGetString(_kIsReportingManager)) == '1';
      UserSession.workLocation     = await kvGetString(_kWorkLocation) ?? '';
      UserSession.permissionMinutesQuota =
          int.tryParse(await kvGetString(_kPermissionQuota) ?? '') ?? 120;
      UserSession.isOnroll = (await kvGetString(_kIsOnroll)) == '1';
      UserSession.exemptFromAttendance = (await kvGetString(_kExemptAttendance)) == '1';
      // Photo URL is fetched from main() once Supabase has finished
      // initializing (fetching it here would race Supabase.initialize()
      // and silently fail every time).
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear() async {
    await kvRemove(_kRole);
    await kvRemove(_kName);
    await kvRemove(_kEmployeeId);
    await kvRemove(_kEmail);
    await kvRemove(_kExpiry);
    await kvRemove(_kDesignation);
    await kvRemove(_kDepartment);
    await kvRemove(_kReportingManager);
    await kvRemove(_kIsReportingManager);
    await kvRemove(_kWorkLocation);
    await kvRemove(_kPermissionQuota);
    await kvRemove(_kIsOnroll);
    await kvRemove(_kExemptAttendance);
  }
}
