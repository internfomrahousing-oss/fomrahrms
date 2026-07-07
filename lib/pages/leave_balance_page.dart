import 'package:flutter/material.dart';
import '../widgets/form_detail_page.dart' as fd;
import '../theme/app_theme.dart';

class LeaveBalancePage extends StatelessWidget {
  const LeaveBalancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return fd.FormDetailPage(
      title: 'Leave Balance Track',
      icon: Icons.balance_rounded,
      color: AppTheme.primaryBlue,
      fields: [
        fd.FormField(label: 'Available Leave', icon: Icons.event_available_rounded, keyboardType: TextInputType.number),
        fd.FormField(label: 'Used Leave',      icon: Icons.event_busy_rounded,      keyboardType: TextInputType.number),
        fd.FormField(label: 'Pending Leave',   icon: Icons.pending_actions_rounded, keyboardType: TextInputType.number),
      ],
    );
  }
}
