import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'models/color_theme_notifier.dart';
import 'models/language_notifier.dart';
import 'models/notification_store.dart';
import 'models/office_timing.dart';
import 'models/theme_notifier.dart';
import 'models/user_session.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/supabase_service.dart';
import 'services/session_storage.dart';
import 'utils/secure_local_storage.dart';
import 'utils/url_strategy.dart';
import 'widgets/notification_popup_overlay.dart';

void main() async {
  configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Restore persisted login before the router guard runs — must be awaited
  // since the router reads UserSession synchronously at first build.
  final restored = await SessionStorage.restore();
  // Load theme preference for the restored user so dark/light persists after refresh.
  if (restored) {
    themeNotifier.loadForUser(UserSession.employeeId);
    staffLanguageNotifier.loadForUser(UserSession.employeeId);
  }

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
      // Keystore/keychain-backed on native instead of plain SharedPreferences
      // — the session holds a real refresh token now that login mints a
      // genuine Supabase Auth session (see lib/utils/secure_local_storage.dart).
      authOptions: FlutterAuthClientOptions(localStorage: platformLocalStorage()),
    );
    // SessionStorage.restore() (above) trusts a locally-cached "logged in"
    // flag with its own 10h/180d expiry, entirely separate from Supabase's
    // real Auth session (the JWT every RLS policy actually keys off). If
    // that real session failed to restore/refresh here — expired refresh
    // token, cleared storage, etc. — every authenticated request from this
    // point on runs as anon and gets silently empty-filtered by RLS instead
    // of erroring, which used to look like "no data" bugs rather than what
    // it is: not actually logged in. Catch that mismatch once at startup
    // and force a real logout instead of leaving the app in a half-signed-in
    // state.
    if (restored && Supabase.instance.client.auth.currentSession == null) {
      await SessionStorage.clear();
      UserSession.clear();
      final context = rootNavigatorKey.currentContext;
      if (context != null) GoRouter.of(context).go('/login');
    }
    // Chained via .then() rather than awaited outright — daily-reminder
    // checks below read the global TaskStore/UserStore that loadAll()
    // populates, so they must run after it, but the app itself shouldn't
    // block its splash screen on this.
    SupabaseService.loadAll().then((_) {
      if (restored && UserSession.loggedIn) {
        NotificationService.checkDailyTaskReminders();
        if (UserSession.role == UserRole.hr || UserSession.role == UserRole.management) {
          NotificationService.checkDailyReminders();
        }
        PushNotificationService.init();
      }
    });
    SupabaseService.restoreCheckInState();
    OfficeTimingStore.ensureLoaded();
    colorThemeNotifier.loadInitial();
    if (restored && UserSession.employeeId.isNotEmpty) {
      SupabaseService.fetchCurrentUserPhotoUrl(UserSession.employeeId).then((url) {
        if (url != null) UserSession.photoUrl = url;
      });
    }
  } catch (_) {
  } finally {
    // Settled one way or another — safe for early queries to stop waiting.
    SupabaseService.markReady();
  }

  // Keep the notification bell fresh without a full realtime subscription —
  // re-poll periodically for as long as the app is open. Also doubles as
  // the retry path for the once-a-day reminder checks (cheap to call
  // repeatedly — each no-ops after its first run each calendar day).
  Timer.periodic(const Duration(seconds: 45), (_) async {
    if (!UserSession.loggedIn) return;
    final list = await SupabaseService.fetchNotifications();
    final newArrivals = NotificationStore.diffNewArrivals(list);
    NotificationStore.all
      ..clear()
      ..addAll(list);
    NotificationStore.recomputeUnread();
    NotificationService.checkDailyReminders();
    NotificationService.checkDailyTaskReminders();
    for (final arrival in newArrivals) {
      showNotificationPopup(arrival);
    }
  });
}
