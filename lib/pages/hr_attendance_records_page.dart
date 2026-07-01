import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../models/attendance_store.dart';

class HrAttendanceRecordsPage extends StatefulWidget {
  const HrAttendanceRecordsPage({super.key});

  @override
  State<HrAttendanceRecordsPage> createState() =>
      _HrAttendanceRecordsPageState();
}

class _HrAttendanceRecordsPageState extends State<HrAttendanceRecordsPage> {
  static const _color = Color(0xFF0D47A1);

  String _search = '';
  DateTime _selectedDate = DateTime.now();
  late DateTime _viewMonth;

  static const _monthNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];
  static const _dayHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
  }

  bool get _isToday {
    final t = DateTime.now();
    return _selectedDate.year == t.year &&
        _selectedDate.month == t.month &&
        _selectedDate.day == t.day;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _matchesDayDt(DateTime date, String dateStr) {
    final parts = dateStr.split('/');
    if (parts.length != 3) return false;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    return day == date.day && month == date.month && year == date.year;
  }

  bool _matchesDay(String dateStr) => _matchesDayDt(_selectedDate, dateStr);

  bool _dayHasCheckIns(DateTime d) =>
      AttendanceStore.checkIns.any((r) => _matchesDayDt(d, r.date));
  bool _dayHasLate(DateTime d) =>
      AttendanceStore.lateComing.any((r) => _matchesDayDt(d, r.date));

  bool _matches(String employee) =>
      _search.isEmpty ||
      employee.toLowerCase().contains(_search.toLowerCase());

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _showCheckInDetail(CheckInRecord record) {
    final gpsRecords = AttendanceStore.gpsRecords
        .where((g) => g.employee == record.employee && g.date == record.date)
        .toList();
    showDialog(
      context: context,
      builder: (ctx) =>
          _CheckInDetailDialog(record: record, gpsRecords: gpsRecords),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final isCurrentMonth = _viewMonth.year == now.year && _viewMonth.month == now.month;
    final startOffset = firstDay.weekday - 1; // Mon=0 … Sun=6

    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Month navigator
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: _color),
              onPressed: () => setState(() {
                _viewMonth = DateTime(
                  _viewMonth.month == 1 ? _viewMonth.year - 1 : _viewMonth.year,
                  _viewMonth.month == 1 ? 12 : _viewMonth.month - 1,
                );
              }),
            ),
            Expanded(
              child: Text(
                '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _color),
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: isCurrentMonth ? Colors.grey.shade300 : _color),
              onPressed: isCurrentMonth ? null : () => setState(() {
                _viewMonth = DateTime(
                  _viewMonth.month == 12 ? _viewMonth.year + 1 : _viewMonth.year,
                  _viewMonth.month == 12 ? 1 : _viewMonth.month + 1,
                );
              }),
            ),
          ]),
          const SizedBox(height: 8),

          // Day-of-week headers
          Row(
            children: _dayHeaders.map((h) => Expanded(
              child: Center(
                child: Text(h,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 4),

          // Day grid
          for (int row = 0; row < rows; row++)
            Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - startOffset + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 40));
                }
                final date = DateTime(_viewMonth.year, _viewMonth.month, dayNum);
                final isFuture = date.isAfter(now);
                final isSelected = _isSameDay(date, _selectedDate);
                final isTodayCell = _isSameDay(date, now);
                final hasCheckin = _dayHasCheckIns(date);
                final hasLate = _dayHasLate(date);

                return Expanded(
                  child: GestureDetector(
                    onTap: isFuture ? null : () => setState(() => _selectedDate = date),
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _color
                            : isTodayCell
                                ? _color.withValues(alpha: 0.08)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isTodayCell && !isSelected
                            ? Border.all(color: _color.withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : isFuture
                                      ? Colors.grey.shade300
                                      : const Color(0xFF1A237E),
                            ),
                          ),
                          if (hasCheckin || hasLate)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (hasCheckin)
                                  Container(
                                    width: 4, height: 4,
                                    margin: const EdgeInsets.only(top: 2, right: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white70 : Colors.green.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (hasLate)
                                  Container(
                                    width: 4, height: 4,
                                    margin: const EdgeInsets.only(top: 2, left: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.amber.shade200 : Colors.orange.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),

          const SizedBox(height: 8),
          // Legend
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 7, height: 7,
                decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('Check-in', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(width: 12),
            Container(width: 7, height: 7,
                decoration: BoxDecoration(color: Colors.orange.shade600, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('Late', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkIns = AttendanceStore.checkIns
        .where((r) => _matches(r.employee) && _matchesDay(r.date))
        .toList();
    final checkOuts = AttendanceStore.checkOuts
        .where((r) => _matches(r.employee) && _matchesDay(r.date))
        .toList();
    final lateComing = AttendanceStore.lateComing
        .where((r) => _matches(r.employee) && _matchesDay(r.date))
        .toList();
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.access_time_rounded,
                  color: _color, size: 26),
            ),
            const SizedBox(width: 16),
            Text('Attendance Management',
                style: Theme.of(context).textTheme.headlineMedium),
          ]),
          const SizedBox(height: 24),

          // Search bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search employee...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _color, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _color, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Month calendar
          _buildCalendar(),
          const SizedBox(height: 8),

          // Selected day label
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: _color),
              const SizedBox(width: 6),
              Text(
                _isToday
                    ? 'Today — ${_fmtDate(_selectedDate)}'
                    : _fmtDate(_selectedDate),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _color),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Check-In Records (clickable rows)
          _Section(
            title: 'Check-In Records',
            icon: Icons.login_rounded,
            color: _color,
            count: checkIns.length,
            child: checkIns.isEmpty
                ? _Empty()
                : _CheckInTable(
                    records: checkIns,
                    color: _color,
                    onRowTap: _showCheckInDetail,
                  ),
          ),
          const SizedBox(height: 16),

          // Check-Out Records
          _Section(
            title: 'Check-Out Records',
            icon: Icons.logout_rounded,
            color: const Color(0xFF1565C0),
            count: checkOuts.length,
            child: checkOuts.isEmpty
                ? _Empty()
                : _Table(
                    columns: const [
                      'Employee', 'Date', 'Time', 'GPS Location'
                    ],
                    rows: checkOuts
                        .map((r) =>
                            [r.employee, r.date, r.time, r.location])
                        .toList(),
                    color: const Color(0xFF1565C0),
                  ),
          ),
          const SizedBox(height: 16),

          // Late Coming Records
          _Section(
            title: 'Late Coming Records',
            icon: Icons.watch_later_rounded,
            color: const Color(0xFF283593),
            count: lateComing.length,
            child: lateComing.isEmpty
                ? _Empty()
                : _Table(
                    columns: const [
                      'Employee', 'Date', 'Arrival Time', 'Reason'
                    ],
                    rows: lateComing
                        .map((r) => [
                              r.employee,
                              r.date,
                              r.arrivalTime,
                              r.reason
                            ])
                        .toList(),
                    color: const Color(0xFF283593),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ── Clickable check-in table ──────────────────────────────────────────────────

class _CheckInTable extends StatelessWidget {
  final List<CheckInRecord> records;
  final Color color;
  final void Function(CheckInRecord) onRowTap;
  const _CheckInTable(
      {required this.records,
      required this.color,
      required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(color.withValues(alpha: 0.06)),
        border: TableBorder.all(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8)),
        columns: [
          DataColumn(
              label: Text('Employee',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: color))),
          DataColumn(
              label: Text('Date',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: color))),
          DataColumn(
              label: Text('Time',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: color))),
          DataColumn(
              label: Row(children: [
            Text('GPS Location',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: color)),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 11, color: color),
          ])),
        ],
        rows: records
            .map((r) => DataRow(
                  onSelectChanged: (_) => onRowTap(r),
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return color.withValues(alpha: 0.04);
                    }
                    return null;
                  }),
                  cells: [
                    DataCell(Text(r.employee,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF37474F)))),
                    DataCell(Text(r.date,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF37474F)))),
                    DataCell(Text(r.time,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF37474F)))),
                    DataCell(Row(children: [
                      Text(r.location,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF37474F))),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded,
                          size: 14, color: color.withValues(alpha: 0.5)),
                    ])),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

