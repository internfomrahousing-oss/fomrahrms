import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/leave_form_config.dart';
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
  static const _color = Color(0xFF2563EB);

  // Populated from Supabase config; falls back to LeaveFormConfig defaults.
  List<String> _allLeaveTypes = List<String>.from(LeaveFormConfig.defaultLeaveTypes);

  DateTime? _fromDate;
  DateTime? _toDate;
  String _leaveType  = 'Casual Leave';
  bool   _isHalfDay  = false;
  final _reasonController = TextEditingController();

  double _usedCl       = 0.0;
  double _usedMl       = 0.0;
  double _usedEl       = 0.0;
  int    _accruedEl    = 0;
  bool   _isOnroll     = false;
  bool   _isElEligible = false;

  List<String> get _leaveTypes {
    if (_isElEligible) {
      return _allLeaveTypes; // all types
    }
    if (_isOnroll) {
      return _allLeaveTypes
          .where((t) => t != 'Earned Leave')
          .toList();
    }
    // Probation: CL only (+ special types like maternity, bereavement etc.)
    return _allLeaveTypes
        .where((t) => t != 'Earned Leave' && t != 'Medical / Sick Leave')
        .toList();
  }

  String get _bucketLabel {
    switch (LeaveStore.effectiveBucket(_leaveType)) {
      case 'ML':  return 'Medical Leave';
      case 'EL':  return 'Earned Leave';
      case 'LOP': return 'LOP';
      default:    return 'Casual Leave';
    }
  }

  double get _usedForBucket {
    switch (LeaveStore.effectiveBucket(_leaveType)) {
      case 'ML': return _usedMl;
      case 'EL': return _usedEl;
      default:   return _usedCl;
    }
  }

  double get _remaining {
    final bucket = LeaveStore.effectiveBucket(_leaveType);
    switch (bucket) {
      case 'ML':  return _isOnroll ? (1.0 - _usedMl).clamp(0.0, 1.0) : 0.0;
      case 'EL':  return (_accruedEl.toDouble() - _usedEl).clamp(0.0, _accruedEl.toDouble());
      case 'LOP': return double.infinity;
      default:    return (1.0 - _usedCl).clamp(0.0, 1.0);
    }
  }

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
    // Load form config first (uses in-memory cache after first fetch).
    try {
      Map<String, dynamic> cfg;
      if (LeaveFormConfig.cached != null) {
        cfg = LeaveFormConfig.cached!;
      } else {
        final active = await SupabaseService.fetchActiveLeaveFormConfig();
        cfg = active != null
            ? Map<String, dynamic>.from(active['form_config'] as Map)
            : LeaveFormConfig.defaults();
        LeaveFormConfig.setCache(cfg);
      }
      final types = LeaveFormConfig.getLeaveTypes(cfg);
      if (mounted) setState(() => _allLeaveTypes = types);
    } catch (_) {}

    try {
      final results = await Future.wait([
        UserStore.load(),
        SupabaseService.fetchLeaveApplications(),
      ]);
      final users  = (results[0] as List).cast<AppUser>();
      final leaves = results[1] as List<LeaveApplication>;

      final matches = users.where((u) => u.name == UserSession.name).toList();
      final me      = matches.isNotEmpty ? matches.first : null;

      // EL cutoff for cumulative tracking
      DateTime? elCutoff;
      if (me != null && me.isElEligible) {
        final ref = me.elLastAvailedAt.isNotEmpty ? me.elLastAvailedAt : me.elEligibleAt;
        elCutoff = ref.isNotEmpty ? DateTime.tryParse(ref) : null;
      }

      // Per-bucket usage
      final now = DateTime.now();
      double usedCl = 0, usedMl = 0, usedEl = 0;
      for (final a in leaves) {
        if (a.employeeName != UserSession.name ||
            a.managerStatus != LeaveApprovalStatus.approved) continue;
        final bucket = LeaveStore.effectiveBucket(a.leaveType);
        if (bucket == 'CL' && a.from.year == now.year && a.from.month == now.month) {
          usedCl += a.effectiveDays;
        } else if (bucket == 'ML' && a.from.year == now.year && a.from.month == now.month) {
          usedMl += a.effectiveDays;
        } else if (bucket == 'EL' && (elCutoff == null || a.from.isAfter(elCutoff))) {
          usedEl += a.effectiveDays;
        }
      }

      // EL accrual
      int accruedEl = 0;
      if (me != null && me.isElEligible) {
        final ref = me.elLastAvailedAt.isNotEmpty ? me.elLastAvailedAt : me.elEligibleAt;
        if (ref.isNotEmpty) {
          final cut = DateTime.tryParse(ref);
          if (cut != null) {
            final months = (now.year - cut.year) * 12 + (now.month - cut.month);
            accruedEl = (months * me.monthlyEl).clamp(0, 9999);
          }
        }
      }

      if (mounted) setState(() {
        _usedCl       = usedCl;
        _usedMl       = usedMl;
        _usedEl       = usedEl;
        _accruedEl    = accruedEl;
        _isOnroll     = me?.isOnroll     ?? false;
        _isElEligible = me?.isElEligible ?? false;
        if (!_leaveTypes.contains(_leaveType)) _leaveType = _leaveTypes.first;
      });
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

  Future<void> _submit() async {
    if (_fromDate == null || (!_isHalfDay && _toDate == null)) {
      _showSnack('Please select from and to dates.', Colors.red);
      return;
    }

    // If bucket balance exceeded, show unpaid-leave T&C dialog before proceeding
    if (_remaining != double.infinity && _effectiveDays > _remaining) {
      final agreed = await _showUnpaidDialog();
      if (!agreed) return;
    }

    _doSubmit();
  }

  Future<bool> _showUnpaidDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Unpaid Leave Notice',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'Your monthly leave balance is exhausted.',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By proceeding, you acknowledge that:',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                  const SizedBox(height: 6),
                  _TcPoint('This leave will be treated as Loss of Pay (LOP).'),
                  _TcPoint('Salary will be deducted for the days applied.'),
                  _TcPoint('This is subject to manager / management approval.'),
                  _TcPoint('LOP entries are recorded in your attendance.'),
                ]),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('I Agree — Apply as LOP'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _doSubmit() {
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
      backgroundColor: null,
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
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _color, width: 2),
                        ),
                        filled: true, fillColor: Colors.white,
                        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
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

                    // Balance strip for the selected leave bucket
                    if (LeaveStore.effectiveBucket(_leaveType) != 'LOP')
                      Builder(builder: (ctx) {
                        final hasBalance = _remaining > 0;
                        final fg = hasBalance
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444);
                        final bg = hasBalance
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2);
                        final border = hasBalance
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Row(children: [
                            Icon(
                              hasBalance
                                  ? Icons.event_available_rounded
                                  : Icons.event_busy_rounded,
                              size: 16, color: fg,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_bucketLabel: ${_fmtEffective(_usedForBucket)} used'
                                ' · ${_remaining == double.infinity ? '∞' : _fmtEffective(_remaining)} remaining',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: fg),
                              ),
                            ),
                          ]),
                        );
                      }),

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

class _TcPoint extends StatelessWidget {
  final String text;
  const _TcPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.circle, size: 5, color: Colors.orange.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
        ),
      ]),
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
              ? const Color(0xFFF8FAFC)
              : (date != null ? color.withValues(alpha: 0.05) : Colors.white),
          border: Border.all(
            color: disabled
                ? const Color(0xFFE5E7EB)
                : (date != null ? color.withValues(alpha: 0.4) : const Color(0xFFE5E7EB)),
            width: date != null && !disabled ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: date != null ? color : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: date != null ? color : const Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              date != null ? _fmt(date!) : 'Select date',
              style: TextStyle(
                fontSize: 13,
                fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                color: date != null ? const Color(0xFF111827) : const Color(0xFF6B7280),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
