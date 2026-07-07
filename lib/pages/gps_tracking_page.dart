import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_store.dart';
import '../models/user_session.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class GpsTrackingPage extends StatefulWidget {
  const GpsTrackingPage({super.key});

  @override
  State<GpsTrackingPage> createState() => _GpsTrackingPageState();
}

class _GpsTrackingPageState extends State<GpsTrackingPage> {
  static Color get _color => AppTheme.accentBlue;

  // Live location
  Position? _livePosition;
  bool _fetchingLive = true;
  String? _liveError;

  // Route tracking
  StreamSubscription<Position>? _routeSub;
  final List<_TrackedPoint> _routePoints = [];
  bool _isTracking = false;

  // Last known location
  Position? _lastKnown;
  String? _lastKnownTime;

  bool get _isEmployee => UserSession.role == UserRole.employee ||
      UserSession.role == UserRole.reportingManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchLiveLocation();
      // Auto-start route tracking if employee is checked in
      if (AttendanceStore.isCheckedIn && _isEmployee) {
        _startRouteTracking();
      }
    });
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm != LocationPermission.denied &&
        perm != LocationPermission.deniedForever;
  }

  Future<void> _fetchLiveLocation() async {
    if (mounted) setState(() { _fetchingLive = true; _liveError = null; });
    try {
      if (!await _ensurePermission()) {
        if (mounted) setState(() => _liveError = 'Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final now = _timeNow();
      if (mounted) {
        setState(() {
          _livePosition = pos;
          _lastKnown = pos;
          _lastKnownTime = now;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _liveError = 'Unable to fetch live location.');
    } finally {
      if (mounted) setState(() => _fetchingLive = false);
    }
  }

  void _startRouteTracking() async {
    if (!await _ensurePermission()) return;
    if (mounted) setState(() { _isTracking = true; _routePoints.clear(); });
    _routeSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final now = _timeNow();
      if (mounted) {
        setState(() {
          _routePoints.insert(0, _TrackedPoint(pos, now));
          _lastKnown = pos;
          _lastKnownTime = now;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _isTracking = false);
    });
  }

  void _stopRouteTracking() {
    _routeSub?.cancel();
    _routeSub = null;
    setState(() => _isTracking = false);
  }

  String _timeNow() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}';
  }

  String _formatPos(Position p) =>
      'Lat: ${p.latitude.toStringAsFixed(5)}, Lng: ${p.longitude.toStringAsFixed(5)}';

  @override
  Widget build(BuildContext context) {
    final checkedIn     = AttendanceStore.isCheckedIn;
    final employeeMode  = _isEmployee && checkedIn;

    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.location_on_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('GPS Tracking', style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            // GPS sharing active banner (employee view while checked in)
            if (employeeMode) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'GPS sharing is active. Your location is being tracked until you check out.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Live Location ──
            _SectionCard(
              title: 'Live Location',
              icon: Icons.my_location_rounded,
              color: _color,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_liveError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_liveError!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_livePosition != null) ...[
                  _CoordRow(Icons.straighten, 'Latitude',
                      _livePosition!.latitude.toStringAsFixed(6)),
                  const SizedBox(height: 8),
                  _CoordRow(Icons.straighten, 'Longitude',
                      _livePosition!.longitude.toStringAsFixed(6)),
                  const SizedBox(height: 8),
                  _CoordRow(Icons.speed_rounded, 'Accuracy',
                      '${_livePosition!.accuracy.toStringAsFixed(1)} m'),
                ] else
                  Text(
                    _fetchingLive
                        ? 'Detecting your location…'
                        : 'Location not available.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _fetchingLive ? null : _fetchLiveLocation,
                    icon: _fetchingLive
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.my_location_rounded),
                    label: Text(_fetchingLive ? 'Detecting…' : 'Refresh Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Route Tracking ──
            _SectionCard(
              title: 'Route Tracking',
              icon: Icons.route_rounded,
              color: AppTheme.primaryBlue,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _isTracking ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isTracking
                        ? 'Tracking active — ${_routePoints.length} points recorded'
                        : 'Tracking stopped',
                    style: TextStyle(
                      color: _isTracking ? Colors.green.shade700 : Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // Employee who is checked in: cannot stop tracking
                if (employeeMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 16, color: AppTheme.primaryBlue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GPS tracking runs until you check out.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  )
                else
                  // HR / Management or not checked in: show Start/Stop buttons
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTracking ? null : _startRouteTracking,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTracking ? _stopRouteTracking : null,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ]),

                if (_routePoints.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),
                  Text('Tracked Points', style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 12)),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _routePoints.length > 5 ? 5 : _routePoints.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final p = _routePoints[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.15)),
                        ),
                        child: Row(children: [
                          Icon(Icons.location_pin, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_formatPos(p.position),
                              style: const TextStyle(fontSize: 12))),
                          Text(p.time,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ]),
                      );
                    },
                  ),
                  if (_routePoints.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('+${_routePoints.length - 5} more points',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // ── Last Known Location ──
            _SectionCard(
              title: 'Last Known Location',
              icon: Icons.history_rounded,
              color: AppTheme.accentBlue,
              child: _lastKnown == null
                  ? Text(
                      'No location recorded yet.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _CoordRow(Icons.straighten, 'Latitude',
                          _lastKnown!.latitude.toStringAsFixed(6)),
                      const SizedBox(height: 8),
                      _CoordRow(Icons.straighten, 'Longitude',
                          _lastKnown!.longitude.toStringAsFixed(6)),
                      const SizedBox(height: 8),
                      _CoordRow(Icons.access_time_rounded, 'Recorded At',
                          _lastKnownTime ?? '—'),
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackedPoint {
  final Position position;
  final String time;
  const _TrackedPoint(this.position, this.time);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CoordRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppTheme.accentBlue),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]);
  }
}
