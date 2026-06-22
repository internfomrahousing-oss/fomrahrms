import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ManagerLeavePage extends StatefulWidget {
  const ManagerLeavePage({super.key});

  @override
  State<ManagerLeavePage> createState() => _ManagerLeavePageState();
}

// ── Data model ─────────────────────────────────────────────────────────────

enum _Status { pending, approved, denied }

class _LeaveRequest {
  final String employee;
  final String leaveType;
  final String from;
  final String to;
  final int days;
  final String reason;
  _Status managerStatus = _Status.pending;

  _LeaveRequest({
    required this.employee,
    required this.leaveType,
    required this.from,
    required this.to,
    required this.days,
    required this.reason,
  });
}

// ── Page state ─────────────────────────────────────────────────────────────

class _ManagerLeavePageState extends State<ManagerLeavePage> {
  static const _accentColor = Color(0xFF1A237E);

  static const _topics = [
    _Topic('Apply Leave',         Icons.event_available_rounded, Color(0xFF0D47A1), '/manager/leave/apply'),
    _Topic('My Approvals',        Icons.approval_rounded,        Color(0xFF1565C0), '/manager/leave/approvals'),
    _Topic('Leave Balance',       Icons.balance_rounded,         Color(0xFF1976D2), '/manager/leave/balance'),
    _Topic('Team Leave Approvals',Icons.group_rounded,           Color(0xFF283593), '/manager/leave/team-approvals'),
  ];

  // Empty — populated from backend when connected
  final List<_LeaveRequest> _requests = [];

  void _setStatus(int i, _Status s) =>
      setState(() => _requests[i].managerStatus = s);

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
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.beach_access_rounded,
                    color: _accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Text('Leave Management',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 20),

            // 4 icon cards
            _TopicGrid(topics: _topics),
            const SizedBox(height: 28),

            // Team leave records section header
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group_rounded,
                    color: _accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Team Leave Records',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1A237E),
                        fontWeight: FontWeight.w700,
                      )),
            ]),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 52),
              child: Text(
                'Employees under your wing',
                style: TextStyle(fontSize: 12, color: Color(0xFF78909C)),
              ),
            ),
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
                          borderSide: const BorderSide(
                              color: _accentColor, width: 2),
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

            // Status badges
            Row(children: [
              _StatusBadge(
                'Pending',
                Icons.hourglass_empty_rounded,
                Colors.orange.shade700,
                _requests
                    .where((r) => r.managerStatus == _Status.pending)
                    .length,
              ),
              const SizedBox(width: 10),
              _StatusBadge(
                'Approved',
                Icons.check_circle_rounded,
                Colors.green.shade700,
                _requests
                    .where((r) => r.managerStatus == _Status.approved)
                    .length,
              ),
              const SizedBox(width: 10),
              _StatusBadge(
                'Denied',
                Icons.cancel_rounded,
                Colors.red.shade700,
                _requests
                    .where((r) => r.managerStatus == _Status.denied)
                    .length,
              ),
            ]),
            const SizedBox(height: 16),

            // Team leave list
            if (_requests.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.inbox_rounded,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No leave requests from your team yet',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14)),
                    ]),
                  ),
                ),
              )
            else
              ...List.generate(_requests.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestCard(
                    request: _requests[i],
                    onApprove: () => _setStatus(i, _Status.approved),
                    onDeny:    () => _setStatus(i, _Status.denied),
                    onReset:   () => _setStatus(i, _Status.pending),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ── Topic card grid ────────────────────────────────────────────────────────

class _Topic {
  final String title;
  final IconData icon;
  final Color color;
  final String? route;
  const _Topic(this.title, this.icon, this.color, this.route);
}

class _TopicGrid extends StatelessWidget {
  final List<_Topic> topics;
  const _TopicGrid({required this.topics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 600 ? 4 : 2;
      final rows = <Widget>[];
      for (int i = 0; i < topics.length; i += cols) {
        final end =
            (i + cols) > topics.length ? topics.length : i + cols;
        final rowItems = topics.sublist(i, end);
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowItems.map((t) {
            final isLast = rowItems.last == t;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: isLast ? 0 : 12, bottom: 12),
                child: _TopicCard(topic: t),
              ),
            );
          }).toList(),
        ));
      }
      return Column(children: rows);
    });
  }
}

class _TopicCard extends StatelessWidget {
  final _Topic topic;
  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: topic.route != null ? () => context.push(topic.route!) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: topic.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(topic.icon, color: topic.color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                topic.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_rounded,
                  size: 14,
                  color: topic.color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Team leave request card ────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final _LeaveRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback onReset;

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onDeny,
    required this.onReset,
  });

  Color _statusColor(_Status s) => switch (s) {
        _Status.approved => Colors.green.shade700,
        _Status.denied   => Colors.red.shade700,
        _Status.pending  => Colors.orange.shade700,
      };

  IconData _statusIcon(_Status s) => switch (s) {
        _Status.approved => Icons.check_circle_rounded,
        _Status.denied   => Icons.cancel_rounded,
        _Status.pending  => Icons.hourglass_empty_rounded,
      };

  String _statusLabel(_Status s) => switch (s) {
        _Status.approved => 'Approved',
        _Status.denied   => 'Denied',
        _Status.pending  => 'Pending',
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
          // Employee + overall status
          Row(children: [
            const Icon(Icons.person_rounded,
                color: Color(0xFF1A237E), size: 20),
            const SizedBox(width: 8),
            Text(request.employee,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E))),
            const Spacer(),
            _StatusPill(sl, sc, si),
          ]),
          const SizedBox(height: 10),

          // Leave details chips
          Wrap(spacing: 16, runSpacing: 6, children: [
            _InfoChip(Icons.label_rounded, request.leaveType),
            _InfoChip(Icons.calendar_today_rounded,
                '${request.from} → ${request.to}'),
            _InfoChip(Icons.numbers_rounded,
                '${request.days} day${request.days == 1 ? '' : 's'}'),
            _InfoChip(Icons.notes_rounded, request.reason),
          ]),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),

          // Manager approval row
          Row(children: [
            const Icon(Icons.manage_accounts_rounded,
                size: 16, color: Color(0xFF78909C)),
            const SizedBox(width: 6),
            const Text('Your Decision:',
                style:
                    TextStyle(fontSize: 12, color: Color(0xFF78909C))),
            const SizedBox(width: 8),
            _StatusPill(sl, sc, si),
            const Spacer(),
            if (request.managerStatus == _Status.pending) ...[
              _ActionBtn('Approve', Colors.green.shade700,
                  Icons.check_rounded, onApprove),
              const SizedBox(width: 8),
              _ActionBtn('Deny', Colors.red.shade700,
                  Icons.close_rounded, onDeny),
            ] else
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.undo_rounded, size: 14),
                label:
                    const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
          ]),
        ]),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

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
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
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
