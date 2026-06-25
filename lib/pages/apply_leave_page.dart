import 'package:flutter/material.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
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
    'Medical / Sick Leave',
    'Earned Leave',
    'Maternity Leave',
    'Paternity Leave',
    'To Vote',
    'Personal Leave',
    'Funeral / Bereavement',
    'LOP or Others',
  ];

  DateTime? _fromDate;
  DateTime? _toDate;
  String _leaveType  = 'Casual Leave';
  bool   _isHalfDay  = false;
  final _reasonController = TextEditingController();

  int    _monthlyAllocation = 0;
  double _usedThisMonth     = 0.0;

  double get _remainingThisMonth =>
      (_monthlyAllocation - _usedThisMonth).clamp(0.0, _monthlyAllocation.toDouble());

  /// Calendar days selected (always >= 1).
  int get _calendarDays {
    if (_fromDate == null || _toDate == null) return 0;
    return _toDate!.difference(_fromDate!).inDays + 1;
  }

  /// Effective deduction: 0.5 for half-day, full count otherwise.
  double get _effectiveDays {
    if (_fromDate == null) return 0.0;
    if (_isHalfDay) return 0.5;
    if (_toDate == null) return 0.0;
    return _calendarDays.toDouble();
  }

  String _fmtEffective(double d) =>
      d == d.truncateToDouble() ? '${d.toInt()} day${d.toInt() == 1 ? '' : 's'}' : '½ day';

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final results = await Future.wait([
        UserStore.load(),
        SupabaseService.fetchLeaveApplications(),
      ]);
      final users  = results[0] as List;
      final leaves = results[1] as List<LeaveApplication>;

      final match = users.where((u) => u.name == UserSession.name).toList();
      final allocation = match.isNotEmpty ? (match.first.leaveAllocation as int) : 21;

      final now = DateTime.now();
      final used = leaves
          .where((a) =>
              a.employeeName == UserSession.name &&
              a.managerStatus == LeaveApprovalStatus.approved &&
              a.from.year == now.year &&
              a.from.month == now.month)
          .fold(0.0, (s, a) => s + a.effectiveDays);

      if (mounted) setState(() { _monthlyAllocation = allocation; _usedThisMonth = used; });
    } catch (_) {}
  }

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
        if (_isHalfDay) {
          _toDate = picked; // half day is always a single date
        } else if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = null;
        }
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

  void _submit() {
    if (_fromDate == null || (!_isHalfDay && _toDate == null)) {
      _showSnack('Please select from and to dates.', Colors.red);
      return;
    }
    if (_monthlyAllocation > 0 && _effectiveDays > _remainingThisMonth) {
      final rem = _remainingThisMonth == 0.5 ? '½' : '$_remainingThisMonth';
      _showSnack(
        'Only $rem day(s) remaining this month. Cannot apply for ${_fmtEffective(_effectiveDays)}.',
        Colors.red,
      );
      return;
    }

    final toDate = _isHalfDay ? _fromDate! : _toDate!;
    final app = LeaveApplication(
      id:           LeaveStore.generateId(),
      employeeName: UserSession.name.isEmpty ? 'Employee' : UserSession.name,
      department:   '',
      leaveType:    _leaveType,
      from:         _fromDate!,
      to:           toDate,
      days:         _isHalfDay ? 1 : _calendarDays,
      reason:       _reasonController.text.trim(),
      appliedOn:    DateTime.now(),
    )
      ..isHalfDay = _isHalfDay;
    LeaveStore.applications.add(app);
    SupabaseService.saveLeaveApplication(app);

    _showSnack('Leave application submitted successfully.', _color);
    _clear();
  }

  void _clear() {
    setState(() {
      _fromDate  = null;
      _toDate    = null;
      _leaveType = 'Casual Leave';
      _isHalfDay = false;
    });
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
                    // Leave type dropdown
                    DropdownButtonFormField<String>(
                      value: _leaveType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Leave Type',
                        prefixIcon: const Icon(Icons.label_rounded, color: _color, size: 20),
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
                      ),
                      items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) { if (v != null) setState(() => _leaveType = v); },
                    ),
                    const SizedBox(height: 14),

                    // Half day / Full day toggle
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isHalfDay = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isHalfDay ? _color : Colors.white,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                              border: Border.all(color: _color.withValues(alpha: 0.5)),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.wb_sunny_rounded, size: 15,
                                  color: !_isHalfDay ? Colors.white : _color),
                              const SizedBox(width: 6),
                              Text('Full Day', style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: !_isHalfDay ? Colors.white : _color)),
                            ]),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isHalfDay = true;
                            if (_fromDate != null) _toDate = _fromDate;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isHalfDay ? _color : Colors.white,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              border: Border.all(color: _color.withValues(alpha: 0.5)),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.brightness_3_rounded, size: 15,
                                  color: _isHalfDay ? Colors.white : _color),
                              const SizedBox(width: 6),
                              Text('Half Day', style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: _isHalfDay ? Colors.white : _color)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

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
                        label: _isHalfDay ? 'Date' : 'To Date',
                        date: _isHalfDay ? _fromDate : _toDate,
                        onTap: _isHalfDay ? () {} : _pickTo,
                        color: _color,
                        disabled: _isHalfDay,
                      )),
                    ]),

                    // Day count pill
                    if (_effectiveDays > 0) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _fmtEffective(_effectiveDays),
                            style: const TextStyle(
                                color: _color,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Monthly balance strip
                    if (_monthlyAllocation > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _remainingThisMonth > 0
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _remainingThisMonth > 0
                                ? const Color(0xFFA5D6A7)
                                : const Color(0xFFEF9A9A),
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            _remainingThisMonth > 0
                                ? Icons.event_available_rounded
                                : Icons.event_busy_rounded,
                            size: 16,
                            color: _remainingThisMonth > 0
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This month: ${_fmtEffective(_usedThisMonth)} used · ${_fmtEffective(_remainingThisMonth)} remaining of $_monthlyAllocation',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _remainingThisMonth > 0
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ),
                        ]),
                      ),

                    const SizedBox(height: 16),

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
  final bool disabled;
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    required this.color,
    this.disabled = false,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFFF5F5F5)
              : (date != null ? color.withValues(alpha: 0.05) : Colors.white),
          border: Border.all(
            color: disabled
                ? const Color(0xFFE0E0E0)
                : (date != null ? color.withValues(alpha: 0.4) : const Color(0xFFE0E0E0)),
            width: date != null && !disabled ? 1.5 : 1,
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
