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

  @override
  void initState() {
    super.initState();
  }

  bool get _isToday {
    final t = DateTime.now();
    return _selectedDate.year == t.year &&
        _selectedDate.month == t.month &&
        _selectedDate.day == t.day;
  }

  bool _matchesDayDt(DateTime date, String dateStr) {
    final parts = dateStr.split('/');
    if (parts.length != 3) return false;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    return day == date.day && month == date.month && year == date.year;
  }

  bool _matchesDay(String dateStr) => _matchesDayDt(_selectedDate, dateStr);

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Widget _buildDateNav() {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 28, color: _color),
                tooltip: 'Previous day',
                onPressed: () => setState(() =>
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        _fmtDate(_selectedDate),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: _color),
                      ),
                      if (isToday)
                        const Text('Today',
                            style: TextStyle(fontSize: 11, color: Colors.grey))
                      else
                        const Text('Tap to pick date',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ]),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    size: 28, color: isToday ? Colors.grey : _color),
                tooltip: 'Next day',
                onPressed: isToday
                    ? null
                    : () => setState(() =>
                        _selectedDate = _selectedDate.add(const Duration(days: 1))),
              ),
            ]),
          ),
        ),
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
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Day navigator
          _buildDateNav(),
          const SizedBox(height: 16),

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

  List<List<double>> _parsePoints(List<GpsRecord> records) {
    final pts = <List<double>>[];
    for (final g in records) {
      final p = g.location
          .replaceAll('Lat: ', '')
          .replaceAll('Lng: ', '')
          .split(', ');
      if (p.length >= 2) {
        final lat = double.tryParse(p[0]);
        final lng = double.tryParse(p[1]);
        if (lat != null && lng != null) pts.add([lat, lng]);
      }
    }
    return pts;
  }

  Widget _buildMap(List<GpsRecord> records) {
    final pts = _parsePoints(records);
    if (pts.isEmpty) return const SizedBox.shrink();

    final jsPoints = pts.map((p) => '[${p[0]},${p[1]}]').join(',');
    final viewId = 'route_${records.length}_${pts.last[0].toStringAsFixed(3)}_${pts.last[1].toStringAsFixed(3)}';

    if (!_registeredViews.contains(viewId)) {
      _registeredViews.add(viewId);
      final mapHtml = '''<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body,#map{width:100%;height:100%}
@keyframes dash{to{stroke-dashoffset:-30}}
@keyframes ripple{0%{transform:scale(1);opacity:.8}100%{transform:scale(3.5);opacity:0}}
.pw{position:relative;width:28px;height:28px}
.pr{position:absolute;top:0;left:0;width:28px;height:28px;border-radius:50%;background:rgba(21,101,192,.3);animation:ripple 1.6s ease-out infinite}
.pd{position:absolute;top:7px;left:7px;width:14px;height:14px;border-radius:50%;background:#1565C0;border:3px solid #fff;box-shadow:0 2px 8px rgba(21,101,192,.7)}
</style>
</head><body>
<div id="map"></div>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
const pts=[$jsPoints];
const map=L.map('map',{zoomControl:true,attributionControl:false});
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19}).addTo(map);
if(pts.length>=2){
  L.polyline(pts,{color:'rgba(21,101,192,.18)',weight:12,lineCap:'round',lineJoin:'round'}).addTo(map);
  const poly=L.polyline(pts,{color:'#1565C0',weight:4,dashArray:'14 8',lineCap:'round',lineJoin:'round',opacity:.95}).addTo(map);
  setTimeout(()=>{const el=poly.getElement();if(el){el.style.animation='dash .8s linear infinite';}},120);
  map.fitBounds(poly.getBounds(),{padding:[36,36]});
}else{
  map.setView(pts[0],16);
}
L.circleMarker(pts[0],{radius:7,fillColor:'#43A047',color:'#fff',weight:2.5,fillOpacity:1}).addTo(map).bindTooltip('Start',{permanent:false,direction:'top'});
const icon=L.divIcon({html:'<div class="pw"><div class="pr"></div><div class="pd"></div></div>',iconSize:[28,28],iconAnchor:[14,14],className:''});
L.marker(pts[pts.length-1],{icon}).addTo(map).bindTooltip('Latest',{permanent:false,direction:'top'});
</script></body></html>''';

      final blob = html.Blob([mapHtml], 'text/html');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
        return html.IFrameElement()
          ..src = blobUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 240,
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

            // GPS section header
            Row(children: [
              const Icon(Icons.route_rounded, color: _color, size: 16),
              const SizedBox(width: 6),
              const Text('Route Tracking',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF37474F))),
              const Spacer(),
              if (gps.isNotEmpty) ...[
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: Colors.green.shade500, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('${gps.length} waypoint${gps.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700)),
              ],
            ]),
            const SizedBox(height: 10),

            if (latestGps != null) ...[
              // Latest coordinates badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _color.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.gps_fixed_rounded, size: 13, color: _color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(latestGps.location,
                        style: const TextStyle(
                            fontSize: 12, color: _color, fontFamily: 'monospace')),
                  ),
                  Text('at ${latestGps.time}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ]),
              ),
              const SizedBox(height: 10),
              // Animated route map
              _buildMap(gps),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
