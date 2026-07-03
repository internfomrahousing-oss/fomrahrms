import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/attendance_store.dart';
import '../models/onboarding_form_config.dart';
import '../models/user_session.dart';
import '../services/gps_tracking_service.dart';
import '../services/supabase_service.dart';

// ── Small tappable button shown on dashboards ─────────────────────────────────
class AttendanceShortcutCard extends StatefulWidget {
  final String attendanceRoute;
  final Color accentColor;

  const AttendanceShortcutCard({
    super.key,
    required this.attendanceRoute,
    required this.accentColor,
  });

  @override
  State<AttendanceShortcutCard> createState() => _AttendanceShortcutCardState();
}

class _AttendanceShortcutCardState extends State<AttendanceShortcutCard> {
  bool _loading = true;
  AttendanceRecord? _record;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rec = await SupabaseService.fetchTodayAttendance(UserSession.employeeId);
    if (!mounted) return;
    setState(() {
      _record = rec;
      _loading = false;
    });
    if (rec != null && rec.checkInTime.isNotEmpty && rec.checkOutTime.isEmpty) {
      AttendanceStore.isCheckedIn = true;
      GpsTrackingService.start();
      _ticker ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _showHRPolicy() async {
    String? policyText;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final active = await SupabaseService.fetchActiveOnboardingFormVersion();
      if (!mounted) return;
      Navigator.pop(context);
      final sections = active != null
          ? OnboardingFormConfig.getSections(
              Map<String, dynamic>.from(active['form_config'] as Map))
          : OnboardingFormConfig.getSections(OnboardingFormConfig.defaults());
      policyText = OnboardingFormConfig.getPolicyTextFromSections(sections);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      policyText = OnboardingFormConfig.defaultPolicyText;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dlgCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(children: [
                const Icon(Icons.policy_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('HR Policy',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(dlgCtx),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  policyText ?? '',
                  style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF37474F)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Close'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttendanceSheet(
        record: _record,
        accentColor: widget.accentColor,
        attendanceRoute: widget.attendanceRoute,
        onDone: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final rec     = _record;
    final accent  = widget.accentColor;

    // Determine status visuals
    final IconData  statusIcon;
    final Color     statusColor;
    final String    statusText;

    if (_loading) {
      statusIcon  = Icons.access_time_rounded;
      statusColor = accent;
      statusText  = 'Attendance';
    } else if (rec != null && rec.checkOutTime.isNotEmpty) {
      statusIcon  = Icons.check_circle_rounded;
      statusColor = isDark ? Colors.blue.shade300 : const Color(0xFF1565C0);
      final dur   = _durationStr(rec);
      statusText  = 'Done · ${rec.checkInTime} – ${rec.checkOutTime}${dur != null ? ' ($dur)' : ''}';
    } else if (rec != null && rec.checkInTime.isNotEmpty) {
      statusIcon  = Icons.check_circle_rounded;
      statusColor = isDark ? Colors.green.shade300 : const Color(0xFF2E7D32);
      statusText  = 'Checked in at ${rec.checkInTime}';
    } else {
      statusIcon  = Icons.fingerprint_rounded;
      statusColor = accent;
      statusText  = 'Check In / Out';
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // ── Attendance check-in/out button ───────────────────────────────
        Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _loading ? null : _openSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_loading)
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  )
                else
                  Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 7),
                Text(statusText,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _loading
                            ? cs.onSurface.withValues(alpha: 0.5)
                            : cs.onSurface)),
                if (!_loading && rec != null && rec.checkInTime.isNotEmpty && rec.checkOutTime.isEmpty) ...[
                  const SizedBox(width: 7),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ── HR Policy button ──────────────────────────────────────────────
        Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showHRPolicy,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.policy_rounded, size: 18,
                    color: isDark ? Colors.blue.shade300 : const Color(0xFF0D47A1)),
                const SizedBox(width: 7),
                Text('HR Policy',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.blue.shade300 : const Color(0xFF0D47A1))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  static String? _durationStr(AttendanceRecord rec) {
    try {
      final inP  = rec.checkInTime.split(':');
      final outP = rec.checkOutTime.split(':');
      if (inP.length == 2 && outP.length == 2) {
        final diff = (int.parse(outP[0]) * 60 + int.parse(outP[1])) -
                     (int.parse(inP[0])  * 60 + int.parse(inP[1]));
        if (diff > 0) {
          final h = diff ~/ 60, m = diff % 60;
          return h > 0 ? '${h}h ${m}m' : '${m}m';
        }
      }
    } catch (_) {}
    return null;
  }
}

// ── Bottom-sheet popup ────────────────────────────────────────────────────────
class _AttendanceSheet extends StatefulWidget {
  final AttendanceRecord? record;
  final Color accentColor;
  final String attendanceRoute;
  final VoidCallback onDone;

  const _AttendanceSheet({
    required this.record,
    required this.accentColor,
    required this.attendanceRoute,
    required this.onDone,
  });

  @override
  State<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<_AttendanceSheet> {
  static const _green = Color(0xFF2E7D32);
  static const _teal  = Color(0xFF00695C);

  late final TextEditingController _timeCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _timeCtrl = TextEditingController(text: _nowTime());
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    super.dispose();
  }

  String _nowTime() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _checkIn() async {
    setState(() => _submitting = true);
    final now = DateTime.now();
    final empName = UserSession.name.isNotEmpty ? UserSession.name : 'Employee';

    AttendanceStore.isCheckedIn = true;
    GpsTrackingService.start();

    final lat = GpsTrackingService.latestLat;
    final lng = GpsTrackingService.latestLng;
    final loc = (lat != null && lng != null) ? '$lat,$lng' : '';

    final err = await SupabaseService.saveCheckIn(
      employeeName: empName,
      employeeId:   UserSession.employeeId,
      date:         _fmtDate(now),
      time:         _timeCtrl.text,
      location:     loc,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sync error: $err'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } else {
      widget.onDone();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Checked in at ${_timeCtrl.text}'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  Future<void> _checkOut() async {
    setState(() => _submitting = true);
    final now = DateTime.now();

    GpsTrackingService.stop();
    AttendanceStore.isCheckedIn = false;

    await SupabaseService.saveCheckOut(
      employeeId: UserSession.employeeId,
      date:       _fmtDate(now),
      time:       _timeCtrl.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    widget.onDone();
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Checked out at ${_timeCtrl.text}'),
      backgroundColor: _teal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final rec     = widget.record;
    final accent  = widget.accentColor;

    final isCheckedIn = rec != null && rec.checkInTime.isNotEmpty && rec.checkOutTime.isEmpty;
    final isDone      = rec != null && rec.checkOutTime.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        const SizedBox(height: 12),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.access_time_rounded, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const Spacer(),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(widget.attendanceRoute);
            },
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('View Details', style: TextStyle(fontSize: 12, color: accent,
                  fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: accent),
            ]),
          ),
        ]),
        const SizedBox(height: 20),

