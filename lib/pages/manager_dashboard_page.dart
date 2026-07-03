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

const _personalItems = [
  _Item('My Attendance', Icons.access_time_rounded,            Color(0xFF1565C0), '/manager/my-attendance'),
  _Item('Leave',         Icons.beach_access_rounded,           Color(0xFF1976D2), '/manager/my-leave'),
  _Item('My Tasks',      Icons.task_alt_rounded,               Color(0xFF0288D1), '/manager/my-tasks'),
  _Item('My Payslips',   Icons.account_balance_wallet_rounded, Color(0xFF283593), '/manager/my-payslips'),
];


// ── Page ──────────────────────────────────────────────────────────────────────
class ManagerDashboardPage extends StatelessWidget {
  const ManagerDashboardPage({super.key});

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
              avatarIcon: Icons.manage_accounts_rounded,
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AttendanceShortcutCard(
                    attendanceRoute: '/manager/my-attendance',
                    accentColor: Color(0xFF1565C0),
                  ),
                  SizedBox(height: narrow ? 20 : 28),

                  _SectionLabel(
                    icon: Icons.person_rounded,
                    label: 'My Space',
                  ),
                  const SizedBox(height: 12),
                  _PersonalGrid(items: _personalItems),
                  const SizedBox(height: 16),
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

// ── Personal grid ─────────────────────────────────────────────────────────────
class _PersonalGrid extends StatelessWidget {
  final List<_Item> items;
  const _PersonalGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 600 ? 3 : 2;
      final rows = <Widget>[];
      for (int i = 0; i < items.length; i += cols) {
        final end = (i + cols) > items.length ? items.length : i + cols;
        final rowItems = items.sublist(i, end);
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowItems.map((item) {
            final isLast = rowItems.last == item;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: isLast ? 0 : 12, bottom: 12),
                child: _DashCard(item: item),
              ),
            );
          }).toList(),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(item.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A3A6B))),
              const SizedBox(height: 3),
              Icon(Icons.arrow_forward_rounded,
                  size: 13, color: item.color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

