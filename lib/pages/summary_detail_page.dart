import 'package:flutter/material.dart';
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
    Color(0xFF0D47A1),
    ['Total Employees', 'Active Employees', 'New Joiners', 'Employees on Leave', 'Employees Working Remotely'],
  ),
  'attendance': const _SectionData(
    'Attendance Summary',
    Icons.access_time_rounded,
    Color(0xFF2E7D32),
    ['Present Today', 'Absent Today', 'Late Arrivals', 'Attendance Percentage', 'GPS Check-In Status'],
  ),
  'task': const _SectionData(
    'Task Summary',
    Icons.task_alt_rounded,
    Color(0xFF6A1B9A),
    ['Tasks Assigned', 'Tasks In Progress', 'Tasks Completed', 'Overdue Tasks', 'Productivity Percentage'],
  ),
  'performance': const _SectionData(
    'Performance Summary',
    Icons.trending_up_rounded,
    Color(0xFF00695C),
    ['Top Performers', 'Low Performers', 'Department Performance Score', 'Employee Ranking'],
  ),
  'payroll': const _SectionData(
    'Payroll Summary',
    Icons.account_balance_wallet_rounded,
    Color(0xFF1565C0),
    ['Payroll Processed', 'Pending Payroll', 'Total Salary Expense', 'Incentives Generated'],
  ),
  'lead': const _SectionData(
    'Lead & Marketing Summary',
    Icons.leaderboard_rounded,
    Color(0xFFE65100),
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
    Color(0xFFC62828),
    ['Leave Approvals Pending', 'Task Approvals Pending', 'Payroll Approvals Pending'],
  ),
  'notifications': const _SectionData(
    'Notifications',
    Icons.notifications_rounded,
    Color(0xFF283593),
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
      return const Scaffold(
        body: Center(child: Text('Section not found')),
      );
    }
    return SectionDetailPage(
      title: data.title,
      icon: data.icon,
      color: data.color,
      items: data.items,
    );
  }
}
