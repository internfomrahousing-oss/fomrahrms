import 'package:flutter/material.dart';
import '../widgets/form_detail_page.dart' as fd;

class DesignationsPage extends StatelessWidget {
  const DesignationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const fd.FormDetailPage(
      title: 'Designations',
      icon: Icons.badge_rounded,
      color: Color(0xFF2563EB),
      fields: [
        fd.FormField(label: 'Create Designation', icon: Icons.add_circle_outline_rounded),
        fd.FormField(label: 'Define Hierarchy',   icon: Icons.account_tree_rounded),
        fd.FormField(label: 'Salary Band Mapping',icon: Icons.monetization_on_rounded, keyboardType: TextInputType.number),
      ],
    );
  }
}
