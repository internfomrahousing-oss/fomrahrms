import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'inline_progress_bar.dart';
import 'report_card_shell.dart';

DataColumn _col(String label, Color color) => DataColumn(
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
    );

WidgetStateProperty<Color?> _hoverColor(Color color) =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) return color.withValues(alpha: 0.04);
      return null;
    });

// ── Top Attendance ──────────────────────────────────────────────────────────

class TopAttendanceRow {
  final String name;
  final String department;
  final double attendancePercent; // 0.0–1.0
  final int daysPresent;
  final int totalDays;
  const TopAttendanceRow({
    required this.name,
    required this.department,
    required this.attendancePercent,
    required this.daysPresent,
    required this.totalDays,
  });
}

/// Ranked by attendance % over the selected range — this app has no
/// reliable per-employee performance-rating field on every account (only
/// sparse, cycle-dependent appraisal scores), so attendance stands in for
/// "top performers" as the one metric that's always populated.
class TopAttendanceTable extends StatelessWidget {
  final List<TopAttendanceRow> rows;
  const TopAttendanceTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryBlue;
    return ReportCardShell(
      title: 'Top Attendance This Range',
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No attendance data for this range',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(color.withValues(alpha: 0.06)),
                border: TableBorder.all(color: AppTheme.borderSubtle, borderRadius: BorderRadius.circular(8)),
                columns: [
                  _col('Employee', color),
                  _col('Department', color),
                  _col('Days Present', color),
                  _col('Attendance', color),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      color: _hoverColor(color),
                      cells: [
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: color.withValues(alpha: 0.1),
                            child: Text(r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Text(r.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ])),
                        DataCell(Text(r.department, style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${r.daysPresent} / ${r.totalDays}', style: const TextStyle(fontSize: 12))),
                        DataCell(InlineProgressBar(percent: r.attendancePercent, color: AppTheme.success)),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Attendance Overview ─────────────────────────────────────────────────────

class AttendanceOverviewRow {
  final DateTime date;
  final int present;
  final int absent;
  final int late;
  final int halfDay;
  final int onLeave;
  final double attendancePercent; // 0.0–1.0
  const AttendanceOverviewRow({
    required this.date,
    required this.present,
    required this.absent,
    required this.late,
    required this.halfDay,
    required this.onLeave,
    required this.attendancePercent,
  });
}

class AttendanceOverviewTable extends StatelessWidget {
  final List<AttendanceOverviewRow> rows;
  const AttendanceOverviewTable({super.key, required this.rows});

  static String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryBlue;
    return ReportCardShell(
      title: 'Attendance Overview',
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No attendance data for this range',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(color.withValues(alpha: 0.06)),
                border: TableBorder.all(color: AppTheme.borderSubtle, borderRadius: BorderRadius.circular(8)),
                columns: [
                  _col('Date', color),
                  _col('Present', color),
                  _col('Absent', color),
                  _col('Late', color),
                  _col('Half Day', color),
                  _col('On Leave', color),
                  _col('Attendance %', color),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      color: _hoverColor(color),
                      cells: [
                        DataCell(Text(_fmtDate(r.date), style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${r.present}', style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${r.absent}', style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${r.late}', style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${r.halfDay}', style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${r.onLeave}', style: const TextStyle(fontSize: 12))),
                        DataCell(InlineProgressBar(percent: r.attendancePercent, color: AppTheme.success)),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
