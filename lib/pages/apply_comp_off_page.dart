import 'package:flutter/material.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';

class ApplyCompOffPage extends StatefulWidget {
  const ApplyCompOffPage({super.key});

  @override
  State<ApplyCompOffPage> createState() => _ApplyCompOffPageState();
}

class _ApplyCompOffPageState extends State<ApplyCompOffPage> {
  static const _color = Color(0xFF2E7D32);

  static const _reasons = [
    'Public Holiday Comp Off',
    'Week Off Comp Off',
    'Site Visit',
    'Leave Comp Off',
    'On Duty',
    'Others',
  ];

  DateTime? _workedDate;
  DateTime? _claimDate;
  String _reason = 'Public Holiday Comp Off';
  final _othersController = TextEditingController();
  final _descController   = TextEditingController();

  bool get _isOthers => _reason == 'Others';

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void dispose() {
    _othersController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickWorked() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _color)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _workedDate = picked);
  }

  Future<void> _pickClaim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _claimDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _color)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _claimDate = picked);
  }

  void _submit() {
    if (_workedDate == null || _claimDate == null) {
      _snack('Please select both dates.'); return;
    }
    if (_isOthers && _othersController.text.trim().isEmpty) {
      _snack('Please specify the reason.'); return;
    }
    final reasonText = _isOthers ? _othersController.text.trim() : _reason;
    final desc       = _descController.text.trim();
    final note = 'Worked on: ${_fmtDate(_workedDate!)} | $reasonText'
        '${desc.isNotEmpty ? ' | $desc' : ''}';

    final app = LeaveApplication(
      id:           LeaveStore.generateId(),
      employeeName: UserSession.name.isEmpty ? 'Employee' : UserSession.name,
      department:   '',
      leaveType:    'Comp Off',
      from:         _claimDate!,
      to:           _claimDate!,
      days:         1,
      reason:       note,
      appliedOn:    DateTime.now(),
    );

    LeaveStore.applications.add(app);
    SupabaseService.saveLeaveApplication(app);

    _snack('Comp Off request submitted successfully.');
    _clear();
  }

  void _clear() {
    setState(() {
      _workedDate = null;
      _claimDate  = null;
      _reason     = 'Public Holiday Comp Off';
    });
    _othersController.clear();
    _descController.clear();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
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
    filled: true,
    fillColor: Colors.white,
    labelStyle: const TextStyle(color: Color(0xFF78909C)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ────────────────────────────────────────────────────
          Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.swap_horiz_rounded, color: _color, size: 26),
            ),
            const SizedBox(width: 16),
            Text('Apply Comp Off',
                style: Theme.of(context).textTheme.headlineMedium),
          ]),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date worked ───────────────────────────────────────
                  _DateField(
                    label: 'Date Worked',
                    hint: 'Select holiday / weekend worked',
                    date: _workedDate,
                    color: _color,
                    onTap: _pickWorked,
                    fmt: _fmtDate,
                  ),
                  const SizedBox(height: 14),

                  // ── Claim date ────────────────────────────────────────
                  _DateField(
                    label: 'Comp Off Date',
                    hint: 'Select day off you want',
                    date: _claimDate,
                    color: _color,
                    onTap: _pickClaim,
                    fmt: _fmtDate,
                  ),
                  const SizedBox(height: 16),

                  // ── Reason dropdown ───────────────────────────────────
                  DropdownButtonFormField<String>(
                    value: _reason,
                    isExpanded: true,
                    decoration: _deco('Reason for Request', Icons.label_rounded),
                    items: _reasons
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) { if (v != null) setState(() => _reason = v); },
                  ),

                  // ── Others text field ─────────────────────────────────
                  if (_isOthers) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _othersController,
                      decoration: _deco('Specify reason', Icons.edit_rounded),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Description ───────────────────────────────────────
                  TextField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 72),
                        child: Icon(Icons.notes_rounded, color: _color, size: 20),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _color, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      labelStyle: const TextStyle(color: Color(0xFF78909C)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Buttons ───────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _color,
                  side: const BorderSide(color: _color),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Apply Comp Off'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String hint;
  final DateTime? date;
  final Color color;
  final VoidCallback onTap;
  final String Function(DateTime) fmt;
  const _DateField({
    required this.label, required this.hint, required this.date,
    required this.color, required this.onTap, required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: date != null ? color.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: date != null
                ? color.withValues(alpha: 0.4)
                : const Color(0xFFE0E0E0),
            width: date != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 18,
              color: date != null ? color : const Color(0xFF90A4AE)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: date != null ? color : const Color(0xFF78909C),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              date != null ? fmt(date!) : hint,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    date != null ? FontWeight.w600 : FontWeight.normal,
                color: date != null
                    ? const Color(0xFF1A237E)
                    : const Color(0xFF90A4AE),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
