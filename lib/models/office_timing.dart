import 'app_user.dart';
import '../services/supabase_service.dart';

int? _minutesOf(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// A named working-hours schedule (check-in, check-out, grace period,
/// target working hours) that HR assigns to one or more designations.
class OfficeTiming {
  final String id;
  final String name;
  final String checkInTime;  // "HH:mm"
  final String checkOutTime; // "HH:mm"
  final int graceMinutes;
  final double workingHours;
  final bool isDefault;

  const OfficeTiming({
    required this.id,
    required this.name,
    required this.checkInTime,
    required this.checkOutTime,
    required this.graceMinutes,
    required this.workingHours,
    this.isDefault = false,
  });

  int get checkInMinutes => _minutesOf(checkInTime) ?? 0;
  int get checkOutMinutes => _minutesOf(checkOutTime) ?? 0;
  int get graceEndMinutes => checkInMinutes + graceMinutes;

  factory OfficeTiming.fromJson(Map<String, dynamic> j) => OfficeTiming(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        checkInTime: j['check_in_time'] as String? ?? '09:30',
        checkOutTime: j['check_out_time'] as String? ?? '18:30',
        graceMinutes: (j['grace_minutes'] as num?)?.toInt() ?? 10,
        workingHours: (j['working_hours'] as num?)?.toDouble() ?? 8,
        isDefault: j['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'check_in_time': checkInTime,
        'check_out_time': checkOutTime,
        'grace_minutes': graceMinutes,
        'working_hours': workingHours,
        'is_default': isDefault,
      };
}

/// In-memory cache of every [OfficeTiming] and which designation each one is
/// assigned to. Every attendance calculation (late/early/overtime) resolves
/// an employee's schedule live from their *current* designation through
/// here — nothing is ever cached on the employee or attendance record
/// itself, so a designation change takes effect on the very next check-in.
class OfficeTimingStore {
  /// Safety net so calculations never misbehave before the first fetch
  /// completes (or if Supabase is unreachable) — matches today's real
  /// values, so behavior is unchanged until HR customizes a timing.
  static const fallback = OfficeTiming(
    id: '',
    name: 'Standard Hours',
    checkInTime: '09:30',
    checkOutTime: '18:30',
    graceMinutes: 10,
    workingHours: 8,
    isDefault: true,
  );

  static List<OfficeTiming> _timings = [];
  static Map<String, String> _designationToTimingId = {};
  static bool _loaded = false;

  static List<OfficeTiming> get all => List.unmodifiable(_timings);

  static OfficeTiming get _defaultTiming =>
      _timings.firstWhere((t) => t.isDefault, orElse: () => fallback);

  /// Fetches timings + designation assignments once; safe to call from
  /// every consuming page's init — later calls are a no-op until
  /// [invalidate] is called.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    await refresh();
  }

  static Future<void> refresh() async {
    final timings = await SupabaseService.fetchOfficeTimings();
    final map = await SupabaseService.fetchDesignationOfficeTimingMap();
    _timings = timings;
    _designationToTimingId = map;
    _loaded = true;
  }

  static void invalidate() => _loaded = false;

  /// Synchronous resolver: explicit assignment → default timing → hardcoded
  /// [fallback]. Safe to call before [ensureLoaded] finishes.
  static OfficeTiming scheduleForDesignation(String designation) {
    final timingId = _designationToTimingId[designation];
    if (timingId != null) {
      final match = _timings.where((t) => t.id == timingId);
      if (match.isNotEmpty) return match.first;
    }
    return _timings.isEmpty ? fallback : _defaultTiming;
  }

  static OfficeTiming scheduleForUser(AppUser u) => scheduleForDesignation(u.designation);

  /// Designations currently assigned to [timingId] (for the admin UI).
  static List<String> designationsFor(String timingId) => _designationToTimingId.entries
      .where((e) => e.value == timingId)
      .map((e) => e.key)
      .toList();
}
