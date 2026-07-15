import 'package:flutter/material.dart';
import '../../l10n/staff_strings.dart';
import '../../models/language_notifier.dart';
import '../../models/leave_store.dart';
import '../../models/user_session.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'staff_history.dart';

// Canonical English values — stored as-is in LeaveApplication.reason so HR's
// (English-only) approval screens and LeaveStore.permMinutesFromReason keep
// working regardless of the Staff Portal's display language.
const _durations = ['30 Minutes', '1 Hour', '1 Hour 30 Minutes', '2 Hours'];
const _durationKeys = {
  '30 Minutes':         'duration_30m',
  '1 Hour':             'duration_1h',
  '1 Hour 30 Minutes':  'duration_1h30m',
  '2 Hours':            'duration_2h',
};

/// Staff Portal permission request: date + a radio-button duration picker,
/// capped at 2 requests per calendar month (count-based, not minutes-based —
/// see LeaveStore.permCountThisMonth). No reason/description field.
class StaffPermissionPage extends StatefulWidget {
  const StaffPermissionPage({super.key});

  @override
  State<StaffPermissionPage> createState() => _StaffPermissionPageState();
}

class _StaffPermissionPageState extends State<StaffPermissionPage> {
  static Color get _color => AppTheme.accentBlue;

  DateTime? _date;
  String _duration = _durations.first;
  bool _submitting = false;
  bool _loading = true;

  String get _employeeName => UserSession.name.isEmpty ? 'Employee' : UserSession.name;
  int get _usedThisMonth => LeaveStore.permCountThisMonth(_employeeName);
  bool get _limitReached => _usedThisMonth >= 2;

  List<LeaveApplication> get _history {
    final list = LeaveStore.applications
        .where((a) => a.employeeName == _employeeName && a.leaveType == 'Permission')
        .toList();
    list.sort((a, b) => b.appliedOn.compareTo(a.appliedOn));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final apps = await SupabaseService.fetchLeaveApplications();
    if (!mounted) return;
    if (apps.isNotEmpty) {
      LeaveStore.applications..clear()..addAll(apps);
      LeaveStore.syncCounter();
    }
    setState(() => _loading = false);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: _color)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_limitReached) return;
    if (_date == null) {
      _snack(st('select_permission_date_err'));
      return;
    }
    setState(() => _submitting = true);

    final app = LeaveApplication(
      id:           LeaveStore.generateId(),
      employeeName: _employeeName,
      department:   UserSession.department,
      leaveType:    'Permission',
      from:         _date!,
      to:           _date!,
      days:         1,
      reason:       _duration,
      appliedOn:    DateTime.now(),
    )..isHalfDay = true;

    LeaveStore.applications.add(app);
    await SupabaseService.saveLeaveApplication(app);

    if (!mounted) return;
    setState(() { _submitting = false; _date = null; _duration = _durations.first; });
    _snack(st('permission_submitted'));
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: staffLanguageNotifier,
      builder: (context, _, __) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 8),
          Icon(Icons.access_time_rounded, size: 48, color: _color),
          const SizedBox(height: 12),
          Text(st('apply_permission'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),

          if (_limitReached)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: Colors.orange.shade700, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(st('permission_limit_reached'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF9A3412))),
                ),
              ]),
            ),

          GestureDetector(
            onTap: _limitReached ? null : _pickDate,
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
                    Text(st('permission_date'),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_date != null ? _fmt(_date!) : st('select_date'),
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _date != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF))),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(st('permission_duration'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _durations.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  RadioListTile<String>(
                    value: _durations[i],
                    groupValue: _duration,
                    onChanged: _limitReached ? null : (v) { if (v != null) setState(() => _duration = v); },
                    activeColor: _color,
                    title: Text(st(_durationKeys[_durations[i]]!),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_submitting || _limitReached) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(st('apply'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 32),
          StaffHistorySection(
            items: _history,
            emptyKey: 'no_permission_history',
            subtitleOf: (a) => st(_durationKeys[a.reason] ?? a.reason),
          ),
        ]),
      ),
    );
  }
}
