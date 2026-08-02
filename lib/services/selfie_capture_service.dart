import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/user_session.dart';

/// Whether the signed-in user must supply a selfie to check in or out.
///
/// Management works to no fixed hours and no fixed location, and their
/// attendance is oversight rather than a record anyone audits, so the selfie
/// adds nothing. Derived from the ROLE in ONE place rather than repeated at
/// each of the six capture sites — the late-reason prompt was raised in three
/// separate files and fixing only one of them cost several rounds.
bool get selfieRequiredForCurrentUser =>
    UserSession.role != UserRole.management;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/image_compress.dart';
import 'gps_tracking_service.dart';
import 'supabase_service.dart';

/// Mandatory attendance selfie: opens the device camera directly (never the
/// gallery), burns the date/day/time/GPS coordinates into the photo, then
/// compresses it to the app's shared ~200KB target. Used by every
/// check-in/check-out entry point so the requirement can't be bypassed by
/// picking a different screen.
class SelfieCaptureService {
  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  /// Returns the final compressed JPEG bytes, or null if the employee
  /// cancelled the camera, the shot couldn't be processed, or it couldn't be
  /// compressed under the size cap — callers must treat null as "selfie
  /// required" and block the check-in/out rather than proceeding without one.
  static Future<Uint8List?> capture({required String label}) async {
    XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600,
        imageQuality: 90,
      );
    } catch (_) {
      return null;
    }
    if (shot == null) return null;

    final pos = await GpsTrackingService.getCurrentLocation();
    final rawBytes = await shot.readAsBytes();

    Uint8List watermarked;
    try {
      watermarked = await _drawWatermark(rawBytes, _lines(label, DateTime.now(), pos));
    } catch (_) {
      return null;
    }

    return compressImage(watermarked, 'image/png');
  }

  /// Captures + uploads in one step, for the three check-in/out entry
  /// points that all need identical "no selfie, no check-in/out" behavior.
  /// Returns the storage path, or null if the employee cancelled the camera
  /// or the shot couldn't be captured/compressed/uploaded — callers must
  /// treat null as a hard stop, not a skip.
  static Future<String?> captureAndUpload({
    required String employeeId,
    required String date, // 'dd/MM/yyyy'
    required String kind, // 'checkin' | 'checkout'
    required String label, // 'Check-In' | 'Check-Out'
  }) async {
    final bytes = await capture(label: label);
    if (bytes == null) return null;
    return SupabaseService.uploadAttendanceSelfie(
      employeeId: employeeId,
      date: date,
      kind: kind,
      bytes: bytes,
    );
  }

  static List<String> _lines(String label, DateTime now, Position? pos) {
    final date =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final day = _days[now.weekday - 1];
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final loc = pos != null
        ? 'GPS: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}'
        : 'GPS: unavailable';
    return ['$label — $date', day, time, loc];
  }

  static Future<Uint8List> _drawWatermark(Uint8List sourceBytes, List<String> lines) async {
    final codec = await ui.instantiateImageCodec(sourceBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final w = image.width.toDouble();
    final h = image.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawImage(image, Offset.zero, Paint());

    final fontSize = (w * 0.032).clamp(14.0, 34.0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: lines.join('\n'),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.35,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 24);

    final bandHeight = textPainter.height + 24;
    canvas.drawRect(
      Rect.fromLTWH(0, h - bandHeight, w, bandHeight),
      Paint()..color = const Color(0xB3000000),
    );
    textPainter.paint(canvas, Offset(12, h - bandHeight + 12));

    final picture = recorder.endRecording();
    final outImage = await picture.toImage(image.width, image.height);
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
