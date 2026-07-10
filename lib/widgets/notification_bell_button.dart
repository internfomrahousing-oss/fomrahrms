import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_category.dart';
import '../models/notification_store.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'notification_bell_icon.dart';

/// How many notifications the dropdown shortcut shows before "Show all" —
/// deliberately short, the full list lives on the Notifications page.
const _dropdownLimit = 5;

/// Bell icon that opens a compact dropdown of recent notifications on tap,
/// instead of navigating straight to the Notifications page. Tapping an
/// item marks it read and goes to its route; "Show all" goes to the full
/// Notifications page. Replaces the old direct-navigation bell everywhere
/// it's used (wide top bar + each shell's mobile AppBar).
class NotificationBellButton extends StatefulWidget {
  final String notificationsRoute;
  final Color color;
  final double size;
  final Color badgeBorderColor;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;

  const NotificationBellButton({
    super.key,
    required this.notificationsRoute,
    this.color = Colors.white70,
    this.size = 22,
    this.badgeBorderColor = Colors.white,
    this.padding = const EdgeInsets.all(10),
    this.decoration,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final _key = GlobalKey();

  void _openDropdown() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screen = MediaQuery.of(context).size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (dialogContext) => Stack(
        children: [
          Positioned(
            top: pos.dy + size.height + 6,
            right: screen.width - pos.dx - size.width,
            child: _NotificationDropdown(
              onOpen: (n) async {
                Navigator.of(dialogContext).pop();
                await NotificationService.markRead(n);
                if (n.route.isNotEmpty && mounted) context.go(n.route);
              },
              onShowAll: () {
                Navigator.of(dialogContext).pop();
                context.go(widget.notificationsRoute);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notifications',
      child: InkWell(
        key: _key,
        onTap: _openDropdown,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: widget.padding,
          decoration: widget.decoration,
          child: NotificationBellIcon(
            color: widget.color,
            size: widget.size,
            badgeBorderColor: widget.badgeBorderColor,
          ),
        ),
      ),
    );
  }
}

class _NotificationDropdown extends StatelessWidget {
  final void Function(AppNotification) onOpen;
  final VoidCallback onShowAll;
  const _NotificationDropdown({required this.onOpen, required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    final items = NotificationStore.forCurrentUser().take(_dropdownLimit).toList();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Text('No notifications yet',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            )
          else
            ...[
              for (final n in items) ...[
                _DropdownTile(notification: n, onTap: () => onOpen(n)),
                const Divider(height: 1),
              ],
            ],
          InkWell(
            onTap: onShowAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Show all',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 15, color: AppTheme.primaryBlue),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _DropdownTile({required this.notification, required this.onTap});

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
    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? AppTheme.lightBlue.withValues(alpha: 0.35) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(categoryFor(notification.type).icon,
                  color: AppTheme.primaryBlue, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(_relativeTime,
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 4, left: 4),
                decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
