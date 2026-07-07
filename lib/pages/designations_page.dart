import 'package:flutter/material.dart';
import '../widgets/form_detail_page.dart' as fd;
import '../theme/app_theme.dart';

class DesignationsPage extends StatelessWidget {
  const DesignationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return fd.FormDetailPage(
      title: 'Designations',
      icon: Icons.badge_rounded,
      color: AppTheme.primaryBlue,
      fields: [
        fd.FormField(label: 'Create Designation', icon: Icons.add_circle_outline_rounded),
        fd.FormField(label: 'Define Hierarchy',   icon: Icons.account_tree_rounded),
        fd.FormField(label: 'Salary Band Mapping',icon: Icons.monetization_on_rounded, keyboardType: TextInputType.number),
      ],
    );
  }
}
