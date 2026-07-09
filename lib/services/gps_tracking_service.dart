import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/user_session.dart';
import 'supabase_service.dart';

class GpsTrackingService {
  static StreamSubscription<Position>? _subscription;
  static Timer? _fallbackTimer;
  static double? latestLat;
  static double? latestLng;

  // Full route accumulated this session (pre-loaded from Supabase on start)
  static final List<List<double>> routePoints = [];

  static bool get isTracking => _subscription != null;

  /// One-shot fix for check-in: fetch a fresh position directly instead of
  /// relying on the position stream (which may not have emitted yet).
  static Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> start() async {
    await stop();

    // Pre-load existing route from Supabase so a page refresh doesn't reset the trail
    if (UserSession.employeeId.isNotEmpty) {
      final today = DateTime.now();
      final dateStr =
          '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';
      final existing = await SupabaseService.fetchGpsPoints(
        employeeId: UserSession.employeeId,
        date: dateStr,
      );
      routePoints.clear();
      routePoints.addAll(existing);
    }

    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_recordPoint);

    // Movement-based updates alone leave long gaps for employees who stay
    // put for hours, so also sample on a timer to keep the trail populated
    // across the full check-in-to-check-out window.
    _fallbackTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final pos = await getCurrentLocation();
      if (pos != null) _recordPoint(pos);
    });
  }

  static void _recordPoint(Position pos) {
    latestLat = pos.latitude;
    latestLng = pos.longitude;
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    routePoints.add([pos.latitude, pos.longitude]);

    if (UserSession.employeeId.isNotEmpty) {
      // Save both the latest single point and the full route
      SupabaseService.updateLocation(
        employeeId: UserSession.employeeId,
        date: dateStr,
        location: '${pos.latitude},${pos.longitude}',
      );
      SupabaseService.updateGpsPoints(
        employeeId: UserSession.employeeId,
        date: dateStr,
        points: List.from(routePoints),
      );
    }
  }

  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    latestLat = null;
    latestLng = null;
    // Don't clear routePoints — HR can still fetch the saved route from Supabase
  }
}
