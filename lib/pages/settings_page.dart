import 'package:flutter/material.dart';
import '../widgets/attendance_shortcut_card.dart' show showHelpCenterDialog;
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
          SizedBox(height: narrow ? 20 : 28),

          // Moved off the dashboard: reference material, not a daily action.
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: Icon(Icons.help_rounded, color: AppTheme.pink),
              title: const Text('Help Center',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('Guides and answers to common questions',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showHelpCenterDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}
