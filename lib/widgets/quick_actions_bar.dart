import 'package:flutter/material.dart';
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
            color: Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
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

// Data for the 4 quick-action buttons
const _qData = [
  (icon: Icons.campaign_rounded,     color: Color(0xFFE53935), label: 'Announcements'),
  (icon: Icons.event_rounded,        color: Color(0xFF43A047), label: 'Holidays'),
  (icon: Icons.emoji_events_rounded, color: Color(0xFFFB8C00), label: 'Emp of Month'),
  (icon: Icons.cake_rounded,         color: Color(0xFF8E24AA), label: 'Birthdays'),
];

Widget _blockFor(int index) {
  switch (index) {
    case 0: return AnnouncementsBlock(canEdit: false);
    case 1: return HolidaysBlock(canEdit: false);
    case 2: return const EmptyBlock();
    default: return BirthdaysBlock(canEdit: false);
  }
}

/// Narrow-layout strip: appears below the AppBar, 4 large colourful icons.
class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D2177),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(_qData.length, (i) {
          final q = _qData[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => _showBlock(context, _blockFor(i)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: q.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: q.color.withValues(alpha: 0.35), width: 1.2),
                  ),
                  child: Icon(q.icon, size: 28, color: q.color),
                ),
                const SizedBox(height: 4),
                Text(q.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9,
                        color: q.color.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }),
      ),
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
                  border: Border.all(color: q.color.withValues(alpha: 0.35), width: 1),
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
