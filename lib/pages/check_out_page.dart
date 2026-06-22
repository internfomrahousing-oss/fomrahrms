import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_store.dart';
import '../widgets/back_button.dart';

class CheckOutPage extends StatefulWidget {
  const CheckOutPage({super.key});

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  static const _color = Color(0xFF1565C0);

  final _timeController     = TextEditingController();
  final _locationController = TextEditingController();

  bool _detectingLocation = false;
  String? _locationError;

  @override
  void dispose() {
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() { _detectingLocation = true; _locationError = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Location permission denied.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _locationController.text =
          'Lat: ${position.latitude.toStringAsFixed(6)}, '
          'Lng: ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      setState(() => _locationError = 'Unable to detect location.');
    } finally {
      setState(() => _detectingLocation = false);
    }
  }

  void _autoFillTime() {
    final now = DateTime.now();
    _timeController.text =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _onSave() {
    if (_timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please fill in the check-out time'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      return;
    }
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
    AttendanceStore.checkOuts.add(CheckOutRecord(
      employee: 'Employee',
      date: date,
      time: _timeController.text,
      location: _locationController.text.isEmpty ? '—' : _locationController.text,
    ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Check-Out saved successfully'),
      backgroundColor: _color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
    _onClear();
  }

  void _onClear() {
    _timeController.clear();
    _locationController.clear();
    setState(() => _locationError = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                child: const Icon(Icons.logout_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Check Out', style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [

                  // Check-Out Time
                  TextField(
                    controller: _timeController,
                    decoration: InputDecoration(
                      labelText: 'Check-Out Time',
                      prefixIcon: const Icon(Icons.access_time_rounded, color: _color, size: 20),
                      suffixIcon: IconButton(
                        tooltip: 'Use current time',
                        icon: const Icon(Icons.schedule_rounded, color: _color),
                        onPressed: _autoFillTime,
                      ),
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
                  ),
                  const SizedBox(height: 20),

                  // GPS Location with auto-detect
                  TextField(
                    controller: _locationController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'GPS Location',
                      prefixIcon: const Icon(Icons.location_on_rounded, color: _color, size: 20),
                      suffixIcon: _detectingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _color),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Detect my location',
                              icon: const Icon(Icons.my_location_rounded, color: _color),
                              onPressed: _detectLocation,
                            ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _locationError != null ? Colors.red : const Color(0xFFE0E0E0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _color, width: 2),
                      ),
                      filled: true, fillColor: Colors.white,
                      labelStyle: const TextStyle(color: Color(0xFF78909C)),
                      errorText: _locationError,
                      hintText: 'Tap  to auto-detect location',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFB0BEC5)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _onClear,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _onSave,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Check Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
