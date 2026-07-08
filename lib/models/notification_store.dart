import 'package:flutter/foundation.dart';
import 'notification_category.dart';
import 'user_session.dart';

class AppNotification {
  final String id;
  final DateTime createdAt;
  final String type;
  final String title;
  final String body;
  final String route;
  final String targetEmail;
  final String targetRole;
  final String targetReportingManager;
  final String sourceId;
  List<String> readBy;

  AppNotification({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.title,
    this.body = '',
    this.route = '',
    this.targetEmail = '',
    this.targetRole = '',
    this.targetReportingManager = '',
    this.sourceId = '',
    List<String>? readBy,
  }) : readBy = readBy ?? [];

  bool isReadBy(String email) =>
      readBy.any((e) => e.trim().toLowerCase() == email.trim().toLowerCase());

  /// True for the first 24h after creation. The default feed/badge only
  /// count recent notifications — older ones stay in the database and
  /// remain visible, just behind the "All time" filter on the Notifications
  /// page, so nothing is ever actually deleted.
  bool get isRecent => DateTime.now().difference(createdAt) < const Duration(days: 1);
}

/// Role label matching the `role` string used everywhere else in the app
/// (AppUser.role: 'Employee' | 'Manager' | 'HR' | 'Management').
String currentRoleLabel() => switch (UserSession.role) {
      UserRole.hr => 'HR',
      UserRole.reportingManager => 'Manager',
      UserRole.management => 'Management',
      UserRole.employee => 'Employee',
    };

class NotificationStore {
  static final List<AppNotification> all = [];
  static final ValueNotifier<int> unreadCount = ValueNotifier(0);

  /// Category ids the signed-in user has muted — persisted in Supabase
  /// (`notification_preferences`) and loaded on login/app start. A muted
  /// category is excluded from both the feed and the unread badge, i.e.
  /// "don't send me this kind" rather than just "hide it right now".
  static Set<String> mutedCategories = {};

  /// True if [n] is addressed to the signed-in user: directly (by email),
  /// by role broadcast, by "everyone" broadcast, or by team (their RM name
  /// matches the notification's target_reporting_manager — same matching
  /// rule as AppUser.reportingManager elsewhere, e.g. add_task_page.dart).
  /// Excludes any category the user has muted.
  static bool isForCurrentUser(AppNotification n) {
    if (mutedCategories.contains(categoryFor(n.type).id)) return false;
    final email = UserSession.email.trim().toLowerCase();
    if (n.targetEmail.isNotEmpty && n.targetEmail.trim().toLowerCase() == email) return true;
    if (n.targetRole == currentRoleLabel() || n.targetRole == 'ALL') return true;
    if (n.targetReportingManager.isNotEmpty &&
        n.targetReportingManager == UserSession.name) return true;
    return false;
  }

  static List<AppNotification> forCurrentUser() {
    final list = all.where(isForCurrentUser).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Only recent (last 24h), unread notifications count toward the badge —
  /// older ones don't keep nagging you once they've aged out of "recent",
  /// even though they're still there if you go looking via the filter.
  static void recomputeUnread() {
    unreadCount.value = forCurrentUser()
        .where((n) => n.isRecent && !n.isReadBy(UserSession.email))
        .length;
  }

  // ── New-arrival detection (drives the top-right popup) ─────────────────

  static Set<String> _knownIds = {};
  static bool _seeded = false;

  /// Call with a freshly-fetched list *before* replacing [all] with it.
  /// The first call after login/app-start just seeds the baseline (so
  /// existing unread history doesn't pop up as if it just arrived); every
  /// call after that returns whichever entries are both brand new and
  /// relevant to the signed-in user, for the popup to show.
  static List<AppNotification> diffNewArrivals(List<AppNotification> freshList) {
    final freshIds = freshList.map((n) => n.id).toSet();
    if (!_seeded) {
      _knownIds = freshIds;
      _seeded = true;
      return [];
    }
    final newIds = freshIds.difference(_knownIds);
    _knownIds = freshIds;
    if (newIds.isEmpty) return [];
    return freshList
        .where((n) => newIds.contains(n.id) && isForCurrentUser(n) && !n.isReadBy(UserSession.email))
        .toList();
  }

  static void reset() {
    all.clear();
    mutedCategories = {};
    unreadCount.value = 0;
    _knownIds = {};
    _seeded = false;
  }
}
