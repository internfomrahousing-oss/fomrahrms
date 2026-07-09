import 'dart:html' as html_lib;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Shared Leaflet route map: draws a road-snapped route (via OSRM) between
/// recorded GPS points, falling back to a straight polyline if OSRM fails.
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
  static final _registered = <String>{};

  String get _viewId =>
      '${widget.keyPrefix}_${widget.recordId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${widget.points.length}';

  @override
  void initState() {
    super.initState();
    if (widget.points.isEmpty || _registered.contains(_viewId)) return;
    _registered.add(_viewId);

    final jsPts = widget.points.map((p) => '[${p[0]},${p[1]}]').join(',');
    final html = '''
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <style>body{margin:0;} #map{width:100%;height:100%;}</style>
      <div id="map"></div>
      <script>
        var pts = [$jsPts];
        var map = L.map('map', {zoomControl:true});
        L.tileLayer(
          'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=FemA7ny3aB6IXHhm2x3R',
          {
            attribution: '\\u00a9 <a href="https://www.maptiler.com/copyright/">MapTiler</a> \\u00a9 <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            maxZoom: 20
          }
        ).addTo(map);

        function addMarkers() {
          L.circleMarker(pts[0], {radius:8,color:'#fff',weight:2,fillColor:'#2E7D32',fillOpacity:1})
            .addTo(map).bindPopup('Check-in');
          if (pts.length > 1) {
            L.circleMarker(pts[pts.length-1], {radius:9,color:'#fff',weight:2,fillColor:'#C62828',fillOpacity:1})
              .addTo(map).bindPopup('Last location');
          }
        }

        if (pts.length > 1) {
          map.setView(pts[0], 13);
          // Reduce to max 25 waypoints for OSRM
          var wp = pts;
          if (pts.length > 25) {
            var step = Math.floor(pts.length / 24);
            wp = [pts[0]];
            for (var i = step; i < pts.length - 1; i += step) wp.push(pts[i]);
            wp.push(pts[pts.length - 1]);
          }
          var coords = wp.map(function(p){ return p[1]+','+p[0]; }).join(';');
          fetch('https://router.project-osrm.org/route/v1/driving/'+coords+'?overview=full&geometries=geojson')
            .then(function(r){ return r.json(); })
            .then(function(data){
              var latLngs;
              if (data.routes && data.routes.length > 0) {
                latLngs = data.routes[0].geometry.coordinates.map(function(c){ return [c[1],c[0]]; });
              } else {
                latLngs = pts;
              }
              var route = L.polyline(latLngs, {color:'#1565C0',weight:4,opacity:0.85}).addTo(map);
              map.fitBounds(route.getBounds(), {padding:[30,30]});
              addMarkers();
            })
            .catch(function(){
              var route = L.polyline(pts, {color:'#1565C0',weight:4,opacity:0.85}).addTo(map);
              map.fitBounds(route.getBounds(), {padding:[30,30]});
              addMarkers();
            });
        } else {
          L.marker(pts[0]).addTo(map).bindPopup('Check-in location').openPopup();
          map.setView(pts[0], 15);
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
    if (widget.points.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(height: widget.height, child: HtmlElementView(viewType: _viewId)),
    );
  }
}