        // Status banner
        if (isDone) ...[
          _doneBanner(rec!, isDark),
          const SizedBox(height: 16),
        ] else if (isCheckedIn) ...[
          _statusBanner(
            icon: Icons.check_circle_rounded,
            text: 'Checked in at ${rec!.checkInTime}',
            fg: isDark ? Colors.green.shade300 : _green,
            bg: isDark ? Colors.green.withValues(alpha: 0.12) : Colors.green.shade50,
            border: isDark ? Colors.green.shade700 : Colors.green.shade200,
          ),
          const SizedBox(height: 16),
        ] else ...[
          _statusBanner(
            icon: Icons.schedule_rounded,
            text: "Not checked in yet today",
            fg: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
            bg: isDark ? Colors.orange.withValues(alpha: 0.12) : Colors.orange.shade50,
            border: isDark ? Colors.orange.shade700 : Colors.orange.shade200,
          ),
          const SizedBox(height: 16),
        ],

        // Time field (hide when done)
        if (!isDone) ...[
          TextField(
            controller: _timeCtrl,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: isCheckedIn ? 'Check-Out Time' : 'Check-In Time',
              prefixIcon: Icon(
                isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
                color: isCheckedIn ? _teal : accent,
                size: 20,
              ),
              suffixIcon: IconButton(
                tooltip: 'Use current time',
                icon: Icon(Icons.schedule_rounded,
                    color: isCheckedIn ? _teal : accent),
                onPressed: () => setState(() => _timeCtrl.text = _nowTime()),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: isCheckedIn ? _teal : accent, width: 2),
              ),
              filled: true,
              fillColor: cs.surface,
            ),
          ),
          const SizedBox(height: 16),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : (isCheckedIn ? _checkOut : _checkIn),
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(isCheckedIn ? Icons.logout_rounded : Icons.login_rounded, size: 18),
              label: Text(isCheckedIn ? 'Check Out' : 'Check In',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCheckedIn ? _teal : accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _statusBanner({
    required IconData icon,
    required String text,
    required Color fg,
    required Color bg,
    required Color border,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: fg),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _doneBanner(AttendanceRecord rec, bool isDark) {
    final dur  = _AttendanceShortcutCardState._durationStr(rec);
    final blue = isDark ? Colors.blue.shade300 : const Color(0xFF1565C0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D47A1).withValues(alpha: 0.12) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_rounded, size: 14, color: blue),
          const SizedBox(width: 6),
          Text('Attendance Complete',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: blue)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _timeBlock('Check In',  rec.checkInTime,  blue),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: blue),
          ),
          _timeBlock('Check Out', rec.checkOutTime, blue),
        ]),
        if (dur != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(dur,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: blue)),
          ),
        ],
      ]),
    );
  }

  Widget _timeBlock(String label, String time, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
      const SizedBox(height: 2),
      Text(time, style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800,
          fontFamily: 'monospace', color: color)),
    ]);
  }
}
