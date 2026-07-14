import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/leave_store.dart';
import '../services/supabase_service.dart';
import '../models/attendance_store.dart';
import '../utils/checkin_status.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

// Fixed status colors — not theme-driven. Chosen as a set (not just
// pairwise) so every status stays distinguishable, including for
// colorblind users; see scripts/validate_palette.js in the dataviz skill.
Color get _blue => AppTheme.primaryBlue;
const _green   = Color(0xFF008300);
const _purple  = Color(0xFF2A78D6); // "Late Coming"
const _yellow  = Color(0xFFEDA100); // "Holiday"
const _magenta = Color(0xFFE87BA4); // "Leave Applied"
const _teal    = Color(0xFF1BAF7A); // "Permission"
const _violet  = Color(0xFF4A3AA7); // "Comp Off"

// Height of one calendar day row (5 top pad + 32 circle + 5 bottom pad),
// used to position the day-detail dropdown without shifting the grid.
const double _dayRowHeight = 42.0;

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
  Set<int> _permissionDays = {};
  Set<int> _compOffDays = {};
  Set<int> _holidayDays = {};
  List<LeaveApplication> _leaveApps = [];
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      SupabaseService.fetchAttendanceForMonth(widget.employeeId, _month.year, _month.month),
      SupabaseService.fetchHolidays(_month.year),
      SupabaseService.fetchLeaveApplications(),
    ]);
    if (!mounted) return;

    final records  = results[0] as List<AttendanceRecord>;
    final holidays = results[1] as List<Map<String, dynamic>>;
    final leaveApps = results[2] as List<LeaveApplication>;

    final Map<int, AttendanceRecord> map = {};
    for (final r in records) {
      final d = _dayOf(r.date);
      if (d != null) map[d] = r;
    }

    // Build holiday set for current month (HR-entered holidays + all Sundays)
    final Set<int> holidayDays = {};
    for (final h in holidays) {
      final date = DateTime.tryParse(h['holiday_date'] as String? ?? '');
      if (date != null && date.year == _month.year && date.month == _month.month) {
        holidayDays.add(date.day);
      }
    }
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      if (DateTime(_month.year, _month.month, d).weekday == DateTime.sunday) {
        holidayDays.add(d);
      }
    }

    // Approved leave/permission/comp-off days — exclude weekends and holidays.
    // Permission and Comp Off are distinct leaveType values from a regular
    // full-day Leave, so each gets its own set rather than lumping them
    // together as "on leave".
    final Set<int> leaves = {}, permissions = {}, compOffs = {};
    for (final app in leaveApps) {
      if (app.employeeName != widget.employeeName) continue;
      if (app.managerStatus != LeaveApprovalStatus.approved) continue;
      final target = switch (app.leaveType) {
        'Permission' => permissions,
        'Comp Off'   => compOffs,
        _            => leaves,
      };
      var d = app.from;
      while (!d.isAfter(app.to)) {
        if (d.year == _month.year && d.month == _month.month) {
          final wd = d.weekday;
          if (wd != DateTime.saturday && wd != DateTime.sunday && !holidayDays.contains(d.day)) {
            target.add(d.day);
          }
        }
        d = d.add(const Duration(days: 1));
      }
    }

    setState(() {
      _attendance     = map;
      _leaveDays      = leaves;
      _permissionDays = permissions;
      _compOffDays    = compOffs;
      _holidayDays    = holidayDays;
      _leaveApps      = leaveApps;
      _loading        = false;
      _selectedDay    = null;
    });
  }

  static int? _dayOf(String date) {
    try { return int.parse(date.split('/').first); } catch (_) { return null; }
  }

  CheckInRowStatus _status(int day) {
    final r = _attendance[day];
    if (r == null) return const CheckInRowStatus(CheckInStatus.none, 0);
    final date = DateTime(_month.year, _month.month, day);
    return checkInStatusFor(r.checkInTime, date, widget.employeeName, _leaveApps);
  }

  // Precedence: actual attendance > holiday > leave > permission > comp off.
  Color? _statusColor(int day) {
    final r = _attendance[day];
    if (r != null && r.checkInTime.isNotEmpty) {
      return _status(day).status == CheckInStatus.late ? _purple : _green;
    }
    if (_holidayDays.contains(day)) return _yellow;
    if (_leaveDays.contains(day)) return _magenta;
    if (_permissionDays.contains(day)) return _teal;
    if (_compOffDays.contains(day)) return _violet;
    return null;
  }

  void _onTap(int day) {
    final rec          = _attendance[day];
    final isLeave       = _leaveDays.contains(day);
    final isPermission  = _permissionDays.contains(day);
    final isCompOff     = _compOffDays.contains(day);
    if (rec == null && !isLeave && !isPermission && !isCompOff) return;

    setState(() => _selectedDay = _selectedDay == day ? null : day);
  }

  // Builds the inline dropdown card for the currently selected day, shown
  // right under its row in the calendar grid — null when nothing selected.
  Widget? _selectedDayContent() {
    final day = _selectedDay;
    if (day == null) return null;
    final rec         = _attendance[day];
    final isLeave      = _leaveDays.contains(day);
    final isPermission = _permissionDays.contains(day);
    final isCompOff    = _compOffDays.contains(day);

    final dayDate = DateTime(_month.year, _month.month, day);
    const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const dow = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final label = '${dow[dayDate.weekday - 1]}, $day ${mon[dayDate.month - 1]} ${dayDate.year}';

    return _DaySheet(
      label: label,
      record: rec,
      isLeave: isLeave,
      isPermission: isPermission,
      isCompOff: isCompOff,
      status: rec != null ? _status(day) : const CheckInRowStatus(CheckInStatus.none, 0),
      onClose: () => setState(() => _selectedDay = null),
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
                      selectedDay: _selectedDay,
                      selectedDayContent: _selectedDayContent(),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Legend ─────────────────────────────────────────────────────
            Wrap(spacing: 20, runSpacing: 8, children: const [
              _Legend(color: _green,  label: 'Present'),
              _Legend(color: _purple, label: 'Late Coming'),
              _Legend(color: _magenta, label: 'Leave Applied'),
              _Legend(color: _teal,   label: 'Permission'),
              _Legend(color: _violet, label: 'Comp Off'),
              _Legend(color: _yellow, label: 'Holiday'),
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
  final int? selectedDay;
  final Widget? selectedDayContent;

  const _CalendarGrid({
    required this.month,
    required this.today,
    required this.statusColor,
    required this.onTap,
    this.selectedDay,
    this.selectedDayContent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) => _buildGrid(context, constraints));
  }

  Widget _buildGrid(BuildContext context, BoxConstraints constraints) {
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

    final stackChildren = <Widget>[Column(children: rows)];

    final day = selectedDay;
    if (day != null && selectedDayContent != null) {
      final dayIndex = offset + day - 1;
      final rowIndex = dayIndex ~/ 7;
      final colIndex = dayIndex % 7;
      const cardWidth = 250.0;
      final colWidth  = constraints.maxWidth / 7;
      final maxLeft   = (constraints.maxWidth - cardWidth).clamp(0.0, double.infinity);
      final left      = (colIndex * colWidth + colWidth / 2 - cardWidth / 2)
          .clamp(0.0, maxLeft);
      stackChildren.add(Positioned(
        top: (rowIndex + 1) * _dayRowHeight - 4,
        left: left,
        width: cardWidth,
        child: selectedDayContent!,
      ));
    }

    return Stack(clipBehavior: Clip.none, children: stackChildren);
  }
}

// ── Day detail dropdown card ──────────────────────────────────────────────────
class _DaySheet extends StatelessWidget {
  final String label;
  final AttendanceRecord? record;
  final bool isLeave;
  final bool isPermission;
  final bool isCompOff;
  final CheckInRowStatus status;
  final VoidCallback onClose;

  const _DaySheet({
    required this.label,
    required this.record,
    required this.isLeave,
    this.isPermission = false,
    this.isCompOff = false,
    required this.status,
    required this.onClose,
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

    final hasAttendance = rec != null && rec.checkInTime.isNotEmpty;

    final String statusLabel;
    final Color  statusColor;
    if (hasAttendance) {
      statusLabel = status.status == CheckInStatus.late ? 'Late Coming' : 'Present';
      statusColor = status.status == CheckInStatus.late ? _purple : _green;
    } else if (isLeave) {
      statusLabel = 'Leave Applied';
      statusColor = _magenta;
    } else if (isPermission) {
      statusLabel = 'Permission';
      statusColor = _teal;
    } else {
      statusLabel = 'Comp Off';
      statusColor = _violet;
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 14, offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 15,
                  color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(statusLabel,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: statusColor)),
        ),
        const SizedBox(height: 10),
        if (hasAttendance) ...[
          _detailRow(context, Icons.login_rounded, 'Check In', rec.checkInTime, _green),
          if (rec.checkInNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            _noteBlock(context, rec.checkInNote),
          ],
          if (status.status == CheckInStatus.permission) ...[
            const SizedBox(height: 6),
            _noteBlock(context,
                'Covered by permission (${permLabel(status.permMinutes)})'),
          ],
          const SizedBox(height: 8),
          if (rec.checkOutTime.isNotEmpty) ...[
            _detailRow(context, Icons.logout_rounded, 'Check Out', rec.checkOutTime,
                const Color(0xFF15803D)),
            if (rec.checkOutNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              _noteBlock(context, rec.checkOutNote),
            ],
            const SizedBox(height: 8),
            if (_dur(rec.checkInTime, rec.checkOutTime) != null)
              _detailRow(context, Icons.timelapse_rounded, 'Duration',
                  _dur(rec.checkInTime, rec.checkOutTime)!, _blue),
          ] else
            _detailRow(context, Icons.logout_rounded, 'Check Out', '— not recorded',
                cs.onSurface.withValues(alpha: 0.4)),
        ] else if (isLeave) ...[
          _noteRow(context, Icons.event_busy_rounded, _magenta, 'On approved leave'),
        ] else if (isPermission) ...[
          _noteRow(context, Icons.event_note_rounded, _teal, 'Approved permission — no attendance recorded'),
        ] else ...[
          _noteRow(context, Icons.swap_horiz_rounded, _violet, 'On approved Comp Off'),
        ],
      ]),
    );
  }

  Widget _noteRow(BuildContext context, IconData icon, Color color, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text, style: TextStyle(fontSize: 11.5,
            color: cs.onSurface.withValues(alpha: 0.7))),
      ),
    ]);
  }

  Widget _detailRow(BuildContext context, IconData icon, String label,
      String value, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9.5,
            color: cs.onSurface.withValues(alpha: 0.5))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            fontFamily: 'monospace', color: color)),
      ]),
    ]);
  }

  Widget _noteBlock(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 34),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 10.5,
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
