import 'package:flutter/material.dart';
import '../models/attendance_store.dart';
import '../models/user_session.dart';
import '../services/gps_tracking_service.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';

class CheckOutPage extends StatefulWidget {
  const CheckOutPage({super.key});

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  static const _color = Color(0xFF1565C0);

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
        content: const Text('Please fill in the check-out time'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      return;
    }
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    AttendanceStore.checkOuts.add(CheckOutRecord(
      employee: UserSession.name.isNotEmpty ? UserSession.name : 'Employee',
      date: date,
      time: _timeController.text,
      location: '—',
    ));
    GpsTrackingService.stop();
    AttendanceStore.isCheckedIn = false;
    SupabaseService.saveCheckOut(
      employeeId: UserSession.employeeId,
      date: date,
      time: _timeController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Checked out — GPS tracking stopped'),
      backgroundColor: _color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
                child:
                    const Icon(Icons.logout_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Check Out',
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
                      labelText: 'Check-Out Time',
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.withValues(alpha: 0.12)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? Colors.orange.shade700
                                : Colors.orange.shade300),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: Colors.orange.shade500,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'GPS tracking is active — will stop on check-out',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange.shade800,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Check Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
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
