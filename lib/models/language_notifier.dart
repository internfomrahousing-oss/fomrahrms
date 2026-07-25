import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages offered in the Staff Portal (Housekeeping/Support Staff).
enum AppLanguage { en, hi, ta }

/// Per-user persisted language preference for the Staff Portal — loads by
/// employeeId on login/restore and resets on logout, so a chosen language
/// survives across logins without asking again.
class LanguageNotifier extends ValueNotifier<AppLanguage> {
  static const _kPrefix = 'fomra_staff_language';
  static String _userId = '';

  LanguageNotifier() : super(AppLanguage.en);

  static String get _key =>
      _userId.isNotEmpty ? '${_kPrefix}_$_userId' : _kPrefix;

  /// Call after login (and on cold-start session restore) with the
  /// employee's ID.
  Future<void> loadForUser(String userId) async {
    _userId = userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      value = AppLanguage.values.firstWhere(
        (l) => l.name == saved,
        orElse: () => AppLanguage.en,
      );
    } catch (_) {
      value = AppLanguage.en;
    }
  }

  /// Call on logout — resets to English until the next user's preference loads.
  void reset() {
    _userId = '';
    value = AppLanguage.en;
  }

  void setLanguage(AppLanguage lang) {
    value = lang;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_key, lang.name);
    }).catchError((_) {});
  }
}

final staffLanguageNotifier = LanguageNotifier();
