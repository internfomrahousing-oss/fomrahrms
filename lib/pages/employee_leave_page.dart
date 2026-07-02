import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final fresh = await SupabaseService.fetchLeaveApplications()
          .timeout(const Duration(seconds: 8));
      if (fresh.isNotEmpty) {
        LeaveStore.applications
          ..clear()
          ..addAll(fresh);
        LeaveStore.syncCounter();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<LeaveApplication> get _apps => LeaveStore.applications
      .where((a) => a.employeeName == UserSession.name)
      .toList();

  int get _pending  => _apps.where((a) => a.effectiveStatus == LeaveApprovalStatus.pending).length;
  int get _approved => _apps.where((a) => a.effectiveStatus == LeaveApprovalStatus.approved).length;
  int get _denied   => _apps.where((a) => a.effectiveStatus == LeaveApprovalStatus.denied).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Row(children: [
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

            // ── Leave Balance button ────────────────────────────────────
            OutlinedButton.icon(
              onPressed: () => context.push('${widget.prefix}/leave/balance'),
              icon: const Icon(Icons.balance_rounded, size: 15),
              label: const Text('Leave Balance', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: _blue),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),

            // ── Apply Leave dropdown ────────────────────────────────────
            PopupMenuButton<String>(
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (val) {
                if (val == 'leave')       context.push('${widget.prefix}/leave/apply');
                else if (val == 'perm')   context.push('${widget.prefix}/leave/permission');
                else if (val == 'compoff')context.push('${widget.prefix}/leave/compoff');
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
                  Text('Apply Leave', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
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

        // ── Status summary ─────────────────────────────────────────────
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(children: [
            _StatusChip('Pending',  Icons.hourglass_empty_rounded,
                Colors.orange.shade700, _pending),
            const SizedBox(width: 10),
            _StatusChip('Approved', Icons.check_circle_rounded,
                Colors.green.shade700, _approved),
            const SizedBox(width: 10),
            _StatusChip('Denied',   Icons.cancel_rounded,
                Colors.red.shade700, _denied),
          ]),
        ),
        const Divider(height: 1),

        // ── Leave history list ─────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _apps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No leave history yet',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text('Tap "Apply Leave" to submit your first request.',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _apps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _AppCard(app: _apps[i]),
                    ),
        ),
      ]),
    );
  }
}

// ── Leave application card ─────────────────────────────────────────────────────
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
          // Top row: leave type + status pill
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
            _InfoChip(Icons.access_time_rounded,
                'Applied: ${_fmt(app.appliedOn)}'),
            if (app.reason.isNotEmpty)
              _InfoChip(Icons.notes_rounded, app.reason),
          ]),

          if (status == LeaveApprovalStatus.denied &&
              app.effectiveComment.isNotEmpty) ...[
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
