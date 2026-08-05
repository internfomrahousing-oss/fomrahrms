import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'report_card_shell.dart';

class DepartmentAttendanceBar {
  final String department;
  final double percent; // 0.0–1.0
  /// Everyone counted as present in this department over the range, and
  /// everyone counted as possible. Carried so a tap can show WHO is behind the
  /// percentage — the chart previously held only the aggregate, so the number
  /// was unexplainable without going elsewhere.
  final List<String> presentNames;
  final List<String> allNames;
  const DepartmentAttendanceBar({
    required this.department,
    required this.percent,
    this.presentNames = const [],
    this.allNames = const [],
  });
}

/// Vertical bar chart of attendance % by department for the selected range.
class DepartmentAttendanceChart extends StatelessWidget {
  final List<DepartmentAttendanceBar> bars;
  /// Called when a department is tapped, so the page can list the people
  /// behind the bar.
  final void Function(DepartmentAttendanceBar)? onBarTap;
  const DepartmentAttendanceChart({super.key, required this.bars, this.onBarTap});

  static String _shorten(String s) => s.length > 10 ? '${s.substring(0, 9)}…' : s;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return ReportCardShell(
        title: 'Department Attendance',
        bodyHeight: 240,
        child: const Center(
          child: Text('No department data for this range',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }
    final color = AppTheme.accentBlue;
    return ReportCardShell(
      title: 'Department Attendance',
      bodyHeight: 260,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.borderSubtle, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            // Tapping a bar lists the people behind the percentage. Uses the
            // chart's own touch callback rather than an overlaid InkWell, so
            // the hit area follows the bar instead of approximating it.
            touchCallback: (event, response) {
              if (onBarTap == null) return;
              if (!event.isInterestedForInteractions) return;
              final idx = response?.spot?.touchedBarGroupIndex;
              if (idx == null || idx < 0 || idx >= bars.length) return;
              onBarTap!(bars[idx]);
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.textPrimary,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${bars[group.x.toInt()].department}\n${rod.toY.round()}%',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_shorten(bars[i].department),
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textPrimary)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < bars.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: bars[i].percent * 100,
                  color: color,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                      show: true, toY: 100, color: color.withValues(alpha: 0.08)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
