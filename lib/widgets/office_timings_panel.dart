import 'package:flutter/material.dart';
import '../constants/org_lists.dart';
import '../models/office_timing.dart';
import '../services/supabase_service.dart';
import '../utils/token_util.dart';
import '../theme/app_theme.dart';

/// Create, edit, and assign department-based working-hours schedules
/// ("Office Timings"). Direct-edit, no approval workflow — every save
/// takes effect immediately, and every attendance calculation (late/early/
/// overtime) resolves an employee's schedule live from their current
/// department, so a reassignment here or a department change takes
/// effect on the very next check-in.
///
/// Embedded as a tab inside LocationManagementPage — no Scaffold/back
/// button of its own, since the host page provides those.
class OfficeTimingsPanel extends StatefulWidget {
  const OfficeTimingsPanel({super.key});

  @override
  State<OfficeTimingsPanel> createState() => _OfficeTimingsPanelState();
}

class _OfficeTimingsPanelState extends State<OfficeTimingsPanel> {
  bool _loading = true;
  List<OfficeTiming> _timings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await OfficeTimingStore.refresh();
    if (!mounted) return;
    setState(() {
      _timings = OfficeTimingStore.all;
      _loading = false;
    });
  }

  Future<void> _openEditor({OfficeTiming? existing}) async {
    final assigned = existing != null
        ? OfficeTimingStore.departmentsFor(existing.id).toSet()
        : <String>{};
    final result = await showDialog<_TimingDraft>(
      context: context,
      builder: (_) => _OfficeTimingDialog(existing: existing, initialAssigned: assigned),
    );
    if (result == null || !mounted) return;

    final id = existing?.id ?? TokenUtil.generate();
    final timing = OfficeTiming(
      id: id,
      name: result.name,
      checkInTime: result.checkInTime,
      checkOutTime: result.checkOutTime,
      graceMinutes: result.graceMinutes,
      workingHours: result.workingHours,
      isDefault: existing?.isDefault ?? false,
    );
    final error = await SupabaseService.saveOfficeTiming(timing);
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $error'),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    // Reconcile department assignments: newly checked → assign, unchecked
    // (that were previously assigned to this timing) → revert to default.
    for (final d in result.assignedDepartments.difference(assigned)) {
      await SupabaseService.assignDepartmentToTiming(d, id);
    }
    for (final d in assigned.difference(result.assignedDepartments)) {
      await SupabaseService.unassignDepartmentTiming(d);
    }

    OfficeTimingStore.invalidate();
    if (mounted) await _load();
  }

  Future<void> _delete(OfficeTiming t) async {
    if (t.isDefault) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Office Timing'),
        content: Text(
            'Delete "${t.name}"? Any department assigned to it will revert to the default timing.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseService.deleteOfficeTiming(t.id);
    OfficeTimingStore.invalidate();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Office Timings',
              style: Theme.of(context).textTheme.titleLarge)),
          ElevatedButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Office Timing'),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          'Each department is assigned one Office Timing, which drives late-arrival, '
          'early-checkout, and overtime calculations across the app. Departments with no '
          'explicit assignment use the default timing.',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final t in _timings)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TimingCard(
                timing: t,
                assignedDepartments: OfficeTimingStore.departmentsFor(t.id),
                onEdit: () => _openEditor(existing: t),
                onDelete: t.isDefault ? null : () => _delete(t),
              ),
            ),
      ]),
    );
  }
}

class _TimingCard extends StatelessWidget {
  final OfficeTiming timing;
  final List<String> assignedDepartments;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  const _TimingCard({
    required this.timing,
    required this.assignedDepartments,
    required this.onEdit,
    this.onDelete,
  });

