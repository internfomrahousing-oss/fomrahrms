import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'user_store.dart';

/// Result of a login-time device-binding check — see [DeviceBindingService.checkLogin].
enum DeviceBindingResult { allowed, blockedOtherDevice }

/// Device Binding: restricts mobile app login (and, as a consequence, mobile
/// check-in/check-out) to one registered phone per employee. Web is never
/// gated — this only secures the native Android/iOS app, per spec.
///
/// There's no server-issued device token, so "this phone" is a random id
/// generated once and persisted locally (SharedPreferences); reinstalling
/// the app produces a new id, same as most consumer device-binding schemes.
class DeviceBindingService {
  static const _idKey = 'device_binding_local_id';

  static bool get isNativeMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<String> _localDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      final rnd = Random.secure();
      id = List<int>.generate(16, (_) => rnd.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await prefs.setString(_idKey, id);
    }
    return id;
  }

  /// Best-effort (deviceName, platformLabel) for the current phone.
  static Future<(String, String)> _deviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        final name = [info.manufacturer, info.model]
            .where((s) => s.trim().isNotEmpty)
            .join(' ')
            .trim();
        return (name.isEmpty ? 'Android device' : name, 'Android');
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await plugin.iosInfo;
        final machine = info.utsname.machine.trim();
        final name = info.name.trim();
        return (name.isNotEmpty ? name : (machine.isNotEmpty ? machine : 'iPhone'), 'iPhone');
      }
    } catch (_) {}
    return ('', '');
  }

  /// Runs at login, for [isNativeMobile] only (callers should skip this
  /// entirely on web). Auto-registers this phone if [user] has no device
  /// bound yet (first login, or after an HR reset); otherwise compares
  /// against the bound device and blocks on a mismatch. Persists via
  /// [UserStore.upsertOne] so it survives across sessions.
  static Future<DeviceBindingResult> checkLogin(AppUser user) async {
    final deviceId = await _localDeviceId();
    final now = DateTime.now().toIso8601String();

    if (user.deviceId.isEmpty) {
      final (name, platform) = await _deviceInfo();
      user.deviceId = deviceId;
      user.deviceName = name;
      user.devicePlatform = platform;
      user.deviceRegisteredAt = now;
      user.deviceLastLogin = now;
      await UserStore.upsertOne(user);
      return DeviceBindingResult.allowed;
    }

    if (user.deviceId != deviceId) {
      return DeviceBindingResult.blockedOtherDevice;
    }

    user.deviceLastLogin = now;
    await UserStore.upsertOne(user);
    return DeviceBindingResult.allowed;
  }

  static const blockedMessage =
      'This account is already linked to another device.\n\n'
      'Please contact HR to reset your registered device.';

  /// Clears [user]'s device binding (HR "Reset Device" action) — the
  /// employee will auto-register a new phone on their next mobile login.
  /// Pure mutation only; callers persist via whatever save path they
  /// already use (e.g. HrEmployeeRecordsPage's onSave, which also syncs
  /// its in-memory list — not just UserStore.upsertOne directly).
  static void resetDevice(AppUser user) {
    user.deviceId = '';
    user.deviceName = '';
    user.devicePlatform = '';
    user.deviceRegisteredAt = '';
    user.deviceLastLogin = '';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "08 Jul 2026"; '—' if [iso] is empty/unparsable.
  static String formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
  }

  /// "Today 09:14 AM" (today) or "08 Jul 2026 09:14 AM"; '—' if empty/unparsable.
  static String formatDateTime(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final time = '${hour12.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
    return isToday ? 'Today $time' : '${formatDate(iso)} $time';
  }
}
