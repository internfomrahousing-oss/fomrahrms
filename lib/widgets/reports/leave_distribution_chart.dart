import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'report_card_shell.dart';

/// One slice of the leave-type donut — [bucket] is the CL/ML/EL/LOP code,
/// [label] the human-readable name shown in the legend.
class LeaveDistributionSlice {
  final String bucket;
  final String label;
  final int count;
  /// Who took this leave type in the range, as 'Name — 12 Aug'. Carried so a
  /// tap can list them; the slice previously held only the count.
  final List<String> entries;
  const LeaveDistributionSlice({
    required this.bucket,
    required this.label,
    required this.count,
    this.entries = const [],
  });
}

const _sliceColors = <String, Color>{
  'CL': Color(0xFF6366F1),  // indigo — Casual
  'ML': Color(0xFFEF4444),  // red — Medical/Sick
  'EL': Color(0xFF3B82F6),  // blue — Earned
  'LOP': Color(0xFF9CA3AF), // grey — Loss of Pay
};
const _otherColor = Color(0xFF22C55E);

/// Donut chart of approved leave applications by type, for the selected
/// date range — mirrors the CL/ML/EL/LOP buckets LeaveStore.effectiveBucket
/// already uses everywhere else leave balances are shown.
class LeaveDistributionChart extends StatelessWidget {
  final List<LeaveDistributionSlice> slices;
  /// Called when a leave type is tapped, so the page can list who took it.
  final void Function(LeaveDistributionSlice)? onSliceTap;
  const LeaveDistributionChart({super.key, required this.slices, this.onSliceTap});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.count);
    if (total == 0) {
      return ReportCardShell(
        title: 'Leave Distribution',
        bodyHeight: 240,
        child: const Center(
          child: Text('No approved leave in this range',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }
    final nonZero = slices.where((s) => s.count > 0).toList();
    return ReportCardShell(
      title: 'Leave Distribution',
      bodyHeight: 240,
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 52,
                sections: [
                  for (final s in nonZero)
                    PieChartSectionData(
                      value: s.count.toDouble(),
                      color: _sliceColors[s.bucket] ?? _otherColor,
                      radius: 34,
                      showTitle: false,
                    ),
                ],
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$total', style: AppTheme.pageHeading.copyWith(fontSize: 28)),
              const Text('Leaves', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final s in nonZero)
                // Legend row is the tap target rather than the pie slice: it
                // carries the label and count, so it is obvious what is being
                // opened, and it works the same on a narrow screen.
                InkWell(
                  onTap: onSliceTap == null ? null : () => onSliceTap!(s),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(
                          color: _sliceColors[s.bucket] ?? _otherColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                    ),
                    Text('${s.count} (${(s.count / total * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    if (onSliceTap != null) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 15, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                    ],
                  ]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}
