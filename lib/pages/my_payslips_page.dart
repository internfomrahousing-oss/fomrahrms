import 'package:flutter/material.dart';
import '../widgets/placeholder_page.dart';

class MyPayslipsPage extends StatelessWidget {
  const MyPayslipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'My Payslips',
      icon: Icons.account_balance_wallet_rounded,
    );
  }
}
