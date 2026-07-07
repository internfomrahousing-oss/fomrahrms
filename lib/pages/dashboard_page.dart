import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../theme/app_theme.dart';
import '../widgets/welcome_banner.dart';
import '../widgets/attendance_shortcut_card.dart';
import '../widgets/dashboard_info_blocks.dart';
import '../widgets/fade_in.dart';
import '../widgets/hover_lift.dart';
import '../widgets/stat_strip.dart';


class _Item {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Item(this.title, this.icon, this.color, this.route);
}

const _personalItems = [
  _Item('My Attendance', Icons.access_time_rounded,            Color(0xFF3B82F6), '/hr/my-attendance'),
  _Item('My Leave',      Icons.beach_access_rounded,           Color(0xFF2563EB), '/hr/my-leave'),
  _Item('My Tasks',      Icons.task_alt_rounded,               Color(0xFF3B82F6), '/hr/my-tasks'),
  _Item('My Payslips',   Icons.account_balance_wallet_rounded, Color(0xFF111827), '/hr/my-payslips'),
];


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

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-width welcome banner
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

                    const AttendanceShortcutCard(
                      attendanceRoute: '/hr/my-attendance',
                      accentColor: Color(0xFF3B82F6),
                    ),
                    SizedBox(height: narrow ? 24 : 32),

                    const DashboardInfoBlocks(canEdit: true),
                    SizedBox(height: narrow ? 24 : 32),

                    _SectionLabel(
                      icon: Icons.person_rounded,
                      label: 'My Space',
                    ),
                    const SizedBox(height: 16),
                    _PersonalGrid(items: _personalItems),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
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

// ── Personal grid ─────────────────────────────────────────────────────────────
class _PersonalGrid extends StatelessWidget {
  final List<_Item> items;
  const _PersonalGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 600;
      final cols = wide ? (items.length % 4 == 0 ? 4 : 3) : 2;
      final rows = <Widget>[];
      for (int i = 0; i < items.length; i += cols) {
        final end = (i + cols) > items.length ? items.length : i + cols;
        final rowItems = items.sublist(i, end);
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
    return HoverLift(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Card(
        color: AppTheme.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () => context.go(item.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Icon(Icons.arrow_upward_rounded, size: 16, color: item.color.withValues(alpha: 0.55)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

