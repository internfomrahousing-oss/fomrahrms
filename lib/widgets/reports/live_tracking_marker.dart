/// Live GPS status per employee. attendance_records.gps_points has no
/// per-point timestamp, so this is a best-effort heuristic rather than a
/// true "last seen N minutes ago" signal: multiple route points recorded
/// this check-in means they've been moving; exactly one (or none, falling
/// back to the single `location` field) means stationary; no location data
/// at all means offline.
enum MovementStatus { moving, stationary, offline }

class LiveEmployeeMarker {
  final String employeeName;
  final String employeeId;
  final double lat;
  final double lng;
  final MovementStatus status;
  const LiveEmployeeMarker({
    required this.employeeName,
    required this.employeeId,
    required this.lat,
    required this.lng,
    required this.status,
  });
}
