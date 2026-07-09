import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'supabase_service.dart';

class UserStore {
  static const _key = 'hrms_users';

  static Future<List<AppUser>> load() async {
    final remote = await SupabaseService.fetchAppUsers();
    if (remote.isNotEmpty) return remote;

    // Supabase empty — load local cache and migrate it to Supabase
    final local = await _loadLocal();
    if (local.isNotEmpty) {
      for (final u in local) {
        await SupabaseService.upsertAppUser(u);
      }
    }
    return local;
  }

  static Future<void> upsertOne(AppUser u) async {
    // Save locally first so data is never lost if Supabase is unavailable
    final users = await _loadLocal();
    final idx = users.indexWhere((x) => x.email == u.email);
    if (idx >= 0) {
      users[idx] = u;
    } else {
      users.add(u);
    }
    await _saveLocal(users);
    await SupabaseService.upsertAppUser(u);
  }

  // Requests a reporting-manager reassignment for [user], awaiting Management
  // approval on the Approvals page — mirrors the grossPay/workLocation
  // pending-change pattern. Callers should only use this for an *existing*
  // non-empty reportingManager; a first-time assignment can be set directly.
  static Future<void> requestReportingManagerChange(
      AppUser user, String newManagerName) async {
    user.reportingManagerPending = newManagerName;
    user.reportingManagerRequestedAt = DateTime.now().toIso8601String();
    await upsertOne(user);
  }

  // Requests a change to [user]'s RM-eligibility flag, awaiting Management
  // approval — always required, regardless of current value.
  static Future<void> requestRmFlagChange(AppUser user, bool newValue) async {
    user.isReportingManagerPending = newValue;
    user.isReportingManagerRequestedAt = DateTime.now().toIso8601String();
    await upsertOne(user);
  }

  static Future<void> deleteOne(String email) async {
    await SupabaseService.deleteAppUser(email);
    final users = await _loadLocal();
    users.removeWhere((u) => u.email == email);
    await _saveLocal(users);
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

  static Future<List<AppUser>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _saveLocal(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(users.map((u) => u.toJson()).toList()));
  }
}
