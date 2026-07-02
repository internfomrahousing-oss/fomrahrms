import 'package:flutter/material.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';

class ApplyPermissionPage extends StatefulWidget {
  const ApplyPermissionPage({super.key});

  @override
  State<ApplyPermissionPage> createState() => _ApplyPermissionPageState();
}

class _ApplyPermissionPageState extends State<ApplyPermissionPage> {
  static const _color = Color(0xFF00838F);

  DateTime? _date;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  String _permType = 'Late Arrival';
  final _reasonController = TextEditingController();

  static const _permTypes = ['Late Arrival', 'Early Departure', 'Short Leave'];

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _color)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickFrom() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _fromTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _color)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fromTime = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _toTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _color)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _toTime = picked);
  }

  void _submit() {
    if (_date == null) {
      _snack('Please select a date.'); return;
    }
    if (_fromTime == null || _toTime == null) {
      _snack('Please select from and to time.'); return;
    }

    final timeInfo = 'Permission: $_permType | ${_fmtTime(_fromTime!)} – ${_fmtTime(_toTime!)}';
    final reason   = _reasonController.text.trim();
    final fullNote = reason.isNotEmpty ? '$timeInfo | $reason' : timeInfo;

    final app = LeaveApplication(
      id:           LeaveStore.generateId(),
      employeeName: UserSession.name.isEmpty ? 'Employee' : UserSession.name,
      department:   '',
      leaveType:    'Permission',
      from:         _date!,
      to:           _date!,
      days:         1,
      reason:       fullNote,
      appliedOn:    DateTime.now(),
    )..isHalfDay = true;

    LeaveStore.applications.add(app);
    SupabaseService.saveLeaveApplication(app);

    _snack('Permission request submitted successfully.');
    setState(() {
      _date = null; _fromTime = null; _toTime = null;
      _permType = 'Late Arrival';
    });
    _reasonController.clear();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              child: const Icon(Icons.access_time_rounded, color: _color, size: 26),
            ),
            const SizedBox(width: 16),
            Text('Apply Permission', style: Theme.of(context).textTheme.headlineMedium),
          ]),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Permission type
                DropdownButtonFormField<String>(
                  value: _permType,
                  isExpanded: true,
                  decoration: _inputDeco('Permission Type', Icons.category_rounded),
                  items: _permTypes.map((t) =>
                      DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _permType = v); },
                ),
                const SizedBox(height: 14),

                // Date
                _DateTile(
                  label: 'Date',
                  value: _date != null ? _fmtDate(_date!) : null,
                  icon: Icons.calendar_today_rounded,
                  onTap: _pickDate,
                  color: _color,
                ),
                const SizedBox(height: 14),

                // From / To time
                Row(children: [
                  Expanded(child: _TimeTile(
                    label: 'From Time',
                    value: _fromTime != null ? _fmtTime(_fromTime!) : null,
                    onTap: _pickFrom,
                    color: _color,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _TimeTile(
                    label: 'To Time',
                    value: _toTime != null ? _fmtTime(_toTime!) : null,
                    onTap: _pickTo,
                    color: _color,
                  )),
                ]),
                const SizedBox(height: 14),

                // Reason
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: _inputDeco('Reason (optional)', Icons.notes_rounded),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit Permission Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _color, size: 20),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _DateTile extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _DateTile({required this.label, required this.value, required this.icon,
      required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: value != null ? color.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: value != null ? color.withValues(alpha: 0.4) : const Color(0xFFE0E0E0),
            width: value != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: value != null ? color : const Color(0xFF90A4AE)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11,
                color: value != null ? color : const Color(0xFF78909C),
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value ?? 'Select',
                style: TextStyle(fontSize: 13,
                    fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                    color: value != null ? const Color(0xFF1A237E) : const Color(0xFF90A4AE))),
          ]),
        ]),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final Color color;
  const _TimeTile({required this.label, required this.value,
      required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: value != null ? color.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: value != null ? color.withValues(alpha: 0.4) : const Color(0xFFE0E0E0),
            width: value != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.schedule_rounded, size: 18,
              color: value != null ? color : const Color(0xFF90A4AE)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11,
                color: value != null ? color : const Color(0xFF78909C),
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value ?? 'Select',
                style: TextStyle(fontSize: 13,
                    fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                    color: value != null ? const Color(0xFF1A237E) : const Color(0xFF90A4AE))),
          ]),
        ]),
      ),
    );
  }
}
