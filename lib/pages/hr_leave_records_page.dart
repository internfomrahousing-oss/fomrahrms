import 'package:flutter/material.dart';
import '../models/leave_store.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';

class HrLeaveRecordsPage extends StatefulWidget {
  const HrLeaveRecordsPage({super.key});

  @override
  State<HrLeaveRecordsPage> createState() => _HrLeaveRecordsPageState();
}

class _HrLeaveRecordsPageState extends State<HrLeaveRecordsPage> {
  static const _color = Color(0xFF0D47A1);

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
      setState(() {
        LeaveStore.applications
          ..clear()
          ..addAll(list);
        LeaveStore.syncCounter();
      });
    } catch (_) {}
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                child: const Icon(Icons.folder_shared_rounded,
                    color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Employee Leave Records',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            // Search bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search employee...',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _color, size: 20),
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
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded, color: _color),
                    tooltip: 'Refresh',
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Status summary
            Row(children: [
              _StatusBadge('Pending', Icons.hourglass_empty_rounded,
                  Colors.orange.shade700,
                  _applications.where((a) =>
                      a.managerStatus == LeaveApprovalStatus.pending).length),
              const SizedBox(width: 10),
              _StatusBadge('Approved', Icons.check_circle_rounded,
                  Colors.green.shade700,
                  _applications.where((a) =>
                      a.managerStatus == LeaveApprovalStatus.approved).length),
              const SizedBox(width: 10),
              _StatusBadge('Denied', Icons.cancel_rounded,
                  Colors.red.shade700,
                  _applications.where((a) =>
                      a.managerStatus == LeaveApprovalStatus.denied).length),
            ]),
            const SizedBox(height: 16),

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
              ..._applications.map((app) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AppCard(app: app, fmt: _fmt),
                  )),
          ],
        ),
      ),
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
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_rounded, color: Color(0xFF0D47A1), size: 20),
            const SizedBox(width: 8),
            Text(app.employeeName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E))),
            const Spacer(),
            Text(app.id,
                style: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 6, children: [
            _InfoChip(Icons.calendar_today_rounded,
                '${fmt(app.from)} → ${fmt(app.to)}'),
            _InfoChip(Icons.numbers_rounded,
                '${app.days} day${app.days == 1 ? '' : 's'}'),
            _InfoChip(Icons.access_time_rounded,
                'Applied: ${fmt(app.appliedOn)}'),
            if (app.reason.isNotEmpty)
              _InfoChip(Icons.notes_rounded, app.reason),
          ]),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.manage_accounts_rounded,
                size: 16, color: Color(0xFF78909C)),
            const SizedBox(width: 6),
            const Text('Manager Decision:',
                style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
            const SizedBox(width: 8),
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
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(ms))),
              ]),
            ),
          ]),
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
      Icon(icon, size: 13, color: const Color(0xFF78909C)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A))),
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
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
