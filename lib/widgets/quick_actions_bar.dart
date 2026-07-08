import 'package:flutter/material.dart';
import '../models/user_session.dart';
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
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: List.generate(_qData.length, (i) {
            final q = _qData[i];
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: Tooltip(
                message: q.label,
                child: InkWell(
                  onTap: () => _showBlock(context, _blockFor(i)),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: q.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: q.color.withValues(alpha: 0.35)),
                    ),
                    child: Icon(q.icon, size: 18, color: q.color),
                  ),
                ),
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
