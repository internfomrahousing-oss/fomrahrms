import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/attendance_store.dart';
import '../services/user_store.dart';
import '../widgets/welcome_banner.dart';

class _Section {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Section(this.title, this.icon, this.color, this.route);
}

const _sections = [
  _Section('Employee Summary',     Icons.people_rounded,                 Color(0xFF0D47A1), '/summary/employee'),
  _Section('Attendance Summary',   Icons.access_time_rounded,            Color(0xFF2E7D32), '/summary/attendance'),
  _Section('Team Leave Approvals', Icons.group_rounded,                  Color(0xFF283593), '/leave-management'),
  _Section('Task Summary',         Icons.task_alt_rounded,               Color(0xFF6A1B9A), '/summary/task'),
  _Section('Performance Summary',  Icons.trending_up_rounded,            Color(0xFF00695C), '/summary/performance'),
  _Section('Payroll Summary',      Icons.account_balance_wallet_rounded, Color(0xFF1565C0), '/summary/payroll'),
  _Section('Lead & Marketing',     Icons.leaderboard_rounded,            Color(0xFFE65100), '/summary/lead'),
  _Section('Maintenance Summary',  Icons.build_rounded,                  Color(0xFF4E342E), '/summary/maintenance'),
  _Section('Approvals Summary',    Icons.approval_rounded,               Color(0xFFC62828), '/summary/approvals'),
  _Section('Notifications',        Icons.notifications_rounded,          Color(0xFF283593), '/summary/notifications'),
];

class _Item {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Item(this.title, this.icon, this.color, this.route);
}

const _personalItems = [
  _Item('My Attendance', Icons.access_time_rounded,            Color(0xFF1565C0), '/hr/my-attendance'),
  _Item('My Leave',      Icons.beach_access_rounded,           Color(0xFF1976D2), '/hr/my-leave'),
  _Item('My Tasks',      Icons.task_alt_rounded,               Color(0xFF0288D1), '/hr/my-tasks'),
  _Item('My Payslips',   Icons.account_balance_wallet_rounded, Color(0xFF283593), '/hr/my-payslips'),
];

class _Stat {
  final String label;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.icon, this.color);
}

const _stats = [
  _Stat('Total Employees', Icons.groups_rounded,          Color(0xFF0D47A1)),
  _Stat('Present',         Icons.check_circle_rounded,    Color(0xFF1565C0)),
  _Stat('Absent',          Icons.cancel_rounded,          Color(0xFF1976D2)),
  _Stat('On-site',         Icons.location_on_rounded,     Color(0xFF42A5F5)),
];

// ── Page ──────────────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _totalEmployees = '—';

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final users = await UserStore.load();
    if (mounted) {
      setState(() => _totalEmployees = users.length.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            _StatStrip(totalEmployees: _totalEmployees),
            SizedBox(height: narrow ? 20 : 28),

            const _TodayCheckIns(),
            SizedBox(height: narrow ? 20 : 28),

            _SectionLabel(
              icon: Icons.admin_panel_settings_rounded,
              label: 'Team Overview',
            ),
            const SizedBox(height: 12),
            _SectionGrid(),
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

// ── Stat strip ────────────────────────────────────────────────────────────────
class _StatStrip extends StatelessWidget {
  final String totalEmployees;
  const _StatStrip({required this.totalEmployees});

  @override
  Widget build(BuildContext context) {
    final values = [totalEmployees, '—', '—', '—'];
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 500;
      if (isNarrow) {
        return Column(children: [
          Row(children: [
            Expanded(child: _StatCircle(stat: _stats[0], value: values[0])),
            const SizedBox(width: 12),
            Expanded(child: _StatCircle(stat: _stats[1], value: values[1])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCircle(stat: _stats[2], value: values[2])),
            const SizedBox(width: 12),
            Expanded(child: _StatCircle(stat: _stats[3], value: values[3])),
          ]),
        ]);
      }
      return Row(
        children: _stats.asMap().entries.map((e) {
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: e.key < _stats.length - 1 ? 12 : 0),
              child: _StatCircle(stat: e.value, value: values[e.key]),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _StatCircle extends StatelessWidget {
  final _Stat stat;
  final String value;
  const _StatCircle({required this.stat, required this.value});

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
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: stat.color)),
            const SizedBox(height: 4),
            Text(stat.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

// ── Section grid ──────────────────────────────────────────────────────────────
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
        final end =
            (i + cols) > _sections.length ? _sections.length : i + cols;
        final rowItems = _sections.sublist(i, end);
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
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
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

// ── Today's Check-Ins ─────────────────────────────────────────────────────────
class _TodayCheckIns extends StatelessWidget {
  static const _color = Color(0xFF2E7D32);

  const _TodayCheckIns();

  @override
  Widget build(BuildContext context) {
    final today    = DateTime.now();
    final todayStr = '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';
    final checkIns = AttendanceStore.checkIns
        .where((r) => r.date == todayStr)
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(icon: Icons.login_rounded, label: "Today's Check-Ins"),
      const SizedBox(height: 12),
      if (checkIns.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_off_rounded, size: 36, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('No check-ins recorded today',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
              ]),
            ),
          ),
        )
      else
        ...checkIns.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: _color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(r.employee,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(r.location,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5)),
                          overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(r.time,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _color)),
                  ),
                ]),
              ),
            )),
    ]);
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

