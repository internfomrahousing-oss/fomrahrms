import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_store.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/back_button.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final list = await SupabaseService.fetchNotifications();
    NotificationStore.all
      ..clear()
      ..addAll(list);
    NotificationStore.recomputeUnread();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(AppNotification n) async {
    await NotificationService.markRead(n);
    if (!mounted) return;
    setState(() {});
    if (n.route.isNotEmpty) context.go(n.route);
  }

  @override
  Widget build(BuildContext context) {
    final items = NotificationStore.forCurrentUser();
    final unread = items.where((n) => !n.isReadBy(UserSession.email)).toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const NavBackButton(),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.lightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.notifications_rounded,
                      color: AppTheme.primaryBlue, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text('Notifications',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                if (unread.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      await NotificationService.markAllRead(items);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Mark all read'),
                  ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? _EmptyState()
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _NotificationTile(
                              notification: items[i],
                              onTap: () => _open(items[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.lightBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.notifications_none_rounded,
                color: AppTheme.primaryBlue, size: 40),
          ),
          const SizedBox(height: 16),
          Text('You\'re all caught up',
              style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  IconData get _icon {
    final t = notification.type;
    if (t.startsWith('leave_')) return Icons.event_available_rounded;
    if (t.startsWith('attendance_')) return Icons.access_time_rounded;
    if (t.startsWith('onroll_')) return Icons.how_to_reg_rounded;
    if (t.startsWith('task_')) return Icons.task_alt_rounded;
    if (t.startsWith('maintenance_')) return Icons.build_rounded;
    if (t.startsWith('candidate_')) return Icons.record_voice_over_rounded;
    if (t.startsWith('onboarding_')) return Icons.assignment_ind_rounded;
    if (t.startsWith('form_edit_')) return Icons.edit_note_rounded;
    if (t.startsWith('payslip_')) return Icons.account_balance_wallet_rounded;
    if (t.startsWith('announcement_')) return Icons.campaign_rounded;
    return Icons.notifications_rounded;
  }

  String get _relativeTime {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final d = notification.createdAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isReadBy(UserSession.email);
    return Material(
      color: unread
          ? AppTheme.lightBlue.withValues(alpha: 0.35)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: AppTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(notification.body,
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                    ],
                    const SizedBox(height: 4),
                    Text(_relativeTime,
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
