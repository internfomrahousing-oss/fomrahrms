import 'dart:html' as html_lib;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/attendance_store.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';

class HrAttendanceRecordsPage extends StatefulWidget {
  final String routePrefix;
  const HrAttendanceRecordsPage({super.key, this.routePrefix = ''});

  @override
  State<HrAttendanceRecordsPage> createState() =>
      _HrAttendanceRecordsPageState();
}

class _HrAttendanceRecordsPageState extends State<HrAttendanceRecordsPage> {
  static const _color = Color(0xFF0D47A1);

  String _search = '';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<AttendanceRecord> _records = [];
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  String _dateToStr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      SupabaseService.fetchAttendanceForDate(_dateToStr(_selectedDate)),
      UserStore.load(),
    ]);
    if (mounted) setState(() {
      _records = results[0] as List<AttendanceRecord>;
      _totalUsers = (results[1] as List).length;
      _isLoading = false;
    });
  }

  bool get _isToday {
    final t = DateTime.now();
    return _selectedDate.year == t.year &&
        _selectedDate.month == t.month &&
        _selectedDate.day == t.day;
  }

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

  void _showDetail(AttendanceRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => _AttendanceDetailDialog(record: record),
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
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadRecords();
    }
  }

  void _showEmployeeList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmployeeListSheet(
        routePrefix: widget.routePrefix,
        parentContext: context,
      ),
    );
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
              Tooltip(
                message: 'Previous day',
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                    _loadRecords();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.chevron_left_rounded, size: 28, color: _color),
                  ),
                ),
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
              Tooltip(
                message: isToday ? '' : 'Next day',
                child: InkWell(
                  onTap: isToday
                      ? null
                      : () {
                          setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                          _loadRecords();
                        },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 28, color: isToday ? Colors.grey.shade400 : _color),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _records
        .where((r) => _matches(r.employeeName))
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
              child: const Icon(Icons.access_time_rounded, color: _color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text('Attendance Management',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            Tooltip(
              message: 'Refresh',
              child: InkWell(
                onTap: _isLoading ? null : _loadRecords,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _color))
                      : const Icon(Icons.refresh_rounded, color: _color, size: 22),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Employee Attendance Records shortcut
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showEmployeeList(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: _color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Employee Attendance Records',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                              color: _color)),
                      Text('View monthly attendance calendar per employee',
                          style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _color),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Search bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search employee...',
                  prefixIcon: const Icon(Icons.search_rounded, color: _color, size: 20),
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
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Day navigator
          _buildDateNav(),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: _color)),
            )
          else ...[
            _AttendanceSummaryCard(records: _records, totalUsers: _totalUsers),
            const SizedBox(height: 16),
            _Section(
              title: 'Attendance Records',
              icon: Icons.access_time_rounded,
              color: _color,
              count: filtered.length,
              child: filtered.isEmpty
                  ? _Empty()
                  : _AttendanceTable(
                      records: filtered,
                      color: _color,
                      onRowTap: _showDetail,
                    ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Attendance summary card ───────────────────────────────────────────────────

class _AttendanceSummaryCard extends StatelessWidget {
  final List<AttendanceRecord> records;
  final int totalUsers;
  const _AttendanceSummaryCard({required this.records, required this.totalUsers});

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final present = records.where((r) => r.checkInTime.isNotEmpty).length;
    final absent  = (totalUsers - present).clamp(0, totalUsers);

    final stats = [
      ('Present', '$present', Icons.check_circle_rounded, _green),
      ('Absent',  '$absent',  Icons.cancel_rounded,       const Color(0xFFC62828)),
      ('Late Arrivals', '—', Icons.schedule_rounded,      const Color(0xFFE65100)),
      ('On Permission', '—', Icons.event_note_rounded,    const Color(0xFF1565C0)),
      ('Comp Off',      '—', Icons.weekend_rounded,       const Color(0xFF6A1B9A)),
      ('On Duty',       '—', Icons.work_rounded,          const Color(0xFF00695C)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bar_chart_rounded, color: _green, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Summary',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32))),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stats.map((s) => _SumStat(
              label: s.$1,
              value: s.$2,
              icon:  s.$3,
              color: s.$4,
            )).toList(),
          ),
        ]),
      ),
    );
  }
}

