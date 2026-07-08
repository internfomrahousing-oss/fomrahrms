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

  /// Notifications addressed to the signed-in user: directly (by email),
  /// by role broadcast, by "everyone" broadcast, or by team (their RM name
  /// matches the notification's target_reporting_manager — same matching
  /// rule as AppUser.reportingManager elsewhere, e.g. add_task_page.dart).
  /// Excludes any category the user has muted.
  static List<AppNotification> forCurrentUser() {
    final email = UserSession.email.trim().toLowerCase();
    final role = currentRoleLabel();
    final name = UserSession.name;
    final list = all.where((n) {
      if (mutedCategories.contains(categoryFor(n.type).id)) return false;
      if (n.targetEmail.isNotEmpty &&
          n.targetEmail.trim().toLowerCase() == email) return true;
      if (n.targetRole == role || n.targetRole == 'ALL') return true;
      if (n.targetReportingManager.isNotEmpty &&
          n.targetReportingManager == name) return true;
      return false;
    }).toList();
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

  static void reset() {
    all.clear();
    mutedCategories = {};
    unreadCount.value = 0;
  }
}
