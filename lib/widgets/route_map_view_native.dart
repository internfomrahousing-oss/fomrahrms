import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Native (Android/iOS/desktop) route map — draws the same OSRM road-snapped
/// route as the web Leaflet implementation, using flutter_map instead of an
/// iframe (which isn't available outside a browser).
class RouteMapView extends StatefulWidget {
  final List<List<double>> points;
  final String recordId;
  final String keyPrefix;
  final double height;
  const RouteMapView({
    super.key,
    required this.points,
    required this.recordId,
    this.keyPrefix = 'route',
    this.height = 200,
  });

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  List<LatLng>? _routeLatLngs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void didUpdateWidget(covariant RouteMapView old) {
    super.didUpdateWidget(old);
    if (old.points != widget.points) _loadRoute();
  }

  Future<void> _loadRoute() async {
    final pts = widget.points;
    if (pts.length <= 1) {
      if (mounted) setState(() { _routeLatLngs = null; _loading = false; });
      return;
    }
    setState(() => _loading = true);

    // Reduce to max 25 waypoints for OSRM, same as the web implementation.
    var wp = pts;
    if (pts.length > 25) {
      final step = (pts.length / 24).floor();
      wp = [pts.first];
      for (var i = step; i < pts.length - 1; i += step) {
        wp.add(pts[i]);
      }
      wp.add(pts.last);
    }
    final coords = wp.map((p) => '${p[1]},${p[0]}').join(';');

    List<LatLng>? result;
    try {
      final res = await http.get(Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final coordinates =
            (routes[0]['geometry']['coordinates'] as List).cast<List>();
        result = coordinates
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
      }
    } catch (_) {
      // Fall through to raw straight-line fallback below.
    }
    result ??= pts.map((p) => LatLng(p[0], p[1])).toList();

    if (mounted) setState(() { _routeLatLngs = result; _loading = false; });
  }

  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgent = 'in.fomrahousing.hrms';

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    if (pts.isEmpty) return const SizedBox.shrink();

    if (pts.length == 1) {
      final center = LatLng(pts[0][0], pts[0][1]);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: widget.height,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 15),
            children: [
              TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgent),
              MarkerLayer(markers: [
                Marker(point: center, width: 20, height: 20,
                    child: const _Dot(color: Color(0xFF2E7D32))),
              ]),
            ],
          ),
        ),
      );
    }

    if (_loading || _routeLatLngs == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final start = LatLng(pts.first[0], pts.first[1]);
    final end = LatLng(pts.last[0], pts.last[1]);
    final bounds = LatLngBounds.fromPoints(_routeLatLngs!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(30),
            ),
          ),
          children: [
            TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgent),
            PolylineLayer(polylines: [
              Polyline(points: _routeLatLngs!, color: const Color(0xFF1565C0), strokeWidth: 4),
            ]),
            MarkerLayer(markers: [
              Marker(point: start, width: 20, height: 20,
                  child: const _Dot(color: Color(0xFF2E7D32))),
              Marker(point: end, width: 22, height: 22,
                  child: const _Dot(color: Color(0xFFC62828))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
  );
}
