import '../models/user_session.dart';
import '../utils/kv_store.dart';

class SessionStorage {
  static const _kRole             = 'fomra_role';
  static const _kName             = 'fomra_name';
  static const _kEmployeeId       = 'fomra_employee_id';
  static const _kEmail            = 'fomra_email';
  static const _kExpiry           = 'fomra_expiry';
  static const _kDesignation      = 'fomra_designation';
  static const _kReportingManager = 'fomra_reporting_manager';

  static const _duration = Duration(hours: 8);

  static Future<void> save() async {
    await kvSetString(_kRole, UserSession.role.name);
    await kvSetString(_kName, UserSession.name);
    await kvSetString(_kEmployeeId, UserSession.employeeId);
    await kvSetString(_kEmail, UserSession.email);
    await kvSetString(_kDesignation, UserSession.designation);
    await kvSetString(_kReportingManager, UserSession.reportingManager);
    await kvSetString(_kExpiry,
        DateTime.now().add(_duration).millisecondsSinceEpoch.toString());
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
      UserSession.reportingManager = await kvGetString(_kReportingManager) ?? '';
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
    await kvRemove(_kReportingManager);
  }
}
