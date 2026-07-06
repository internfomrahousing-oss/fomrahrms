import 'package:flutter/material.dart';
import '../widgets/back_button.dart';
import 'my_attendance_page.dart';
import 'employee_leave_page.dart';

const _blue = Color(0xFF2563EB);

// Combines MyAttendancePage and EmployeeLeavePage into one scrollable page
// under a single sidebar entry ("My Attendance and Leaves").
class MyAttendanceAndLeavePage extends StatelessWidget {
  final String checkInRoute;
  final String leavePrefix;
  const MyAttendanceAndLeavePage({
    super.key,
    required this.checkInRoute,
    this.leavePrefix = '/employee',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_note_rounded, color: _blue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text('My Attendance and Leaves',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
          ]),
          const SizedBox(height: 24),
          MyAttendancePage(checkInRoute: checkInRoute, embedded: true),
          const SizedBox(height: 32),
          const Divider(height: 1),
          const SizedBox(height: 24),
          EmployeeLeavePage(prefix: leavePrefix, embedded: true),
        ]),
      ),
    );
  }
}
