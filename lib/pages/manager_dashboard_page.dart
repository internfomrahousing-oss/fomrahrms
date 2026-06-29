import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _Section {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Section(this.title, this.icon, this.color, this.route);
}

const _hrSections = [
  _Section('Employee Summary',     Icons.people_rounded,                 Color(0xFF0D47A1), '/manager/employee-management'),
  _Section('Attendance Summary',   Icons.access_time_rounded,            Color(0xFF2E7D32), '/manager/attendance-management'),
  _Section('Interview Review',     Icons.rate_review_rounded,            Color(0xFF1565C0), '/manager/interview-review'),
  _Section('Team Leave Approvals', Icons.group_rounded,                  Color(0xFF283593), '/manager/leave/team-approvals'),
  _Section('Task Summary',         Icons.task_alt_rounded,               Color(0xFF6A1B9A), '/manager/task-management'),
  _Section('Performance Summary',  Icons.trending_up_rounded,            Color(0xFF00695C), '/manager/performance-management'),
  _Section('Payroll Summary',      Icons.account_balance_wallet_rounded, Color(0xFF1565C0), '/manager/payroll-management'),
  _Section('Lead & Marketing',     Icons.leaderboard_rounded,            Color(0xFFE65100), '/manager/lead-management'),
  _Section('Maintenance Summary',  Icons.build_rounded,                  Color(0xFF4E342E), '/manager/maintenance-management'),
  _Section('Approvals Summary',    Icons.approval_rounded,               Color(0xFFC62828), '/manager/approvals'),
  _Section('Notifications',        Icons.notifications_rounded,          Color(0xFF283593), '/manager/notifications'),
];

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

class _Stat {
  final String label;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.icon, this.color);
}

const _stats = [
  _Stat('Total Employees', Icons.groups_rounded,       Color(0xFF0D47A1)),
  _Stat('Present',         Icons.check_circle_rounded, Color(0xFF1565C0)),
  _Stat('Absent',          Icons.cancel_rounded,       Color(0xFF1976D2)),
  _Stat('On-site',         Icons.location_on_rounded,  Color(0xFF42A5F5)),
];

// ── Page ──────────────────────────────────────────────────────────────────────
class ManagerDashboardPage extends StatelessWidget {
  const ManagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — hide title on mobile (AppBar already shows it)
            if (!narrow) ...[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Dashboard',
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
                  colors: [Color(0xFF1A237E), Color(0xFF283593)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A237E).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.manage_accounts_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Welcome back!',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                    const Text('Manager',
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
                      child: const Text('Reporting Manager',
                          style:
                              TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ]),
                ),
              ]),
            ),
            SizedBox(height: narrow ? 16 : 24),

            _StatStrip(),
            SizedBox(height: narrow ? 20 : 28),

            _SectionLabel(
              icon: Icons.admin_panel_settings_rounded,
              label: 'Team Overview',
            ),
            const SizedBox(height: 12),
            _SectionGrid(sections: _hrSections),
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
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF0D47A1), size: 18),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E))),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
    ]);
  }
}

// ── Stat strip ────────────────────────────────────────────────────────────────
class _StatStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 500;
      if (isNarrow) {
        return Column(children: [
          Row(children: [
            Expanded(child: _StatCircle(stat: _stats[0])),
            const SizedBox(width: 12),
            Expanded(child: _StatCircle(stat: _stats[1])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCircle(stat: _stats[2])),
            const SizedBox(width: 12),
            Expanded(child: _StatCircle(stat: _stats[3])),
          ]),
        ]);
      }
      return Row(
        children: _stats.asMap().entries.map((e) {
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: e.key < _stats.length - 1 ? 12 : 0),
              child: _StatCircle(stat: e.value),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _StatCircle extends StatelessWidget {
  final _Stat stat;
  const _StatCircle({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stat.color,
                boxShadow: [
                  BoxShadow(
                    color: stat.color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(stat.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text('—',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: stat.color)),
            const SizedBox(height: 4),
            Text(stat.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF546E7A))),
          ],
        ),
      ),
    );
  }
}

// ── Section grid ──────────────────────────────────────────────────────────────
class _SectionGrid extends StatelessWidget {
  final List<_Section> sections;
  const _SectionGrid({required this.sections});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 900
          ? 3
          : constraints.maxWidth > 600
              ? 2
              : 1;
      final rows = <Widget>[];
      for (int i = 0; i < sections.length; i += cols) {
        final end =
            (i + cols) > sections.length ? sections.length : i + cols;
        final rowItems = sections.sublist(i, end);
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowItems.map((s) {
            final isLast = rowItems.last == s;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: isLast ? 0 : 12, bottom: 12),
                child: _SectionCard(section: s),
              ),
            );
          }).toList(),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(section.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(section.icon, color: section.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A237E))),
                    const SizedBox(height: 2),
                    Text('View details',
                        style: TextStyle(
                            fontSize: 11,
                            color: section.color.withValues(alpha: 0.8))),
                  ]),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13,
                color: section.color.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
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

