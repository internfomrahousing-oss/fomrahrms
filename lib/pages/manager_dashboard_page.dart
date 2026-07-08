

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_shortcut_card.dart';
import '../widgets/dashboard_info_blocks.dart';
import '../widgets/fade_in.dart';
import '../widgets/milestone_confetti.dart';
import '../widgets/my_space_blocks.dart';
import '../widgets/task_analytics_block.dart';
import '../widgets/welcome_banner.dart';

// ── Page ──────────────────────────────────────────────────────────────────────
class ManagerDashboardPage extends StatelessWidget {
  const ManagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return MilestoneConfetti(
      child: Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WelcomeBanner(
              avatarIcon: Icons.manage_accounts_rounded,
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: FadeIn(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(
                    icon: Icons.person_rounded,
                    label: 'My Space',
                  ),
                  const SizedBox(height: 16),
                  _MySpaceRow(children: [
                    AttendanceShortcutCard(
                      attendanceRoute: '/manager/my-attendance',
                      accentColor: AppTheme.accentBlue,
                      columns: 2,
                      extraTiles: [
                        QuickTile(label: 'Leave Request', icon: Icons.event_available_rounded,
                            color: AppTheme.primaryBlue, route: '/manager/my-leave'),
                        QuickTile(label: 'Attendance Sheet', icon: Icons.fact_check_rounded,
                            color: AppTheme.warning, route: '/manager/attendance-management'),
                      ],
                    ),
                    const MyTasksBlock(viewAllRoute: '/manager/my-tasks', modern: true),
                    const TaskAnalyticsBlock(showTeam: true, modern: true),
                  ]),
                  const SizedBox(height: 16),
                  _MySpaceRow(children: const [
                    MyLeaveBlock(applyRoute: '/manager/my-leave', compact: true),
                    MyAttendanceSummaryBlock(viewRoute: '/manager/my-attendance', compact: true),
                    MyPayslipBlock(viewRoute: '/manager/my-payslips', compact: true),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Text(label,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface)),
      const SizedBox(width: 16),
      Expanded(child: Divider(color: cs.outlineVariant)),
    ]);
  }
}

// ── My Space responsive row ────────────────────────────────────────────────────
class _MySpaceRow extends StatelessWidget {
  final List<Widget> children;
  const _MySpaceRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 900;
      if (wide) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      }
      return Column(children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ]);
    });
  }
}
