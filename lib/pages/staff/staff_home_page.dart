import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/staff_strings.dart';
import '../../models/attendance_store.dart';
import '../../models/language_notifier.dart';
import '../../models/leave_store.dart';
import '../../models/user_session.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// Staff Portal home: a premium dashboard built around the single
/// attendance action — greeting, big Check In/Check Out card, a stat row
/// (today's status, working hours, this month's holiday allowance), and
/// shortcuts into Leave/Permission. No notes are ever asked for on
/// check-in/out, unlike the regular employee flow.
class StaffHomePage extends StatefulWidget {
  const StaffHomePage({super.key});

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  bool _loading = true;
  bool _busy = false;
  AttendanceRecord? _record;
  Timer? _ticker;

  String get _employeeName => UserSession.name.isEmpty ? 'Employee' : UserSession.name;

  @override
  void initState() {
    super.initState();
    _load();
    // Keeps the live "worked so far" figure ticking while checked in.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.fetchTodayAttendance(UserSession.employeeId),
      SupabaseService.fetchLeaveApplications(),
    ]);
    if (!mounted) return;
    final rec = results[0] as AttendanceRecord?;
    final apps = results[1] as List<LeaveApplication>;
    if (apps.isNotEmpty) {
      LeaveStore.applications..clear()..addAll(apps);
      LeaveStore.syncCounter();
    }
    setState(() { _record = rec; _loading = false; });
  }

  String _nowHhMm() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    await SupabaseService.saveCheckIn(
      employeeName: _employeeName,
      employeeId: UserSession.employeeId,
      date: _today(),
      time: _nowHhMm(),
      location: '',
      note: '',
    );
    final rec = await SupabaseService.fetchTodayAttendance(UserSession.employeeId);
    if (!mounted) return;
    setState(() { _record = rec; _busy = false; });
  }

  Future<void> _checkOut() async {
    setState(() => _busy = true);
    await SupabaseService.saveCheckOut(
      employeeId: UserSession.employeeId,
      date: _today(),
      time: _nowHhMm(),
      note: '',
    );
    final rec = await SupabaseService.fetchTodayAttendance(UserSession.employeeId);
    if (!mounted) return;
    setState(() { _record = rec; _busy = false; });
  }

  String get _greetingKey {
    final h = DateTime.now().hour;
    if (h < 12) return 'greeting_morning';
    if (h < 17) return 'greeting_afternoon';
    return 'greeting_evening';
  }

  static int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// "Xh Ym" between check-in and check-out (or now, if still checked in).
  /// Null when there's nothing to show yet.
  String? get _workingHours {
    final rec = _record;
    if (rec == null || rec.checkInTime.isEmpty) return null;
    final start = _toMinutes(rec.checkInTime);
    if (start == null) return null;
    int end;
    if (rec.checkOutTime.isNotEmpty) {
      end = _toMinutes(rec.checkOutTime) ?? start;
    } else {
      final now = DateTime.now();
      end = now.hour * 60 + now.minute;
    }
    final diff = end - start;
    if (diff < 0) return null;
    return '${diff ~/ 60}h ${diff % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final checkedIn  = _record != null && _record!.checkInTime.isNotEmpty;
    final checkedOut = checkedIn && _record!.checkOutTime.isNotEmpty;
    final usedThisMonth = LeaveStore.staffLeaveCountThisMonth(_employeeName);

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: staffLanguageNotifier,
      builder: (context, _, __) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${st(_greetingKey)},',
                style: AppTheme.bodyText.copyWith(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(_employeeName, style: AppTheme.pageHeading.copyWith(fontSize: 28)),
            const SizedBox(height: 24),

            _CheckInCard(
              checkedIn: checkedIn,
              checkedOut: checkedOut,
              busy: _busy,
              checkInTime: _record?.checkInTime ?? '',
              checkOutTime: _record?.checkOutTime ?? '',
              onCheckIn: _checkIn,
              onCheckOut: _checkOut,
            ),
            const SizedBox(height: 20),

            LayoutBuilder(builder: (context, c) {
              final narrow = c.maxWidth < 620;
              final tiles = [
                _StatTile(
                  icon: Icons.badge_rounded,
                  color: AppTheme.primaryBlue,
                  label: st('todays_status'),
                  value: checkedOut
                      ? st('status_shift_completed')
                      : checkedIn
                          ? st('status_checked_in')
                          : st('not_checked_in'),
                ),
                _StatTile(
                  icon: Icons.timer_rounded,
                  color: AppTheme.warning,
                  label: st('working_hours'),
                  value: _workingHours ?? '—',
                ),
                _StatTile(
                  icon: Icons.event_available_rounded,
                  color: AppTheme.success,
                  label: st('holiday_allowance'),
                  value: '$usedThisMonth/${LeaveStore.staffMonthlyHolidayAllowance}',
                ),
              ];
              return narrow
                  ? Column(children: [
                      for (final t in tiles) ...[t, const SizedBox(height: 12)],
                    ])
                  : Row(children: [
                      for (final t in tiles) ...[Expanded(child: t), const SizedBox(width: 12)],
                    ]);
            }),
            const SizedBox(height: 28),

            Text(st('quick_actions'), style: AppTheme.cardHeading),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.event_busy_rounded,
                  label: st('apply_leave'),
                  onTap: () => context.go('/staff/leave'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.access_time_rounded,
                  label: st('apply_permission'),
                  onTap: () => context.go('/staff/permission'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  final bool checkedIn;
  final bool checkedOut;
  final bool busy;
  final String checkInTime;
  final String checkOutTime;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  const _CheckInCard({
    required this.checkedIn, required this.checkedOut, required this.busy,
    required this.checkInTime, required this.checkOutTime,
    required this.onCheckIn, required this.onCheckOut,
  });

  @override
  Widget build(BuildContext context) {
    final color = checkedOut
        ? AppTheme.primaryBlue
        : checkedIn ? AppTheme.error : AppTheme.success;
    final title = checkedOut
        ? st('shift_completed')
        : checkedIn ? st('checked_in_success') : st('check_in');
    final timeLabel = checkedOut ? st('checked_out_at') : st('checked_in_at');
    final time = checkedOut ? checkOutTime : checkInTime;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(
                checkedOut ? Icons.task_alt_rounded : (checkedIn ? Icons.logout_rounded : Icons.login_rounded),
                color: color, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTheme.cardHeading.copyWith(color: color, fontSize: 18)),
              if (checkedIn) ...[
                const SizedBox(height: 4),
                Text('$timeLabel $time', style: AppTheme.captionText),
              ],
            ]),
          ),
          if (!checkedOut)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: busy ? null : (checkedIn ? onCheckOut : onCheckIn),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  disabledBackgroundColor: color.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Icon(checkedIn ? Icons.logout_rounded : Icons.login_rounded, size: 18),
                label: Text(checkedIn ? st('check_out') : st('check_in')),
              ),
            ),
        ]),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTheme.captionText),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
          ]),
        ),
      ),
    );
  }
}
