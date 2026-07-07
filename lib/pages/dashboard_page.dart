import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/welcome_banner.dart';
import '../widgets/attendance_shortcut_card.dart';
import '../widgets/dashboard_info_blocks.dart';
import '../widgets/fade_in.dart';
import '../widgets/milestone_confetti.dart';
import '../widgets/my_space_blocks.dart';
import '../widgets/stat_strip.dart';
import '../widgets/task_analytics_block.dart';
import '../theme/app_theme.dart';

// ── Page ──────────────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _totalEmployees = '—';
  String _present = '—';
  String _absent  = '—';

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final today = DateTime.now();
    final dateStr =
        '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';

    final users   = await UserStore.load();
    final records = await SupabaseService.fetchAttendanceForDate(dateStr);

    final total   = users.length;
    final present = records.where((r) => r.checkInTime.isNotEmpty).length;
    final absent  = (total - present).clamp(0, total);

    if (mounted) {
      setState(() {
        _totalEmployees = '$total';
        _present = '$present';
        _absent  = '$absent';
      });
    }
  }

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
            // Full-width header
            WelcomeBanner(
              subtitle: 'Fomra Housing & Infrastructure',
              avatarIcon: Icons.admin_panel_settings_rounded,
              onRefresh: _loadCount,
            ),

            Padding(
              padding: EdgeInsets.all(pad),
              child: FadeIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HrStatStrip(totalEmployees: _totalEmployees, present: _present, absent: _absent),
                    SizedBox(height: narrow ? 24 : 32),

                    AttendanceShortcutCard(
                      attendanceRoute: '/hr/my-attendance',
                      accentColor: AppTheme.accentBlue,
                      extraTiles: [
                        QuickTile(label: 'Leave Request', icon: Icons.event_available_rounded,
                            color: AppTheme.primaryBlue, route: '/hr/my-leave'),
                        QuickTile(label: 'Attendance Sheet', icon: Icons.fact_check_rounded,
                            color: AppTheme.warning, route: '/attendance-management'),
                      ],
                    ),
                    SizedBox(height: narrow ? 24 : 32),

                    const DashboardInfoBlocks(canEdit: true),
                    SizedBox(height: narrow ? 24 : 32),

                    _SectionLabel(icon: Icons.person_rounded, label: 'My Space'),
                    const SizedBox(height: 16),
                    _MySpaceRow(children: const [
                      MyTasksBlock(viewAllRoute: '/hr/my-tasks'),
                      TaskAnalyticsBlock(),
                      MyLeaveBlock(applyRoute: '/hr/my-leave'),
                      MyPayslipBlock(viewRoute: '/hr/my-payslips'),
                      MyAttendanceSummaryBlock(viewRoute: '/hr/my-attendance'),
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

// ── Stat strip ────────────────────────────────────────────────────────────────
class _HrStatStrip extends StatelessWidget {
  final String totalEmployees;
  final String present;
  final String absent;
  const _HrStatStrip(
      {required this.totalEmployees,
      required this.present,
      required this.absent});

  double? _pct(String num, String denom) {
    final n = int.tryParse(num);
    final d = int.tryParse(denom);
    if (n == null || d == null || d == 0) return null;
    return (n / d).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AppStatStrip(cards: [
      AppStatCard(
        title: 'Total Employees',
        value: totalEmployees,
        icon: Icons.groups_rounded,
      ),
      AppStatCard(
        title: 'Present Today',
        value: present,
        icon: Icons.check_circle_rounded,
        gaugePercent: _pct(present, totalEmployees),
      ),
      AppStatCard(
        title: 'Absent Today',
        value: absent,
        icon: Icons.cancel_rounded,
        gaugePercent: _pct(absent, totalEmployees),
      ),
      const AppStatCard(
        title: 'On-site',
        value: '—',
        icon: Icons.location_on_rounded,
        gaugePercent: 0,
      ),
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