class _SumStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SumStat({required this.label, required this.value,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF78909C))),
        ]),
      ]),
    );
  }
}

// ── Unified attendance table ──────────────────────────────────────────────────

class _AttendanceTable extends StatelessWidget {
  final List<AttendanceRecord> records;
  final Color color;
  final void Function(AttendanceRecord) onRowTap;
  const _AttendanceTable({
    required this.records,
    required this.color,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(color.withValues(alpha: 0.06)),
        border: TableBorder.all(
            color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(8)),
        columns: [
          DataColumn(label: Text('Employee',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color))),
          DataColumn(label: Text('Date',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color))),
          DataColumn(label: Text('Check-In Time',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color))),
          DataColumn(label: Text('Check-Out Time',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color))),
          DataColumn(label: Row(children: [
            Text('Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 11, color: color),
          ])),
        ],
        rows: records.map((r) {
          final bothRecorded = r.checkInTime.isNotEmpty && r.checkOutTime.isNotEmpty;
          final statusText = bothRecorded
              ? 'In & Out recorded'
              : r.checkInTime.isNotEmpty ? 'Checked in' : 'Checked out';
          final statusColor = bothRecorded ? Colors.green.shade700 : color;
          return DataRow(
            onSelectChanged: (_) => onRowTap(r),
            color: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) return color.withValues(alpha: 0.04);
              return null;
            }),
            cells: [
              DataCell(Text(r.employeeName,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
              DataCell(Text(r.date,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
              DataCell(Text(r.checkInTime.isNotEmpty ? r.checkInTime : '—',
                  style: TextStyle(fontSize: 12,
                      color: r.checkInTime.isNotEmpty
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.grey.shade400))),
              DataCell(Text(r.checkOutTime.isNotEmpty ? r.checkOutTime : '—',
                  style: TextStyle(fontSize: 12,
                      color: r.checkOutTime.isNotEmpty
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.grey.shade400))),
              DataCell(Row(children: [
                Text(statusText,
                    style: TextStyle(fontSize: 11, color: statusColor.withValues(alpha: 0.9))),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 14, color: statusColor.withValues(alpha: 0.5)),
              ])),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Attendance detail dialog ──────────────────────────────────────────────────

class _AttendanceDetailDialog extends StatelessWidget {
  final AttendanceRecord record;
  const _AttendanceDetailDialog({required this.record});

  static const _color = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    final r = record;
    final hasCheckOut = r.checkOutTime.isNotEmpty;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.access_time_rounded, color: _color, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Attendance Record',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade600),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              _InfoRow(Icons.person_rounded, 'Employee', r.employeeName),
              if (r.employeeId.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoRow(Icons.badge_rounded, 'Employee ID', r.employeeId),
              ],
              const SizedBox(height: 10),
              _InfoRow(Icons.calendar_today_rounded, 'Date', r.date),
              const SizedBox(height: 10),
              _InfoRow(Icons.login_rounded, 'Check-In', r.checkInTime.isNotEmpty ? r.checkInTime : '—'),
              const SizedBox(height: 10),
              _InfoRow(Icons.logout_rounded, 'Check-Out', hasCheckOut ? r.checkOutTime : '—'),
              if (r.gpsPoints.isNotEmpty || r.location.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RouteMap(record: r),
              ],
              if (r.checkInTime.isNotEmpty && hasCheckOut) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text('Full day attendance recorded',
                        style: TextStyle(fontSize: 13, color: Colors.green.shade700,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ] else if (r.checkInTime.isNotEmpty && !hasCheckOut) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(children: [
                    Icon(Icons.pending_rounded, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text('Employee not yet checked out',
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ],
            ],
          ),
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

// ── Route map widget ─────────────────────────────────────────────────────────

class _RouteMap extends StatefulWidget {
  final AttendanceRecord record;
  const _RouteMap({required this.record});

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  static final _registered = <String>{};

  String get _viewId {
    final pts = widget.record.gpsPoints.length;
    return 'hr_route_${widget.record.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_$pts';
  }

  List<List<double>> get _points {
    if (widget.record.gpsPoints.isNotEmpty) return widget.record.gpsPoints;
    // Fallback: single point from location field
    final parts = widget.record.location.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) return [[lat, lng]];
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    final pts = _points;
    if (pts.isEmpty) return;
    if (_registered.contains(_viewId)) return;
    _registered.add(_viewId);

    // Build JS points array
    final jsPts = pts.map((p) => '[${p[0]},${p[1]}]').join(',');

    final html = '''
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <style>body{margin:0;padding:0;} #map{width:100%;height:100%;}</style>
      <div id="map"></div>
      <script>
        var pts = [$jsPts];
        var map = L.map('map', {zoomControl:true});
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          {attribution:'© OpenStreetMap'}).addTo(map);

        if (pts.length > 1) {
          var route = L.polyline(pts, {color:'#1565C0', weight:4, opacity:0.85}).addTo(map);

          // Green circle = start
          L.circleMarker(pts[0], {
            radius:8, color:'#fff', weight:2,
            fillColor:'#2E7D32', fillOpacity:1
          }).addTo(map).bindPopup('Check-in location');

          // Red circle = latest point
          L.circleMarker(pts[pts.length-1], {
            radius:9, color:'#fff', weight:2,
            fillColor:'#C62828', fillOpacity:1
          }).addTo(map).bindPopup('Last known location');

          map.fitBounds(route.getBounds(), {padding:[30,30]});
        } else {
          L.marker(pts[0]).addTo(map).bindPopup('Location').openPopup();
          map.setView(pts[0], 15);
        }
      </script>
    ''';

    final blob = html_lib.Blob([html], 'text/html');
    final url  = html_lib.Url.createObjectUrl(blob);
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId, (_) => html_lib.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width  = '100%'
        ..style.height = '100%',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pts = _points;
    if (pts.isEmpty) return const SizedBox.shrink();

    final last = pts.last;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.route_rounded, size: 15, color: Color(0xFF1565C0)),
        const SizedBox(width: 6),
        Text(
          pts.length > 1 ? 'Route (${pts.length} points)' : 'Last Known Location',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 200,
          child: HtmlElementView(viewType: _viewId),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Last: ${last[0].toStringAsFixed(6)}, ${last[1].toStringAsFixed(6)}',
        style: TextStyle(fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
    ]);
  }
}

// ── Employee list bottom sheet ────────────────────────────────────────────────
class _EmployeeListSheet extends StatefulWidget {
  final String routePrefix;
  final BuildContext parentContext;
  const _EmployeeListSheet({required this.routePrefix, required this.parentContext});

  @override
  State<_EmployeeListSheet> createState() => _EmployeeListSheetState();
}

class _EmployeeListSheetState extends State<_EmployeeListSheet> {
  static const _color = Color(0xFF0D47A1);
  List<AppUser> _all = [];
  List<AppUser> _filtered = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await UserStore.load();
    if (!mounted) return;
    final active = users.where((u) => u.active).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _all      = active;
      _filtered = active;
      _loading  = false;
    });
  }

  void _filter(String q) {
    setState(() {
      _search   = q;
      _filtered = _all
          .where((u) => u.name.toLowerCase().contains(q.toLowerCase()) ||
                        u.designation.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle + header
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_alt_rounded, color: _color, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Select Employee',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: false,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search by name or designation...',
                prefixIcon: const Icon(Icons.search_rounded, color: _color, size: 20),
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
                fillColor: cs.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: cs.outlineVariant, height: 1),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _color, strokeWidth: 2))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_off_rounded, size: 40,
                              color: cs.onSurface.withValues(alpha: 0.2)),
                          const SizedBox(height: 8),
                          Text('No employees found',
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.4),
                                  fontSize: 13)),
                        ]),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                        itemBuilder: (_, i) {
                          final emp = _filtered[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _color.withValues(alpha: 0.1),
                              child: Text(
                                emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    color: _color, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            title: Text(emp.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: emp.designation.isNotEmpty
                                ? Text(emp.designation,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)))
                                : null,
                            trailing: const Icon(Icons.chevron_right_rounded, color: _color),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.parentContext.go(
                                '${widget.routePrefix}/attendance/employee-attendance-calendar',
                                extra: {
                                  'employeeId':   emp.employeeId,
                                  'employeeName': emp.name,
                                },
                              );
                            },
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
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
