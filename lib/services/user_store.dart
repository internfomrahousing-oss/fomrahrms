import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

class UserStore {
  static const _key = 'hrms_users';

  static Future<List<AppUser>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> save(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(users.map((u) => u.toJson()).toList()));
  }

  static Future<AppUser?> findByEmail(String email) async {
    final users = await load();
    try {
      return users.firstWhere(
        (u) => u.email.trim().toLowerCase() == email.trim().toLowerCase() && u.active,
      );
    } catch (_) {
      return null;
    }
  }
}
