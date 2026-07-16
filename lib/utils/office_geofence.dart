import 'dart:math' as math;

/// Office premises center: 13°05'06.1"N 80°13'21.9"E. Office-workLocation
/// employees must be within [radiusMeters] of this point to check in without
/// giving a reason — see check_in_page.dart.
class OfficeGeofence {
  static const double centerLat = 13.085027778;
  static const double centerLng = 80.222750000;
  static const double radiusMeters = 30;

  static double distanceMeters(double lat, double lng) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat - centerLat);
    final dLng = _degToRad(lng - centerLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(centerLat)) *
            math.cos(_degToRad(lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static bool isWithinOffice(double lat, double lng) =>
      distanceMeters(lat, lng) <= radiusMeters;

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
