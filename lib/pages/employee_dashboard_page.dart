import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _Item {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Item(this.title, this.icon, this.color, this.route);
}

const _items = [
  _Item('My Attendance', Icons.access_time_rounded,            Color(0xFF1565C0), '/employee/attendance-management'),
  _Item('Leave',         Icons.beach_access_rounded,           Color(0xFF1976D2), '/employee/leave-management'),
  _Item('My Tasks',      Icons.task_alt_rounded,               Color(0xFF0288D1), '/employee/tasks'),
  _Item('My Payslips',   Icons.account_balance_wallet_rounded, Color(0xFF283593), '/employee/payslips'),
  _Item('Maintenance',   Icons.build_rounded,                  Color(0xFF4E342E), '/employee/maintenance-management'),
  _Item('Onboarding',    Icons.how_to_reg_rounded,             Color(0xFF00695C), '/employee/employee-onboarding'),
  _Item('Notifications', Icons.notifications_rounded,          Color(0xFF0D47A1), '/employee/notifications'),
];

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — hide title on mobile (AppBar shows it)
            if (!narrow) ...[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Dashboard',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('FOMRA Housing & Infrastructure',
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
              const SizedBox(height: 24),
            ],

            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Welcome back!',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const Text('Employee',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Staff Member',
                          style: TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                  ]),
                ),
              ]),
            ),
            SizedBox(height: narrow ? 16 : 24),

            // Menu grid
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
    );
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
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 12),
              ),
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

