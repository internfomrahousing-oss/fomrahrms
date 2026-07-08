import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

/// Global "break glass" switch: when on, every employee sees app check-in/out
/// regardless of their individual work location — for company-wide emergencies
/// (e.g. the biometric device is down). Shared across all sessions via
/// app_settings, same pattern as [colorThemeNotifier].
class EmergencyAttendanceNotifier extends ValueNotifier<bool> {
  EmergencyAttendanceNotifier() : super(false);

  Future<void> loadInitial() async {
    value = await SupabaseService.fetchEmergencyAttendanceAll();
  }

  Future<void> setAll(bool enabled) async {
    value = enabled;
    await SupabaseService.setEmergencyAttendanceAll(enabled);
  }
}

final emergencyAttendanceNotifier = EmergencyAttendanceNotifier();
