import 'package:flutter/material.dart';
import '../widgets/placeholder_page.dart';

class AdministrationPage extends StatelessWidget {
  const AdministrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Administration',
      icon: Icons.admin_panel_settings_rounded,
    );
  }
}
