import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static const _kPrefix = 'fomra_theme';
  static String _userId  = '';

  ThemeNotifier() : super(ThemeMode.light);

  static String get _key =>
      _userId.isNotEmpty ? '${_kPrefix}_$_userId' : _kPrefix;

  /// Call after login with the employee's ID.
  void loadForUser(String userId) {
    _userId = userId;
    try {
      final saved = html.window.localStorage[_key];
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
    try {
      html.window.localStorage[_key] = mode == ThemeMode.dark ? 'dark' : 'light';
    } catch (_) {}
  }
}

final themeNotifier = ThemeNotifier();
