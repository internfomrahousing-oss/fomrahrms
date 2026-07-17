import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/task_transitions.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class MyTasksPage extends StatefulWidget {
  // Pre-selects a status filter chip — set when arriving from the Task
  // Analytics legend (e.g. tapping "Delayed" jumps here already filtered).
  final TaskStatus? initialStatus;
  const MyTasksPage({super.key, this.initialStatus});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  TaskStatus? _filter;
  bool _loading = true;
  // Private list — filtered to only THIS user's tasks, isolated from TaskStore
  List<Task> _tasks = [];
  // task.id -> this employee's own 1-based task number (see TaskStore.taskNumbersFor)
  Map<String, int> _numbers = {};

  static const _filters = [
    (null,                'All'),
    (TaskStatus.assigned,   'Assigned'),
    (TaskStatus.pending,    'Pending'),
    (TaskStatus.inProgress, 'In Progress'),
    (TaskStatus.completed,  'Completed'),
    (TaskStatus.delayed,    'Delayed'),
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialStatus;
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
    applyTaskAutoTransitions(allTasks);

    if (!mounted) return;
    setState(() {
      _tasks = name.isEmpty
          ? []
          : allTasks.where((t) =>
              t.assignedEmployee.trim() == name ||
              t.teamMembers.any((m) => m.trim() == name)).toList();
      _numbers = TaskStore.taskNumbersFor(name, allTasks);
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

  // Employee clicks "Mark as Received" → inProgress + save receivedAt
  void _onReceived(Task t) {
    final now = DateTime.now();
    setState(() {
      t.status = TaskStatus.inProgress;
      t.receivedAt = now;
    });
    SupabaseService.updateTaskReceived(t.id, now);
    NotificationService.taskStatusChanged(
      taskName: t.name, status: 'In Progress', changedBy: UserSession.name,
    );
  }

  // Employee clicks "Mark as Done" → completed (irreversible). [note] is
  // the mandatory reason when this task was already Delayed — see
  // _MyTaskCard's confirm-done flow, which is what enforces that.
  void _onDone(Task t, String note) {
    setState(() {
      t.status = TaskStatus.completed;
      if (note.isNotEmpty) t.completionNote = note;
    });
    SupabaseService.updateTaskStatus(t.id, TaskStatus.completed, note: note);
    // Fire-and-forget: let this employee's reporting manager know.
    if (UserSession.reportingManager.isNotEmpty) {
      NotificationService.taskCompleted(
        taskName: t.name,
        reportingManagerName: UserSession.reportingManager,
      );
    }
    NotificationService.taskStatusChanged(
      taskName: t.name, status: 'Completed', changedBy: UserSession.name,
    );
  }

  // Group task done: mark member complete; flip overall if all done
  void _onGroupDone(Task t, String note) {
    final name = UserSession.name.trim();
    final updated = Map<String, String>.from(t.teamMemberStatuses);
    updated[name] = TaskStatus.completed.name;
    final allCompleted =
        t.teamMembers.every((m) => (updated[m.trim()] ?? 'assigned') == 'completed');
    setState(() {
      t.teamMemberStatuses = updated;
      if (allCompleted) t.status = TaskStatus.completed;
      if (note.isNotEmpty) t.completionNote = note;
    });
    SupabaseService.updateTeamMemberStatus(t.id, updated, allCompleted, note: note);
    // Only notify once the whole group task is done, and only fire-and-forget.
    if (allCompleted && UserSession.reportingManager.isNotEmpty) {
      NotificationService.taskCompleted(
        taskName: t.name,
        reportingManagerName: UserSession.reportingManager,
      );
    }
    NotificationService.taskStatusChanged(
      taskName: t.name,
      status: allCompleted ? 'Completed' : 'Updated',
      changedBy: name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filtered;

    final narrow = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(narrow ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              const NavBackButton(),
              SizedBox(width: narrow ? 4 : 8),
              if (!narrow) ...[
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.task_alt_rounded,
                      color: AppTheme.accentBlue, size: 22),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text('My Tasks',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: Icon(Icons.refresh_rounded, color: AppTheme.accentBlue),
                onPressed: _load,
              ),
              if (UserSession.role == UserRole.employee ||
                  UserSession.role == UserRole.reportingManager) ...[
                SizedBox(width: narrow ? 2 : 4),
                narrow
                    ? IconButton(
                        tooltip: 'Add Task',
                        onPressed: () async {
                          final route = UserSession.role == UserRole.employee
                              ? '/employee/tasks/add'
                              : '/manager/my-tasks/add';
                          await context.push(route);
                          if (mounted) _load();
                        },
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () async {
                          final route = UserSession.role == UserRole.employee
                              ? '/employee/tasks/add'
                              : '/manager/my-tasks/add';
                          await context.push(route);
                          if (mounted) _load();
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Task'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
              ],
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
                      selectedColor: AppTheme.accentBlue,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white
                            : const Color(0xFF6B7280),
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: active
                              ? AppTheme.accentBlue
                              : const Color(0xFFE5E7EB),
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
                color: AppTheme.accentBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentBlue),
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
                    number: _numbers[t.id] ?? 0,
                    displayStatus: _effectiveStatus(t),
                    isGroupTask: isGroup,
                    onReceived: () => _onReceived(t),
                    onDone: isGroup
                        ? (note) => _onGroupDone(t, note)
                        : (note) => _onDone(t, note),
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
  final int number;
  final TaskStatus displayStatus;
  final bool isGroupTask;
  final VoidCallback onReceived;
  // Called with the completion reason — empty string when the task wasn't
  // Delayed (no reason required in that case).
  final void Function(String note) onDone;
  const _MyTaskCard({
    required this.task,
    required this.number,
    required this.displayStatus,
    this.isGroupTask = false,
    required this.onReceived,
    required this.onDone,
  });

  @override
  State<_MyTaskCard> createState() => _MyTaskCardState();
}

class _MyTaskCardState extends State<_MyTaskCard> {
  bool _expanded = false;

  static Color get _color => AppTheme.accentBlue;

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
        TaskStatus.assigned   => const Color(0xFF3B82F6),
        TaskStatus.pending    => Colors.orange.shade700,
        TaskStatus.inProgress => const Color(0xFF2563EB),
        TaskStatus.completed  => Colors.green.shade700,
        TaskStatus.delayed    => Colors.red.shade700,
      };

  String _statusLabel(TaskStatus s) => switch (s) {
        TaskStatus.assigned   => 'Assigned',
        TaskStatus.pending    => 'Pending',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.completed  => 'Completed',
        TaskStatus.delayed    => 'Delayed',
      };

  // Delayed tasks require a reason before they can be marked done; anything
  // else completes immediately with no reason needed.
  Future<void> _confirmDone(TaskStatus effectiveStatus) async {
    if (effectiveStatus != TaskStatus.delayed) {
      widget.onDone('');
      return;
    }

    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Reason for delay'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'This task is overdue. Please explain why before marking it done.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Reason', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'A reason is required' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(dlgCtx, true);
            },
            child: const Text('Mark as Done'),
          ),
        ],
      ),
    );

    if (confirmed == true) widget.onDone(ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final ds = widget.displayStatus; // effective status for this user
    final pc = _priorityColor(t.priority);
    final sc = _statusColor(ds);
    final sl = _statusLabel(ds);
    final pl = _priorityLabel(t.priority);

    final isOverdue = ds != TaskStatus.completed &&
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
                    Text('Task #${widget.number}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(t.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827))),
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
                  isOverdue ? Colors.red.shade600 : const Color(0xFF6B7280),
                ),
                if (t.weightage > 0)
                  _InfoChip(Icons.star_rounded,
                      '${t.weightage} pts', _color),
                if (t.department.isNotEmpty)
                  _InfoChip(Icons.business_rounded,
                      t.department, const Color(0xFF6B7280)),
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
                          color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  Text(t.description,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF111827))),
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

                // Action buttons based on current status
                if (ds == TaskStatus.assigned && !t.isSelfAssigned)
                  ElevatedButton.icon(
                    onPressed: widget.onReceived,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('Mark as Received',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else if (ds == TaskStatus.assigned && t.isSelfAssigned ||
                    ds == TaskStatus.inProgress ||
                    ds == TaskStatus.pending ||
                    ds == TaskStatus.delayed)
                  ElevatedButton.icon(
                    onPressed: () => _confirmDone(ds),
                    icon: const Icon(Icons.task_alt_rounded, size: 16),
                    label: const Text('Mark as Done',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else if (ds == TaskStatus.completed)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_rounded, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('Completed — no further changes',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
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
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600)),
    ]);
  }
}

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
