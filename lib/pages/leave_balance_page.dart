import 'package:flutter/material.dart';
import '../widgets/form_detail_page.dart' as fd;

class LeaveBalancePage extends StatelessWidget {
  const LeaveBalancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const fd.FormDetailPage(
      title: 'Leave Balance Track',
      icon: Icons.balance_rounded,
      color: Color(0xFF2563EB),
      fields: [
        fd.FormField(label: 'Available Leave', icon: Icons.event_available_rounded, keyboardType: TextInputType.number),
        fd.FormField(label: 'Used Leave',      icon: Icons.event_busy_rounded,      keyboardType: TextInputType.number),
        fd.FormField(label: 'Pending Leave',   icon: Icons.pending_actions_rounded, keyboardType: TextInputType.number),
      ],
    );
  }
}
