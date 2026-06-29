import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';

class TaskManagementPage extends StatefulWidget {
  const TaskManagementPage({super.key});

  @override
  State<TaskManagementPage> createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends State<TaskManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskStatus? _filter;
  bool _loading = true;

  static const _filters = [
    (null, 'All'),
    (TaskStatus.assigned, 'Assigned'),
    (TaskStatus.pending, 'Pending'),
    (TaskStatus.inProgress, 'In Progress'),
    (TaskStatus.completed, 'Completed'),
    (TaskStatus.delayed, 'Delayed'),
    (TaskStatus.rejected, 'Rejected'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tasks = await SupabaseService.fetchTasks();
    TaskStore.tasks
      ..clear()
      ..addAll(tasks);
    if (mounted) setState(() => _loading = false);
  }

  List<Task> get _filtered => _filter == null
      ? TaskStore.tasks
      : TaskStore.tasks.where((t) => t.status == _filter).toList();

  String get _addRoute {
    final loc = GoRouterState.of(context).uri.path;
    return loc.startsWith('/manager')
        ? '/manager/task-management/add'
        : '/task-management/add';
  }

  void _onStatusChanged(Task t, TaskStatus s) {
    setState(() => t.status = s);
    SupabaseService.updateTaskStatus(t.id, s);
  }

  void _onDelete(Task t) {
    setState(() => TaskStore.tasks.remove(t));
    SupabaseService.deleteTask(t.id);
  }

  @override
  Widget build(BuildContext context) {
    final onTab0 = _tabController.index == 0;

    return Scaffold(
      backgroundColor: null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.task_alt_rounded,
                    color: Color(0xFF6A1B9A), size: 22),
              ),
              const SizedBox(width: 14),
              Text('Task Management',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              if (onTab0) ...[
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded,
                      color: Color(0xFF6A1B9A)),
                  onPressed: _load,
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: () async {
                    await context.push(_addRoute);
                    if (mounted) _load();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6A1B9A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6A1B9A),
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            tabs: const [
              Tab(text: 'Tasks'),
              Tab(text: 'Performance Management'),
              Tab(text: 'Salary Hike Engine'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TasksTab(
                  loading: _loading,
                  filters: _filters,
                  currentFilter: _filter,
                  filtered: _filtered,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  onStatusChanged: _onStatusChanged,
                  onDelete: _onDelete,
                ),
                const _PlaceholderTab(
                  icon: Icons.trending_up_rounded,
                  title: 'Performance Management',
                  subtitle: 'Coming soon',
                ),
                const _PlaceholderTab(
                  icon: Icons.monetization_on_rounded,
                  title: 'Salary Hike Engine',
                  subtitle: 'Coming soon',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tasks tab ────────────────────────────────────────────────────────────────

class _TasksTab extends StatelessWidget {
  final bool loading;
  final List<(TaskStatus?, String)> filters;
  final TaskStatus? currentFilter;
  final List<Task> filtered;
  final ValueChanged<TaskStatus?> onFilterChanged;
  final void Function(Task, TaskStatus) onStatusChanged;
  final void Function(Task) onDelete;

  const _TasksTab({
    required this.loading,
    required this.filters,
    required this.currentFilter,
    required this.filtered,
    required this.onFilterChanged,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final active = currentFilter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.$2),
                    selected: active,
                    onSelected: (_) => onFilterChanged(f.$1),
                    selectedColor: const Color(0xFF6A1B9A),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          active ? Colors.white : const Color(0xFF546E7A),
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: active
                            ? const Color(0xFF6A1B9A)
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
          const SizedBox(height: 20),

          // Count badge
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${filtered.length} task${filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6A1B9A)),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Task list
          if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 48, horizontal: 24),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.task_alt_rounded,
                        size: 52, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      currentFilter == null
                          ? 'No tasks yet'
                          : 'No ${_filterLabel(currentFilter!).toLowerCase()} tasks',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text('Tap "Add Task" to create one',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),
                  ]),
                ),
              ),
            )
          else
            ...filtered.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaskCard(
                    task: t,
                    onStatusChanged: (s) => onStatusChanged(t, s),
                    onDelete: (UserSession.role == UserRole.hr ||
                            UserSession.role == UserRole.management)
                        ? () => onDelete(t)
                        : null,
                  ),
                )),
        ],
      ),
    );
  }
}

