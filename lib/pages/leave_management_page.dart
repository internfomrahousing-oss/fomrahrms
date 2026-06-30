import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/leave_store.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.beach_access_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 22),
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
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _accentColor, width: 2),
                        ),
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
                  child: _ApplicationCard(app: app),
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
  const _ApplicationCard({required this.app});

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
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
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
          _DecisionRow(
            status: app.managerStatus,
            decidedBy: app.decidedBy,
            comment: app.rejectionComment,
          ),
        ]),
      ),
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
      Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
    ]);
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

// ── HR audit row showing one level's decision with name ────────────────────

class _DecisionRow extends StatelessWidget {
  final LeaveApprovalStatus status;
  final String decidedBy;
  final String comment;
  const _DecisionRow({
    required this.status,
    required this.decidedBy,
    required this.comment,
  });

  Color _color() => switch (status) {
        LeaveApprovalStatus.approved => Colors.green.shade700,
        LeaveApprovalStatus.denied   => Colors.red.shade700,
        LeaveApprovalStatus.pending  => Colors.orange.shade700,
      };

  String _label() => switch (status) {
        LeaveApprovalStatus.approved => 'Approved',
        LeaveApprovalStatus.denied   => 'Denied',
        LeaveApprovalStatus.pending  => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.manage_accounts_rounded,
              size: 13, color: Color(0xFF78909C)),
          const SizedBox(width: 5),
          Text(
            status == LeaveApprovalStatus.pending
                ? 'Pending decision'
                : '${_label()} by ${decidedBy.isEmpty ? 'Manager' : decidedBy}',
            style: TextStyle(
                fontSize: 11, color: c, fontWeight: FontWeight.w700),
          ),
        ]),
        if (status == LeaveApprovalStatus.denied && comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('"$comment"',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade700,
                  fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}
