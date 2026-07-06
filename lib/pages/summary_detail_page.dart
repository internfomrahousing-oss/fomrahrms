import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/section_detail_page.dart';

class _SectionData {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  const _SectionData(this.title, this.icon, this.color, this.items);
}

final _sectionMap = {
  'employee': const _SectionData(
    'Employee Summary',
    Icons.people_rounded,
    Color(0xFF2563EB),
    ['Total Employees', 'Active Employees', 'Employees on Leave', 'Employees on Permission', 'Employees Working Remotely'],
  ),
  'attendance': const _SectionData(
    'Attendance Summary',
    Icons.access_time_rounded,
    Color(0xFF22C55E),
    ['Present Today', 'Absent Today', 'Late Arrivals', 'On Permission', 'Comp Off', 'On Duty'],
  ),
  'task': const _SectionData(
    'Task Summary',
    Icons.task_alt_rounded,
    Color(0xFF2563EB),
    ['Tasks Assigned', 'Tasks In Progress', 'Tasks Completed', 'Overdue Tasks', 'Productivity Percentage'],
  ),
  'performance': const _SectionData(
    'Performance Summary',
    Icons.trending_up_rounded,
    Color(0xFF15803D),
    ['Top Performers', 'Low Performers', 'Department Performance Score', 'Employee Ranking'],
  ),
  'payroll': const _SectionData(
    'Payroll Summary',
    Icons.account_balance_wallet_rounded,
    Color(0xFF3B82F6),
    ['Payroll Processed', 'Pending Payroll', 'Total Salary Expense', 'Incentives Generated'],
  ),
  'lead': const _SectionData(
    'Lead & Marketing Summary',
    Icons.leaderboard_rounded,
    Color(0xFFF59E0B),
    ['Total Leads', 'New Leads', 'Converted Leads', 'Active Campaigns', 'Campaign ROI'],
  ),
  'maintenance': const _SectionData(
    'Maintenance Summary',
    Icons.build_rounded,
    Color(0xFF4E342E),
    ['Open Tickets', 'Pending Issues', 'Resolved Issues'],
  ),
  'approvals': const _SectionData(
    'Approvals Summary',
    Icons.approval_rounded,
    Color(0xFFEF4444),
    ['Leave Approvals Pending', 'Task Approvals Pending', 'Payroll Approvals Pending'],
  ),
  'notifications': const _SectionData(
    'Notifications',
    Icons.notifications_rounded,
    Color(0xFF111827),
    ['Alerts', 'Announcements', 'Policy Updates'],
  ),
};

class SummaryDetailPage extends StatelessWidget {
  final String sectionId;
  const SummaryDetailPage({super.key, required this.sectionId});

  @override
  Widget build(BuildContext context) {
    final data = _sectionMap[sectionId];
    if (data == null) {
      return const Scaffold(body: Center(child: Text('Section not found')));
    }
    if (sectionId == 'employee') return _EmployeeSummaryPage(data: data);
    if (sectionId == 'attendance') return _AttendanceSummaryPage(data: data);
    return SectionDetailPage(
      title: data.title,
      icon: data.icon,
      color: data.color,
      items: data.items,
    );
  }
}

class _EmployeeSummaryPage extends StatefulWidget {
  final _SectionData data;
  const _EmployeeSummaryPage({required this.data});

  @override
  State<_EmployeeSummaryPage> createState() => _EmployeeSummaryPageState();
}

class _EmployeeSummaryPageState extends State<_EmployeeSummaryPage> {
  bool _loading = true;
  Map<String, String> _values = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = DateTime.now();
    final dateStr =
        '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';

    final users = await UserStore.load();
    final total = users.length;

    final records = await SupabaseService.fetchAttendanceForDate(dateStr);
    final present = records.where((r) => r.checkInTime.isNotEmpty).length;
    final onLeave = (total - present).clamp(0, total);

    if (mounted) {
      setState(() {
        _values = {
          'Total Employees':         '$total',
          'Active Employees':        '$present',
          'Employees on Leave':      '$onLeave',
          'Employees on Permission': '—',
          'Employees Working Remotely': '—',
        };
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return SectionDetailPage(
      title: widget.data.title,
      icon: widget.data.icon,
      color: widget.data.color,
      items: widget.data.items,
      values: _values,
    );
  }
}

// ── Attendance Summary ─────────────────────────────────────────────────────────
class _AttendanceSummaryPage extends StatefulWidget {
  final _SectionData data;
  const _AttendanceSummaryPage({required this.data});

  @override
  State<_AttendanceSummaryPage> createState() => _AttendanceSummaryPageState();
}

class _AttendanceSummaryPageState extends State<_AttendanceSummaryPage> {
  bool _loading = true;
  Map<String, String> _values = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = DateTime.now();
    final dateStr =
        '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';

    final users = await UserStore.load();
    final total = users.length;

    final records = await SupabaseService.fetchAttendanceForDate(dateStr);
    final present = records.where((r) => r.checkInTime.isNotEmpty).length;
    final absent = (total - present).clamp(0, total);

    if (mounted) {
      setState(() {
        _values = {
          'Present Today': '$present',
          'Absent Today':  '$absent',
          'Late Arrivals': '—',
          'On Permission': '—',
          'Comp Off':      '—',
          'On Duty':       '—',
        };
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return SectionDetailPage(
      title: widget.data.title,
      icon: widget.data.icon,
      color: widget.data.color,
      items: widget.data.items,
      values: _values,
    );
  }
}
