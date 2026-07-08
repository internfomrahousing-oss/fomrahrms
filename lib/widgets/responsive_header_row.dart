import 'package:flutter/material.dart';
import 'back_button.dart';

/// Back button + icon badge + title/subtitle + action buttons, laid out so
/// the title always gets enough width to wrap by word instead of by letter.
/// On narrow screens the actions drop to their own wrapped row below the
/// title instead of squeezing it down to a sliver.
class ResponsiveHeaderRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double iconSize;
  final String title;
  final double? titleFontSize;
  final Color? titleColor;
  final String? subtitle;
  final List<Widget> actions;

  const ResponsiveHeaderRow({
    super.key,
    required this.icon,
    required this.color,
    this.iconSize = 36,
    required this.title,
    this.titleFontSize,
    this.titleColor,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final row = Row(children: [
      const NavBackButton(),
      const SizedBox(width: 8),
      Container(
        width: iconSize, height: iconSize,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(iconSize >= 40 ? 10 : 8),
        ),
        child: Icon(icon, color: color, size: iconSize >= 40 ? 22 : 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: titleFontSize ?? (narrow ? 18 : 22),
                  fontWeight: FontWeight.bold,
                  color: titleColor ?? color)),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ]),
      ),
      if (!narrow)
        for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
    ]);

    if (narrow && actions.isNotEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        row,
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ]);
    }
    return row;
  }
}
