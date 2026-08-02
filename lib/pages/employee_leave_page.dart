import 'package:flutter/material.dart';
import '../utils/attendance_cycle.dart';
import '../utils/el_accrual.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../utils/month_picker.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class EmployeeLeavePage extends StatefulWidget {
  final String prefix;
  // When true, renders just the content (no Scaffold/back-button/page title)
  // so it can be embedded inside another page, e.g. MyAttendanceAndLeavePage.
  final bool embedded;
  const EmployeeLeavePage({super.key, this.prefix = '/employee', this.embedded = false});

  @override
  State<EmployeeLeavePage> createState() => _EmployeeLeavePageState();
}

class _EmployeeLeavePageState extends State<EmployeeLeavePage> {
  static Color get _blue => AppTheme.primaryBlue;
  static Color get _purple => AppTheme.primaryBlue;

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
    final apps = _apps.where((a) {
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
    // Pending requests need attention first, so surface them ahead of
    // already-decided (approved/denied) ones.
    apps.sort((a, b) {
      final aPending = a.effectiveStatus == LeaveApprovalStatus.pending;
      final bPending = b.effectiveStatus == LeaveApprovalStatus.pending;
      if (aPending == bPending) return 0;
      return aPending ? -1 : 1;
    });
    return apps;
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
    // Attendance cycle runs 26th -> 25th, so a calendar-month comparison
    // splits a single cycle across two windows (and merges two cycles into
    // one) around the boundary.
    return isInCurrentCycle(a.from);
  }

  double _usedBucket(String bucket) => _apps
      .where((a) =>
          a.managerStatus == LeaveApprovalStatus.approved &&
          _isThisMonth(a) &&
          a.bucket == bucket)
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

  int _elAccrued() => elAccruedFor(_appUser);

  @override
  Widget build(BuildContext context) {
    final user = _appUser;

    final balanceAndActions = Row(mainAxisSize: MainAxisSize.min, children: [
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
          _menuItem('perm',    Icons.access_time_rounded,     'Apply Permission', AppTheme.accentBlue),
          _menuItem('compoff', Icons.swap_horiz_rounded,      'Apply Comp Off',   const Color(0xFF22C55E)),
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
        icon: Icon(Icons.refresh_rounded, color: _blue, size: 20),
        onPressed: _loadData,
      ),
    ]);

    final titleRow = widget.embedded
        ? Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.beach_access_rounded, color: _blue, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Leave',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ])
        : Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.beach_access_rounded, color: _blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Leave Management',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
          ]);

    // On narrow screens there isn't room for the title AND the balance
    // chip / Apply Leave button / refresh icon on one line — cramming them
    // into a single Row starves the title's Expanded text down to almost
    // no width, which makes it wrap one letter per line. Stack them
    // instead, letting the actions row scroll sideways if still tight.
    final header = LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 480;
      if (!narrow) {
        return Row(children: [
          Expanded(child: titleRow),
          balanceAndActions,
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        titleRow,
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: balanceAndActions,
        ),
      ]);
    });

    // ── Leave history (shared between embedded / standalone) ──────────────
    final historyChildren = <Widget>[
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
        _buildTypeChip('Leave',      'leave',      Icons.event_available_rounded,  AppTheme.primaryBlue),
        _buildTypeChip('Permission', 'Permission', Icons.access_time_rounded,      AppTheme.accentBlue),
        _buildTypeChip('Comp Off',   'Comp Off',   Icons.swap_horiz_rounded,       const Color(0xFF22C55E)),
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
    ];

    if (widget.embedded) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: historyChildren),
      ]);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(child: Column(children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: header,
        ),
        const Divider(height: 1),

        // ── Body ──────────────────────────────────────────────────────────
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: historyChildren),
                ),
      ])),
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
          _Pill('ML', mlAvail, AppTheme.accentBlue),
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
            style: const TextStyle(fontSize: 8, color: Color(0xFF6B7280))),
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
                      fontWeight: FontWeight.w700, color: Color(0xFF111827))),
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
      Icon(icon, size: 12, color: const Color(0xFF6B7280)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
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
