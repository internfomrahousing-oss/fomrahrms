import 'package:flutter/material.dart';
import '../widgets/placeholder_page.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Approvals',
      icon: Icons.approval_rounded,
    );
  }
}
