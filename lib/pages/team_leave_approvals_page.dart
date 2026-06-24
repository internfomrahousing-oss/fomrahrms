import 'package:flutter/material.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';

class TeamLeaveApprovalsPage extends StatefulWidget {
  const TeamLeaveApprovalsPage({super.key});

  @override
  State<TeamLeaveApprovalsPage> createState() => _TeamLeaveApprovalsPageState();
}

class _TeamLeaveApprovalsPageState extends State<TeamLeaveApprovalsPage> {
  static const _color = Color(0xFF283593);

  List<LeaveApplication> get _requests {
    if (!_teamLoaded) return LeaveStore.applications; // still loading
    return LeaveStore.applications
        .where((a) => _teamNames.contains(a.employeeName))
        .toList();
  }

  Set<String> _teamNames = {};
  bool _teamLoaded = false;
  String _search = '';
  LeaveApprovalStatus? _filterStatus;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchLeaveApplications().timeout(const Duration(seconds: 8)),
        UserStore.load(),
      ]);

      final leaves = results[0] as List<LeaveApplication>;
      final users  = results[1] as List;

      if (leaves.isNotEmpty) {
        LeaveStore.applications..clear()..addAll(leaves);
        LeaveStore.syncCounter();
      }

      // Build the set of employee names that report to this manager
      final myTeam = users
          .cast<dynamic>()
          .where((u) => u.reportingManager == UserSession.name)
          .map<String>((u) => u.name as String)
          .toSet();

      if (mounted) setState(() { _teamNames = myTeam; _teamLoaded = true; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LeaveApplication> get _filtered {
    return _requests.where((r) {
      final matchSearch = _search.isEmpty ||
          r.employeeName.toLowerCase().contains(_search.toLowerCase()) ||
          r.leaveType.toLowerCase().contains(_search.toLowerCase());
      final matchStatus =
          _filterStatus == null || r.managerStatus == _filterStatus;
      return matchSearch && matchStatus;
    }).toList();
  }

  Future<void> _setStatus(LeaveApplication app, LeaveApprovalStatus s) async {
    if (app.decidedBy == 'Management') return;
    final newDecidedBy = s == LeaveApprovalStatus.pending ? '' : UserSession.name;
    setState(() {
      app.managerStatus = s;
      app.decidedBy = newDecidedBy;
    });
    await SupabaseService.updateLeaveManagerStatus(app.id, s, decidedBy: newDecidedBy);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pendingCount =
        _requests.where((r) => r.managerStatus == LeaveApprovalStatus.pending).length;
    final approvedCount =
        _requests.where((r) => r.managerStatus == LeaveApprovalStatus.approved).length;
    final deniedCount =
        _requests.where((r) => r.managerStatus == LeaveApprovalStatus.denied).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                child: const Icon(Icons.group_rounded,
                    color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Team Leave Approvals',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 2),
                const Text('Employees under your wing',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF78909C))),
              ]),
            ]),
            const SizedBox(height: 24),

            // Summary strip
            Row(children: [
              _SummaryChip(
                label: 'Pending',
                count: pendingCount,
                icon: Icons.hourglass_empty_rounded,
                color: Colors.orange.shade700,
                active: _filterStatus == LeaveApprovalStatus.pending,
                onTap: () => setState(() => _filterStatus =
                    _filterStatus == LeaveApprovalStatus.pending
                        ? null
                        : LeaveApprovalStatus.pending),
              ),
              const SizedBox(width: 10),
              _SummaryChip(
                label: 'Approved',
                count: approvedCount,
                icon: Icons.check_circle_rounded,
                color: Colors.green.shade700,
                active: _filterStatus == LeaveApprovalStatus.approved,
                onTap: () => setState(() => _filterStatus =
                    _filterStatus == LeaveApprovalStatus.approved
                        ? null
                        : LeaveApprovalStatus.approved),
              ),
              const SizedBox(width: 10),
              _SummaryChip(
                label: 'Denied',
                count: deniedCount,
                icon: Icons.cancel_rounded,
                color: Colors.red.shade700,
                active: _filterStatus == LeaveApprovalStatus.denied,
                onTap: () => setState(() => _filterStatus =
                    _filterStatus == LeaveApprovalStatus.denied
                        ? null
                        : LeaveApprovalStatus.denied),
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
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _color, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _search = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _color, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filter hint
            if (_filterStatus != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Text(
                    'Showing: ${_filterStatus!.name[0].toUpperCase()}${_filterStatus!.name.substring(1)} only',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF78909C)),
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

            // Loading indicator
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              )),

            // Request cards
            if (!_loading && _teamLoaded && _teamNames.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.group_off_rounded, size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No employees assigned to you',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                          'Ask Management to assign employees to you\nvia Administration → Edit User → Reporting Manager.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ]),
                  ),
                ),
              )
            else if (!_loading && _requests.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.inbox_rounded, size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No leave requests from your team',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Leave requests submitted by your team\nwill appear here for approval.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ]),
                  ),
                ),
              )
            else if (!_loading && filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.search_off_rounded,
                          size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No results match your search',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13)),
                    ]),
                  ),
                ),
              )
            else if (!_loading)
              ...filtered.map((app) {
                final canUndo = app.decidedBy != 'Management';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestCard(
                    request: app,
                    onApprove: () => _setStatus(app, LeaveApprovalStatus.approved),
                    onDeny:    () => _setStatus(app, LeaveApprovalStatus.denied),
                    onReset:   canUndo ? () => _setStatus(app, LeaveApprovalStatus.pending) : null,

                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ── Request card ───────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _RequestCard extends StatelessWidget {
  final LeaveApplication request;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback? onReset; // null = management locked, cannot undo

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onDeny,
    required this.onReset,
  });

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
    final sc = _statusColor(request.managerStatus);
    final si = _statusIcon(request.managerStatus);
    final sl = _statusLabel(request.managerStatus);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Employee header row
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  const Color(0xFF283593).withValues(alpha: 0.1),
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
              _DetailRow(Icons.label_rounded,           'Leave Type', request.leaveType),
              const SizedBox(height: 8),
              _DetailRow(Icons.date_range_rounded,      'Duration',   '${_fmtDate(request.from)}  →  ${_fmtDate(request.to)}'),
              const SizedBox(height: 8),
              _DetailRow(Icons.numbers_rounded,         'Days',       '${request.days} day${request.days == 1 ? '' : 's'}'),
              const SizedBox(height: 8),
              _DetailRow(Icons.notes_rounded,           'Reason',     request.reason),
            ]),
          ),
          const SizedBox(height: 14),

          // Action row
          if (request.managerStatus == LeaveApprovalStatus.pending)
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sc)),
                ]),
              ),
              const Spacer(),
              if (onReset != null)
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.undo_rounded, size: 15),
                  label: const Text('Undo'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF78909C)),
                )
              else
                Tooltip(
                  message: 'Only Management can undo this decision',
                  child: Icon(Icons.lock_rounded, size: 16, color: Colors.grey.shade400),
                ),
            ]),
        ]),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

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
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: active ? Colors.white : color),
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
