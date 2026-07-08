import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/leave_store.dart';
import '../services/supabase_service.dart';
import '../models/attendance_store.dart';
import '../utils/checkin_status.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

Color get _blue => AppTheme.primaryBlue;
const _green  = Color(0xFF22C55E);
const _purple = Color(0xFF2563EB); // fixed status color for "Late Coming" — not theme-driven
const _red    = Color(0xFFEF4444);

class EmployeeAttendanceCalendarPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const EmployeeAttendanceCalendarPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EmployeeAttendanceCalendarPage> createState() =>
      _EmployeeAttendanceCalendarPageState();
}

class _EmployeeAttendanceCalendarPageState
    extends State<EmployeeAttendanceCalendarPage> {
  late DateTime _month;
  bool _loading = true;
  Map<int, AttendanceRecord> _attendance = {};
  Set<int> _leaveDays = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await SupabaseService.fetchAttendanceForMonth(
        widget.employeeId, _month.year, _month.month);
    if (!mounted) return;

    final Map<int, AttendanceRecord> map = {};
    for (final r in records) {
      final d = _dayOf(r.date);
      if (d != null) map[d] = r;
    }

    final Set<int> leaves = {};
    for (final app in LeaveStore.applications) {
      if (app.employeeName != widget.employeeName) continue;
      if (app.managerStatus != LeaveApprovalStatus.approved) continue;
      var d = app.from;
      while (!d.isAfter(app.to)) {
        if (d.year == _month.year && d.month == _month.month) leaves.add(d.day);
        d = d.add(const Duration(days: 1));
      }
    }

    setState(() {
      _attendance = map;
      _leaveDays  = leaves;
      _loading    = false;
    });
  }

  static int? _dayOf(String date) {
    try { return int.parse(date.split('/').first); } catch (_) { return null; }
  }

  CheckInRowStatus _status(int day) {
    final r = _attendance[day];
    if (r == null) return const CheckInRowStatus(CheckInStatus.none, 0);
    final date = DateTime(_month.year, _month.month, day);
    return checkInStatusFor(r.checkInTime, date, widget.employeeName, LeaveStore.applications);
  }

  Color? _statusColor(int day) {
    if (_leaveDays.contains(day)) return _red;
    final r = _attendance[day];
    if (r != null && r.checkInTime.isNotEmpty) {
      return _status(day).status == CheckInStatus.late ? _purple : _green;
    }
    return null;
  }

  void _onTap(int day) {
    final rec     = _attendance[day];
    final isLeave = _leaveDays.contains(day);
    if (rec == null && !isLeave) return;

    final dayDate = DateTime(_month.year, _month.month, day);
    const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const dow = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final label = '${dow[dayDate.weekday - 1]}, $day ${mon[dayDate.month - 1]} ${dayDate.year}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DaySheet(
        label: label,
        record: rec,
        isLeave: isLeave,
        status: rec != null ? _status(day) : const CheckInRowStatus(CheckInStatus.none, 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final now = DateTime.now();
    const mNames = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];

    return Scaffold(
      backgroundColor: null,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ────────────────────────────────────────────────────
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.access_time_rounded, color: _blue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.employeeName,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const Text('Attendance Calendar',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ]),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Calendar card ──────────────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                child: Column(children: [
                  Row(children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                      onPressed: () {
                        _month = DateTime(_month.year, _month.month - 1);
                        _load();
                      },
                    ),
                    Expanded(
                      child: Text(
                        '${mNames[_month.month - 1]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: cs.onSurface),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                      onPressed: () {
                        _month = DateTime(_month.year, _month.month + 1);
                        _load();
                      },
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Row(children: [
                    _WDay('Sun'), _WDay('Mon'), _WDay('Tue'), _WDay('Wed'),
                    _WDay('Thu'), _WDay('Fri'), _WDay('Sat'),
                  ]),
                  const SizedBox(height: 4),
                  Divider(height: 1, color: cs.outlineVariant),
                  const SizedBox(height: 4),

                  if (_loading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2)),
                    )
                  else
                    _CalendarGrid(
                      month: _month,
                      today: now,
                      statusColor: _statusColor,
                      onTap: _onTap,
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Legend ─────────────────────────────────────────────────────
            Wrap(spacing: 20, runSpacing: 8, children: const [
              _Legend(color: _green,  label: 'Present'),
              _Legend(color: _purple, label: 'Late Coming'),
              _Legend(color: _red,    label: 'Absent'),
            ]),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

// ── Calendar grid ─────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final Color? Function(int day) statusColor;
  final void Function(int day) onTap;

  const _CalendarGrid({
    required this.month,
    required this.today,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final firstDay    = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset      = firstDay.weekday % 7;

    final cells = <Widget>[];
    for (int i = 0; i < offset; i++) {
      cells.add(const Expanded(child: SizedBox()));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final isToday = today.year == month.year &&
                      today.month == month.month &&
                      today.day == day;
      final sColor = statusColor(day);

      final decoration = isToday
          ? BoxDecoration(color: _blue, shape: BoxShape.circle)
          : sColor != null
              ? BoxDecoration(
                  color: sColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: sColor, width: 1.5),
                )
              : null;

      final textColor = isToday
          ? Colors.white
          : sColor != null
              ? sColor
              : cs.onSurface.withValues(alpha: 0.35);

      cells.add(Expanded(
        child: GestureDetector(
          onTap: () => onTap(day),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Center(
              child: Container(
                width: 32, height: 32,
                decoration: decoration,
                alignment: Alignment.center,
                child: Text('$day',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: (isToday || sColor != null)
                            ? FontWeight.w700 : FontWeight.w400,
                        color: textColor)),
              ),
            ),
          ),
        ),
      ));
    }

    final rem = (offset + daysInMonth) % 7;
    if (rem != 0) {
      for (int i = 0; i < 7 - rem; i++) {
        cells.add(const Expanded(child: SizedBox()));
      }
    }

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(Row(children: cells.sublist(i, i + 7)));
    }
    return Column(children: rows);
  }
}