  Widget _stat(BuildContext context, IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Row(children: [
                Text(timing.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (timing.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Default',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                  ),
                ],
              ]),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_rounded, size: 19),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: onDelete == null ? 'The default timing cannot be deleted' : 'Delete',
              icon: Icon(Icons.delete_outline_rounded, size: 19,
                  color: onDelete == null ? Theme.of(context).disabledColor : Colors.red.shade600),
              onPressed: onDelete,
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 8, children: [
            _stat(context, Icons.login_rounded, 'In ${timing.checkInTime}'),
            _stat(context, Icons.logout_rounded, 'Out ${timing.checkOutTime}'),
            _stat(context, Icons.timer_outlined, '${timing.graceMinutes}m grace'),
            _stat(context, Icons.hourglass_bottom_rounded, '${timing.workingHours}h working'),
          ]),
          if (assignedDepartments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: assignedDepartments
                .map((d) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(d, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ))
                .toList()),
          ] else if (!timing.isDefault) ...[
            const SizedBox(height: 10),
            Text('No departments assigned yet',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ]),
      ),
    );
  }
}

class _TimingDraft {
  final String name;
  final String checkInTime;
  final String checkOutTime;
  final int graceMinutes;
  final double workingHours;
  final Set<String> assignedDepartments;
  const _TimingDraft({
    required this.name,
    required this.checkInTime,
    required this.checkOutTime,
    required this.graceMinutes,
    required this.workingHours,
    required this.assignedDepartments,
  });
}

class _OfficeTimingDialog extends StatefulWidget {
  final OfficeTiming? existing;
  final Set<String> initialAssigned;
  const _OfficeTimingDialog({this.existing, required this.initialAssigned});

  @override
  State<_OfficeTimingDialog> createState() => _OfficeTimingDialogState();
}

class _OfficeTimingDialogState extends State<_OfficeTimingDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _graceCtrl;
  late final TextEditingController _hoursCtrl;
  late TimeOfDay _checkIn;
  late TimeOfDay _checkOut;
  late Set<String> _selectedDepartments;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _graceCtrl = TextEditingController(text: (t?.graceMinutes ?? 10).toString());
    _hoursCtrl = TextEditingController(text: (t?.workingHours ?? 8).toString());
    _checkIn = _parseTime(t?.checkInTime) ?? const TimeOfDay(hour: 9, minute: 30);
    _checkOut = _parseTime(t?.checkOutTime) ?? const TimeOfDay(hour: 18, minute: 30);
    _selectedDepartments = Set<String>.from(widget.initialAssigned);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _graceCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickCheckIn() async {
    final picked = await showTimePicker(context: context, initialTime: _checkIn);
    if (picked != null) setState(() => _checkIn = picked);
  }

  Future<void> _pickCheckOut() async {
    final picked = await showTimePicker(context: context, initialTime: _checkOut);
    if (picked != null) setState(() => _checkOut = picked);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name for this timing.');
      return;
    }
    final grace = int.tryParse(_graceCtrl.text.trim());
    if (grace == null || grace < 0) {
      setState(() => _error = 'Grace period must be a whole number of minutes.');
      return;
    }
    final hours = double.tryParse(_hoursCtrl.text.trim());
    if (hours == null || hours <= 0) {
      setState(() => _error = 'Working hours must be a positive number.');
      return;
    }
    Navigator.pop(context, _TimingDraft(
      name: name,
      checkInTime: _fmtTime(_checkIn),
      checkOutTime: _fmtTime(_checkOut),
      graceMinutes: grace,
      workingHours: hours,
      assignedDepartments: _selectedDepartments,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(widget.existing == null ? 'Add Office Timing' : 'Edit Office Timing'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Early Shift'),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCheckIn,
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: Text('In: ${_fmtTime(_checkIn)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCheckOut,
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: Text('Out: ${_fmtTime(_checkOut)}'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _graceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Grace (minutes)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _hoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Working hours'),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Text('Assign to departments',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Checking a department moves it off any other timing it was assigned to.',
                style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: kDepartments.map((d) {
              final selected = _selectedDepartments.contains(d);
              return FilterChip(
                label: Text(d, style: const TextStyle(fontSize: 12.5)),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedDepartments.add(d);
                  } else {
                    _selectedDepartments.remove(d);
                  }
                }),
              );
            }).toList()),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
