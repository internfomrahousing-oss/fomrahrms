import 'package:flutter/material.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';

class TeamLeaveApprovalsPage extends StatefulWidget {
  /// false = Manager  →  sees only their team
  /// true  = Management → sees all employees, can view/edit any decision
  final bool isManagement;
  const TeamLeaveApprovalsPage({super.key, this.isManagement = false});

  @override
  State<TeamLeaveApprovalsPage> createState() => _TeamLeaveApprovalsPageState();
}

class _TeamLeaveApprovalsPageState extends State<TeamLeaveApprovalsPage> {
  static const _color = Color(0xFF283593);
  bool get _isMgmt => widget.isManagement;

  Set<String> _teamNames = {};
  bool _teamLoaded = false;
  String _search = '';
  LeaveApprovalStatus? _filterStatus;
  bool _loading = false;

  // Management sees all; manager sees only their team
  List<LeaveApplication> get _requests {
    if (_isMgmt) return LeaveStore.applications;
    if (!_teamLoaded) return LeaveStore.applications;
    return LeaveStore.applications
        .where((a) => _teamNames.contains(a.employeeName))
        .toList();
  }

  List<LeaveApplication> get _filtered => _requests.where((r) {
        final matchSearch = _search.isEmpty ||
            r.employeeName.toLowerCase().contains(_search.toLowerCase()) ||
            r.leaveType.toLowerCase().contains(_search.toLowerCase());
        final matchStatus =
            _filterStatus == null || r.managerStatus == _filterStatus;
        return matchSearch && matchStatus;
      }).toList();

