import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';

class HrLeaveRecordsPage extends StatefulWidget {
  const HrLeaveRecordsPage({super.key});

  @override
  State<HrLeaveRecordsPage> createState() => _HrLeaveRecordsPageState();
}

class _HrLeaveRecordsPageState extends State<HrLeaveRecordsPage>
    with SingleTickerProviderStateMixin {
  static const _color = Color(0xFF0D47A1);

  late final TabController _tabs;
  bool _loading = true;

  // Month shown in the All Applications tab — always starts on the current month.
  // Resets to current month each time the page is (re)opened.
  late DateTime _selectedMonth;

  List<AppUser> _employees = [];
  List<LeaveApplication> get _applications => LeaveStore.applications;

  List<LeaveApplication> get _monthApps {
    return _applications.where((a) =>
        a.from.year == _selectedMonth.year &&
        a.from.month == _selectedMonth.month).toList();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  static const _monthNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        UserStore.load(),
        SupabaseService.fetchLeaveApplications().timeout(const Duration(seconds: 8)),
      ]);

      final users = results[0] as List<AppUser>;
      final leaves = results[1] as List<LeaveApplication>;

      if (leaves.isNotEmpty) {
        LeaveStore.applications..clear()..addAll(leaves);
        LeaveStore.syncCounter();
      }

      if (mounted) {
        setState(() {
          _employees = users.where((u) => u.role == 'Employee' || u.role == 'Manager').toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAllocation(AppUser user, int days) async {
    user.leaveAllocation = days;
    await UserStore.upsertOne(user);
    if (mounted) setState(() {});
  }

  // Filter to current month only — leaves reset each month, no carry-over
  bool _isThisMonth(LeaveApplication a) {
    final now = DateTime.now();
    return a.from.year == now.year && a.from.month == now.month;
  }

  double _usedByType(String name, String type, {bool monthOnly = true}) =>
      _applications.where((a) =>
          a.employeeName == name &&
          a.leaveType == type &&
          a.managerStatus == LeaveApprovalStatus.approved &&
          (!monthOnly || _isThisMonth(a)))
      .fold(0.0, (s, a) => s + a.effectiveDays);

static String _fmtD(double d) =>
      d % 1 == 0 ? '${d.toInt()}d' : '${d.toStringAsFixed(1)}d';

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = _selectedMonth.isAfter(now)
        ? DateTime(now.year, now.month, 1)
        : DateTime(_selectedMonth.year, _selectedMonth.month, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.day,
    );

    if (picked != null && mounted) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: Column(
        children: [
          // Header
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const NavBackButton(),
                  const SizedBox(width: 8),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_shared_rounded, color: _color, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Leave Records', style: Theme.of(context).textTheme.headlineMedium),
                    const Text('HR Management', style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
                  ]),
                  const Spacer(),
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded, color: _color),
                    tooltip: 'Refresh',
                  ),
                ]),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabs,
                  labelColor: _color,
                  unselectedLabelColor: const Color(0xFF78909C),
                  indicatorColor: _color,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Employee Allocations'),
                    Tab(icon: Icon(Icons.list_alt_rounded, size: 18),  text: 'All Applications'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _buildAllocationsTab(),
                      _buildApplicationsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Employee allocations ───────────────────────────────────────────

  Widget _buildAllocationsTab() {
    if (_employees.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No employees found', style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Add employees via Administration first.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _employees.length,
      itemBuilder: (context, i) {
        final user = _employees[i];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Employee info row
              Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _color.withValues(alpha: 0.12),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: Color(0xFF1A237E))),
                    Text(user.email,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                    Text(user.designation.isEmpty ? user.role : '${user.designation} · ${user.role}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                  ]),
                ),
                // Editable allocation badge
                _AllocationEditor(
                  value: user.leaveAllocation,
                  onSave: (days) => _saveAllocation(user, days),
                ),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // ML / CL reset monthly; EL is cumulative
              Row(children: [
                _LeaveTypeBlock('ML',
                  used: _usedByType(user.name, 'Medical / Sick Leave'),
                  quota: user.monthlyMl,
                  color: const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                _LeaveTypeBlock('CL',
                  used: _usedByType(user.name, 'Casual Leave'),
                  quota: user.monthlyCl,
                  color: Colors.teal.shade700),
                const SizedBox(width: 8),
                _LeaveTypeBlock('EL',
                  used: _usedByType(user.name, 'Earned Leave', monthOnly: false),
                  quota: user.monthlyEl * 12,
                  color: Colors.purple.shade700),
              ]),
            ]),
          ),
        );
      },
    );
  }

  // ── Tab 2: All leave applications (read-only, filtered by month) ─────────

  Widget _buildApplicationsTab() {
    final apps     = _monthApps;
    final pending  = apps.where((a) => a.managerStatus == LeaveApprovalStatus.pending).length;
    final approved = apps.where((a) => a.managerStatus == LeaveApprovalStatus.approved).length;
    final denied   = apps.where((a) => a.managerStatus == LeaveApprovalStatus.denied).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Month navigator
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(children: [
                  Tooltip(
                    message: 'Previous month',
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.month == 1 ? _selectedMonth.year - 1 : _selectedMonth.year,
                          _selectedMonth.month == 1 ? 12 : _selectedMonth.month - 1,
                        );
                      }),
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
                      onTap: _pickMonth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(children: [
                          Text(
                            '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: _color),
                          ),
                          Text(
                            _isCurrentMonth ? 'Current month' : 'Tap to pick month',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF78909C)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: _isCurrentMonth ? '' : 'Next month',
                    child: InkWell(
                      onTap: _isCurrentMonth ? null : () => setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.month == 12 ? _selectedMonth.year + 1 : _selectedMonth.year,
                          _selectedMonth.month == 12 ? 1 : _selectedMonth.month + 1,
                        );
                      }),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.chevron_right_rounded, size: 28,
                            color: _isCurrentMonth ? Colors.grey.shade400 : _color),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Summary badges
        Row(children: [
          _StatusBadge('Pending',  Icons.hourglass_empty_rounded, Colors.orange.shade700, pending),
          const SizedBox(width: 10),
          _StatusBadge('Approved', Icons.check_circle_rounded,    Colors.green.shade700,  approved),
          const SizedBox(width: 10),
          _StatusBadge('Denied',   Icons.cancel_rounded,          Colors.red.shade700,    denied),
        ]),
        const SizedBox(height: 16),

        if (apps.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(children: [
                  Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    _isCurrentMonth
                        ? 'No applications this month'
                        : 'No applications in ${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                ]),
              ),
            ),
          )
        else
          ...apps.map((app) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AppCard(app: app, fmt: _fmt),
              )),
      ],
    );
  }
}

