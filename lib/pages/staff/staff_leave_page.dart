import 'package:flutter/material.dart';
import '../../models/leave_store.dart';
import '../../models/user_session.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// Staff Portal leave application: just a date and an Apply button — no
/// leave type, reason, or half-day picker, per the simplified spec.
class StaffLeavePage extends StatefulWidget {
  const StaffLeavePage({super.key});

  @override
  State<StaffLeavePage> createState() => _StaffLeavePageState();
}

class _StaffLeavePageState extends State<StaffLeavePage> {
  static Color get _color => AppTheme.primaryBlue;

  DateTime? _date;
  bool _submitting = false;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: _color)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_date == null) {
      _snack('Please select a leave date.');
      return;
    }
    setState(() => _submitting = true);

    final app = LeaveApplication(
      id:           LeaveStore.generateId(),
      employeeName: UserSession.name.isEmpty ? 'Employee' : UserSession.name,
      department:   UserSession.department,
      leaveType:    'Leave',
      from:         _date!,
      to:           _date!,
      days:         1,
      reason:       '',
      appliedOn:    DateTime.now(),
    );

    LeaveStore.applications.add(app);
    await SupabaseService.saveLeaveApplication(app);

    if (!mounted) return;
    setState(() { _submitting = false; _date = null; });
    _snack('Leave Request Submitted Successfully.');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      backgroundColor: _color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 8),
        Icon(Icons.event_busy_rounded, size: 48, color: _color),
        const SizedBox(height: 12),
        const Text('Apply Leave',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: _date != null ? _color.withValues(alpha: 0.06) : Colors.white,
              border: Border.all(
                  color: _date != null ? _color.withValues(alpha: 0.5) : const Color(0xFFE5E7EB),
                  width: _date != null ? 1.5 : 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded, size: 24, color: _color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Leave Date',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_date != null ? _fmt(_date!) : 'Select date',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _date != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF))),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Apply', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
