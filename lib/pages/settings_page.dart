import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_picker_block.dart';

/// Settings.
///
/// The theme picker used to sit inline on the management dashboard, above the
/// operational content — the first thing seen on opening the app, and a
/// personal preference rather than something anyone needs at a glance. Moved
/// here so the dashboard leads with work.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(narrow ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.settings_rounded, color: AppTheme.primaryBlue, size: narrow ? 22 : 26),
            const SizedBox(width: 10),
            Text(
              'Settings',
              style: TextStyle(
                fontSize: narrow ? 20 : 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Personal preferences. These apply to your account only and do not '
            'affect anyone else.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          SizedBox(height: narrow ? 20 : 28),

          const ThemePickerBlock(),
        ],
      ),
    );
  }
}
