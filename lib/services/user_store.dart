import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'supabase_service.dart';

class UserStore {
  static const _key = 'hrms_users';

  static Future<List<AppUser>>? _inFlight;

  // Coalesces concurrent calls into a single request — sibling widgets on
  // the same page (e.g. dashboard blocks) each call load() from their own
  // initState() on the same frame, which used to fire one identical
  // full-table fetch per widget. The in-flight slot clears as soon as that
  // fetch resolves, so a later call still fetches fresh — this only removes
  // duplicate *concurrent* requests, it doesn't add staleness.
  static Future<List<AppUser>> load() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _loadFresh();
    _inFlight = future;
    future.whenComplete(() => _inFlight = null);
    return future;
  }

  static Future<List<AppUser>> _loadFresh() async {
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

  // Applies a reporting-manager reassignment immediately, with no approval
  // step — used when Management (the approver itself) makes the change.
  static Future<void> applyReportingManagerChange(
      AppUser user, String newManagerName) async {
    user.reportingManager = newManagerName;
    user.reportingManagerPending = '';
    user.reportingManagerRequestedAt = '';
    await upsertOne(user);
  }

  // Applies an RM-eligibility flag change immediately, with no approval step
  // — used when Management (the approver itself) makes the change.
  static Future<void> applyRmFlagChange(AppUser user, bool newValue) async {
    user.isReportingManager = newValue;
    user.isReportingManagerPending = false;
    user.isReportingManagerRequestedAt = '';
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

  // Same as [findByEmail], but also matches on companyEmail or employeeId —
  // used by the sign-in/forgot-password flow so employees can use the
  // identifier they actually know.
  static Future<AppUser?> findByLoginOrCompanyEmail(String identifier) async {
    final users = await load();
    final q = identifier.trim().toLowerCase();
    try {
      return users.firstWhere(
        (u) =>
            u.active &&
            (u.email.trim().toLowerCase() == q ||
                (u.companyEmail.trim().isNotEmpty && u.companyEmail.trim().toLowerCase() == q) ||
                u.employeeId.trim().toLowerCase() == q),
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
