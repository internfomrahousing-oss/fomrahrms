import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_category.dart';
import '../models/notification_store.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/back_button.dart';
import '../widgets/filter_panel.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  // null = "All" — the view filter only narrows what's currently shown,
  // it doesn't change what the user receives (that's the mute preference).
  String? _viewFilter;
  // Default view is the last 24h (matches the unread badge); nothing is
  // ever deleted — flip to "All time" to see everything, still further
  // narrowable by the category chips below.
  bool _showAll = false;

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

  Future<void> _openPreferences() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PreferencesSheet(),
    );
    if (mounted) setState(() {}); // muted categories may have changed
  }

  @override
  Widget build(BuildContext context) {
    final all = NotificationStore.forCurrentUser();
    final scoped = _showAll ? all : all.where((n) => n.isRecent).toList();
    final items = _viewFilter == null
        ? scoped
        : scoped.where((n) => categoryFor(n.type).id == _viewFilter).toList();
    final unread = items.where((n) => !n.isReadBy(UserSession.email)).toList();
    final presentCategoryIds = scoped.map((n) => categoryFor(n.type).id).toSet();
    final presentCategories = notificationCategories
        .where((c) => presentCategoryIds.contains(c.id))
        .toList();
    final hasOlder = !_showAll && all.length > scoped.length;

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
                  onPressed: _openPreferences,
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Notification preferences',
                ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilterTriggerButton(
              hasActiveFilters: _showAll || _viewFilter != null,
              onTap: () {
                bool showAllDraft = _showAll;
                String? viewFilterDraft = _viewFilter;
                showFilterPanel(
                  context,
                  title: 'Filters',
                  onReset: () { showAllDraft = false; viewFilterDraft = null; },
                  onApply: () => setState(() { _showAll = showAllDraft; _viewFilter = viewFilterDraft; }),
                  builder: (context, setPanelState) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FilterChipGroup<bool>(
                      label: 'Time range',
                      value: showAllDraft ? true : null,
                      options: const [true],
                      labelOf: (_) => 'All time',
                      onChanged: (v) => setPanelState(() => showAllDraft = v ?? false),
                    ),
                    if (presentCategories.length > 1)
                      FilterChipGroup<String>(
                        label: 'Category',
                        value: viewFilterDraft,
                        options: presentCategories.map((c) => c.id).toList(),
                        labelOf: (id) => presentCategories.firstWhere((c) => c.id == id).label,
                        onChanged: (v) => setPanelState(() => viewFilterDraft = v),
                      ),
                  ]),
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? _EmptyState(
                          filtered: _viewFilter != null,
                          hasOlder: hasOlder,
                          onShowAll: () => setState(() => _showAll = true),
                        )
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

/// Bottom sheet where the user picks which categories of notification they
/// want to receive at all — distinct from the page's view filter, which
/// only changes what's shown right now.
class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet();

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late Set<String> _muted = {...NotificationStore.mutedCategories};
  late final List<NotificationCategory> _categories =
      categoriesForRole(currentRoleLabel());
  bool _saving = false;

  Future<void> _toggle(String categoryId, bool getNotified) async {
    setState(() {
      if (getNotified) {
        _muted.remove(categoryId);
      } else {
        _muted.add(categoryId);
      }
      _saving = true;
    });
    NotificationStore.mutedCategories = _muted;
    NotificationStore.recomputeUnread();
    await SupabaseService.setMutedCategories(UserSession.email, _muted.toList());
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Notification preferences',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (_saving)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Choose which kinds of notifications you want to get.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            for (final c in _categories)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(c.icon, color: AppTheme.primaryBlue, size: 22),
                title: Text(c.label, style: const TextStyle(fontSize: 14)),
                value: !_muted.contains(c.id),
                onChanged: (v) => _toggle(c.id, v),
                activeColor: AppTheme.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered;
  final bool hasOlder;
  final VoidCallback? onShowAll;
  const _EmptyState({this.filtered = false, this.hasOlder = false, this.onShowAll});

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
            child: Icon(
                filtered ? Icons.filter_alt_off_rounded : Icons.notifications_none_rounded,
                color: AppTheme.primaryBlue, size: 40),
          ),
          const SizedBox(height: 16),
          Text(filtered ? 'Nothing in this category' : 'You\'re all caught up',
              style: Theme.of(context).textTheme.headlineSmall),
          if (hasOlder) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onShowAll,
              child: const Text('Show older notifications'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  IconData get _icon => categoryFor(notification.type).icon;

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
