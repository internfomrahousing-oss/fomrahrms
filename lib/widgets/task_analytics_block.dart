import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/employee_store.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import 'dashboard_info_blocks.dart';

/// Donut-chart breakdown of task status counts. Shows the current user's
/// own tasks, and — for managers — a second donut for their team's tasks
/// (tasks assigned to employees who report to them).
class TaskAnalyticsBlock extends StatefulWidget {
  final bool showTeam;
  final bool showIcon;
  const TaskAnalyticsBlock({super.key, this.showTeam = false, this.showIcon = true});

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
              : !widget.showTeam
                  ? _StatusDonut(label: 'Status Breakdown', counts: _mine)
                  : LayoutBuilder(builder: (_, constraints) {
                      final donuts = [
                        _StatusDonut(label: 'My Tasks', counts: _mine),
                        _StatusDonut(label: 'Team Tasks', counts: _team),
                      ];
                      if (constraints.maxWidth > 420) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: donuts[0]),
                            const SizedBox(width: 16),
                            Expanded(child: donuts[1]),
                          ],
                        );
                      }
                      return Column(children: [
                        donuts[0],
                        const SizedBox(height: 20),
                        donuts[1],
                      ]);
                    }),
    );
  }
}

// ── Donut + legend ──────────────────────────────────────────────────────────

class _StatusDonut extends StatelessWidget {
  final String label;
  final Map<TaskStatus, int> counts;
  const _StatusDonut({required this.label, required this.counts});

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
                            Padding(
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
                                          color: cs.onSurface.withValues(alpha: 0.75))),
                                ),
                                Text('${counts[s]}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: taskStatusColor(s))),
                              ]),
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
