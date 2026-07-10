import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/task_transitions.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';
import 'performance_management_page.dart';
import 'salary_hike_engine_page.dart';

enum _TaskSort { dueDate, priority, recentlyAdded, alphabetical }

class TaskManagementPage extends StatefulWidget {
  const TaskManagementPage({super.key});

  @override
  State<TaskManagementPage> createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends State<TaskManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskStatus? _filter;
  TaskPriority? _priorityFilter;
  String? _assigneeFilter;
  _TaskSort _sort = _TaskSort.dueDate;
  String _search = '';
  bool _loading = true;

  static const _filters = [
    (null, 'All'),
    (TaskStatus.assigned, 'Assigned'),
    (TaskStatus.pending, 'Pending'),
    (TaskStatus.inProgress, 'In Progress'),
    (TaskStatus.completed, 'Completed'),
    (TaskStatus.delayed, 'Delayed'),
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
    applyTaskAutoTransitions(tasks);
    TaskStore.tasks
      ..clear()
      ..addAll(tasks);
    if (mounted) setState(() => _loading = false);
  }

  bool _isMe(String person) =>
      person.trim().toLowerCase() == UserSession.name.trim().toLowerCase();

  int get _pendingCount =>
      TaskStore.tasks.where((t) => t.status == TaskStatus.pending).length;
  int get _completedCount =>
      TaskStore.tasks.where((t) => t.status == TaskStatus.completed).length;
  int get _delayedCount =>
      TaskStore.tasks.where((t) => t.status == TaskStatus.delayed).length;
  int get _assignedToMeCount => TaskStore.tasks
      .where((t) =>
          _isMe(t.assignedEmployee) || t.teamMembers.any(_isMe))
      .length;

