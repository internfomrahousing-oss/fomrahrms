import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'report_card_shell.dart';

class AttendanceTrendPoint {
  final DateTime date;
  final double percent; // 0.0–1.0
  const AttendanceTrendPoint({required this.date, required this.percent});
}

/// Day-over-day attendance % line chart for the selected date range.
class AttendanceTrendChart extends StatelessWidget {
  final List<AttendanceTrendPoint> points;
  const AttendanceTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryBlue;
    if (points.isEmpty) {
      return ReportCardShell(
        title: 'Attendance Trend',
        bodyHeight: 240,
        child: const Center(
          child: Text('No attendance data for this range',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }
    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].percent * 100),
    ];
    return ReportCardShell(
      title: 'Attendance Trend',
      bodyHeight: 240,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.borderSubtle, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
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
                reservedSize: 26,
                interval: points.length > 8 ? (points.length / 6).ceilToDouble() : 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  final d = points[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${d.day}/${d.month}',
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppTheme.textPrimary,
              getTooltipItems: (spots) => spots.map((s) {
                final p = points[s.x.toInt()];
                return LineTooltipItem(
                  '${p.date.day}/${p.date.month}/${p.date.year}\nAttendance: ${(p.percent * 100).round()}%',
                  const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: color,
              barWidth: 3,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(radius: 3, color: color, strokeWidth: 2, strokeColor: AppTheme.white),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
