import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_shortcut_card.dart';
import '../widgets/dashboard_info_blocks.dart';
import '../widgets/fade_in.dart';
import '../widgets/hover_lift.dart';
import '../widgets/task_analytics_block.dart';
import '../widgets/welcome_banner.dart';

class _Item {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Item(this.title, this.icon, this.color, this.route);
}

const _items = [
  _Item('Leave',         Icons.beach_access_rounded,           Color(0xFF2563EB), '/employee/leave-management'),
  _Item('My Payslips',   Icons.account_balance_wallet_rounded, Color(0xFF111827), '/employee/payslips'),
  _Item('Maintenance',   Icons.build_rounded,                  Color(0xFF4E342E), '/employee/maintenance-management'),
  _Item('Notifications', Icons.notifications_rounded,          Color(0xFF2563EB), '/employee/notifications'),
];

const _blue = Color(0xFF2563EB);

class EmployeeDashboardPage extends StatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage> {
  int _refreshKey = 0;

  Future<void> _refresh() async {
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WelcomeBanner(
              avatarIcon: Icons.person_rounded,
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: FadeIn(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AttendanceShortcutCard(
                    attendanceRoute: '/employee/attendance-management',
                    accentColor: Color(0xFF2563EB),
                  ),
                  SizedBox(height: narrow ? 16 : 24),

                  narrow
                      ? const Column(children: [
                          MyTasksBlock(viewAllRoute: '/employee/tasks'),
                          SizedBox(height: 16),
                          TaskAnalyticsBlock(),
                        ])
                      : const IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: MyTasksBlock(viewAllRoute: '/employee/tasks')),
                              SizedBox(width: 16),
                              Expanded(child: TaskAnalyticsBlock()),
                            ],
                          ),
                        ),
                  SizedBox(height: narrow ? 16 : 24),

                  _SectionLabel(icon: Icons.apps_rounded, label: 'Quick Access'),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 600;
                    final cols = wide ? (_items.length % 4 == 0 ? 4 : 3) : 2;
                    final rows = <Widget>[];
                    for (int i = 0; i < _items.length; i += cols) {
                      final end = (i + cols) > _items.length ? _items.length : i + cols;
                      final rowItems = _items.sublist(i, end);
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
                  }),
                  const SizedBox(height: 8),
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

// ── Dash card ─────────────────────────────────────────────────────────────────
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
