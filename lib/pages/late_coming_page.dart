import 'package:flutter/material.dart';
import '../models/attendance_store.dart';
import '../widgets/back_button.dart';

class LateComingPage extends StatefulWidget {
  const LateComingPage({super.key});

  @override
  State<LateComingPage> createState() => _LateComingPageState();
}

class _LateComingPageState extends State<LateComingPage> {
  static const _color = Color(0xFF111827);

  final _timeCtrl   = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _date = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
    _autoFillTime();
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _autoFillTime() {
    final now = DateTime.now();
    _timeCtrl.text = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
  }

  void _onSave() {
    if (_timeCtrl.text.isEmpty || _reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please fill in all fields'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      return;
    }
    AttendanceStore.lateComing.add(LateComingRecord(
      employee:    'Employee',
      date:        _date,
      arrivalTime: _timeCtrl.text,
      reason:      _reasonCtrl.text.trim(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Late coming recorded successfully'),
      backgroundColor: _color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
    _timeCtrl.clear();
    _reasonCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.watch_later_rounded, color: _color, size: 26),
            ),
            const SizedBox(width: 16),
            Text('Late Coming', style: Theme.of(context).textTheme.headlineMedium),
          ]),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Date (read-only, auto-filled)
                TextField(
                  readOnly: true,
                  controller: TextEditingController(text: _date),
                  decoration: InputDecoration(
                    labelText: 'Date',
                    prefixIcon: const Icon(Icons.calendar_today_rounded, color: _color, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    filled: true, fillColor: const Color(0xFFF8FAFC),
                    labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
                const SizedBox(height: 16),

                // Arrival Time
                TextField(
                  controller: _timeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Arrival Time',
                    prefixIcon: const Icon(Icons.access_time_rounded, color: _color, size: 20),
                    suffixIcon: IconButton(
                      tooltip: 'Use current time',
                      icon: const Icon(Icons.schedule_rounded, color: _color),
                      onPressed: _autoFillTime,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _color, width: 2),
                    ),
                    filled: true, fillColor: Colors.white,
                    labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
                const SizedBox(height: 16),

                // Reason
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Reason for Late Coming',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 48),
                      child: Icon(Icons.notes_rounded, color: _color, size: 20),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _color, width: 2),
                    ),
                    filled: true, fillColor: Colors.white,
                    labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () { _timeCtrl.clear(); _reasonCtrl.clear(); },
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
                icon: const Icon(Icons.send_rounded),
                label: const Text('Submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
