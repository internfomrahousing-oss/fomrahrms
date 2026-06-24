import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/task_store.dart';
import '../models/app_user.dart';
import '../models/employee_store.dart';
import '../services/user_store.dart';
import '../services/supabase_service.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  static const _accent = Color(0xFF6A1B9A);

  final _formKey = GlobalKey<FormState>();

  // Create Task fields
  String _taskId = '';
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _startDate;
  DateTime? _dueDate;
  final _weightageCtrl = TextEditingController();
  String _attachment = '';

  // Users loaded from UserStore for assignment
  List<AppUser> _users = [];

  // Assign Task fields
  Employee? _assignedEmployee;
  final List<Employee> _teamMembers = [];
  final List<String> _selectedDepartments = [];

  static const _allDepartments = [
    'Engineering', 'Sales', 'HR', 'Finance', 'Marketing',
    'Operations', 'Legal', 'Administration',
  ];

  static const _priorities = [
    (TaskPriority.low,      'Low',      Color(0xFF2E7D32)),
    (TaskPriority.medium,   'Medium',   Color(0xFFE65100)),
    (TaskPriority.high,     'High',     Color(0xFFBF360C)),
    (TaskPriority.critical, 'Critical', Color(0xFFB71C1C)),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final users = await UserStore.load();
    final id = await TaskStore.generateId();
    if (mounted) {
      setState(() {
        _users = users.where((u) => u.active).toList();
        _taskId = id;
      });
    }
  }

  // Convert AppUser to Employee for picker compatibility
  Employee _toEmployee(AppUser u) => Employee(
    id:          u.email,
    name:        u.name,
    department:  u.role,
    designation: u.designation,
    mobile:      u.mobile,
    email:       u.email,
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _weightageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_dueDate ?? (_startDate ?? now).add(const Duration(days: 1))),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  void _pickEmployee() {
    if (_users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees found. Add users via Administration first.')),
      );
      return;
    }
    final employees = _users.map(_toEmployee).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EmployeePickerSheet(
        employees: employees,
        selected: _assignedEmployee,
        onPick: (e) => setState(() => _assignedEmployee = e),
      ),
    );
  }

  void _pickDepartment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DepartmentPickerSheet(
        all: _allDepartments,
        selected: List.from(_selectedDepartments),
        onConfirm: (list) => setState(() {
          _selectedDepartments.clear();
          _selectedDepartments.addAll(list);
        }),
      ),
    );
  }

  void _pickTeam() {
    if (_users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees found. Add users via Administration first.')),
      );
      return;
    }
    final employees = _users.map(_toEmployee).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TeamPickerSheet(
        employees: employees,
        selected: List.from(_teamMembers),
        onConfirm: (list) => setState(() {
          _teamMembers.clear();
          _teamMembers.addAll(list);
        }),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and due dates')),
      );
      return;
    }
    if (_dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due date must be after start date')),
      );
      return;
    }

    final teamNames = _teamMembers.map((e) => e.name).toList();
    final dept      = _selectedDepartments.join(', ');

    final task = Task(
      id: _taskId,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      priority: _priority,
      startDate: _startDate!,
      dueDate: _dueDate!,
      weightage: int.tryParse(_weightageCtrl.text.trim()) ?? 0,
      assignedEmployee: _assignedEmployee?.name ?? '',
      teamMembers: teamNames,
      department: dept,
      attachment: _attachment,
    );

    // Add to in-memory store and persist to Supabase
    TaskStore.tasks.add(task);
    await SupabaseService.saveTask(task);

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_task_rounded,
                      color: _accent, size: 22),
                ),
                const SizedBox(width: 14),
                Text('Add Task',
                    style:
                        Theme.of(context).textTheme.headlineMedium),
              ]),
              const SizedBox(height: 28),

              // ── Section 1: Create Task ─────────────────────────────
              _SectionHeader(
                  icon: Icons.create_rounded,
                  label: '1. Create Task'),
              const SizedBox(height: 16),

              // Task ID (read-only)
              _ReadOnlyField(
                label: 'Task ID',
                value: _taskId,
                icon: Icons.tag_rounded,
              ),
              const SizedBox(height: 14),

              // Task Name
              _Field(
                controller: _nameCtrl,
                label: 'Task Name',
                icon: Icons.title_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Description
              _Field(
                controller: _descCtrl,
                label: 'Description',
                icon: Icons.description_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 14),

              // Priority
              _DropdownLabel(label: 'Priority', icon: Icons.flag_rounded),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: _priorities.map((p) {
                final active = _priority == p.$1;
                return ChoiceChip(
                  label: Text(p.$2),
                  selected: active,
                  onSelected: (_) => setState(() => _priority = p.$1),
                  selectedColor: p.$3,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : p.$3,
                  ),
                  backgroundColor: p.$3.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: active
                            ? p.$3
                            : p.$3.withValues(alpha: 0.3)),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 0),
                );
              }).toList()),
              const SizedBox(height: 14),

              // Start Date & Due Date
              Row(children: [
                Expanded(
                  child: _DateField(
                    label: 'Start Date',
                    icon: Icons.play_arrow_rounded,
                    date: _startDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Due Date',
                    icon: Icons.event_rounded,
                    date: _dueDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // Weightage
              _Field(
                controller: _weightageCtrl,
                label: 'Weightage (points)',
                icon: Icons.star_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 14),

              // Attachment
              _AttachmentField(
                value: _attachment,
                onTap: () => setState(() => _attachment = 'file_attached.pdf'),
              ),
              const SizedBox(height: 32),

              // ── Section 2: Assign Task ─────────────────────────────
              _SectionHeader(
                  icon: Icons.group_add_rounded,
                  label: '2. Assign Task'),
              const SizedBox(height: 16),

              // Employee Assignment
              _AssignCard(
                icon: Icons.person_rounded,
                label: 'Employee Assignment',
                subtitle: _assignedEmployee != null
                    ? _assignedEmployee!.name
                    : 'Tap to assign to a single employee',
                onTap: _pickEmployee,
                trailing: _assignedEmployee != null
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () =>
                            setState(() => _assignedEmployee = null),
                      )
                    : null,
              ),

              // Employee detail card
              if (_assignedEmployee != null) ...[
                const SizedBox(height: 8),
                _EmployeeDetailCard(employee: _assignedEmployee!),
              ],
              const SizedBox(height: 12),

              // Team Assignment
              _AssignCard(
                icon: Icons.groups_rounded,
                label: 'Team Assignment',
                subtitle: _teamMembers.isEmpty
                    ? 'Tap to select multiple employees'
                    : '${_teamMembers.length} member${_teamMembers.length == 1 ? '' : 's'} selected',
                onTap: _pickTeam,
                trailing: _teamMembers.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () =>
                            setState(() => _teamMembers.clear()),
                      )
                    : null,
              ),

              if (_teamMembers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _teamMembers.map((e) => Chip(
                    avatar: CircleAvatar(
                      backgroundColor:
                          const Color(0xFF6A1B9A).withValues(alpha: 0.15),
                      child: Text(e.name[0],
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6A1B9A),
                              fontWeight: FontWeight.bold)),
                    ),
                    label: Text(e.name,
                        style: const TextStyle(fontSize: 12)),
                    onDeleted: () =>
                        setState(() => _teamMembers.remove(e)),
                    deleteIconColor: Colors.grey.shade500,
                  )).toList(),
                ),
              ],
              const SizedBox(height: 12),

              // Department Assignment
              _AssignCard(
                icon: Icons.business_rounded,
                label: 'Department Assignment',
                subtitle: _selectedDepartments.isEmpty
                    ? 'Tap to select one or more departments'
                    : '${_selectedDepartments.length} department${_selectedDepartments.length == 1 ? '' : 's'} selected',
                onTap: _pickDepartment,
                trailing: _selectedDepartments.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () =>
                            setState(() => _selectedDepartments.clear()),
                      )
                    : null,
              ),

              if (_selectedDepartments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _selectedDepartments.map((d) => Chip(
                    avatar: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.business_rounded,
                          size: 12, color: Color(0xFF6A1B9A)),
                    ),
                    label: Text(d, style: const TextStyle(fontSize: 12)),
                    onDeleted: () =>
                        setState(() => _selectedDepartments.remove(d)),
                    deleteIconColor: Colors.grey.shade500,
                  )).toList(),
                ),
              ],
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Create Task',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Employee picker bottom sheet ────────────────────────────────────────────

