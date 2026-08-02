import 'app_user.dart';
import 'user_session.dart';
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

  /// Management has no fixed hours. When true, a check-in against this timing
  /// is never assessed for lateness — see checkInStatusFor(). Modelled on the
  /// timing rather than as a special-case department, because Management has
  /// no department at all and keying off a blank one would silently exempt any
  /// future employee whose department had simply not been filled in yet.
  final bool noFixedTiming;

  const OfficeTiming({
    required this.id,
    required this.name,
    required this.checkInTime,
    required this.checkOutTime,
    required this.graceMinutes,
    required this.workingHours,
    this.isDefault = false,
    this.noFixedTiming = false,
  });

  int get checkInMinutes => _minutesOf(checkInTime) ?? 0;
  int get checkOutMinutes => _minutesOf(checkOutTime) ?? 0;
  int get graceEndMinutes => checkInMinutes + graceMinutes;

  // office_timings.working_hours is a Postgres `numeric` column, which
  // PostgREST serializes as a JSON string, not a number — `as num?` throws
  // on that. See the matching note on SupabaseService._numFromJson.
  static double? _numFromJson(dynamic v) => switch (v) {
        num n => n.toDouble(),
        String s => double.tryParse(s),
        _ => null,
      };

  factory OfficeTiming.fromJson(Map<String, dynamic> j) => OfficeTiming(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        checkInTime: j['check_in_time'] as String? ?? '09:30',
        checkOutTime: j['check_out_time'] as String? ?? '18:30',
        graceMinutes: (j['grace_minutes'] as num?)?.toInt() ?? 10,
        workingHours: _numFromJson(j['working_hours']) ?? 8,
        isDefault: j['is_default'] as bool? ?? false,
        noFixedTiming: j['no_fixed_timing'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'check_in_time': checkInTime,
        'check_out_time': checkOutTime,
        'grace_minutes': graceMinutes,
        'working_hours': workingHours,
        'is_default': isDefault,
        'no_fixed_timing': noFixedTiming,
      };
}

/// In-memory cache of every [OfficeTiming] and which department each one is
/// assigned to. Every attendance calculation (late/early/overtime) resolves
/// an employee's schedule live from their *current* department through
/// here — nothing is ever cached on the employee or attendance record
/// itself, so a department change takes effect on the very next check-in.
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
  static Map<String, String> _departmentToTimingId = {};
  static bool _loaded = false;

  static List<OfficeTiming> get all => List.unmodifiable(_timings);

  static OfficeTiming get _defaultTiming =>
      _timings.firstWhere((t) => t.isDefault, orElse: () => fallback);

  /// Fetches timings + department assignments once; safe to call from
  /// every consuming page's init — later calls are a no-op until
  /// [invalidate] is called.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    await refresh();
  }

  static Future<void> refresh() async {
    final timings = await SupabaseService.fetchOfficeTimings();
    final map = await SupabaseService.fetchDepartmentOfficeTimingMap();
    _timings = timings;
    _departmentToTimingId = map;
    _loaded = true;
  }

  static void invalidate() => _loaded = false;

  /// Synchronous resolver: explicit assignment → default timing → hardcoded
  /// [fallback]. Safe to call before [ensureLoaded] finishes.
  static OfficeTiming scheduleForDepartment(String department) {
    final timingId = _departmentToTimingId[department];
    if (timingId != null) {
      final match = _timings.where((t) => t.id == timingId);
      if (match.isNotEmpty) return match.first;
    }
    return _timings.isEmpty ? fallback : _defaultTiming;
  }

  /// The timing that means "no fixed hours", if one is configured.
  static OfficeTiming? get _noFixedTiming {
    final m = _timings.where((t) => t.noFixedTiming);
    return m.isEmpty ? null : m.first;
  }

  /// Management has no department and no fixed hours, so resolve by ROLE
  /// first. Falling through to scheduleForDepartment('') would land them on
  /// the 09:30 default and flag them late.
  /// Per-employee exemption takes precedence over the department lookup.
  static OfficeTiming scheduleFor({
    required bool exemptFromTiming,
    required String department,
  }) {
    if (exemptFromTiming) {
      // Never fall through to the department lookup for an exempt user. If the
      // store has not loaded yet, _noFixedTiming is null and the old code
      // dropped to scheduleForDepartment() — which for Management (no
      // department) returns the 09:30 default and produces a late prompt for
      // someone who has no fixed hours at all.
      //
      // That load-order dependency was the real cause of the exemption
      // "not working": the flag, the role and the data were all correct, and
      // the store simply had not arrived yet. Returning a synthetic
      // no-fixed-timing schedule makes the exemption independent of load
      // order entirely.
      return _noFixedTiming ?? noFixedTimingFallback;
    }
    return scheduleForDepartment(department);
  }

  /// Used when a user is exempt from fixed timings but the store has not
  /// loaded. Mirrors the 'Management — No Fixed Timing' row.
  static const noFixedTimingFallback = OfficeTiming(
    id: '',
    name: 'No Fixed Timing',
    checkInTime: '00:00',
    checkOutTime: '23:59',
    graceMinutes: 0,
    workingHours: 0,
    noFixedTiming: true,
  );

  @Deprecated('Use scheduleFor(exemptFromTiming:, department:) — exemption is per employee, not per role')
  static OfficeTiming scheduleForRole(String role, String department) {
    if (role == 'Management' || role == 'CEO') {
      final t = _noFixedTiming;
      if (t != null) return t;
    }
    return scheduleForDepartment(department);
  }

  /// Schedule for the SIGNED-IN user.
  ///
  /// Management works to no fixed hours — check in and out at any time, with
  /// no late-reason prompt. That is derived from the ROLE, not only from the
  /// exempt_from_timing flag.
  ///
  /// The distinction matters: the flag travels login -> UserSession -> local
  /// storage, so a session created before the flag existed carries a stale
  /// `false` until the user signs out. Role has always been part of the
  /// session, so keying on it as well makes the exemption immediate and
  /// immune to that staleness. The flag still applies to non-Management users
  /// who are individually exempt.
  static OfficeTiming scheduleForCurrentUser() => scheduleFor(
        exemptFromTiming:
            UserSession.exemptFromTiming || UserSession.role == UserRole.management,
        department: UserSession.department,
      );

  static OfficeTiming scheduleForUser(AppUser u) => scheduleFor(
        exemptFromTiming: u.exemptFromTiming || u.isManagement,
        department: u.department,
      );

  /// Departments currently assigned to [timingId] (for the admin UI).
  static List<String> departmentsFor(String timingId) => _departmentToTimingId.entries
      .where((e) => e.value == timingId)
      .map((e) => e.key)
      .toList();
}
