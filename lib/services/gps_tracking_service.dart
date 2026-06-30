import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_store.dart';
import '../models/user_session.dart';

class GpsTrackingService {
  static StreamSubscription<Position>? _subscription;

  static bool get isTracking => _subscription != null;

  static Future<void> start() async {
    await stop();

    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    final employee =
        UserSession.name.isNotEmpty ? UserSession.name : 'Employee';

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      final now = DateTime.now();
      AttendanceStore.gpsRecords.add(GpsRecord(
        employee: employee,
        date: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
        location:
            'Lat: ${pos.latitude.toStringAsFixed(6)}, Lng: ${pos.longitude.toStringAsFixed(6)}',
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      ));
    });
  }

  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