class _EmployeePickerSheet extends StatelessWidget {
  final List<Employee> employees;
  final Employee? selected;
  final ValueChanged<Employee> onPick;
  const _EmployeePickerSheet({
    required this.employees,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            const Text('Select Employee',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E))),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: ctrl,
            itemCount: employees.length,
            itemBuilder: (_, i) {
              final e = employees[i];
              final isSelected = selected?.id == e.id;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                  child: Text(e.name[0],
                      style: const TextStyle(
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(e.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('${e.designation} • ${e.department}',
                    style: const TextStyle(fontSize: 12)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF6A1B9A))
                    : null,
                onTap: () {
                  onPick(e);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Team picker bottom sheet ────────────────────────────────────────────────

class _TeamPickerSheet extends StatefulWidget {
  final List<Employee> employees;
  final List<Employee> selected;
  final ValueChanged<List<Employee>> onConfirm;
  const _TeamPickerSheet({
    required this.employees,
    required this.selected,
    required this.onConfirm,
  });

  @override
  State<_TeamPickerSheet> createState() => _TeamPickerSheetState();
}

class _TeamPickerSheetState extends State<_TeamPickerSheet> {
  late final List<Employee> _picked;

  @override
  void initState() {
    super.initState();
    _picked = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Text('Select Team Members (${_picked.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E))),
            const Spacer(),
            TextButton(
              onPressed: () {
                widget.onConfirm(_picked);
                Navigator.pop(context);
              },
              child: const Text('Done',
                  style: TextStyle(
                      color: Color(0xFF6A1B9A),
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: ctrl,
            itemCount: widget.employees.length,
            itemBuilder: (_, i) {
              final e = widget.employees[i];
              final checked = _picked.any((p) => p.id == e.id);
              return CheckboxListTile(
                value: checked,
                onChanged: (_) => setState(() {
                  if (checked) {
                    _picked.removeWhere((p) => p.id == e.id);
                  } else {
                    _picked.add(e);
                  }
                }),
                secondary: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                  child: Text(e.name[0],
                      style: const TextStyle(
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(e.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('${e.designation} • ${e.department}',
                    style: const TextStyle(fontSize: 12)),
                activeColor: const Color(0xFF6A1B9A),
                controlAffinity: ListTileControlAffinity.trailing,
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Department picker bottom sheet ─────────────────────────────────────────

class _DepartmentPickerSheet extends StatefulWidget {
  final List<String> all;
  final List<String> selected;
  final ValueChanged<List<String>> onConfirm;
  const _DepartmentPickerSheet({
    required this.all,
    required this.selected,
    required this.onConfirm,
  });

  @override
  State<_DepartmentPickerSheet> createState() =>
      _DepartmentPickerSheetState();
}

class _DepartmentPickerSheetState extends State<_DepartmentPickerSheet> {
  late final List<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Text('Select Departments (${_picked.length})',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E))),
            const Spacer(),
            TextButton(
              onPressed: () {
                widget.onConfirm(_picked);
                Navigator.pop(context);
              },
              child: const Text('Done',
                  style: TextStyle(
                      color: Color(0xFF6A1B9A),
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: ctrl,
            itemCount: widget.all.length,
            itemBuilder: (_, i) {
              final d = widget.all[i];
              final checked = _picked.contains(d);
              return CheckboxListTile(
                value: checked,
                onChanged: (_) => setState(() {
                  if (checked) {
                    _picked.remove(d);
                  } else {
                    _picked.add(d);
                  }
                }),
                secondary: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business_rounded,
                      size: 18, color: Color(0xFF6A1B9A)),
                ),
                title: Text(d,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                activeColor: const Color(0xFF6A1B9A),
                controlAffinity: ListTileControlAffinity.trailing,
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Employee detail card ────────────────────────────────────────────────────

class _EmployeeDetailCard extends StatelessWidget {
  final Employee employee;
  const _EmployeeDetailCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6A1B9A).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor:
              const Color(0xFF6A1B9A).withValues(alpha: 0.12),
          child: Text(
            employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Color(0xFF6A1B9A),
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(employee.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E))),
            const SizedBox(height: 2),
            Text(employee.designation,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF78909C))),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.business_rounded,
                  size: 12, color: Color(0xFF78909C)),
              const SizedBox(width: 4),
              Text(employee.department,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF546E7A))),
              if (employee.email.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(Icons.email_rounded,
                    size: 12, color: Color(0xFF78909C)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(employee.email,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF546E7A)),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Reusable form widgets ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF6A1B9A), size: 18),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E))),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
    ]);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6A1B9A)),
            border: InputBorder.none,
            labelStyle: const TextStyle(
                fontSize: 13, color: Color(0xFF78909C)),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ReadOnlyField(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F7FA),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(icon, size: 18, color: const Color(0xFF6A1B9A)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF78909C))),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E))),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Auto-generated',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6A1B9A),
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateField(
      {required this.label,
      required this.icon,
      required this.date,
      required this.onTap});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, size: 18, color: const Color(0xFF6A1B9A)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF78909C))),
              const SizedBox(height: 2),
              Text(
                date != null ? _fmt(date!) : 'Select date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: date != null
                      ? const Color(0xFF1A237E)
                      : const Color(0xFFBDBDBD),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _AttachmentField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _AttachmentField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.attach_file_rounded,
                size: 18, color: Color(0xFF6A1B9A)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Attachment',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF78909C))),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Tap to attach file' : value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF1A237E),
                  ),
                ),
              ]),
            ),
            if (value.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Browse',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6A1B9A),
                        fontWeight: FontWeight.w600)),
              )
            else
              const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 18),
          ]),
        ),
      ),
    );
  }
}

class _AssignCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  const _AssignCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(icon, color: const Color(0xFF6A1B9A), size: 20),
        ),
        title: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E))),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF78909C))),
        trailing: trailing ??
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFF78909C)),
        onTap: onTap,
      ),
    );
  }
}

class _DropdownLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _DropdownLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF6A1B9A)),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF546E7A))),
    ]);
  }
}
