import 'package:flutter/material.dart';
import '../models/attendance_store.dart';
import '../models/user_session.dart';
import '../services/gps_tracking_service.dart';
import '../widgets/back_button.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  static const _color = Color(0xFF0D47A1);

  final _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _autoFillTime();
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  void _autoFillTime() {
    final now = DateTime.now();
    _timeController.text =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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
    AttendanceStore.checkIns.add(CheckInRecord(
      employee: UserSession.name.isNotEmpty ? UserSession.name : 'Employee',
      date: date,
      time: _timeController.text,
      location: '—',
    ));
    AttendanceStore.isCheckedIn = true;
    GpsTrackingService.start();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Checked in — GPS tracking started'),
      backgroundColor: _color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
    setState(() {});
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
                child: Column(children: [
                  TextField(
                    controller: _timeController,
                    decoration: InputDecoration(
                      labelText: 'Check-In Time',
                      prefixIcon: const Icon(Icons.access_time_rounded,
                          color: _color, size: 20),
                      suffixIcon: IconButton(
                        tooltip: 'Refresh time',
                        icon: const Icon(Icons.schedule_rounded, color: _color),
                        onPressed: _autoFillTime,
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _color, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      labelStyle:
                          const TextStyle(color: Color(0xFF78909C)),
                    ),
                  ),

                  if (AttendanceStore.isCheckedIn) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'GPS tracking active until check-out',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
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
