import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum TaskStatus { assigned, pending, inProgress, completed, delayed, rejected }
enum TaskPriority { low, medium, high, critical }

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
}
