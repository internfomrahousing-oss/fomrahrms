import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_store.dart';
import '../models/user_session.dart';
import '../widgets/back_button.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  static const _color = Color(0xFF0D47A1);
  static final _registeredViews = <String>{};

  final _timeController = TextEditingController();

  bool _detectingLocation = true; // auto-detecting on open
  String? _locationError;
  double? _lat;
  double? _lng;
  String? _mapViewId;

  @override
  void initState() {
    super.initState();
    _autoFillTime();
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectLocation());
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    if (mounted) setState(() { _detectingLocation = true; _locationError = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationError = 'Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationError = 'Location permission denied.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final lat = position.latitude;
      final lng = position.longitude;
      final viewId = 'checkin_map_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';
      if (!_registeredViews.contains(viewId)) {
        _registeredViews.add(viewId);
        final l1 = lng - 0.005;
        final la1 = lat - 0.005;
        final l2 = lng + 0.005;
        final la2 = lat + 0.005;
        ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
          return html.IFrameElement()
            ..src = 'https://www.openstreetmap.org/export/embed.html'
                '?bbox=$l1,$la1,$l2,$la2&layer=mapnik&marker=$lat,$lng'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true;
        });
      }
      if (mounted) {
        setState(() {
          _lat = lat;
          _lng = lng;
          _mapViewId = viewId;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationError = 'Unable to detect location.');
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  void _autoFillTime() {
    final now = DateTime.now();
    _timeController.text =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String get _locationText {
    if (_lat == null || _lng == null) return '—';
    return 'Lat: ${_lat!.toStringAsFixed(6)}, Lng: ${_lng!.toStringAsFixed(6)}';
  }

  void _onSave() {
    if (_timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please fill in the check-in time'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      return;
    }
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    AttendanceStore.checkIns.add(CheckInRecord(
      employee: UserSession.name.isNotEmpty ? UserSession.name : 'Employee',
      date: date,
      time: _timeController.text,
      location: _locationText,
    ));
    AttendanceStore.isCheckedIn = true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Check-In saved successfully'),
      backgroundColor: _color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
    _onClear();
  }

  void _onClear() {
    _autoFillTime();
    setState(() {
      _lat = null;
      _lng = null;
      _mapViewId = null;
      _locationError = null;
    });
    _detectLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.login_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Check In', style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [

                  // Check-In Time (auto-filled)
                  _buildField(
                    controller: _timeController,
                    label: 'Check-In Time',
                    icon: Icons.access_time_rounded,
                    suffix: IconButton(
                      tooltip: 'Refresh time',
                      icon: const Icon(Icons.schedule_rounded, color: _color),
                      onPressed: _autoFillTime,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // GPS Location section (auto-detected)
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.location_on_rounded, color: _color, size: 18),
                      const SizedBox(width: 6),
                      const Text('GPS Location',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
                      const Spacer(),
                      _detectingLocation
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _color),
                            )
                          : TextButton.icon(
                              onPressed: _detectLocation,
                              icon: const Icon(Icons.my_location_rounded, size: 16),
                              label: const Text('Re-detect', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: _color),
                            ),
                    ]),
                    const SizedBox(height: 8),

                    if (_locationError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline_rounded, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Text(_locationError!,
                              style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                        ]),
                      )
                    else if (_lat == null)
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: const Center(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _color),
                            ),
                            SizedBox(width: 8),
                            Text('Detecting your location…',
                                style: TextStyle(fontSize: 12, color: Color(0xFFB0BEC5))),
                          ]),
                        ),
                      )
                    else ...[
                      // Coordinates badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _color.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.gps_fixed_rounded, size: 12, color: _color),
                          const SizedBox(width: 6),
                          Text(
                            'Lat: ${_lat!.toStringAsFixed(6)},  Lng: ${_lng!.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12, color: _color, fontFamily: 'monospace'),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      // Map view
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDDE3EA)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: HtmlElementView(viewType: _mapViewId!),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Check In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _color, size: 20),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _color, width: 2),
        ),
        filled: true, fillColor: Colors.white,
        labelStyle: const TextStyle(color: Color(0xFF78909C)),
      ),
    );
  }
}
