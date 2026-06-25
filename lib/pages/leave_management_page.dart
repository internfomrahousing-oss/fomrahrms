import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';

class LeaveManagementPage extends StatefulWidget {
  const LeaveManagementPage({super.key});

  @override
  State<LeaveManagementPage> createState() => _LeaveManagementPageState();
}

class _LeaveManagementPageState extends State<LeaveManagementPage> {
  static const _accentColor = Color(0xFF0D47A1);

  List<LeaveApplication> get _applications => LeaveStore.applications;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await SupabaseService.fetchLeaveApplications()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (list.isNotEmpty) {
        LeaveStore.applications
          ..clear()
          ..addAll(list);
        LeaveStore.syncCounter();
      }
      setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _setManagerStatus(int i, LeaveApprovalStatus s, {String rejectionComment = ''}) {
    final app       = _applications[i];
    final decidedBy = s == LeaveApprovalStatus.pending
        ? ''
        : (UserSession.name.isNotEmpty ? UserSession.name : 'Management');
    setState(() {
      app.managerStatus    = s;
      app.decidedBy        = decidedBy;
      app.rejectionComment = rejectionComment;
    });
    SupabaseService.updateLeaveManagerStatus(app.id, s,
        decidedBy: decidedBy, rejectionComment: rejectionComment);
  }

  Future<void> _confirmDeny(int i) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Leave'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Provide a reason for rejection (optional):',
              style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Insufficient leave balance / Busy project period',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _setManagerStatus(i, LeaveApprovalStatus.denied,
          rejectionComment: reasonCtrl.text.trim());
    }
    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.beach_access_rounded,
                    color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Text('Leave Management',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 20),

            // Employee Leave Records section
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_shared_rounded,
                    color: _accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Employee Leave Records',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1A237E),
                        fontWeight: FontWeight.w700,
                      )),
            ]),
            const SizedBox(height: 16),

            // Search + filter bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search employee or leave type...',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _accentColor, size: 20),
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
                              const BorderSide(color: _accentColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list_rounded, size: 16),
                    label: const Text('Filter'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Status summary badges
            Row(children: [
              _StatusBadge(
                  'Pending',
                  Icons.hourglass_empty_rounded,
                  Colors.orange.shade700,
                  _applications
                      .where((a) => a.managerStatus == LeaveApprovalStatus.pending)
                      .length),
              const SizedBox(width: 10),
              _StatusBadge(
                  'Approved',
                  Icons.check_circle_rounded,
                  Colors.green.shade700,
                  _applications
                      .where((a) => a.managerStatus == LeaveApprovalStatus.approved)
                      .length),
              const SizedBox(width: 10),
              _StatusBadge(
                  'Denied',
                  Icons.cancel_rounded,
                  Colors.red.shade700,
                  _applications
                      .where((a) => a.managerStatus == LeaveApprovalStatus.denied)
                      .length),
            ]),
            const SizedBox(height: 16),

            // Applications list
            if (_applications.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.inbox_rounded,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No leave applications yet',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14)),
                    ]),
                  ),
                ),
              )
            else
              ...List.generate(_applications.length, (i) {
                final app = _applications[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ApplicationCard(
                    app: app,
                    onManagerApprove: () =>
                        _setManagerStatus(i, LeaveApprovalStatus.approved),
                    onManagerDeny: () => _confirmDeny(i),
                    onReset: () =>
                        _setManagerStatus(i, LeaveApprovalStatus.pending),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ── Leave records widgets ──────────────────────────────────────────────────

class _ApplicationCard extends StatelessWidget {
  final LeaveApplication app;
  final VoidCallback onManagerApprove;
  final VoidCallback onManagerDeny;
  final VoidCallback onReset;

  const _ApplicationCard({
    required this.app,
    required this.onManagerApprove,
    required this.onManagerDeny,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_rounded,
                color: Color(0xFF0D47A1), size: 20),
            const SizedBox(width: 8),
            Text(app.employeeName,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 6, children: [
            _InfoChip(Icons.calendar_today_rounded,
                '${_fmt(app.from)} → ${_fmt(app.to)}'),
            _InfoChip(Icons.numbers_rounded,
                app.isHalfDay ? '½ day' : '${app.days} day${app.days == 1 ? '' : 's'}'),
            if (app.reason.isNotEmpty)
              _InfoChip(Icons.notes_rounded, app.reason),
          ]),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.manage_accounts_rounded,
                size: 16, color: Color(0xFF78909C)),
            const SizedBox(width: 6),
            if (app.managerStatus == LeaveApprovalStatus.pending)
              const Text('Status:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF78909C)))
            else
              Text(
                '${_statusLabel(app.managerStatus)} by ${app.decidedBy.isEmpty ? 'Management' : app.decidedBy}',
                style: TextStyle(
                    fontSize: 12,
                    color: _statusColor(app.managerStatus),
                    fontWeight: FontWeight.w600),
              ),
            const SizedBox(width: 8),
            if (app.managerStatus == LeaveApprovalStatus.pending)
              _StatusPill(_statusLabel(app.managerStatus),
                  _statusColor(app.managerStatus),
                  _statusIcon(app.managerStatus)),
            if (app.managerStatus == LeaveApprovalStatus.pending) ...[
              const Spacer(),
              _ActionBtn('Approve', Colors.green.shade700,
                  Icons.check_rounded, onManagerApprove),
              const SizedBox(width: 8),
              _ActionBtn('Deny', Colors.red.shade700,
                  Icons.close_rounded, onManagerDeny),
            ],
            if (app.managerStatus != LeaveApprovalStatus.pending) ...[
              const Spacer(),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.undo_rounded, size: 14),
                label: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ]),
          // Rejection reason strip
          if (app.managerStatus == LeaveApprovalStatus.denied &&
              app.rejectionComment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    app.rejectionComment,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
      Icon(icon, size: 13, color: const Color(0xFF78909C)),
      const SizedBox(width: 4),
      Text(label,
          style:
              const TextStyle(fontSize: 12, color: Color(0xFF546E7A))),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.color, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}
