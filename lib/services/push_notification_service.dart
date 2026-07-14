import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../firebase_options.dart';
import '../models/user_session.dart';
import '../widgets/notification_popup_overlay.dart';
import 'supabase_service.dart';

/// Registers this device for FCM push and wires notification taps to the
/// same routes the in-app bell/popup already use. The 45s poll in main.dart
/// already covers "app is open" delivery, so this only needs to add
/// background/terminated delivery — Android and web both render FCM's
/// `notification` payload as a system-tray notification with zero extra
/// display code, so there's nothing to do here for that part either.
class PushNotificationService {
  static String? _currentToken;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized || UserSession.email.isEmpty) return;
    try {
      await Firebase.initializeApp(
        options: kIsWeb ? webFirebaseOptions : null,
      );
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = kIsWeb
          ? await messaging.getToken(vapidKey: webPushVapidKey)
          : await messaging.getToken();
      if (token != null) await _saveToken(token);

      messaging.onTokenRefresh.listen(_saveToken);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleTap(initialMessage);

      _initialized = true;
    } catch (e) {
      // Firebase not configured, or the permission/browser doesn't support
      // push — not fatal, the in-app 45s poll still covers notifications.
      if (kDebugMode) debugPrint('PushNotificationService.init failed: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    _currentToken = token;
    await SupabaseService.upsertDeviceToken(
      token: token,
      email: UserSession.email,
      platform: kIsWeb ? 'web' : 'android',
    );
  }

  static Future<void> unregister() async {
    final token = _currentToken;
    _currentToken = null;
    _initialized = false;
    if (token != null) await SupabaseService.deleteDeviceToken(token);
  }

  static void _handleTap(RemoteMessage message) {
    final route = message.data['route'];
    final context = rootNavigatorKey.currentContext;
    if (route != null && route.isNotEmpty && context != null) {
      GoRouter.of(context).go(route);
    }
  }
}
