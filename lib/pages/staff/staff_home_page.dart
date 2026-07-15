import 'package:flutter/material.dart';
import '../../l10n/staff_strings.dart';
import '../../models/attendance_store.dart';
import '../../models/language_notifier.dart';
import '../../models/user_session.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// Staff Portal home: a single attendance button, nothing else.
/// Not checked in  -> green "Check In"
/// Checked in      -> "Checked In Successfully" + red "Check Out"
/// Checked out     -> "Shift Completed Successfully"
/// No notes are ever asked for, unlike the regular employee check-in/out flow.
class StaffHomePage extends StatefulWidget {
  const StaffHomePage({super.key});

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  bool _loading = true;
  bool _busy = false;
  AttendanceRecord? _record;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rec = await SupabaseService.fetchTodayAttendance(UserSession.employeeId);
    if (!mounted) return;
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
    final empName = UserSession.name.isNotEmpty ? UserSession.name : 'Employee';
    await SupabaseService.saveCheckIn(
      employeeName: empName,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final checkedIn  = _record != null && _record!.checkInTime.isNotEmpty;
    final checkedOut = checkedIn && _record!.checkOutTime.isNotEmpty;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: staffLanguageNotifier,
      builder: (context, _, __) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (checkedOut)
              _StatusCard(
                icon: Icons.task_alt_rounded,
                color: AppTheme.primaryBlue,
                title: st('shift_completed'),
                timeLabel: st('checked_out_at'),
                time: _record!.checkOutTime,
              )
            else if (checkedIn)
              _StatusCard(
                icon: Icons.check_circle_rounded,
                color: Colors.green.shade600,
                title: st('checked_in_success'),
                timeLabel: st('checked_in_at'),
                time: _record!.checkInTime,
              ),
            const SizedBox(height: 32),
            if (!checkedOut)
              _BigAttendanceButton(
                checkedIn: checkedIn,
                busy: _busy,
                onTap: checkedIn ? _checkOut : _checkIn,
              ),
          ]),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String timeLabel;
  final String time;
  const _StatusCard({
    required this.icon, required this.color, required this.title,
    required this.timeLabel, required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 10),
        Text(timeLabel, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        Text(time,
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800,
                fontFamily: 'monospace', color: color)),
      ]),
    );
  }
}

class _BigAttendanceButton extends StatelessWidget {
  final bool checkedIn;
  final bool busy;
  final VoidCallback onTap;
  const _BigAttendanceButton({required this.checkedIn, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = checkedIn ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    return SizedBox(
      width: 240,
      height: 240,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
        ),
        child: busy
            ? const SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(checkedIn ? Icons.logout_rounded : Icons.login_rounded, size: 64),
                const SizedBox(height: 12),
                Text(checkedIn ? st('check_out') : st('check_in'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
      ),
    );
  }
}
