import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_store.dart';
import '../models/theme_notifier.dart';
import '../models/user_session.dart';
import '../services/audit_log_service.dart';
import '../services/push_notification_service.dart';
import '../services/session_storage.dart';
import '../services/supabase_service.dart';
import '../services/task_logout_gate.dart';
import 'task_update_gate_dialog.dart';

/// Signs the current user out — after first checking whether they still owe
/// today's comment on any of their active tasks (tasksNeedingUpdateToday).
/// If they do, a dialog collects those updates (or lets them back out)
/// before the actual sign-out proceeds. Every shell's logout button should
/// call this instead of duplicating the sign-out sequence.
///
/// [extraReset] runs any shell-specific cleanup (e.g. Staff Portal's
/// language notifier) alongside the shared resets.
Future<void> performLogout(BuildContext context, {VoidCallback? extraReset}) async {
  final pending = await tasksNeedingUpdateToday();
  if (pending.isNotEmpty) {
    if (!context.mounted) return;
    final proceed = await showTaskUpdateGateDialog(context, pending);
    if (proceed != true) return;
  }
  AuditLogService.log('logout');
  themeNotifier.reset();
  extraReset?.call();
  NotificationStore.reset();
  PushNotificationService.unregister();
  SupabaseService.signOut();
  SessionStorage.clear();
  UserSession.clear();
  if (context.mounted) context.go('/login');
}
