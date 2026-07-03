import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/attendance_shortcut_card.dart';
import '../widgets/dashboard_info_blocks.dart';
import '../widgets/stat_strip.dart';
import '../widgets/welcome_banner.dart';

const _mgmtColor = Color(0xFF4A148C);
const _mgmtAccent = Color(0xFF7B1FA2);

class _Section {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Section(this.title, this.icon, this.color, this.route);
}

const _sections = [
  _Section('Employee Summary',      Icons.people_rounded,                 Color(0xFF4A148C), '/management/employee-management'),
  _Section('Attendance Summary',    Icons.access_time_rounded,            Color(0xFF2E7D32), '/management/attendance-management'),
  _Section('Leave Management',      Icons.event_available_rounded,        Color(0xFF283593), '/management/leave-management'),
  _Section('Team Leave Approvals',  Icons.group_rounded,                  Color(0xFF00695C), '/management/leave/team-approvals'),
  _Section('Task Summary',          Icons.task_alt_rounded,               Color(0xFF6A1B9A), '/management/task-management'),
  _Section('Performance Summary',   Icons.trending_up_rounded,            Color(0xFF1565C0), '/management/performance-management'),
  _Section('Payroll Summary',       Icons.account_balance_wallet_rounded, Color(0xFF4A148C), '/management/payroll-management'),
  _Section('Lead & Marketing',      Icons.leaderboard_rounded,            Color(0xFFE65100), '/management/lead-management'),
  _Section('Maintenance Summary',   Icons.build_rounded,                  Color(0xFF4E342E), '/management/maintenance-management'),
  _Section('Interview Review',       Icons.rate_review_rounded,            Color(0xFF6A1B9A), '/management/interview-review'),
  _Section('Approvals Summary',     Icons.approval_rounded,               Color(0xFFC62828), '/management/approvals'),
  _Section('Reports & Analytics',   Icons.bar_chart_rounded,              Color(0xFF37474F), '/management/reports-analytics'),
  _Section('Administration',        Icons.admin_panel_settings_rounded,   Color(0xFF880E4F), '/management/administration'),
];

class _Item {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Item(this.title, this.icon, this.color, this.route);
}

const _personalItems = [
  _Item('My Attendance', Icons.access_time_rounded,            Color(0xFF1565C0), '/management/my-attendance'),
  _Item('My Leave',      Icons.beach_access_rounded,           Color(0xFF1976D2), '/management/my-leave'),
  _Item('My Tasks',      Icons.task_alt_rounded,               Color(0xFF0288D1), '/management/my-tasks'),
  _Item('My Payslips',   Icons.account_balance_wallet_rounded, Color(0xFF283593), '/management/my-payslips'),
  _Item('My Profile',    Icons.person_rounded,                 Color(0xFF0D47A1), '/management/my-profile'),
];


class ManagementDashboardPage extends StatefulWidget {
  const ManagementDashboardPage({super.key});

  @override
  State<ManagementDashboardPage> createState() =>
      _ManagementDashboardPageState();
}

class _ManagementDashboardPageState extends State<ManagementDashboardPage> {
  String _totalEmployees = '—';
  String _present = '—';
  String _absent  = '—';

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final today   = DateTime.now();
    final dateStr = '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';
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
    final pad = narrow ? 16.0 : 24.0;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WelcomeBanner(
              avatarIcon: Icons.manage_accounts_rounded,
              onRefresh: _loadCount,
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MgmtStatStrip(totalEmployees: _totalEmployees, present: _present, absent: _absent),
                  SizedBox(height: narrow ? 20 : 28),

                  const AttendanceShortcutCard(
                    attendanceRoute: '/management/my-attendance',
                    accentColor: Color(0xFF1565C0),
                  ),
                  SizedBox(height: narrow ? 20 : 28),

                  const DashboardInfoBlocks(canEdit: true),
                  SizedBox(height: narrow ? 20 : 28),

                  _SectionLabel(icon: Icons.business_center_rounded, label: 'Management Overview'),
                  const SizedBox(height: 12),
                  _SectionGrid(),
                  SizedBox(height: narrow ? 20 : 28),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: cs.primary, size: 18),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface)),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: cs.outlineVariant)),
    ]);
  }
}

class _MgmtStatStrip extends StatelessWidget {
  final String totalEmployees;
  final String present;
  final String absent;
  const _MgmtStatStrip(
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
        title: 'Pending Leaves',
        value: '—',
        icon: Icons.event_busy_rounded,
        gaugePercent: 0,
      ),
    ]);
  }
}

class _SectionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 600;
      final cols = wide ? 4 : 2;
      final rows = <Widget>[];
      for (int i = 0; i < _sections.length; i += cols) {
        final end = (i + cols) > _sections.length ? _sections.length : i + cols;
        final rowItems = _sections.sublist(i, end);
        final missing = cols - rowItems.length;
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...rowItems.map((s) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: (s == rowItems.last && missing == 0) ? 0 : 12,
                  bottom: 12,
                ),
                child: _SectionCard(section: s),
              ),
            )),
            for (int j = 0; j < missing; j++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: j < missing - 1 ? 12 : 0),
                  child: const SizedBox(),
                ),
              ),
          ],
        ));
      }
      return Column(children: rows);
    });
  }
}

class _SectionCard extends StatelessWidget {
  final _Section section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: section.color.withValues(alpha: 0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: section.color.withValues(alpha: 0.18), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(section.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(section.icon, color: section.color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(section.title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: section.color)),
            const SizedBox(height: 6),
            Icon(Icons.arrow_upward_rounded, size: 16, color: section.color.withValues(alpha: 0.55)),
          ]),
        ),
      ),
    );
  }
}

class _PersonalGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 600;
      final cols = wide ? (_personalItems.length % 4 == 0 ? 4 : 3) : 2;
      final rows = <Widget>[];
      for (int i = 0; i < _personalItems.length; i += cols) {
        final end = (i + cols) > _personalItems.length ? _personalItems.length : i + cols;
        final rowItems = _personalItems.sublist(i, end);
        final missing = cols - rowItems.length;
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...rowItems.map((item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: (item == rowItems.last && missing == 0) ? 0 : 12,
                  bottom: 12,
                ),
                child: _DashCard(item: item),
              ),
            )),
            for (int j = 0; j < missing; j++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: j < missing - 1 ? 12 : 0),
                  child: const SizedBox(),
                ),
              ),
          ],
        ));
      }
      return Column(children: rows);
    });
  }
}

class _DashCard extends StatelessWidget {
  final _Item item;
  const _DashCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: item.color.withValues(alpha: 0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: item.color.withValues(alpha: 0.18), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(item.title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: item.color)),
            const SizedBox(height: 6),
            Icon(Icons.arrow_upward_rounded, size: 16, color: item.color.withValues(alpha: 0.55)),
          ]),
        ),
      ),
    );
  }
}
