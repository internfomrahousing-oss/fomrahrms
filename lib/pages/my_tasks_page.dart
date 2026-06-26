import 'package:flutter/material.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  TaskStatus? _filter;
  bool _loading = true;
  // Private list — filtered to only THIS user's tasks, isolated from TaskStore
  List<Task> _tasks = [];

  static const _filters = [
    (null,                'All'),
    (TaskStatus.assigned,   'Assigned'),
    (TaskStatus.pending,    'Pending'),
    (TaskStatus.inProgress, 'In Progress'),
    (TaskStatus.completed,  'Completed'),
    (TaskStatus.delayed,    'Delayed'),
    (TaskStatus.rejected,   'Rejected'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload every time this page becomes the active route
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final allTasks = await SupabaseService.fetchTasks();
    final name = UserSession.name.trim();
    if (!mounted) return;
    setState(() {
      _tasks = name.isEmpty
          ? []
          : allTasks.where((t) =>
              t.assignedEmployee.trim() == name ||
              t.teamMembers.any((m) => m.trim() == name)).toList();
      _loading = false;
    });
  }

  bool _isGroup(Task t) =>
      t.teamMembers.any((m) => m.trim() == UserSession.name.trim());

  // Effective status: group task → member's individual status; single → overall
  TaskStatus _effectiveStatus(Task t) {
    final name = UserSession.name.trim();
    if (t.teamMembers.any((m) => m.trim() == name)) {
      return TaskStatus.values.firstWhere(
        (s) => s.name == (t.teamMemberStatuses[name] ?? 'assigned'),
        orElse: () => TaskStatus.assigned,
      );
    }
    return t.status;
  }

  List<Task> get _filtered {
    if (_filter == null) return _tasks;
    return _tasks.where((t) => _effectiveStatus(t) == _filter).toList();
  }

  // Single-assigned task: update overall status
  void _onStatusChanged(Task t, TaskStatus s) {
    setState(() => t.status = s);
    SupabaseService.updateTaskStatus(t.id, s);
  }

  // Group task: update this member's status; flip overall to completed if all done
  void _onGroupStatusChanged(Task t, TaskStatus s) {
    final name = UserSession.name.trim();
    final updated = Map<String, String>.from(t.teamMemberStatuses);
    updated[name] = s.name;
    final allCompleted =
        t.teamMembers.every((m) => (updated[m.trim()] ?? 'assigned') == 'completed');
    setState(() {
      t.teamMemberStatuses = updated;
      if (allCompleted) t.status = TaskStatus.completed;
    });
    SupabaseService.updateTeamMemberStatus(t.id, updated, allCompleted);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.task_alt_rounded,
                    color: Color(0xFF0288D1), size: 22),
              ),
              const SizedBox(width: 14),
              Text('My Tasks',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0288D1)),
                onPressed: _load,
              ),
            ]),
            const SizedBox(height: 20),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final active = _filter == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: active,
                      onSelected: (_) =>
                          setState(() => _filter = f.$1),
                      selectedColor: const Color(0xFF0288D1),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white
                            : const Color(0xFF546E7A),
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: active
                              ? const Color(0xFF0288D1)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 0),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Count
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0288D1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0288D1)),
              ),
            ),
            const SizedBox(height: 16),

            // Task list
            if (_tasks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 48, horizontal: 24),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.task_alt_rounded,
                          size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No tasks assigned yet',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                          'Tasks assigned to you will appear here.',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12)),
                    ]),
                  ),
                ),
              )
            else if (tasks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.search_off_rounded,
                          size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No tasks in this category',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13)),
                    ]),
                  ),
                ),
              )
            else
              ...tasks.map((t) {
                final isGroup = _isGroup(t);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MyTaskCard(
                    task: t,
                    displayStatus: _effectiveStatus(t),
                    isGroupTask: isGroup,
                    onStatusChanged: isGroup
                        ? (s) => _onGroupStatusChanged(t, s)
                        : (s) => _onStatusChanged(t, s),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ── Task card (employee view) ──────────────────────────────────────────────

class _MyTaskCard extends StatefulWidget {
  final Task task;
  final TaskStatus displayStatus; // individual status for this user
  final bool isGroupTask;
  final ValueChanged<TaskStatus> onStatusChanged;
  const _MyTaskCard({
    required this.task,
    required this.displayStatus,
    this.isGroupTask = false,
    required this.onStatusChanged,
  });

  @override
  State<_MyTaskCard> createState() => _MyTaskCardState();
}

class _MyTaskCardState extends State<_MyTaskCard> {
  bool _expanded = false;

  static const _color = Color(0xFF0288D1);

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.low      => Colors.green.shade600,
        TaskPriority.medium   => Colors.orange.shade700,
        TaskPriority.high     => Colors.deepOrange.shade700,
        TaskPriority.critical => Colors.red.shade800,
      };

  String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.low      => 'Low',
        TaskPriority.medium   => 'Medium',
        TaskPriority.high     => 'High',
        TaskPriority.critical => 'Critical',
      };

  Color _statusColor(TaskStatus s) => switch (s) {
        TaskStatus.assigned   => const Color(0xFF1565C0),
        TaskStatus.pending    => Colors.orange.shade700,
        TaskStatus.inProgress => const Color(0xFF6A1B9A),
        TaskStatus.completed  => Colors.green.shade700,
        TaskStatus.delayed    => Colors.red.shade700,
        TaskStatus.rejected   => Colors.grey.shade700,
      };

  String _statusLabel(TaskStatus s) => switch (s) {
        TaskStatus.assigned   => 'Assigned',
        TaskStatus.pending    => 'Pending',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.completed  => 'Completed',
        TaskStatus.delayed    => 'Delayed',
        TaskStatus.rejected   => 'Rejected',
      };

  // Employee can only move to these statuses
  static const _allowedTransitions = [
    TaskStatus.inProgress,
    TaskStatus.completed,
    TaskStatus.pending,
  ];

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final ds = widget.displayStatus; // effective status for this user
    final pc = _priorityColor(t.priority);
    final sc = _statusColor(ds);
    final sl = _statusLabel(ds);
    final pl = _priorityLabel(t.priority);

    final isOverdue = ds != TaskStatus.completed &&
        ds != TaskStatus.rejected &&
        t.dueDate.isBefore(DateTime.now());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(t.id,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(t.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A237E))),
                  ]),
                ),
                const SizedBox(width: 8),
                if (widget.isGroupTask)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Pill('Group', Colors.teal.shade600),
                  ),
                _Pill(pl, pc),
                const SizedBox(width: 6),
                _Pill(sl, sc),
                const SizedBox(width: 6),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade400,
                ),
              ]),
              const SizedBox(height: 10),

              // Summary row
              Wrap(spacing: 14, runSpacing: 6, children: [
                _InfoChip(
                  Icons.event_rounded,
                  'Due: ${_fmt(t.dueDate)}',
                  isOverdue ? Colors.red.shade600 : const Color(0xFF78909C),
                ),
                if (t.weightage > 0)
                  _InfoChip(Icons.star_rounded,
                      '${t.weightage} pts', _color),
                if (t.department.isNotEmpty)
                  _InfoChip(Icons.business_rounded,
                      t.department, const Color(0xFF78909C)),
              ]),

              if (isOverdue && ds != TaskStatus.completed) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.warning_rounded,
                        size: 12, color: Colors.red.shade600),
                    const SizedBox(width: 4),
                    Text('Overdue',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade600)),
                  ]),
                ),
              ],

              if (_expanded) ...[
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),

                if (t.description.isNotEmpty) ...[
                  const Text('Description',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF78909C))),
                  const SizedBox(height: 4),
                  Text(t.description,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1A237E))),
                  const SizedBox(height: 12),
                ],

                Wrap(spacing: 24, runSpacing: 8, children: [
                  _DetailItem('Start Date', _fmt(t.startDate)),
                  _DetailItem('Due Date', _fmt(t.dueDate)),
                  if (t.weightage > 0)
                    _DetailItem('Weightage', '${t.weightage} pts'),
                  if (t.department.isNotEmpty)
                    _DetailItem('Department', t.department),
                  if (t.teamMembers.isNotEmpty)
                    _DetailItem('Team', t.teamMembers.join(', ')),
                ]),
                const SizedBox(height: 16),

                // Update status (limited options for employee)
                const Text('Update Status:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF78909C))),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ..._allowedTransitions
                      .where((s) => s != ds)
                      .map((s) {
                    final c = _statusColor(s);
                    return ElevatedButton(
                      onPressed: () => widget.onStatusChanged(s),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(_statusLabel(s),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    );
                  }),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 11, color: color)),
    ]);
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF78909C),
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A237E),
              fontWeight: FontWeight.w600)),
    ]);
  }
}

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
