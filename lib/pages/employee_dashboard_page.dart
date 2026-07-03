import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/attendance_shortcut_card.dart';
import '../widgets/welcome_banner.dart';

class _Item {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Item(this.title, this.icon, this.color, this.route);
}

const _items = [
  _Item('Leave',         Icons.beach_access_rounded,           Color(0xFF1976D2), '/employee/leave-management'),
  _Item('My Payslips',   Icons.account_balance_wallet_rounded, Color(0xFF283593), '/employee/payslips'),
  _Item('Maintenance',   Icons.build_rounded,                  Color(0xFF4E342E), '/employee/maintenance-management'),
  _Item('Notifications', Icons.notifications_rounded,          Color(0xFF0D47A1), '/employee/notifications'),
];

const _blue = Color(0xFF0D47A1);

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});

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
            const WelcomeBanner(
              avatarIcon: Icons.person_rounded,
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AttendanceShortcutCard(
                    attendanceRoute: '/employee/attendance-management',
                    accentColor: Color(0xFF0D47A1),
                  ),
                  SizedBox(height: narrow ? 16 : 24),

                  _SectionLabel(icon: Icons.apps_rounded, label: 'Quick Access'),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final cols = constraints.maxWidth > 600 ? 3 : 2;
                    final rows = <Widget>[];
                    for (int i = 0; i < _items.length; i += cols) {
                      final end =
                          (i + cols) > _items.length ? _items.length : i + cols;
                      final rowItems = _items.sublist(i, end);
                      rows.add(Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: rowItems.map((item) {
                          final isLast = rowItems.last == item;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: isLast ? 0 : 12, bottom: 12),
                              child: _DashCard(item: item),
                            ),
                          );
                        }).toList(),
                      ));
                    }
                    return Column(children: rows);
                  }),
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(item.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 12)),
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: item.color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
