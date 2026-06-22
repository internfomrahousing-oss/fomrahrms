import 'package:flutter/material.dart';
import '../widgets/placeholder_page.dart';

class MyAttendancePage extends StatelessWidget {
  const MyAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'My Attendance',
      icon: Icons.access_time_rounded,
    );
  }
}