// ── Day detail bottom sheet ───────────────────────────────────────────────────
class _DaySheet extends StatelessWidget {
  final String label;
  final AttendanceRecord? record;
  final bool isLeave;
  final CheckInRowStatus status;

  const _DaySheet({
    required this.label,
    required this.record,
    required this.isLeave,
    required this.status,
  });

  static String? _dur(String inT, String outT) {
    try {
      final i = inT.split(':'), o = outT.split(':');
      final diff = (int.parse(o[0]) * 60 + int.parse(o[1])) -
                   (int.parse(i[0]) * 60 + int.parse(i[1]));
      if (diff <= 0) return null;
      final h = diff ~/ 60, m = diff % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final rec    = record;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String statusLabel;
    final Color  statusColor;
    if (isLeave) {
      statusLabel = 'Absent';
      statusColor = _red;
    } else if (status.status == CheckInStatus.late) {
      statusLabel = 'Late Coming';
      statusColor = _purple;
    } else {
      statusLabel = 'Present';
      statusColor = _green;
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ]),
        const SizedBox(height: 20),
        if (isLeave) ...[
          Row(children: [
            Icon(Icons.event_busy_rounded, size: 18, color: _red),
            const SizedBox(width: 10),
            Text('On approved leave', style: TextStyle(fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.7))),
          ]),
        ] else if (rec != null && rec.checkInTime.isNotEmpty) ...[
          _detailRow(context, Icons.login_rounded, 'Check In', rec.checkInTime, _green),
          if (rec.checkInNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            _noteBlock(context, rec.checkInNote),
          ],
          if (status.status == CheckInStatus.permission) ...[
            const SizedBox(height: 8),
            _noteBlock(context,
                'Covered by approved permission (${permLabel(status.permMinutes)})'),
          ],
          const SizedBox(height: 12),
          if (rec.checkOutTime.isNotEmpty) ...[
            _detailRow(context, Icons.logout_rounded, 'Check Out', rec.checkOutTime,
                const Color(0xFF15803D)),
            if (rec.checkOutNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              _noteBlock(context, rec.checkOutNote),
            ],
            const SizedBox(height: 12),
            if (_dur(rec.checkInTime, rec.checkOutTime) != null)
              _detailRow(context, Icons.timelapse_rounded, 'Duration',
                  _dur(rec.checkInTime, rec.checkOutTime)!, _blue),
          ] else
            _detailRow(context, Icons.logout_rounded, 'Check Out', '— not recorded',
                cs.onSurface.withValues(alpha: 0.4)),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label,
      String value, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.5))),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            fontFamily: 'monospace', color: color)),
      ]),
    ]);
  }

  Widget _noteBlock(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 12,
          color: cs.onSurface.withValues(alpha: 0.7))),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────
class _WDay extends StatelessWidget {
  final String label;
  const _WDay(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 18, height: 18,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    ),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65))),
  ]);
}