  List<String> get _assignees {
    final set = <String>{};
    for (final t in TaskStore.tasks) {
      if (t.assignedEmployee.trim().isNotEmpty) set.add(t.assignedEmployee.trim());
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<Task> get _filtered {
    var list = TaskStore.tasks.where((t) {
      if (_filter != null && t.status != _filter) return false;
      if (_priorityFilter != null && t.priority != _priorityFilter) return false;
      if (_assigneeFilter != null && t.assignedEmployee != _assigneeFilter) return false;
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        if (!(t.id.toLowerCase().contains(q) ||
            t.name.toLowerCase().contains(q) ||
            t.assignedEmployee.toLowerCase().contains(q) ||
            t.department.toLowerCase().contains(q))) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sort) {
      case _TaskSort.dueDate:
        list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      case _TaskSort.priority:
        list.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      case _TaskSort.recentlyAdded:
        list = list.reversed.toList();
      case _TaskSort.alphabetical:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  String get _addRoute {
    final loc = GoRouterState.of(context).uri.path;
    return loc.startsWith('/manager')
        ? '/manager/task-management/add'
        : '/task-management/add';
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
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.task_alt_rounded,
                    color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Task Management',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 2),
                    Text('Create, assign and track tasks efficiently',
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (onTab0) ...[
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: IconButton(
                    tooltip: 'Refresh',
                    icon: Icon(Icons.refresh_rounded,
                        color: AppTheme.primaryBlue, size: 20),
                    onPressed: _load,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await context.push(_addRoute);
                    if (mounted) _load();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
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
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryBlue,
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
                  totalCount: TaskStore.tasks.length,
                  pendingCount: _pendingCount,
                  completedCount: _completedCount,
                  delayedCount: _delayedCount,
                  assignedToMeCount: _assignedToMeCount,
                  countFor: (s) => s == null
                      ? TaskStore.tasks.length
                      : TaskStore.tasks.where((t) => t.status == s).length,
                  search: _search,
                  priorityFilter: _priorityFilter,
                  assigneeFilter: _assigneeFilter,
                  assignees: _assignees,
                  sort: _sort,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  onSearchChanged: (v) => setState(() => _search = v),
                  onPriorityChanged: (v) => setState(() => _priorityFilter = v),
                  onAssigneeChanged: (v) => setState(() => _assigneeFilter = v),
                  onSortChanged: (v) => setState(() => _sort = v),
                  onDelete: _onDelete,
                ),
                const SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: PerformanceManagementBody(),
                ),
                const SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: SalaryHikeEngineBody(),
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
  final int totalCount;
  final int pendingCount;
  final int completedCount;
  final int delayedCount;
  final int assignedToMeCount;
  final int Function(TaskStatus?) countFor;
  final String search;
  final TaskPriority? priorityFilter;
  final String? assigneeFilter;
  final List<String> assignees;
  final _TaskSort sort;
  final ValueChanged<TaskStatus?> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<TaskPriority?> onPriorityChanged;
  final ValueChanged<String?> onAssigneeChanged;
  final ValueChanged<_TaskSort> onSortChanged;
  final void Function(Task) onDelete;

  const _TasksTab({
    required this.loading,
    required this.filters,
    required this.currentFilter,
    required this.filtered,
    required this.totalCount,
    required this.pendingCount,
    required this.completedCount,
    required this.delayedCount,
    required this.assignedToMeCount,
    required this.countFor,
    required this.search,
    required this.priorityFilter,
    required this.assigneeFilter,
    required this.assignees,
    required this.sort,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onPriorityChanged,
    required this.onAssigneeChanged,
    required this.onSortChanged,
    required this.onDelete,
  });

  String _pct(int count) =>
      totalCount == 0 ? '0%' : '${(count / totalCount * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat cards
          _StatCardsRow(
            total: totalCount,
            pending: pendingCount,
            completed: completedCount,
            delayed: delayedCount,
            assignedToMe: assignedToMeCount,
            pct: _pct,
          ),
          const SizedBox(height: 20),

          // Search + filters + sort
          LayoutBuilder(builder: (context, constraints) {
            final search = TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search tasks by name, ID, assignee, department...',
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppTheme.primaryBlue, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            );

            final priorityDropdown = _DropdownField<TaskPriority?>(
              label: 'Priority',
              value: priorityFilter,
              icon: Icons.flag_rounded,
              display: (p) => p == null ? 'All' : taskPriorityLabel(p),
              options: const [null, ...TaskPriority.values],
              onChanged: onPriorityChanged,
            );

            final assigneeDropdown = _DropdownField<String?>(
              label: 'Assignee',
              value: assigneeFilter,
              icon: Icons.person_rounded,
              display: (a) => a ?? 'All',
              options: [null, ...assignees],
              onChanged: onAssigneeChanged,
            );

            final sortDropdown = _DropdownField<_TaskSort>(
              label: 'Sort',
              value: sort,
              icon: Icons.swap_vert_rounded,
              display: (s) => switch (s) {
                _TaskSort.dueDate => 'Due Date',
                _TaskSort.priority => 'Priority',
                _TaskSort.recentlyAdded => 'Recently Added',
                _TaskSort.alphabetical => 'A → Z',
              },
              options: _TaskSort.values,
              onChanged: onSortChanged,
            );

            if (constraints.maxWidth < 760) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(child: Padding(padding: const EdgeInsets.all(16), child: search)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  priorityDropdown,
                  assigneeDropdown,
                  sortDropdown,
                ]),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: Card(child: Padding(padding: const EdgeInsets.all(16), child: search)),
              ),
              const SizedBox(width: 10),
              priorityDropdown,
              const SizedBox(width: 8),
              assigneeDropdown,
              const SizedBox(width: 8),
              sortDropdown,
            ]);
          }),
          const SizedBox(height: 16),

          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final active = currentFilter == f.$1;
                final color = f.$1 == null
                    ? const Color(0xFF111827)
                    : taskStatusColor(f.$1!);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _TaskFilterChip(
                    label: '${f.$2} (${countFor(f.$1)})',
                    selected: active,
                    color: color,
                    onTap: () => onFilterChanged(f.$1),
                  ),
                );
              }).toList(),
            ),
          ),
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
                      totalCount == 0
                          ? 'No tasks yet'
                          : 'No tasks match your filters',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        totalCount == 0
                            ? 'Tap "Add Task" to create one'
                            : 'Try adjusting the search or filters',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),
                  ]),
                ),
              ),
            )
          else ...[
            Text('${filtered.length} task${filtered.length == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            ...filtered.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaskCard(
                    task: t,
                    onDelete: (UserSession.role == UserRole.hr ||
                            UserSession.role == UserRole.management)
                        ? () => onDelete(t)
                        : null,
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ── Stat cards ───────────────────────────────────────────────────────────────

class _StatCardsRow extends StatelessWidget {
  final int total;
  final int pending;
  final int completed;
  final int delayed;
  final int assignedToMe;
  final String Function(int) pct;

  const _StatCardsRow({
    required this.total,
    required this.pending,
    required this.completed,
    required this.delayed,
    required this.assignedToMe,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(
        icon: Icons.assignment_rounded,
        iconColor: AppTheme.primaryBlue,
        label: 'Total Tasks',
        value: '$total',
        sublabel: 'All tasks',
        subColor: Colors.grey.shade500,
      ),
      _StatTile(
        icon: Icons.hourglass_top_rounded,
        iconColor: AppTheme.warning,
        label: 'Pending',
        value: '$pending',
        sublabel: '${pct(pending)} of total',
        subColor: AppTheme.warning,
      ),
      _StatTile(
        icon: Icons.check_circle_rounded,
        iconColor: AppTheme.success,
        label: 'Completed',
        value: '$completed',
        sublabel: '${pct(completed)} of total',
        subColor: AppTheme.success,
      ),
      _StatTile(
        icon: Icons.error_rounded,
        iconColor: AppTheme.error,
        label: 'Delayed',
        value: '$delayed',
        sublabel: '${pct(delayed)} of total',
        subColor: AppTheme.error,
      ),
      _StatTile(
        icon: Icons.person_rounded,
        iconColor: AppTheme.purple,
        label: 'Assigned to Me',
        value: '$assignedToMe',
        sublabel: '${pct(assignedToMe)} of total',
        subColor: AppTheme.purple,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 900;
      if (wide) {
        return Row(children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: tiles[i]),
          ],
        ]);
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final t in tiles) SizedBox(width: 200, child: t),
        ],
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sublabel;
  final Color subColor;
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sublabel,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
              const SizedBox(height: 1),
              Text(sublabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, color: subColor, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Dropdown field ───────────────────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final IconData icon;
  final String Function(T) display;
  final List<T> options;
  final ValueChanged<T> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.icon,
    required this.display,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => options.map((o) {
        final selected = o == value;
        return PopupMenuItem<T>(
          value: o,
          child: Text(display(o),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppTheme.primaryBlue : const Color(0xFF111827))),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(display(value),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827))),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey.shade500),
        ]),
      ),
    );
  }
}

