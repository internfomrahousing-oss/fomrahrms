import 'dart:async';
import 'dart:html' as html_lib;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../models/attendance_store.dart';
import '../models/user_session.dart';
import '../services/gps_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  static Color get _color => AppTheme.primaryBlue;

  bool _loading = true;
  AttendanceRecord? _record; // today's record from Supabase

  final _timeController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _autoFillTime();
    _loadTodayRecord();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _timeController.dispose();
    super.dispose();
  }

  void _autoFillTime() {
    final now = DateTime.now();
    _timeController.text =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTodayRecord() async {
    final rec = await SupabaseService.fetchTodayAttendance(UserSession.employeeId);
    if (!mounted) return;
    setState(() {
      _record = rec;
      _loading = false;
    });
    if (rec != null && rec.checkInTime.isNotEmpty) {
      AttendanceStore.isCheckedIn = rec.checkOutTime.isEmpty;
      if (AttendanceStore.isCheckedIn) {
        GpsTrackingService.start();
        _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  Future<void> _onCheckIn() async {
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final empName = UserSession.name.isNotEmpty ? UserSession.name : 'Employee';

    AttendanceStore.isCheckedIn = true;
    GpsTrackingService.start();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });

    final lat = GpsTrackingService.latestLat;
    final lng = GpsTrackingService.latestLng;
    final loc = (lat != null && lng != null) ? '$lat,$lng' : '';

    final err = await SupabaseService.saveCheckIn(
      employeeName: empName,
      employeeId: UserSession.employeeId,
      date: date,
      time: _timeController.text,
      location: loc,
    );

    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sync error: $err'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } else {
      if (UserSession.email.isNotEmpty) {
        NotificationService.checkInRecorded(
          employeeEmail: UserSession.email,
          time: _timeController.text,
          employeeRoutePrefix: NotificationService.routePrefixForRole(UserSession.role),
        );
      }
      // Re-fetch to get the saved record
      final rec = await SupabaseService.fetchTodayAttendance(UserSession.employeeId);
      if (mounted) setState(() => _record = rec);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.login_rounded, color: _color, size: 26),
            ),
            const SizedBox(width: 16),
            Text('Check In', style: Theme.of(context).textTheme.headlineMedium),
          ]),
          const SizedBox(height: 24),

          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(),
            ))
          else if (_record != null && _record!.checkInTime.isNotEmpty)
            _CheckedInView(record: _record!, refreshTimer: _refreshTimer)
          else
            _CheckInForm(
              timeController: _timeController,
              color: _color,
              cs: cs,
              onRefreshTime: _autoFillTime,
              onCheckIn: _onCheckIn,
            ),
        ]),
      ),
    );
  }
}

// ── Already checked in view ───────────────────────────────────────────────────
class _CheckedInView extends StatelessWidget {
  final AttendanceRecord record;
  final Timer? refreshTimer;
  const _CheckedInView({required this.record, this.refreshTimer});

  static Color get _color => AppTheme.primaryBlue;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pts = record.gpsPoints.isNotEmpty
        ? record.gpsPoints
        : _parseSingleLocation(record.location);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Status banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.green.withValues(alpha: 0.12) : Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.green.shade700 : Colors.green.shade300),
        ),
        child: Row(children: [
          Icon(Icons.check_circle_rounded,
              color: isDark ? Colors.green.shade400 : Colors.green.shade600, size: 28),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Checked In',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.green.shade300 : Colors.green.shade800)),
            const SizedBox(height: 2),
            Text(record.date,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.green.shade400 : Colors.green.shade600)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(record.checkInTime,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                    fontFamily: 'monospace')),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Location & route
      if (pts.isNotEmpty) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.route_rounded, color: _color, size: 18),
                const SizedBox(width: 8),
                Text(
                  pts.length > 1 ? 'Route (${pts.length} points)' : 'Check-In Location',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ]),
              const SizedBox(height: 12),
              _RouteMapView(points: pts, recordId: record.id),
              const SizedBox(height: 8),
              Text(
                'Last: ${pts.last[0].toStringAsFixed(6)}, ${pts.last[1].toStringAsFixed(6)}',
                style: TextStyle(fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
      ],

      // GPS status
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
        ),
        child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: Colors.blue.shade400, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            record.checkOutTime.isEmpty
                ? 'GPS tracking active until check-out'
                : 'Checked out at ${record.checkOutTime}',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                fontWeight: FontWeight.w500),
          ),
        ]),
      ),
    ]);
  }

  List<List<double>> _parseSingleLocation(String loc) {
    final parts = loc.split(',');
    if (parts.length != 2) return [];
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return [];
    return [[lat, lng]];
  }
}

// ── Leaflet route map (reusable) ──────────────────────────────────────────────
class _RouteMapView extends StatefulWidget {
  final List<List<double>> points;
  final String recordId;
  const _RouteMapView({required this.points, required this.recordId});

  @override
  State<_RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<_RouteMapView> {
  static final _registered = <String>{};

  String get _viewId =>
      'route_${widget.recordId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${widget.points.length}';

  @override
  void initState() {
    super.initState();
    if (widget.points.isEmpty || _registered.contains(_viewId)) return;
    _registered.add(_viewId);

    final jsPts = widget.points.map((p) => '[${p[0]},${p[1]}]').join(',');
    final htmlContent = '''
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

    final blob = html_lib.Blob([htmlContent], 'text/html');
    final url  = html_lib.Url.createObjectUrl(blob);
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId, (_) => html_lib.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width  = '100%'
        ..style.height = '100%',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(height: 220, child: HtmlElementView(viewType: _viewId)),
    );
  }
}

// ── Check-in form (not yet checked in) ───────────────────────────────────────
class _CheckInForm extends StatelessWidget {
  final TextEditingController timeController;
  final Color color;
  final ColorScheme cs;
  final VoidCallback onRefreshTime;
  final VoidCallback onCheckIn;
  const _CheckInForm({
    required this.timeController, required this.color,
    required this.cs, required this.onRefreshTime, required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: timeController,
            decoration: InputDecoration(
              labelText: 'Check-In Time',
              prefixIcon: Icon(Icons.access_time_rounded, color: color, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Refresh time',
                icon: Icon(Icons.schedule_rounded, color: color),
                onPressed: onRefreshTime,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 2),
              ),
              filled: true,
              fillColor: cs.surface,
              labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onCheckIn,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Check In'),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ]);
  }
}
