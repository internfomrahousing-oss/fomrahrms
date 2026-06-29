import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/back_button.dart';

enum _Status { pending, approved, denied }

class _Application {
  final String employeeId;
  final String employeeName;
  final String department;
  final String leaveType;
  final String from;
  final String to;
  final int days;
  final String reason;
  final String appliedOn;
  _Status status = _Status.pending;
  DateTime? decidedAt;
  _Application({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.leaveType,
    required this.from,
    required this.to,
    required this.days,
    required this.reason,
    required this.appliedOn,
  });
}

class LeaveApprovalsPage extends StatefulWidget {
  const LeaveApprovalsPage({super.key});

  @override
  State<LeaveApprovalsPage> createState() => _LeaveApprovalsPageState();
}

class _LeaveApprovalsPageState extends State<LeaveApprovalsPage> {
  static const _color = Color(0xFF1565C0);

  // Empty list — will be populated from backend when connected
  final List<_Application> _applications = [];

  @override
  Widget build(BuildContext context) {
    final pending  = _applications.where((a) => a.status == _Status.pending).toList();
    final reviewed = _applications.where((a) => a.status != _Status.pending).toList();

    return Scaffold(
      backgroundColor: null,
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
                child: const Icon(Icons.approval_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Leave Approvals',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              _CountChip(
                label: 'Pending',
                count: pending.length,
                color: Colors.orange.shade700,
              ),
            ]),
            const SizedBox(height: 24),

            if (_applications.isEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.inbox_rounded,
                          size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No leave applications yet',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14)),
                    ]),
                  ),
                ),
              ),
            ] else ...[
              if (pending.isNotEmpty) ...[
                _SectionLabel('Pending', pending.length, Colors.orange.shade700),
                const SizedBox(height: 8),
                ...pending.map((app) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ApplicationCard(
                        application: app,
                        onApprove: () => setState(() { app.status = _Status.approved; app.decidedAt = DateTime.now(); }),
                        onDeny:    () => setState(() { app.status = _Status.denied;   app.decidedAt = DateTime.now(); }),
                        onReset:   () => setState(() { app.status = _Status.pending;  app.decidedAt = null; }),
                      ),
                    )),
                const SizedBox(height: 8),
              ],
              if (reviewed.isNotEmpty) ...[
                _SectionLabel('Reviewed', reviewed.length, const Color(0xFF78909C)),
                const SizedBox(height: 8),
                ...reviewed.map((app) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ApplicationCard(
                        application: app,
                        onApprove: () => setState(() { app.status = _Status.approved; app.decidedAt = DateTime.now(); }),
                        onDeny:    () => setState(() { app.status = _Status.denied;   app.decidedAt = DateTime.now(); }),
                        onReset:   () => setState(() { app.status = _Status.pending;  app.decidedAt = null; }),
                      ),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionLabel(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.hourglass_empty_rounded, size: 13, color: color),
        const SizedBox(width: 5),
        Text('$count $label',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  final _Application application;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback onReset;
  const _ApplicationCard({
    required this.application,
    required this.onApprove,
    required this.onDeny,
    required this.onReset,
    super.key,
  });

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  static const _undoWindow = Duration(minutes: 10);
  Timer? _timer;

  bool get _canUndo {
    final da = widget.application.decidedAt;
    if (da == null || widget.application.status == _Status.pending) return false;
    return DateTime.now().difference(da) < _undoWindow;
  }

  String get _countdown {
    final da = widget.application.decidedAt;
    if (da == null) return '';
    final remaining = _undoWindow - DateTime.now().difference(da);
    if (remaining.isNegative) return '';
    final m = remaining.inMinutes;
    final s = remaining.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _maybeStartTimer();
  }

  @override
  void didUpdateWidget(covariant _ApplicationCard old) {
    super.didUpdateWidget(old);
    _timer?.cancel();
    _maybeStartTimer();
  }

  void _maybeStartTimer() {
    if (!_canUndo) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_canUndo) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color get _statusColor => switch (widget.application.status) {
        _Status.approved => Colors.green.shade700,
        _Status.denied   => Colors.red.shade700,
        _Status.pending  => Colors.orange.shade700,
      };
  String get _statusLabel => switch (widget.application.status) {
        _Status.approved => 'Approved',
        _Status.denied   => 'Denied',
        _Status.pending  => 'Pending',
      };
  IconData get _statusIcon => switch (widget.application.status) {
        _Status.approved => Icons.check_circle_rounded,
        _Status.denied   => Icons.cancel_rounded,
        _Status.pending  => Icons.hourglass_empty_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final isPending = app.status == _Status.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Employee row
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF0D47A1).withValues(alpha: 0.1),
              child: const Icon(Icons.person_rounded,
                  color: Color(0xFF0D47A1), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(app.employeeName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(app.employeeId,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1))),
                  ),
                ]),
                Text(app.department,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF78909C))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon, size: 12, color: _statusColor),
                const SizedBox(width: 4),
                Text(_statusLabel,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: _statusColor)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Leave details grid
          Wrap(spacing: 24, runSpacing: 8, children: [
            _Detail(Icons.category_rounded,      'Leave Type', app.leaveType),
            _Detail(Icons.calendar_today_rounded, 'From',      app.from),
            _Detail(Icons.event_rounded,          'To',        app.to),
            _Detail(Icons.today_rounded,          'Days',      '${app.days} day${app.days == 1 ? '' : 's'}'),
            _Detail(Icons.schedule_rounded,       'Applied On', app.appliedOn),
          ]),
          const SizedBox(height: 10),

          // Reason
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF78909C)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(app.reason,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF546E7A))),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Action buttons
          if (isPending)
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onApprove,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onDeny,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Deny'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ])
          else
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon, size: 14, color: _statusColor),
                  const SizedBox(width: 6),
                  Text(_statusLabel,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _statusColor)),
                ]),
              ),
              const Spacer(),
              if (_canUndo)
                TextButton.icon(
                  onPressed: widget.onReset,
                  icon: const Icon(Icons.undo_rounded, size: 14),
                  label: Text('Undo ($_countdown)',
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF78909C)),
                ),
            ]),
        ]),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Detail(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: const Color(0xFF0D47A1)),
      const SizedBox(width: 4),
      Text('$label: ',
          style: const TextStyle(fontSize: 12, color: Color(0xFF78909C))),
      Text(value,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF263238))),
    ]);
  }
}
