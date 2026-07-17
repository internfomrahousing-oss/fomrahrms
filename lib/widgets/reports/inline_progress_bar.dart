import 'package:flutter/material.dart';

/// Small percentage bar for a single table cell (e.g. daily attendance %),
/// or a full-width bar when [width] is left null. Styled off the quota bar
/// in hr_leave_records_page.dart's _LeaveTypeBlock — this app has no
/// existing per-row table progress bar to reuse directly.
class InlineProgressBar extends StatelessWidget {
  final double percent; // 0.0–1.0
  final Color color;
  final double? width; // null = fill available width via Expanded
  const InlineProgressBar({
    super.key,
    required this.percent,
    required this.color,
    this.width = 90,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: 6,
        backgroundColor: color.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
    return Row(children: [
      width != null ? SizedBox(width: width, child: bar) : Expanded(child: bar),
      const SizedBox(width: 8),
      Text('${(clamped * 100).round()}%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}