  int get _pendingCount =>
      _requests.where((r) => r.managerStatus == LeaveApprovalStatus.pending).length;
  int get _approvedCount =>
      _requests.where((r) => r.managerStatus == LeaveApprovalStatus.approved).length;
  int get _deniedCount =>
      _requests.where((r) => r.managerStatus == LeaveApprovalStatus.denied).length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchLeaveApplications()
            .timeout(const Duration(seconds: 8)),
        UserStore.load(),
      ]);
      final leaves = results[0] as List<LeaveApplication>;
      final users  = results[1] as List;

      if (leaves.isNotEmpty) {
        LeaveStore.applications..clear()..addAll(leaves);
        LeaveStore.syncCounter();
      }

      final myTeam = users
          .cast<dynamic>()
          .where((u) => u.reportingManager == UserSession.name)
          .map<String>((u) => u.name as String)
          .toSet();

      if (mounted) {
        setState(() {
          _teamNames  = myTeam;
          _teamLoaded = true;
          _loading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Both manager and management update the same field
  Future<void> _approve(LeaveApplication app) async {
    final by = UserSession.name;
    setState(() {
      app.managerStatus    = LeaveApprovalStatus.approved;
      app.decidedBy        = by;
      app.rejectionComment = '';
    });
    await SupabaseService.updateLeaveManagerStatus(
        app.id, LeaveApprovalStatus.approved, decidedBy: by);
  }

  Future<void> _deny(LeaveApplication app) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deny Leave',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Reason for denial (optional):',
              style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
          const SizedBox(height: 10),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Insufficient notice / Busy period',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white),
            child: const Text('Deny'),
          ),
        ],
      ),
    );
    if (ok != true) { reasonCtrl.dispose(); return; }
    final comment = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    final by = UserSession.name;
    setState(() {
      app.managerStatus    = LeaveApprovalStatus.denied;
      app.decidedBy        = by;
      app.rejectionComment = comment;
    });
    await SupabaseService.updateLeaveManagerStatus(
        app.id, LeaveApprovalStatus.denied,
        decidedBy: by, rejectionComment: comment);
  }

  Future<void> _reset(LeaveApplication app) async {
    setState(() {
      app.managerStatus    = LeaveApprovalStatus.pending;
      app.decidedBy        = '';
      app.rejectionComment = '';
    });
    await SupabaseService.updateLeaveManagerStatus(
        app.id, LeaveApprovalStatus.pending);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isMgmt
                    ? Icons.admin_panel_settings_rounded
                    : Icons.group_rounded,
                color: _color, size: 26),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _isMgmt ? 'Leave Approvals' : 'Team Leave Approvals',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                _isMgmt
                    ? 'View and edit all leave decisions'
                    : 'Employees under your wing',
                style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
              ),
            ]),
          ]),
          const SizedBox(height: 24),

          // Summary chips
          Row(children: [
            _SummaryChip(
              label: 'Pending',
              count: _pendingCount,
              icon: Icons.hourglass_empty_rounded,
              color: Colors.orange.shade700,
              active: _filterStatus == LeaveApprovalStatus.pending,
              onTap: () => setState(() => _filterStatus =
                  _filterStatus == LeaveApprovalStatus.pending
                      ? null : LeaveApprovalStatus.pending),
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Approved',
              count: _approvedCount,
              icon: Icons.check_circle_rounded,
              color: Colors.green.shade700,
              active: _filterStatus == LeaveApprovalStatus.approved,
              onTap: () => setState(() => _filterStatus =
                  _filterStatus == LeaveApprovalStatus.approved
                      ? null : LeaveApprovalStatus.approved),
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Denied',
              count: _deniedCount,
              icon: Icons.cancel_rounded,
              color: Colors.red.shade700,
              active: _filterStatus == LeaveApprovalStatus.denied,
              onTap: () => setState(() => _filterStatus =
                  _filterStatus == LeaveApprovalStatus.denied
                      ? null : LeaveApprovalStatus.denied),
            ),
          ]),
          const SizedBox(height: 16),

          // Search bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search employee or leave type...',
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: _color, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _search = ''))
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _color, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_filterStatus != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Text(
                  'Showing: ${_filterStatus!.name[0].toUpperCase()}${_filterStatus!.name.substring(1)} only',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _filterStatus = null),
                  child: const Text('Clear',
                      style: TextStyle(
                          fontSize: 12,
                          color: _color,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),

          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator())),

          if (!_loading && !_isMgmt && _teamLoaded && _teamNames.isEmpty)
            _emptyCard(
              icon: Icons.group_off_rounded,
              title: 'No employees assigned to you',
              subtitle:
                  'Ask Management to assign employees via Administration → Edit User → Reporting Manager.',
            )
          else if (!_loading && _requests.isEmpty)
            _emptyCard(
              icon: Icons.inbox_rounded,
              title: _isMgmt
                  ? 'No leave requests yet'
                  : 'No leave requests from your team',
              subtitle: 'Leave requests will appear here for approval.',
            )
          else if (!_loading && filtered.isEmpty)
            _emptyCard(
              icon: Icons.search_off_rounded,
              title: 'No results match your search',
              subtitle: '',
            )
          else if (!_loading)
            ...filtered.map((app) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestCard(
                    request:      app,
                    isManagement: _isMgmt,
                    onApprove:    () => _approve(app),
                    onDeny:       () => _deny(app),
                    onReset:      () => _reset(app),
                  ),
                )),
        ]),
      ),
    );
  }

  Widget _emptyCard(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(children: [
            Icon(icon, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Request card ───────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _RequestCard extends StatelessWidget {
  final LeaveApplication request;
  final bool isManagement;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback onReset;

  const _RequestCard({
    required this.request,
    required this.isManagement,
    required this.onApprove,
    required this.onDeny,
    required this.onReset,
  });

  static Color _sc(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => Colors.green.shade700,
        LeaveApprovalStatus.denied   => Colors.red.shade700,
        LeaveApprovalStatus.pending  => Colors.orange.shade700,
      };
  static IconData _si(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => Icons.check_circle_rounded,
        LeaveApprovalStatus.denied   => Icons.cancel_rounded,
        LeaveApprovalStatus.pending  => Icons.hourglass_empty_rounded,
      };
  static String _sl(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => 'Approved',
        LeaveApprovalStatus.denied   => 'Denied',
        LeaveApprovalStatus.pending  => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    final status = request.managerStatus;
    final sc     = _sc(status);
    final si     = _si(status);
    final sl     = _sl(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Employee header
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF283593).withValues(alpha: 0.1),
              child: Text(
                request.employeeName.isNotEmpty
                    ? request.employeeName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Color(0xFF283593),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.employeeName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E))),
                    Text(request.department,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF78909C))),
                  ]),
            ),
            _StatusPill(sl, sc, si),
          ]),
          const SizedBox(height: 14),

          // Leave details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF283593).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF283593).withValues(alpha: 0.08)),
            ),
            child: Column(children: [
              _DetailRow(Icons.label_rounded,      'Leave Type', request.leaveType),
              const SizedBox(height: 8),
              _DetailRow(Icons.date_range_rounded, 'Duration',
                  '${_fmtDate(request.from)}  →  ${_fmtDate(request.to)}'),
              const SizedBox(height: 8),
              _DetailRow(Icons.numbers_rounded,    'Days',
                  request.isHalfDay
                      ? '½ day'
                      : '${request.days} day${request.days == 1 ? '' : 's'}'),
              if (request.reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailRow(Icons.notes_rounded, 'Reason', request.reason),
              ],
            ]),
          ),
          const SizedBox(height: 14),

          // Action row
          if (status == LeaveApprovalStatus.pending)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDeny,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Deny'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ])
          else
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(si, size: 16, color: sc),
                  const SizedBox(width: 6),
                  Text(
                    '$sl by ${request.decidedBy.isEmpty ? 'Manager' : request.decidedBy}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sc),
                  ),
                ]),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.undo_rounded, size: 15),
                label: const Text('Undo'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF78909C)),
              ),
            ]),

          // Denial reason
          if (status == LeaveApprovalStatus.denied &&
              request.rejectionComment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(request.rejectionComment,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade800)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: const Color(0xFF78909C)),
      const SizedBox(width: 8),
      Text('$label: ',
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF78909C),
              fontWeight: FontWeight.w500)),
      Expanded(
        child: Text(value,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A237E),
                fontWeight: FontWeight.w600)),
      ),
    ]);
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
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? Colors.white : color),
          const SizedBox(width: 6),
          Text('$count $label',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : color)),
        ]),
      ),
    );
  }
}
