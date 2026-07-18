import 'dart:math' as math;
import '../models/attendance_location.dart';

/// Distance/containment calculations against HR-configured [OfficeLocation]s.
/// Replaces the single hardcoded point/radius that used to live in
/// office_geofence.dart.
class Geofence {
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}

/// Outcome of checking a GPS fix against everywhere an employee is allowed
/// to be, per their resolved [AttendancePolicy].
class GeofenceResult {
  /// Whether this policy has any location concept at all (false for
  /// unrestricted policies) — drives whether a note can ever be required.
  final bool requiresLocation;
  final bool isWithinAnyLocation;
  final OfficeLocation? nearestLocation;
  final double? nearestDistanceMeters;

  const GeofenceResult({
    required this.requiresLocation,
    required this.isWithinAnyLocation,
    this.nearestLocation,
    this.nearestDistanceMeters,
  });

  /// True only when the policy demands a location AND the given position
  /// isn't near any of them (including a missing/unreadable GPS fix).
  bool get outsideAllowedLocation => requiresLocation && !isWithinAnyLocation;

  static const unrestricted = GeofenceResult(requiresLocation: false, isWithinAnyLocation: true);
}

/// Evaluates [position] (nullable — a failed GPS read counts as "outside")
/// against [locations] under [policy]. [locations] should already be
/// filtered to the employee's assigned, active locations.
GeofenceResult evaluateGeofence({
  required AttendancePolicy policy,
  required List<OfficeLocation> locations,
  required double? lat,
  required double? lng,
}) {
  if (!policy.requiresLocation) return GeofenceResult.unrestricted;
  if (lat == null || lng == null || locations.isEmpty) {
    return GeofenceResult(
      requiresLocation: true,
      isWithinAnyLocation: false,
      nearestLocation: locations.isEmpty ? null : locations.first,
    );
  }

  OfficeLocation? nearest;
  double? nearestDist;
  bool within = false;
  for (final loc in locations) {
    final d = Geofence.distanceMeters(lat, lng, loc.latitude, loc.longitude);
    if (nearestDist == null || d < nearestDist) {
      nearestDist = d;
      nearest = loc;
    }
    if (d <= loc.radiusMeters) within = true;
  }

  return GeofenceResult(
    requiresLocation: true,
    isWithinAnyLocation: within,
    nearestLocation: nearest,
    nearestDistanceMeters: nearestDist,
  );
}
