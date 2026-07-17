import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_category.dart';
import '../models/notification_store.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Attached to GoRouter so popups can be shown from anywhere (e.g. the
/// background poll timer in main.dart) without needing a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

const _popupDuration = Duration(seconds: 10);

// Tracks which vertical slots are currently occupied by an on-screen popup,
// across *all* calls — not just notifications arriving in the same poll
// batch — so a popup that arrives while an earlier one is still visible
// takes the next free slot instead of landing on top of it.
final Set<int> _occupiedPopupSlots = {};

int _claimPopupSlot() {
  var i = 0;
  while (_occupiedPopupSlots.contains(i)) {
    i++;
  }
  _occupiedPopupSlots.add(i);
  return i;
}

/// Shows a transient card near the top-right (below the bell icon, which
/// sits top-right in every shell's top bar) for a newly-arrived
/// notification. Auto-dismisses; tapping it marks the notification read
/// and navigates to its route.
void showNotificationPopup(AppNotification n) {
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;

  final slot = _claimPopupSlot();
  var released = false;
  void releaseSlot() {
    if (released) return;
    released = true;
    _occupiedPopupSlots.remove(slot);
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _PopupPositioned(
      stackIndex: slot,
      child: _PopupCard(
        notification: n,
        onDismiss: () {
          if (entry.mounted) entry.remove();
          releaseSlot();
        },
        onTap: () {
          if (entry.mounted) entry.remove();
          releaseSlot();
          NotificationService.markRead(n);
          final routeContext = rootNavigatorKey.currentContext;
          if (n.route.isNotEmpty && routeContext != null) {
            GoRouter.of(routeContext).go(n.route);
          }
        },
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(_popupDuration, () {
    if (entry.mounted) entry.remove();
    releaseSlot();
  });
}

class _PopupPositioned extends StatelessWidget {
  final int stackIndex;
  final Widget child;
  const _PopupPositioned({required this.stackIndex, required this.child});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 68 + (stackIndex * 78),
      right: 16,
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

class _PopupCard extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onTap;
  const _PopupCard({required this.notification, required this.onDismiss, required this.onTap});

  @override
  State<_PopupCard> createState() => _PopupCardState();
}

class _PopupCardState extends State<_PopupCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _slide = Tween<Offset>(begin: const Offset(0.3, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.lightBlue,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(categoryFor(n.type).icon, color: AppTheme.primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        if (n.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.onDismiss,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
