import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum TaskStatus { assigned, pending, inProgress, completed, delayed }
enum TaskPriority { low, medium, high, critical }

/// Round-trips a [TaskStatus] through a route's `?status=` query param —
/// used to deep-link from the Task Analytics legend into a pre-filtered
/// task list. Unknown/missing values fall back to "no filter" rather than
/// throwing, since this only ever comes from a URL we generated ourselves.
TaskStatus? taskStatusFromName(String? name) {
  for (final s in TaskStatus.values) {
    if (s.name == name) return s;
  }
  return null;
}

class Task {
  final String id;
  String name;
  String description;
  TaskPriority priority;
  DateTime startDate;
  DateTime dueDate;
  int weightage;
  TaskStatus status;
  String assignedEmployee;
  List<String> teamMembers;
  // Per-member status for group tasks: memberName → status.name
  Map<String, String> teamMemberStatuses;
  String department;
  String attachment;
  DateTime? receivedAt;
  bool isSelfAssigned;

  Task({
    required this.id,
    required this.name,
    required this.description,
    required this.priority,
    required this.startDate,
    required this.dueDate,
    required this.weightage,
    this.status = TaskStatus.assigned,
    this.assignedEmployee = '',
    this.teamMembers = const [],
    Map<String, String>? teamMemberStatuses,
    this.department = '',
    this.attachment = '',
    this.receivedAt,
    this.isSelfAssigned = false,
  }) : teamMemberStatuses = teamMemberStatuses ?? {};

  Map<String, dynamic> toJson() => {
    'id':                    id,
    'name':                  name,
    'description':           description,
    'priority':              priority.name,
    'start_date':            startDate.toIso8601String().split('T')[0],
    'due_date':              dueDate.toIso8601String().split('T')[0],
    'weightage':             weightage,
    'status':                status.name,
    'assigned_employee':     assignedEmployee,
    'team_members':          jsonEncode(teamMembers),
    'team_member_statuses':  jsonEncode(teamMemberStatuses),
    'department':            department,
    'attachment':            attachment,
    'received_at':           receivedAt?.toIso8601String(),
    'is_self_assigned':      isSelfAssigned,
  };

  factory Task.fromJson(Map<String, dynamic> j) {
    List<String> parseList(dynamic v) {
      if (v == null || (v is String && v.isEmpty)) return [];
      if (v is List) return List<String>.from(v);
      try {
        final d = jsonDecode(v as String);
        if (d is List) return List<String>.from(d);
      } catch (_) {}
      return [];
    }
    Map<String, String> parseStatuses(dynamic v) {
      if (v == null || (v is String && v.isEmpty)) return {};
      try {
        final d = jsonDecode(v is String ? v : jsonEncode(v));
        if (d is Map) return Map<String, String>.from(d);
      } catch (_) {}
      return {};
    }
    return Task(
      id:                   (j['id'] as String?) ?? '',
      name:                 (j['name'] as String?) ?? '',
      description:          (j['description'] as String?) ?? '',
      priority:             TaskPriority.values.firstWhere(
        (p) => p.name == (j['priority'] as String?),
        orElse: () => TaskPriority.medium,
      ),
      startDate:            DateTime.tryParse((j['start_date'] as String?) ?? '') ?? DateTime.now(),
      dueDate:              DateTime.tryParse((j['due_date'] as String?) ?? '') ?? DateTime.now(),
      weightage:            (j['weightage'] as int?) ?? 0,
      status:               TaskStatus.values.firstWhere(
        (s) => s.name == ((j['status'] as String?) ?? 'assigned'),
        orElse: () => TaskStatus.assigned,
      ),
      assignedEmployee:     (j['assigned_employee'] as String?) ?? '',
      teamMembers:          parseList(j['team_members']),
      teamMemberStatuses:   parseStatuses(j['team_member_statuses']),
      department:           (j['department'] as String?) ?? '',
      attachment:           (j['attachment'] as String?) ?? '',
      receivedAt:           j['received_at'] != null
          ? DateTime.tryParse(j['received_at'] as String)
          : null,
      isSelfAssigned:       (j['is_self_assigned'] as bool?) ?? false,
    );
  }
}

class TaskStore {
  static final List<Task> tasks = [];
  static const _counterKey = 'task_id_counter';

  // Async — persists counter to SharedPreferences so IDs are always sequential
  // across app restarts, even before Supabase syncs.
  static Future<String> generateId() async {
    final prefs = await SharedPreferences.getInstance();
    int counter = prefs.getInt(_counterKey) ?? 0;

    // Also check loaded tasks in case prefs were cleared
    for (final t in tasks) {
      if (t.id.startsWith('TSK-')) {
        final n = int.tryParse(t.id.substring(4));
        if (n != null && n > counter) counter = n;
      }
    }

    counter++;
    await prefs.setInt(_counterKey, counter);
    return 'TSK-${counter.toString().padLeft(3, '0')}';
  }

  static bool _belongsTo(Task t, String employeeName) =>
      t.assignedEmployee.trim() == employeeName ||
      t.teamMembers.any((m) => m.trim() == employeeName);

  static int _creationOrder(Task t) =>
      int.tryParse(t.id.replaceFirst('TSK-', '')) ?? 0;

  /// 1-based position of each of [employeeName]'s own tasks (as assignee or
  /// team member) among just their tasks, ordered by creation (ascending
  /// TSK-### id) — every employee's tasks are numbered #1, #2... on their
  /// own, independent of the shared global id.
  static Map<String, int> taskNumbersFor(String employeeName, List<Task> allTasks) {
    final name = employeeName.trim();
    if (name.isEmpty) return {};
    final mine = allTasks.where((t) => _belongsTo(t, name)).toList()
      ..sort((a, b) => _creationOrder(a).compareTo(_creationOrder(b)));
    return {for (var i = 0; i < mine.length; i++) mine[i].id: i + 1};
  }
}