// ── Allocation editor widget ─────────────────────────────────────────────────

class _AllocationEditor extends StatefulWidget {
  final int value;
  final void Function(int) onSave;
  const _AllocationEditor({required this.value, required this.onSave});

  @override
  State<_AllocationEditor> createState() => _AllocationEditorState();
}

class _AllocationEditorState extends State<_AllocationEditor> {
  static const _color = Color(0xFF0D47A1);
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_AllocationEditor old) {
    super.didUpdateWidget(old);
    if (!_editing) _ctrl.text = '${widget.value}';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v != null && v > 0) {
      widget.onSave(v);
      setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 56,
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _color),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _color, width: 2),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _save,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.check_rounded, size: 16, color: Colors.green.shade700),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => setState(() { _ctrl.text = '${widget.value}'; _editing = false; }),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade400),
          ),
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
      ),
      child: Text('${widget.value} days',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _color)),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF78909C))),
    ]);
  }
}

class _LeaveTypeBlock extends StatelessWidget {
  final String type;
  final double used;
  final int quota;
  final Color color;
  const _LeaveTypeBlock(this.type, {required this.used, required this.quota, required this.color});

  static String _fmt(double d) =>
      d % 1 == 0 ? '${d.toInt()}d' : '${d.toStringAsFixed(1)}d';

  @override
  Widget build(BuildContext context) {
    final available = (quota - used).clamp(0.0, quota.toDouble());
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 5),
          Row(children: [
            Icon(Icons.event_available_rounded, size: 11, color: Colors.green.shade700),
            const SizedBox(width: 3),
            Text(_fmt(available),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.green.shade700)),
            const SizedBox(width: 2),
            const Text('available', style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 11, color: Colors.orange.shade700),
            const SizedBox(width: 3),
            Text(_fmt(used),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700)),
            const SizedBox(width: 2),
            const Text('used', style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
          ]),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  const _StatusBadge(this.label, this.icon, this.color, this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text('$count $label',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _AppCard extends StatelessWidget {
  final LeaveApplication app;
  final String Function(DateTime) fmt;
  const _AppCard({required this.app, required this.fmt});

  Color _statusColor(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => Colors.green.shade700,
        LeaveApprovalStatus.denied   => Colors.red.shade700,
        LeaveApprovalStatus.pending  => Colors.orange.shade700,
      };
  IconData _statusIcon(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => Icons.check_circle_rounded,
        LeaveApprovalStatus.denied   => Icons.cancel_rounded,
        LeaveApprovalStatus.pending  => Icons.hourglass_empty_rounded,
      };
  String _statusLabel(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => 'Approved',
        LeaveApprovalStatus.denied   => 'Denied',
        LeaveApprovalStatus.pending  => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    final ms = app.managerStatus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_rounded, color: Color(0xFF0D47A1), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(app.employeeName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(ms).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(ms), size: 12, color: _statusColor(ms)),
                const SizedBox(width: 4),
                Text(_statusLabel(ms),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: _statusColor(ms))),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 4, children: [
            if (app.leaveType.isNotEmpty)
              _Chip(Icons.label_rounded, app.leaveType),
            _Chip(Icons.calendar_today_rounded, '${fmt(app.from)} → ${fmt(app.to)}'),
            _Chip(Icons.numbers_rounded, '${app.days} day${app.days == 1 ? '' : 's'}'),
            if (app.reason.isNotEmpty)
              _Chip(Icons.notes_rounded, app.reason),
          ]),
          if (ms != LeaveApprovalStatus.pending) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.manage_accounts_rounded,
                  size: 12, color: _statusColor(ms).withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                '${_statusLabel(ms)} by ${app.decidedBy.isEmpty ? 'Manager' : app.decidedBy}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(ms)),
              ),
              if (ms == LeaveApprovalStatus.denied &&
                  app.rejectionComment.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '· "${app.rejectionComment}"',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: const Color(0xFF78909C)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A))),
    ]);
  }
}
