import 'package:flutter/material.dart';
import '../models/attendance_store.dart';
import '../services/supabase_service.dart';

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
  bool _isLoading = false;
  List<AttendanceRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  String _dateToStr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.fetchAttendanceForDate(_dateToStr(_selectedDate));
    if (mounted) setState(() { _records = list; _isLoading = false; });
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
    final checkIns  = filtered.where((r) => r.checkInTime.isNotEmpty).toList();
    final checkOuts = filtered.where((r) => r.checkOutTime.isNotEmpty).toList();

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
            // Check-In Records
            _Section(
              title: 'Check-In Records',
              icon: Icons.login_rounded,
              color: _color,
              count: checkIns.length,
              child: checkIns.isEmpty
                  ? _Empty()
                  : _AttendanceTable(
                      records: checkIns,
                      showCheckOut: false,
                      color: _color,
                      onRowTap: _showDetail,
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
                  : _AttendanceTable(
                      records: checkOuts,
                      showCheckOut: true,
                      color: const Color(0xFF1565C0),
                      onRowTap: _showDetail,
                    ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Unified attendance table ──────────────────────────────────────────────────

class _AttendanceTable extends StatelessWidget {
  final List<AttendanceRecord> records;
  final bool showCheckOut;
  final Color color;
  final void Function(AttendanceRecord) onRowTap;
  const _AttendanceTable({
    required this.records,
    required this.showCheckOut,
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
            color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
        columns: [
          DataColumn(label: Text('Employee',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color))),
          DataColumn(label: Text('Date',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color))),
          DataColumn(label: Text(showCheckOut ? 'Check-Out Time' : 'Check-In Time',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color))),
          DataColumn(label: Row(children: [
            Text('Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 11, color: color),
          ])),
        ],
        rows: records.map((r) => DataRow(
          onSelectChanged: (_) => onRowTap(r),
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return color.withValues(alpha: 0.04);
            return null;
          }),
          cells: [
            DataCell(Text(r.employeeName,
                style: const TextStyle(fontSize: 12, color: Color(0xFF37474F)))),
            DataCell(Text(r.date,
                style: const TextStyle(fontSize: 12, color: Color(0xFF37474F)))),
            DataCell(Text(showCheckOut ? r.checkOutTime : r.checkInTime,
                style: const TextStyle(fontSize: 12, color: Color(0xFF37474F)))),
            DataCell(Row(children: [
              Text(r.checkInTime.isNotEmpty && r.checkOutTime.isNotEmpty
                  ? 'In & Out recorded'
                  : r.checkInTime.isNotEmpty ? 'Checked in' : 'Checked out',
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 14, color: color.withValues(alpha: 0.5)),
            ])),
          ],
        )).toList(),
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
