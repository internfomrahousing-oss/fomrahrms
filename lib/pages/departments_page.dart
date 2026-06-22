import 'package:flutter/material.dart';
import '../widgets/form_detail_page.dart' as fd;

class DepartmentsPage extends StatelessWidget {
  const DepartmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const fd.FormDetailPage(
      title: 'Departments',
      icon: Icons.account_tree_rounded,
      color: Color(0xFF2E7D32),
      fields: [
        fd.FormField(label: 'Create Department',      icon: Icons.add_business_rounded),
        fd.FormField(label: 'Assign Department Head', icon: Icons.person_pin_rounded),
        fd.FormField(label: 'Employee Mapping',       icon: Icons.group_rounded),
      ],
    );
  }
}
