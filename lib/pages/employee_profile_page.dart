import 'package:flutter/material.dart';
import '../widgets/form_detail_page.dart' as fd;

class EmployeeProfilePage extends StatelessWidget {
  const EmployeeProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const fd.FormDetailPage(
      title: 'Employee Profile',
      icon: Icons.person_rounded,
      color: Color(0xFF0D47A1),
      fields: [
        fd.FormField(label: 'Employee ID',      icon: Icons.badge_rounded),
        fd.FormField(label: 'Employee Name',    icon: Icons.person_outline_rounded),
        fd.FormField(label: 'Mobile Number',    icon: Icons.phone_rounded,           keyboardType: TextInputType.phone),
        fd.FormField(label: 'Email',            icon: Icons.email_rounded,           keyboardType: TextInputType.emailAddress),
        fd.FormField(label: 'Address',          icon: Icons.location_on_rounded,     maxLines: 2),
        fd.FormField(label: 'Department',       icon: Icons.account_tree_rounded),
        fd.FormField(label: 'Designation',      icon: Icons.work_rounded),
        fd.FormField(label: 'Manager',          icon: Icons.manage_accounts_rounded),
        fd.FormField(label: 'Date of Joining',  icon: Icons.calendar_today_rounded),
        fd.FormField(label: 'Salary Details',   icon: Icons.account_balance_wallet_rounded, keyboardType: TextInputType.number),
        fd.FormField(label: 'Documents',        icon: Icons.folder_rounded),
      ],
    );
  }
}
