import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static const _kKey = 'fomra_theme';

  ThemeNotifier() : super(_load());

  static ThemeMode _load() {
    try {
      if (html.window.localStorage[_kKey] == 'dark') return ThemeMode.dark;
    } catch (_) {}
    return ThemeMode.light;
  }

  void setMode(ThemeMode mode) {
    value = mode;
    try {
      html.window.localStorage[_kKey] = mode == ThemeMode.dark ? 'dark' : 'light';
    } catch (_) {}
  }
}

final themeNotifier = ThemeNotifier();
