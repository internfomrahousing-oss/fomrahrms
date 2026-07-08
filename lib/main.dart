import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'models/color_theme_notifier.dart';
import 'models/emergency_attendance_notifier.dart';
import 'models/notification_store.dart';
import 'models/theme_notifier.dart';
import 'models/user_session.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'services/session_storage.dart';

void main() async {
  setUrlStrategy(HashUrlStrategy());
  WidgetsFlutterBinding.ensureInitialized();

  // Restore persisted login before the router guard runs.
  final restored = SessionStorage.restore();
  // Load theme preference for the restored user so dark/light persists after refresh.
  if (restored) themeNotifier.loadForUser(UserSession.employeeId);

  // Start the app immediately so the splash screen clears.
  runApp(const FomraHrmsApp());

  // Initialize Supabase in the background after the first frame.
  try {
    await Supabase.initialize(
      url: 'https://jjkijnmrtkkukdboajxu.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impqa2lqbm1ydGtrdWtkYm9hanh1'
          'Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMTE0NDMsImV4cCI6MjA5NzY4'
          'NzQ0M30.6I2swrTQDDT0phQvRqDkLFFo_BxtmxD3NE9R8lDbDeI',
    );
    SupabaseService.loadAll();
    SupabaseService.restoreCheckInState();
    colorThemeNotifier.loadInitial();
    emergencyAttendanceNotifier.loadInitial();
    if (restored && UserSession.employeeId.isNotEmpty) {
      SupabaseService.fetchCurrentUserPhotoUrl(UserSession.employeeId).then((url) {
        if (url != null) UserSession.photoUrl = url;
      });
    }
    if (restored &&
        (UserSession.role == UserRole.hr || UserSession.role == UserRole.management)) {
      NotificationService.checkDailyReminders();
    }
  } catch (_) {}

  // Keep the notification bell fresh without a full realtime subscription —
  // re-poll periodically for as long as the app is open. Also doubles as
  // the retry path for the once-a-day tenure/EL-eligibility check (cheap
  // to call repeatedly — it no-ops after the first run each calendar day).
  Timer.periodic(const Duration(seconds: 45), (_) async {
    if (!UserSession.loggedIn) return;
    final list = await SupabaseService.fetchNotifications();
    NotificationStore.all
      ..clear()
      ..addAll(list);
    NotificationStore.recomputeUnread();
    NotificationService.checkDailyReminders();
  });
}
