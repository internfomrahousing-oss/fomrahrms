import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../theme/app_theme.dart';
import 'dashboard_info_blocks.dart';

/// A quick-action icon that, on tap, opens its own anchored dropdown panel
/// (positioned just below the icon) containing [block] — rather than a
/// shared full-screen bottom sheet. Each of the 4 quick-action icons gets
/// its own independent dropdown.
class QuickActionDropdownIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Widget block;
  final double boxSize;
  final double iconSize;
  final BorderRadius borderRadius;
  final bool whiteIcon;
  const QuickActionDropdownIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.block,
    this.boxSize = 36,
    this.iconSize = 18,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.whiteIcon = false,
  });

  @override
  State<QuickActionDropdownIcon> createState() => _QuickActionDropdownIconState();
}

class _QuickActionDropdownIconState extends State<QuickActionDropdownIcon> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth - 32).clamp(240, 320).toDouble();

    _entry = OverlayEntry(builder: (_) {
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
            child: Container(
              width: panelWidth,
              constraints: const BoxConstraints(maxHeight: 420),
              padding: const EdgeInsets.all(4),
              child: SingleChildScrollView(child: widget.block),
            ),
          ),
        ),
      ]);
    });
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Tooltip(
        message: widget.label,
        child: InkWell(
          onTap: _toggle,
          borderRadius: widget.borderRadius,
          child: Container(
            width: widget.boxSize,
            height: widget.boxSize,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: widget.whiteIcon ? 0.18 : 0.15),
              borderRadius: widget.borderRadius,
              border: Border.all(color: widget.color.withValues(alpha: 0.35)),
            ),
            child: Icon(widget.icon, size: widget.iconSize,
                color: widget.whiteIcon ? Colors.white : widget.color),
          ),
        ),
      ),
    );
  }
}

// Single professional accent shared by all quick-action icons (was a
// different bright color per icon — kept uniform for a more formal look).
// These icons always sit on the dark top-bar/banner gradient, so use the
// active theme's accent — the same color used for the sidebar's selected
// nav item, which is already chosen to read well against that background.
Color get _qColor => AppTheme.accentBlue;

List<({IconData icon, Color color, String label})> get _qData => [
  (icon: Icons.campaign_rounded,     color: _qColor, label: 'Announcements'),
  (icon: Icons.event_rounded,        color: _qColor, label: 'Holidays'),
  (icon: Icons.emoji_events_rounded, color: _qColor, label: 'Emp of Month'),
  (icon: Icons.cake_rounded,         color: _qColor, label: 'Birthdays'),
];

// HR/Management get the full announcement history plus add/delete controls
// here too, matching the "Announcements" card on their dashboards — everyone
// else gets the read-only, past-7-days view.
bool get _canEditAnnouncements =>
    UserSession.role == UserRole.hr || UserSession.role == UserRole.management;

Widget _blockFor(int i) {
  switch (i) {
    case 0: return AnnouncementsBlock(canEdit: _canEditAnnouncements);
    case 1: return HolidaysBlock(canEdit: false);
    case 3: return BirthdaysBlock(canEdit: false);
    default: return const EmptyBlock();
  }
}

/// Places a row of small square quick-action icons above the narrow-layout
/// body. Previously these floated on top of the scrollable content (a Stack
/// overlay), which visually collided with cards underneath — now they sit
/// inline, above the content, so nothing overlaps.
class QuickActionsBody extends StatelessWidget {
  final Widget child;
  const QuickActionsBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Same gradient as the app bar above and the banner below, so all three
      // read as one continuous surface instead of stacked flat-color bands.
      Container(
        decoration: BoxDecoration(gradient: AppTheme.headerGradient),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: List.generate(_qData.length, (i) {
            final q = _qData[i];
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: QuickActionDropdownIcon(
                icon: q.icon,
                color: q.color,
                label: q.label,
                block: _blockFor(i),
              ),
            );
          }),
        ),
      ),
      Expanded(child: child),
    ]);
  }
}

/// Vertical strip of 4 icons — for embedding next to the banner avatar.
class QuickActionIconsVertical extends StatelessWidget {
  const QuickActionIconsVertical({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_qData.length, (i) {
        final q = _qData[i];
        return Padding(
          padding: EdgeInsets.only(bottom: i < _qData.length - 1 ? 8 : 0),
          child: QuickActionDropdownIcon(
            icon: q.icon,
            color: q.color,
            label: q.label,
            block: _blockFor(i),
            boxSize: 44,
            iconSize: 22,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }
}

/// Wide top-bar version: 4 colourful icon buttons with tooltips.
class QuickActionIcons extends StatelessWidget {
  const QuickActionIcons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_qData.length, (i) {
        final q = _qData[i];
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
          child: QuickActionDropdownIcon(
            icon: q.icon,
            color: q.color,
            label: q.label,
            block: _blockFor(i),
            boxSize: 36,
            iconSize: 20,
            whiteIcon: true,
          ),
        );
      }),
    );
  }
}
