import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../utils/month_picker.dart';
import '../widgets/back_button.dart';

class EmployeeLeavePage extends StatefulWidget {
  final String prefix;
  const EmployeeLeavePage({super.key, this.prefix = '/employee'});

  @override
  State<EmployeeLeavePage> createState() => _EmployeeLeavePageState();
}

class _EmployeeLeavePageState extends State<EmployeeLeavePage> {
  static const _blue   = Color(0xFF0D47A1);
  static const _purple = Color(0xFF6A1B9A);

  bool _loading = false;
  AppUser? _appUser;
  String _typeFilter = 'all'; // 'all' | 'leave' | 'Permission' | 'Comp Off'
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchLeaveApplications().timeout(const Duration(seconds: 8)),
        UserStore.load(),
      ]);
      final leaves = results[0] as List<LeaveApplication>;
      final users  = results[1] as List<AppUser>;

      if (leaves.isNotEmpty) {
        LeaveStore.applications
          ..clear()
          ..addAll(leaves);
        LeaveStore.syncCounter();
      }

      final match = users.where((u) => u.name == UserSession.name).toList();
      if (mounted) setState(() {
        _appUser = match.isNotEmpty ? match.first : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LeaveApplication> get _apps => LeaveStore.applications
      .where((a) => a.employeeName == UserSession.name)
      .toList();

  List<LeaveApplication> get _filtered {
    return _apps.where((a) {
      final matchType = _typeFilter == 'all'
          ? true
          : _typeFilter == 'leave'
              ? (a.leaveType != 'Permission' && a.leaveType != 'Comp Off')
              : a.leaveType == _typeFilter;
      final matchMonth = _selectedMonth == null ||
          (a.from.year == _selectedMonth!.year &&
              a.from.month == _selectedMonth!.month);
      return matchType && matchMonth;
    }).toList();
  }

  int get _pending  => _filtered.where((a) => a.effectiveStatus == LeaveApprovalStatus.pending).length;
  int get _approved => _filtered.where((a) => a.effectiveStatus == LeaveApprovalStatus.approved).length;
  int get _denied   => _filtered.where((a) => a.effectiveStatus == LeaveApprovalStatus.denied).length;

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(context, _selectedMonth);
    if (picked != null && mounted) setState(() => _selectedMonth = picked);
  }

  Widget _buildTypeChip(String label, String value, IconData icon, Color color) {
    final active = _typeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.3),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
        ]),
      ),
    );
  }

  Widget _buildMonthChip() {
    final active = _selectedMonth != null;
    return GestureDetector(
      onTap: _pickMonth,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _blue.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _blue : _blue.withValues(alpha: 0.3),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_month_rounded, size: 13, color: _blue),
          const SizedBox(width: 5),
          Text(
            active ? monthLabel(_selectedMonth!) : 'Month',
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: _blue),
          ),
          if (active) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() => _selectedMonth = null),
              child: Icon(Icons.close_rounded, size: 12, color: _blue),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Balance helpers ────────────────────────────────────────────────────────
  bool _isThisMonth(LeaveApplication a) {
    final now = DateTime.now();
    return a.from.year == now.year && a.from.month == now.month;
  }

  double _usedBucket(String bucket) => _apps
      .where((a) =>
          a.managerStatus == LeaveApprovalStatus.approved &&
          _isThisMonth(a) &&
          LeaveStore.effectiveBucket(a.leaveType) == bucket)
      .fold(0.0, (s, a) => s + a.effectiveDays);

  double _usedElSinceAvail() {
    final user = _appUser;
    if (user == null) return 0;
    final refStr = user.elLastAvailedAt.isNotEmpty ? user.elLastAvailedAt : user.elEligibleAt;
    final cutoff = refStr.isNotEmpty ? DateTime.tryParse(refStr) : null;
    return _apps
        .where((a) =>
            a.managerStatus == LeaveApprovalStatus.approved &&
            a.leaveType == 'Earned Leave' &&
            (cutoff == null || a.from.isAfter(cutoff)))
        .fold(0.0, (s, a) => s + a.effectiveDays);
  }

  int _elAccrued() {
    final user = _appUser;
    if (user == null) return 0;
    final refStr = user.elLastAvailedAt.isNotEmpty ? user.elLastAvailedAt : user.elEligibleAt;
    if (refStr.isEmpty) return 0;
    final ref = DateTime.tryParse(refStr);
    if (ref == null) return 0;
    final now = DateTime.now();
    final months = (now.year - ref.year) * 12 + (now.month - ref.month);
    return (months * user.monthlyEl).clamp(0, 9999);
  }

  @override
  Widget build(BuildContext context) {
    final user = _appUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.beach_access_rounded, color: _blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Leave Management',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),

            // ── Compact leave balance ─────────────────────────────────────
            if (user != null) _CompactBalance(
              clAvail: (user.monthlyCl - _usedBucket('CL')).clamp(0, 99).toInt(),
              mlAvail: user.isOnroll || user.isElEligible
                  ? (user.monthlyMl - _usedBucket('ML')).clamp(0, 99).toInt()
                  : -1,
              elAvail: user.isElEligible
                  ? (_elAccrued() - _usedElSinceAvail()).clamp(0, 999).toInt()
                  : -1,
            ),
            const SizedBox(width: 10),

            // ── Apply Leave dropdown ──────────────────────────────────────
            PopupMenuButton<String>(
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (val) {
                if (val == 'leave')        context.push('${widget.prefix}/leave/apply');
                else if (val == 'perm')    context.push('${widget.prefix}/leave/permission');
                else if (val == 'compoff') context.push('${widget.prefix}/leave/compoff');
              },
              itemBuilder: (_) => [
                _menuItem('leave',   Icons.event_available_rounded, 'Apply Leave',      _purple),
                _menuItem('perm',    Icons.access_time_rounded,     'Apply Permission', const Color(0xFF00838F)),
                _menuItem('compoff', Icons.swap_horiz_rounded,      'Apply Comp Off',   const Color(0xFF2E7D32)),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _purple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Apply Leave',
                      style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white),
                ]),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, color: _blue, size: 20),
              onPressed: _loadData,
            ),
          ]),
        ),
        const Divider(height: 1),

        // ── Body ──────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Status chips ────────────────────────────────────
                    Row(children: [
                      _StatusChip('Pending',  Icons.hourglass_empty_rounded,
                          Colors.orange.shade700, _pending),
                      const SizedBox(width: 8),
                      _StatusChip('Approved', Icons.check_circle_rounded,
                          Colors.green.shade700, _approved),
                      const SizedBox(width: 8),
                      _StatusChip('Denied',   Icons.cancel_rounded,
                          Colors.red.shade700, _denied),
                    ]),
                    const SizedBox(height: 10),

                    // ── Type filter chips + month picker ─────────────────
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      _buildTypeChip('All',        'all',        Icons.list_rounded,             _blue),
                      _buildTypeChip('Leave',      'leave',      Icons.event_available_rounded,  const Color(0xFF6A1B9A)),
                      _buildTypeChip('Permission', 'Permission', Icons.access_time_rounded,      const Color(0xFF00838F)),
                      _buildTypeChip('Comp Off',   'Comp Off',   Icons.swap_horiz_rounded,       const Color(0xFF2E7D32)),
                      _buildMonthChip(),
                    ]),
                    const SizedBox(height: 12),

                    // ── Leave history ───────────────────────────────────
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _apps.isEmpty
                                  ? 'No leave history yet'
                                  : 'No records for this filter',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                            ),
                            if (_apps.isEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Tap "Apply Leave" to submit your first request.',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            ],
                          ]),
                        ),
                      )
                    else
                      ..._filtered.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AppCard(app: a),
                          )),
                  ],
                ),
        ),
      ]),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
