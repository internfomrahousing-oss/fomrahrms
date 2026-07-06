import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_info_blocks.dart';

void _showBlock(BuildContext context, Widget block) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, ctrl) => Column(children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: Colors.black12, borderRadius: BorderRadius.circular(2)),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: block,
          ),
        ),
      ]),
    ),
  );
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

Widget _blockFor(int i) {
  switch (i) {
    case 0: return AnnouncementsBlock(canEdit: false);
    case 1: return HolidaysBlock(canEdit: false);
    case 3: return BirthdaysBlock(canEdit: false);
    default: return const EmptyBlock();
  }
}

/// Wraps the narrow-layout body with a floating vertical strip of 4 icons
/// pinned to the top-right — visually below the bell and star in the AppBar.
class QuickActionsBody extends StatelessWidget {
  final Widget child;
  const QuickActionsBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: List.generate(_qData.length, (i) {
              final q = _qData[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _showBlock(context, _blockFor(i)),
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: q.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: q.color.withValues(alpha: 0.45), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: q.color.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(q.icon, size: 24, color: q.color),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
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
          child: Tooltip(
            message: q.label,
            child: GestureDetector(
              onTap: () => _showBlock(context, _blockFor(i)),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: q.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: q.color.withValues(alpha: 0.45), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: q.color.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(q.icon, size: 22, color: q.color),
              ),
            ),
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
          child: Tooltip(
            message: q.label,
            child: InkWell(
              onTap: () => _showBlock(context, _blockFor(i)),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: q.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: q.color.withValues(alpha: 0.35), width: 1),
                ),
                child: Icon(q.icon, color: q.color, size: 20),
              ),
            ),
          ),
        );
      }),
    );
  }
}
