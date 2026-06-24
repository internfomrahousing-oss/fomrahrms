import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_session.dart';

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
  _Item('My Attendance', Icons.access_time_rounded,            Color(0xFF6A1B9A), '/management/my-attendance'),
  _Item('My Leave',      Icons.beach_access_rounded,           Color(0xFF7B1FA2), '/management/my-leave'),
  _Item('My Tasks',      Icons.task_alt_rounded,               Color(0xFF8E24AA), '/management/my-tasks'),
  _Item('My Payslips',   Icons.account_balance_wallet_rounded, Color(0xFF283593), '/management/my-payslips'),
  _Item('My Profile',    Icons.person_rounded,                 Color(0xFF4A148C), '/management/my-profile'),
];

class _Stat {
  final String label;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.icon, this.color);
}

const _stats = [
  _Stat('Total Employees', Icons.groups_rounded,       Color(0xFF4A148C)),
  _Stat('Present Today',   Icons.check_circle_rounded, Color(0xFF2E7D32)),
  _Stat('Pending Leaves',  Icons.event_busy_rounded,   Color(0xFF6A1B9A)),
  _Stat('Open Tasks',      Icons.task_alt_rounded,     Color(0xFF1565C0)),
];

class ManagementDashboardPage extends StatelessWidget {
  const ManagementDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad = narrow ? 16.0 : 24.0;

    return Material(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!narrow) ...[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Management Dashboard',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('FOMRA Housing & Infrastructure — Management Portal',
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
                  colors: [_mgmtColor, _mgmtAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _mgmtColor.withValues(alpha: 0.35),
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
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        UserSession.name.isNotEmpty
                            ? UserSession.name
                            : 'Management',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Management — Full Access',
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            SizedBox(height: narrow ? 16 : 24),

            _StatStrip(),
            SizedBox(height: narrow ? 20 : 28),

            _SectionLabel(icon: Icons.business_center_rounded, label: 'Management Overview'),
            const SizedBox(height: 12),
            _SectionGrid(),
            SizedBox(height: narrow ? 20 : 28),

            _SectionLabel(icon: Icons.person_rounded, label: 'My Space'),
            const SizedBox(height: 12),
            _PersonalGrid(),
            const SizedBox(height: 16),
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
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: _mgmtColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _mgmtColor, size: 18),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _mgmtColor)),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
    ]);
  }
}

class _StatStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 500;
      if (isNarrow) {
        return Column(children: [
          Row(children: [
            Expanded(child: _StatCard(stat: _stats[0])),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(stat: _stats[1])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(stat: _stats[2])),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(stat: _stats[3])),
          ]),
        ]);
      }
      return Row(
        children: _stats.asMap().entries.map((e) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: e.key < _stats.length - 1 ? 12 : 0),
              child: _StatCard(stat: e.value),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 900
          ? 3
          : constraints.maxWidth > 600
              ? 2
              : 1;
      final rows = <Widget>[];
      for (int i = 0; i < _sections.length; i += cols) {
        final end = (i + cols) > _sections.length ? _sections.length : i + cols;
        final rowItems = _sections.sublist(i, end);
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowItems.map((s) {
            final isLast = rowItems.last == s;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 12, bottom: 12),
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
                            color: _mgmtColor)),
                    const SizedBox(height: 2),
                    Text('View details',
                        style: TextStyle(
                            fontSize: 11,
                            color: section.color.withValues(alpha: 0.8))),
                  ]),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: section.color.withValues(alpha: 0.5)),
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
      final cols = constraints.maxWidth > 600 ? 3 : 2;
      final rows = <Widget>[];
      for (int i = 0; i < _personalItems.length; i += cols) {
        final end = (i + cols) > _personalItems.length ? _personalItems.length : i + cols;
        final rowItems = _personalItems.sublist(i, end);
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowItems.map((item) {
            final isLast = rowItems.last == item;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 12, bottom: 12),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          ]),
        ),
      ),
    );
  }
}
