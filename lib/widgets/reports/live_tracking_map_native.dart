import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'live_tracking_marker.dart';

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'in.fomrahousing.hrms';

Color _statusColor(MovementStatus s) => switch (s) {
      MovementStatus.moving => const Color(0xFF22C55E),
      MovementStatus.stationary => const Color(0xFFF59E0B),
      MovementStatus.offline => const Color(0xFF9CA3AF),
    };

/// Multi-marker live tracking map (native/desktop) — same flutter_map
/// tile/marker setup as route_map_view_native.dart, one marker per
/// currently-checked-in employee instead of a single route replay.
class LiveTrackingMap extends StatelessWidget {
  final List<LiveEmployeeMarker> markers;
  final double height;
  const LiveTrackingMap({super.key, required this.markers, this.height = 320});

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No one is currently checked in',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ),
      );
    }
    final points = markers.map((m) => LatLng(m.lat, m.lng)).toList();
    final bounds = LatLngBounds.fromPoints(points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: points.length > 1
                ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40))
                : null,
            initialCenter: points.length == 1 ? points.first : bounds.center,
            initialZoom: points.length == 1 ? 14 : 12,
          ),
          children: [
            TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgent),
            MarkerLayer(markers: [
              for (final m in markers)
                Marker(
                  point: LatLng(m.lat, m.lng),
                  width: 120,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: _EmployeeDot(marker: m),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _EmployeeDot extends StatelessWidget {
  final LiveEmployeeMarker marker;
  const _EmployeeDot({required this.marker});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${marker.employeeName}\n${marker.status.name}',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            color: _statusColor(marker.status),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
        ),
      ]),
    );
  }
}
