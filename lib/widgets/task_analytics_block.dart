import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/employee_store.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/task_transitions.dart';
import '../theme/app_theme.dart';
import 'dashboard_info_blocks.dart';

/// Donut-chart breakdown of task status counts. Shows the current user's
/// own tasks, and — for managers — a second donut for their team's tasks
/// (tasks assigned to employees who report to them).
class TaskAnalyticsBlock extends StatefulWidget {
  final bool showTeam;
  final bool showIcon;
  // Employee/Manager dashboards opt into an added "Completion Rate"
  // footer; HR keeps the original donut-only card (modern defaults false).
  final bool modern;
  // Tapping a legend row (Pending/Completed/Delayed/...) jumps to this
  // route pre-filtered to that status — null keeps the legend static.
  final String? viewAllRoute;
  // Same, for the "Team Tasks" donut when [showTeam] is true.
  final String? teamViewAllRoute;
  const TaskAnalyticsBlock({
    super.key,
    this.showTeam = false,
    this.showIcon = true,
    this.modern = false,
    this.viewAllRoute,
    this.teamViewAllRoute,
  });

  @override
  State<TaskAnalyticsBlock> createState() => _TaskAnalyticsBlockState();
}

class _TaskAnalyticsBlockState extends State<TaskAnalyticsBlock> {
  Map<TaskStatus, int> _mine = {};
  Map<TaskStatus, int> _team = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final all = await SupabaseService.fetchTasks();
    applyTaskAutoTransitions(all);
    final name = UserSession.name.trim();

    final mine = <TaskStatus, int>{};
    for (final t in all) {
      final isMine = name.isNotEmpty &&
          (t.assignedEmployee.trim() == name ||
              t.teamMembers.any((m) => m.trim() == name));
      if (isMine) mine[t.status] = (mine[t.status] ?? 0) + 1;
    }

    final team = <TaskStatus, int>{};
    if (widget.showTeam) {
      final teamNames = EmployeeStore.employees
          .where((e) => e.manager.trim() == name)
          .map((e) => e.name.trim())
          .toSet();
      for (final t in all) {
        final inTeam = teamNames.contains(t.assignedEmployee.trim()) ||
            t.teamMembers.any((m) => teamNames.contains(m.trim()));
        if (inTeam) team[t.status] = (team[t.status] ?? 0) + 1;
      }
    }

    if (!mounted) return;
    setState(() { _mine = mine; _team = team; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final totalMine = _mine.values.fold(0, (a, b) => a + b);
    final totalTeam = _team.values.fold(0, (a, b) => a + b);
    final hasAny = totalMine > 0 || totalTeam > 0;

    return InfoCard(
      icon: Icons.pie_chart_rounded,
      title: 'Task Analytics',
      showIcon: widget.showIcon,
      onRefresh: _load,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          : !hasAny
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: Text('No tasks yet',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    !widget.showTeam
                        ? _StatusDonut(
                            label: 'Status Breakdown',
                            counts: _mine,
                            onTapStatus: widget.viewAllRoute == null
                                ? null
                                : (s) => context.push('${widget.viewAllRoute}?status=${s.name}'),
                          )
                        // Stacked rather than width-adaptive: this card only ever
                        // sits in a narrow My Space row slot, and LayoutBuilder
                        // can't be used here anyway (it can't report intrinsic
                        // dimensions, which the row's IntrinsicHeight needs).
                        : Column(children: [
                            _StatusDonut(
                              label: 'My Tasks',
                              counts: _mine,
                              onTapStatus: widget.viewAllRoute == null
                                  ? null
                                  : (s) => context.push('${widget.viewAllRoute}?status=${s.name}'),
                            ),
                            const SizedBox(height: 20),
                            _StatusDonut(
                              label: 'Team Tasks',
                              counts: _team,
                              onTapStatus: widget.teamViewAllRoute == null
                                  ? null
                                  : (s) => context.push('${widget.teamViewAllRoute}?status=${s.name}'),
                            ),
                          ]),
                    if (widget.modern) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _CompletionRateFooter(counts: _mine),
                    ],
                  ],
                ),
    );
  }
}

// ── Completion-rate footer (modern style) ─────────────────────────────────────
class _CompletionRateFooter extends StatelessWidget {
  final Map<TaskStatus, int> counts;
  const _CompletionRateFooter({required this.counts});

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final completed = counts[TaskStatus.completed] ?? 0;
    final rate = total > 0 ? ((completed / total) * 100).round() : 0;

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Completion Rate',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text('$rate%',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          const Text('Overall Completion',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
      ),
      const SizedBox(width: 16),
      SizedBox(
        width: 100, height: 48,
        child: CustomPaint(painter: _SparklinePainter(color: AppTheme.primaryBlue)),
      ),
    ]);
  }
}

// Purely decorative trend line — there's no historical completion-rate
// data stored yet, so this shows shape/motion only, no invented numbers.
class _SparklinePainter extends CustomPainter {
  final Color color;
  const _SparklinePainter({required this.color});

  static const _pts = [0.5, 0.35, 0.55, 0.3, 0.6, 0.4, 0.2];

  @override
  void paint(Canvas canvas, Size size) {
    final stepX = size.width / (_pts.length - 1);
    final points = [
      for (int i = 0; i < _pts.length; i++) Offset(i * stepX, size.height * _pts[i])
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final mid = Offset((points[i].dx + points[i + 1].dx) / 2, (points[i].dy + points[i + 1].dy) / 2);
      line.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    line.lineTo(points.last.dx, points.last.dy);

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.color != color;
}

// ── Donut + legend ──────────────────────────────────────────────────────────

class _StatusDonut extends StatelessWidget {
  final String label;
  final Map<TaskStatus, int> counts;
  // Tapping a legend row jumps to the pre-filtered task list for that
  // status — null renders the legend as plain (non-interactive) text.
  final void Function(TaskStatus status)? onTapStatus;
  const _StatusDonut({required this.label, required this.counts, this.onTapStatus});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = counts.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.7))),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 84, height: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(size: const Size(84, 84), painter: _DonutPainter(counts)),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$total',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface)),
                      Text(total == 1 ? 'task' : 'tasks',
                          style: TextStyle(
                              fontSize: 9, color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: total == 0
                  ? Text('None',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in TaskStatus.values)
                          if ((counts[s] ?? 0) > 0)
                            InkWell(
                              onTap: onTapStatus == null ? null : () => onTapStatus!(s),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                        color: taskStatusColor(s), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(taskStatusLabel(s),
                                        style: TextStyle(
                                            fontSize: 11,
                                            decoration: onTapStatus == null
                                                ? TextDecoration.none
                                                : TextDecoration.underline,
                                            decorationColor: cs.onSurface.withValues(alpha: 0.3),
                                            color: cs.onSurface.withValues(alpha: 0.75))),
                                  ),
                                  Text('${counts[s]}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: taskStatusColor(s))),
                                ]),
                              ),
                            ),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<TaskStatus, int> counts;
  const _DonutPainter(this.counts);

  @override
  void paint(Canvas canvas, Size size) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 14.0;
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (total == 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false,
          Paint()
            ..color = Colors.grey.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth);
      return;
    }

    double start = -math.pi / 2;
    for (final s in TaskStatus.values) {
      final c = counts[s] ?? 0;
      if (c == 0) continue;
      final sweep = 2 * math.pi * (c / total);
      canvas.drawArc(rect, start, sweep, false,
          Paint()
            ..color = taskStatusColor(s)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.counts != counts;
}
