import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kConsentKey = 'fomra_location_consent_given';

/// Shows a one-time disclosure before the first background-location request
/// on Android, where the OS also shows a persistent "tracking active"
/// notification with no way to hide it while checked in. No-op on other
/// platforms and on every check-in after the first.
Future<void> ensureLocationConsent(BuildContext context) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kConsentKey) == true) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Location Tracking'),
      content: const Text(
        'While you\'re checked in, FOMRA HRMS tracks your location — '
        'including when the app is closed or your phone is locked — so your '
        'route is visible to HR/management. Tracking stops automatically '
        'when you check out. Android will show a persistent notification the '
        'whole time you\'re checked in.',
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('I Understand, Enable Tracking'),
        ),
      ],
    ),
  );

  await prefs.setBool(_kConsentKey, true);
}