// ── Filter chip ──────────────────────────────────────────────────────────────

class _TaskFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TaskFilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF6B7280))),
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
    };

Color taskPriorityColor(TaskPriority p) => switch (p) {
      TaskPriority.low => Colors.green.shade600,
      TaskPriority.medium => Colors.orange.shade700,
      TaskPriority.high => Colors.deepOrange.shade700,
      TaskPriority.critical => Colors.red.shade800,
    };

String taskPriorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
      TaskPriority.critical => 'Critical',
    };

Color taskStatusColor(TaskStatus s) => switch (s) {
      TaskStatus.assigned => const Color(0xFF3B82F6),
      TaskStatus.pending => Colors.orange.shade700,
      TaskStatus.inProgress => const Color(0xFF2563EB),
      TaskStatus.completed => Colors.green.shade700,
      TaskStatus.delayed => Colors.red.shade700,
    };

// ── Task card ────────────────────────────────────────────────────────────────

class _TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onDelete;
  const _TaskCard({required this.task, this.onDelete});

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final pc = taskPriorityColor(t.priority);
    final sc = taskStatusColor(t.status);
    final sl = _filterLabel(t.status);
    final pl = taskPriorityLabel(t.priority);
    final overdue = t.status == TaskStatus.delayed;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: sc),
            Expanded(
              child: InkWell(
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
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.onSurface)),
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
                      Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        _InfoChip(Icons.calendar_today_rounded,
                            'Due: ${_fmt(t.dueDate)}'),
                        if (overdue)
                          Text('Overdue',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red.shade700)),
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
                                  color: Color(0xFF6B7280))),
                          const SizedBox(height: 4),
                          Text(t.description,
                              style: TextStyle(
                                  fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
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

                        // Status is managed automatically — no manual move-to for managers
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
            ),
          ],
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
      Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
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
          style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