// ── Check-In detail dialog ────────────────────────────────────────────────────

class _CheckInDetailDialog extends StatefulWidget {
  final CheckInRecord record;
  final List<GpsRecord> gpsRecords;
  const _CheckInDetailDialog(
      {required this.record, required this.gpsRecords});

  @override
  State<_CheckInDetailDialog> createState() => _CheckInDetailDialogState();
}

class _CheckInDetailDialogState extends State<_CheckInDetailDialog> {
  static const _color = Color(0xFF0D47A1);
  static final _registeredViews = <String>{};

  Widget _buildMap(String location) {
    // Parse "Lat: X, Lng: Y"
    final parts = location.replaceAll('Lat: ', '').replaceAll('Lng: ', '').split(', ');
    if (parts.length < 2) return const SizedBox.shrink();
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return const SizedBox.shrink();

    final viewId =
        'checkin_detail_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
    if (!_registeredViews.contains(viewId)) {
      _registeredViews.add(viewId);
      final l1 = lng - 0.005;
      final la1 = lat - 0.005;
      final l2 = lng + 0.005;
      final la2 = lat + 0.005;
      ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
        return html.IFrameElement()
          ..src = 'https://www.openstreetmap.org/export/embed.html'
              '?bbox=$l1,$la1,$l2,$la2&layer=mapnik&marker=$lat,$lng'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;
      });
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 200,
        child: HtmlElementView(viewType: viewId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final gps = widget.gpsRecords;
    final latestGps = gps.isNotEmpty ? gps.last : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            // Header
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.login_rounded, color: _color, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Check-In Details',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                ),
              ),
            ]),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Info rows
            _InfoRow(Icons.person_rounded, 'Employee', r.employee),
            const SizedBox(height: 10),
            _InfoRow(Icons.calendar_today_rounded, 'Date', r.date),
            const SizedBox(height: 10),
            _InfoRow(Icons.access_time_rounded, 'Check-In Time', r.time),
            const SizedBox(height: 20),

            // GPS section
            Row(children: [
              const Icon(Icons.location_on_rounded,
                  color: _color, size: 16),
              const SizedBox(width: 6),
              const Text('GPS Tracking',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF37474F))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gps.isNotEmpty
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: gps.isNotEmpty
                          ? Colors.green.shade300
                          : Colors.grey.shade300),
                ),
                child: Text(
                  '${gps.length} point${gps.length == 1 ? '' : 's'} recorded',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: gps.isNotEmpty
                          ? Colors.green.shade700
                          : Colors.grey.shade600),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            if (latestGps != null) ...[
              // Latest coordinates badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: _color.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.gps_fixed_rounded,
                      size: 13, color: _color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(latestGps.location,
                        style: const TextStyle(
                            fontSize: 12,
                            color: _color,
                            fontFamily: 'monospace')),
                  ),
                  Text('at ${latestGps.time}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ]),
              ),
              const SizedBox(height: 10),
              // Map
              _buildMap(latestGps.location),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.location_off_rounded,
                      size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Text('No GPS data recorded yet',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF0D47A1)),
      const SizedBox(width: 10),
      Text('$label:',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF78909C))),
      const SizedBox(width: 8),
      Text(value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A237E))),
    ]);
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final Widget child;
  const _Section(
      {required this.title,
      required this.icon,
      required this.color,
      required this.count,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ]),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          child,
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(children: [
          Icon(Icons.inbox_rounded, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 4),
          Text('No records for this day',
              style:
                  TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final Color color;
  const _Table(
      {required this.columns, required this.rows, required this.color});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(color.withValues(alpha: 0.06)),
        border: TableBorder.all(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8)),
        columns: columns
            .map((c) => DataColumn(
                  label: Text(c,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: color)),
                ))
            .toList(),
        rows: rows
            .map((row) => DataRow(
                  cells: row
                      .map((cell) => DataCell(
                            Text(cell,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF37474F))),
                          ))
                      .toList(),
                ))
            .toList(),
      ),
    );
  }
}
