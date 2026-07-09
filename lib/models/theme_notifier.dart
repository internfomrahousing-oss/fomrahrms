import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static const _kPrefix = 'fomra_theme';
  static String _userId  = '';

  ThemeNotifier() : super(ThemeMode.light);

  static String get _key =>
      _userId.isNotEmpty ? '${_kPrefix}_$_userId' : _kPrefix;

  /// Call after login with the employee's ID.
  Future<void> loadForUser(String userId) async {
    _userId = userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      value = ThemeMode.light;
    }
  }

  /// Call on logout — resets to light until next user's prefs are loaded.
  void reset() {
    _userId = '';
    value   = ThemeMode.light;
  }

  void setMode(ThemeMode mode) {
    value = mode;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
    }).catchError((_) {});
  }
}

final themeNotifier = ThemeNotifier();
