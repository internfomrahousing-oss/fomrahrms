import 'dart:convert';
import 'dart:html' as html_lib;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'live_tracking_marker.dart';

String _statusHex(MovementStatus s) => switch (s) {
      MovementStatus.moving => '#22C55E',
      MovementStatus.stationary => '#F59E0B',
      MovementStatus.offline => '#9CA3AF',
    };

/// Multi-marker live tracking map (web) — same Leaflet-iframe approach as
/// route_map_view_web.dart, one circle marker per currently-checked-in
/// employee instead of a single route replay.
class LiveTrackingMap extends StatefulWidget {
  final List<LiveEmployeeMarker> markers;
  final double height;
  const LiveTrackingMap({super.key, required this.markers, this.height = 320});

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  static int _instanceCounter = 0;
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'live_tracking_map_${_instanceCounter++}';
    _register(widget.markers);
  }

  @override
  void didUpdateWidget(covariant LiveTrackingMap old) {
    super.didUpdateWidget(old);
    if (old.markers != widget.markers) {
      // Leaflet instances can't be swapped in place once registered — a new
      // view id forces a fresh iframe with the updated marker set.
      _viewId = 'live_tracking_map_${_instanceCounter++}';
      _register(widget.markers);
      setState(() {});
    }
  }

  void _register(List<LiveEmployeeMarker> markers) {
    final jsMarkers = markers
        .map((m) => jsonEncode({
              'lat': m.lat,
              'lng': m.lng,
              'name': m.employeeName,
              'color': _statusHex(m.status),
              'status': m.status.name,
            }))
        .join(',');

    final html = '''
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <style>body{margin:0;} #map{width:100%;height:100%;}</style>
      <div id="map"></div>
      <script>
        var pts = [$jsMarkers];
        var map = L.map('map', {zoomControl:true});
        L.tileLayer(
          'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=FemA7ny3aB6IXHhm2x3R',
          {
            attribution: '\\u00a9 <a href="https://www.maptiler.com/copyright/">MapTiler</a> \\u00a9 <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            maxZoom: 20
          }
        ).addTo(map);

        if (pts.length > 0) {
          var group = [];
          pts.forEach(function(p) {
            var marker = L.circleMarker([p.lat, p.lng], {
              radius: 9, color: '#fff', weight: 2, fillColor: p.color, fillOpacity: 1
            }).addTo(map).bindPopup(p.name + ' (' + p.status + ')');
            group.push(marker);
          });
          if (pts.length === 1) {
            map.setView([pts[0].lat, pts[0].lng], 14);
          } else {
            var fg = L.featureGroup(group);
            map.fitBounds(fg.getBounds(), {padding: [40, 40]});
          }
        } else {
          map.setView([20.5937, 78.9629], 5);
        }
      </script>
    ''';

    final blob = html_lib.Blob([html], 'text/html');
    final url = html_lib.Url.createObjectUrl(blob);
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId, (_) => html_lib.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.markers.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No one is currently checked in',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(height: widget.height, child: HtmlElementView(viewType: _viewId)),
    );
  }
}
