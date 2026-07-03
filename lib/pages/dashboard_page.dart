import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/welcome_banner.dart';
import '../widgets/attendance_shortcut_card.dart';


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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            _StatStrip(totalEmployees: _totalEmployees, present: _present, absent: _absent),
            SizedBox(height: narrow ? 20 : 28),

            const AttendanceShortcutCard(
              attendanceRoute: '/hr/my-attendance',
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

// ── Stat strip ────────────────────────────────────────────────────────────────
class _StatStrip extends StatelessWidget {
  final String totalEmployees;
  final String present;
  final String absent;
  const _StatStrip({required this.totalEmployees, required this.present, required this.absent});

  @override
  Widget build(BuildContext context) {
    final values = [totalEmployees, present, absent, '—'];
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ),
        ),
      ),
    );
  }
}

