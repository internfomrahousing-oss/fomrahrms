import 'package:flutter/material.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';

class ApplyLeavePage extends StatefulWidget {
  const ApplyLeavePage({super.key});

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  static const _color = Color(0xFF0D47A1);

  static const _leaveTypes = [
    'Casual Leave',
    'Sick Leave',
    'Earned Leave',
    'House Visit',
    'Outdoor Duty',
  ];

  DateTime? _fromDate;
  DateTime? _toDate;
  String _leaveType = 'Casual Leave';
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _color),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = null;
      });
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? (_fromDate ?? DateTime.now()),
      firstDate: _fromDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _color),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  int get _numDays {
    if (_fromDate == null || _toDate == null) return 0;
    return _toDate!.difference(_fromDate!).inDays + 1;
  }

  void _submit() {
    if (_fromDate == null || _toDate == null) {
      _showSnack('Please select from and to dates.', Colors.red);
      return;
    }

    final app = LeaveApplication(
      id:           LeaveStore.generateId(),
      employeeName: UserSession.name.isEmpty ? 'Employee' : UserSession.name,
      department:   '',
      leaveType:    _leaveType,
      from:         _fromDate!,
      to:           _toDate!,
      days:         _numDays,
      reason:       _reasonController.text.trim(),
      appliedOn:    DateTime.now(),
    );
    LeaveStore.applications.add(app);
    SupabaseService.saveLeaveApplication(app);

    _showSnack('Leave application submitted successfully.', _color);
    _clear();
  }

  void _clear() {
    setState(() { _fromDate = null; _toDate = null; _leaveType = 'Casual Leave'; });
    _reasonController.clear();
  }

  void _showSnack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
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
                child: const Icon(Icons.event_available_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Apply Leave', style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // From / To date row
                    Row(children: [
                      Expanded(child: _DateTile(
                        label: 'From Date',
                        date: _fromDate,
                        onTap: _pickFrom,
                        color: _color,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _DateTile(
                        label: 'To Date',
                        date: _toDate,
                        onTap: _pickTo,
                        color: _color,
                      )),
                    ]),

                    // Day count pill
                    if (_numDays > 0) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_numDays day${_numDays == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: _color,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Reason
                    TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Reason',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.notes_rounded, color: _color, size: 20),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit Application'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final Color color;
  const _DateTile({required this.label, required this.date, required this.onTap, required this.color});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: date != null ? color.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: date != null ? color.withValues(alpha: 0.4) : const Color(0xFFE0E0E0),
            width: date != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: date != null ? color : const Color(0xFF78909C),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: date != null ? color : const Color(0xFF90A4AE)),
            const SizedBox(width: 8),
            Text(
              date != null ? _fmt(date!) : 'Select date',
              style: TextStyle(
                fontSize: 13,
                fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                color: date != null ? const Color(0xFF1A237E) : const Color(0xFF90A4AE),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
