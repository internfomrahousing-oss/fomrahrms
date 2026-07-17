import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'report_card_shell.dart';

class WorkingHoursDay {
  final String label; // e.g. 'Mon'
  final double avgHours;
  final double overtimeHours;
  const WorkingHoursDay({required this.label, required this.avgHours, required this.overtimeHours});
}

/// Grouped bars — average hours worked vs. overtime hours (beyond 8/day),
/// per day in the selected range.
class WorkingHoursChart extends StatelessWidget {
  final List<WorkingHoursDay> days;
  const WorkingHoursChart({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return ReportCardShell(
        title: 'Working Hours Analytics',
        bodyHeight: 240,
        child: const Center(
          child: Text('No attendance data for this range',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }
    final avgColor = AppTheme.primaryBlue;
    const otColor = AppTheme.warning;
    final maxHours = days
        .map((d) => d.avgHours > d.overtimeHours ? d.avgHours : d.overtimeHours)
        .fold<double>(8, (m, v) => v > m ? v : m);

    return ReportCardShell(
      title: 'Working Hours Analytics',
      bodyHeight: 260,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _legendDot('Average Hours', avgColor),
          const SizedBox(width: 16),
          _legendDot('Overtime Hours', otColor),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxHours * 1.25).ceilToDouble(),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.borderSubtle, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.textPrimary,
                  getTooltipItem: (group, _, rod, rodIndex) {
                    final label = rodIndex == 0 ? 'Avg' : 'OT';
                    return BarTooltipItem(
                      '${days[group.x.toInt()].label}\n$label: ${rod.toY.toStringAsFixed(1)}h',
                      const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}h',
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(days[i].label,
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(x: i, barsSpace: 4, barRods: [
                    BarChartRodData(
                        toY: days[i].avgHours, color: avgColor, width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                    BarChartRodData(
                        toY: days[i].overtimeHours, color: otColor, width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                  ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _legendDot(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ]);
}