PopupMenuItem<String> _menuItem(String val, IconData icon, String label, Color color) =>
    PopupMenuItem<String>(
      value: val,
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
      ]),
    );

// ── Compact balance (header row) ──────────────────────────────────────────────
class _CompactBalance extends StatelessWidget {
  final int clAvail;
  final int mlAvail; // -1 = not applicable
  final int elAvail; // -1 = not applicable
  const _CompactBalance(
      {required this.clAvail, required this.mlAvail, required this.elAvail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCFD8DC)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Pill('CL', clAvail, Colors.teal.shade700),
        if (mlAvail >= 0) ...[
          const SizedBox(width: 1),
          Container(width: 1, height: 20, color: const Color(0xFFCFD8DC)),
          const SizedBox(width: 1),
          _Pill('ML', mlAvail, const Color(0xFF1565C0)),
        ],
        if (elAvail >= 0) ...[
          const SizedBox(width: 1),
          Container(width: 1, height: 20, color: const Color(0xFFCFD8DC)),
          const SizedBox(width: 1),
          _Pill('EL', elAvail, Colors.purple.shade700),
        ],
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final int avail;
  final Color color;
  const _Pill(this.label, this.avail, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: color, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text('${avail}d',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        Text('avail',
            style: const TextStyle(fontSize: 8, color: Color(0xFF90A4AE))),
      ]),
    );
  }
}

// ── Leave application card ─────────────────────────────────────────────────────
class _AppCard extends StatelessWidget {
  final LeaveApplication app;
  const _AppCard({required this.app});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
    final status = app.effectiveStatus;
    final sColor = _statusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(app.leaveType,
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
            ),
            _StatusPill(_statusLabel(status), sColor, _statusIcon(status)),
          ]),
          const SizedBox(height: 10),

          Wrap(spacing: 16, runSpacing: 6, children: [
            _InfoChip(Icons.calendar_today_rounded,
                '${_fmt(app.from)} → ${_fmt(app.to)}'),
            _InfoChip(Icons.numbers_rounded,
                app.isHalfDay ? '½ day' : '${app.days} day${app.days == 1 ? '' : 's'}'),
            _InfoChip(Icons.access_time_rounded, 'Applied: ${_fmt(app.appliedOn)}'),
            if (app.reason.isNotEmpty)
              _InfoChip(Icons.notes_rounded, app.reason),
          ]),

          if (status == LeaveApprovalStatus.denied && app.effectiveComment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 13, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(app.effectiveComment,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade800)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusPill(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: const Color(0xFF78909C)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  const _StatusChip(this.label, this.icon, this.color, this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: color, height: 1.0)),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.75), height: 1.3)),
        ]),
      ]),
    );
  }
}
