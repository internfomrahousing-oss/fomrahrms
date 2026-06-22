import 'package:flutter/material.dart';
import '../widgets/placeholder_page.dart';

class PayrollManagementPage extends StatelessWidget {
  const PayrollManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Payroll Management',
      icon: Icons.account_balance_wallet_rounded,
    );
  }
}
