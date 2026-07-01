import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../models/attendance_store.dart';
import '../models/user_session.dart';
import '../services/gps_tracking_service.dart';
import '../services/supabase_service.dart';
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
  Timer? _mapTimer;

  @override
  void initState() {
    super.initState();
    _autoFillTime();
    // If already checked in, start refreshing the map display
    if (AttendanceStore.isCheckedIn) _startMapTimer();
  }

  @override
  void dispose() {
    _mapTimer?.cancel();
    _timeController.dispose();
    super.dispose();
  }

  void _autoFillTime() {
    final now = DateTime.now();
    _timeController.text =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _startMapTimer() {
    _mapTimer?.cancel();
    // Refresh map every 30 seconds to show updated position
    _mapTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
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
    final date =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final empName = UserSession.name.isNotEmpty ? UserSession.name : 'Employee';
    AttendanceStore.checkIns.add(CheckInRecord(
      employee: empName,
      date: date,
      time: _timeController.text,
      location: '—',
    ));
    AttendanceStore.isCheckedIn = true;
    GpsTrackingService.start();
    _startMapTimer();
    SupabaseService.saveCheckIn(
      employeeName: empName,
      employeeId: UserSession.employeeId,
      date: date,
      time: _timeController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Checked in — GPS tracking started'),
      backgroundColor: _color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
    setState(() {});
  }

  Widget _buildMap(double lat, double lng) {
    final viewId =
        'checkin_live_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
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
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.location_on_rounded, color: _color, size: 16),
        const SizedBox(width: 6),
        Text('Live Location',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface)),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() {}),
          icon: const Icon(Icons.refresh_rounded, size: 15),
          label: const Text('Refresh', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: _color,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]),
      const SizedBox(height: 6),
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
            'Lat: ${lat.toStringAsFixed(6)},  Lng: ${lng.toStringAsFixed(6)}',
            style: const TextStyle(
                fontSize: 12, color: _color, fontFamily: 'monospace'),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: HtmlElementView(viewType: viewId),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final lat = GpsTrackingService.latestLat;
    final lng = GpsTrackingService.latestLng;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.login_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Check In',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  TextField(
                    controller: _timeController,
                    decoration: InputDecoration(
                      labelText: 'Check-In Time',
                      prefixIcon: const Icon(Icons.access_time_rounded,
                          color: _color, size: 20),
                      suffixIcon: IconButton(
                        tooltip: 'Refresh time',
                        icon:
                            const Icon(Icons.schedule_rounded, color: _color),
                        onPressed: _autoFillTime,
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _color, width: 2),
                      ),
                      filled: true,
                      fillColor: cs.surface,
                      labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),

                  if (AttendanceStore.isCheckedIn) ...[
                    const SizedBox(height: 16),
                    // GPS active banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? Colors.green.shade700
                                : Colors.green.shade300),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'GPS tracking active until check-out',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.green.shade300
                                  : Colors.green.shade800,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Live map — shown once GPS has a fix
                    if (lat != null && lng != null)
                      _buildMap(lat, lng)
                    else
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Center(
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: cs.primary),
                                ),
                                const SizedBox(width: 8),
                                Text('Acquiring GPS location…',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface.withValues(alpha: 0.5))),
                              ]),
                        ),
                      ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 16),

            if (!AttendanceStore.isCheckedIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onSave,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Check In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Already Checked In'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side: BorderSide(color: Colors.green.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
