import 'dart:html' as html;
import '../models/user_session.dart';
import '../services/supabase_service.dart';

class SessionStorage {
  static const _kRole             = 'fomra_role';
  static const _kName             = 'fomra_name';
  static const _kEmployeeId       = 'fomra_employee_id';
  static const _kEmail            = 'fomra_email';
  static const _kExpiry           = 'fomra_expiry';
  static const _kDesignation      = 'fomra_designation';
  static const _kReportingManager = 'fomra_reporting_manager';

  static const _duration = Duration(hours: 8);

  static void save() {
    final storage = html.window.localStorage;
    storage[_kRole]             = UserSession.role.name;
    storage[_kName]             = UserSession.name;
    storage[_kEmployeeId]       = UserSession.employeeId;
    storage[_kEmail]            = UserSession.email;
    storage[_kDesignation]      = UserSession.designation;
    storage[_kReportingManager] = UserSession.reportingManager;
    storage[_kExpiry]           =
        DateTime.now().add(_duration).millisecondsSinceEpoch.toString();
  }

  static bool restore() {
    try {
      final storage   = html.window.localStorage;
      final expiryStr = storage[_kExpiry];
      if (expiryStr == null) return false;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      if (DateTime.now().isAfter(expiry)) {
        clear();
        return false;
      }
      final roleName = storage[_kRole];
      if (roleName == null) return false;
      final role = UserRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => UserRole.employee,
      );
      UserSession.loggedIn         = true;
      UserSession.role             = role;
      UserSession.name             = storage[_kName] ?? '';
      UserSession.employeeId       = storage[_kEmployeeId] ?? '';
      UserSession.email            = storage[_kEmail] ?? '';
      UserSession.designation      = storage[_kDesignation] ?? '';
      UserSession.reportingManager = storage[_kReportingManager] ?? '';
      // Fetch photo URL in background after restore
      final empId = UserSession.employeeId;
      if (empId.isNotEmpty) {
        SupabaseService.fetchCurrentUserPhotoUrl(empId).then((url) {
          if (url != null) UserSession.photoUrl = url;
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static void clear() {
    final storage = html.window.localStorage;
    storage.remove(_kRole);
    storage.remove(_kName);
    storage.remove(_kEmployeeId);
    storage.remove(_kEmail);
    storage.remove(_kExpiry);
    storage.remove(_kDesignation);
    storage.remove(_kReportingManager);
  }
}