// ── Placeholder tab ──────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: const Color(0xFF6A1B9A), size: 40),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle,
              style:
                  TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

String _filterLabel(TaskStatus s) => switch (s) {
      TaskStatus.assigned => 'Assigned',
      TaskStatus.pending => 'Pending',
      TaskStatus.inProgress => 'In Progress',
      TaskStatus.completed => 'Completed',
      TaskStatus.delayed => 'Delayed',
      TaskStatus.rejected => 'Rejected',
    };

// ── Task card ────────────────────────────────────────────────────────────────

class _TaskCard extends StatefulWidget {
  final Task task;
  final ValueChanged<TaskStatus> onStatusChanged;
  final VoidCallback? onDelete;
  const _TaskCard(
      {required this.task, required this.onStatusChanged, this.onDelete});

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _expanded = false;

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.low => Colors.green.shade600,
        TaskPriority.medium => Colors.orange.shade700,
        TaskPriority.high => Colors.deepOrange.shade700,
        TaskPriority.critical => Colors.red.shade800,
      };

  String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
        TaskPriority.critical => 'Critical',
      };

  Color _statusColor(TaskStatus s) => switch (s) {
        TaskStatus.assigned => const Color(0xFF1565C0),
        TaskStatus.pending => Colors.orange.shade700,
        TaskStatus.inProgress => const Color(0xFF6A1B9A),
        TaskStatus.completed => Colors.green.shade700,
        TaskStatus.delayed => Colors.red.shade700,
        TaskStatus.rejected => Colors.grey.shade700,
      };

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final pc = _priorityColor(t.priority);
    final sc = _statusColor(t.status);
    final sl = _filterLabel(t.status);
    final pl = _priorityLabel(t.priority);

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
                const SizedBox(width: 12),
                _Pill(pl, pc),
                const SizedBox(width: 8),
                _Pill(sl, sc),
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade400,
                ),
              ]),

              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 6, children: [
                _InfoChip(Icons.calendar_today_rounded,
                    'Due: ${_fmt(t.dueDate)}'),
                if (t.weightage > 0)
                  _InfoChip(Icons.star_rounded, '${t.weightage} pts'),
                if (t.assignedEmployee.isNotEmpty)
                  _InfoChip(Icons.person_rounded, t.assignedEmployee),
                if (t.department.isNotEmpty)
                  _InfoChip(Icons.business_rounded, t.department),
              ]),

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
                  _DetailItem('Weightage', '${t.weightage} pts'),
                  if (t.department.isNotEmpty)
                    _DetailItem('Department', t.department),
                  if (t.assignedEmployee.isNotEmpty)
                    _DetailItem('Assigned To', t.assignedEmployee),
                  if (t.teamMembers.isNotEmpty)
                    _DetailItem('Team', t.teamMembers.join(', ')),
                ]),
                const SizedBox(height: 14),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    const Text('Move to: ',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF78909C))),
                    ...TaskStatus.values
                        .where((s) => s != t.status)
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(_filterLabel(s),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _statusColor(s))),
                                backgroundColor: _statusColor(s)
                                    .withValues(alpha: 0.08),
                                side: BorderSide(
                                    color: _statusColor(s)
                                        .withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20)),
                                onPressed: () =>
                                    widget.onStatusChanged(s),
                                padding: EdgeInsets.zero,
                              ),
                            )),
                  ]),
                ),
                if (widget.onDelete != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Task'),
                            content: Text('Delete "${t.name}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onDelete!();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: Icon(Icons.delete_rounded,
                          size: 16, color: Colors.red.shade700),
                      label: Text('Delete Task',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

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
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
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
      Text(label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A))),
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
