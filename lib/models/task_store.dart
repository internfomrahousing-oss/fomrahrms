import 'dart:convert';

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
    this.department = '',
    this.attachment = '',
  });

  Map<String, dynamic> toJson() => {
    'id':                id,
    'name':              name,
    'description':       description,
    'priority':          priority.name,
    'start_date':        startDate.toIso8601String().split('T')[0],
    'due_date':          dueDate.toIso8601String().split('T')[0],
    'weightage':         weightage,
    'status':            status.name,
    'assigned_employee': assignedEmployee,
    'team_members':      jsonEncode(teamMembers),
    'department':        department,
    'attachment':        attachment,
  };

  factory Task.fromJson(Map<String, dynamic> j) {
    List<String> parseTeam(dynamic v) {
      if (v == null || (v is String && v.isEmpty)) return [];
      if (v is List) return List<String>.from(v);
      try {
        final decoded = jsonDecode(v as String);
        if (decoded is List) return List<String>.from(decoded);
      } catch (_) {}
      return [];
    }
    return Task(
      id:               (j['id'] as String?) ?? '',
      name:             (j['name'] as String?) ?? '',
      description:      (j['description'] as String?) ?? '',
      priority:         TaskPriority.values.firstWhere(
        (p) => p.name == (j['priority'] as String?),
        orElse: () => TaskPriority.medium,
      ),
      startDate:        DateTime.tryParse((j['start_date'] as String?) ?? '') ?? DateTime.now(),
      dueDate:          DateTime.tryParse((j['due_date'] as String?) ?? '') ?? DateTime.now(),
      weightage:        (j['weightage'] as int?) ?? 0,
      status:           TaskStatus.values.firstWhere(
        (s) => s.name == ((j['status'] as String?) ?? 'assigned'),
        orElse: () => TaskStatus.assigned,
      ),
      assignedEmployee: (j['assigned_employee'] as String?) ?? '',
      teamMembers:      parseTeam(j['team_members']),
      department:       (j['department'] as String?) ?? '',
      attachment:       (j['attachment'] as String?) ?? '',
    );
  }
}

class TaskStore {
  static final List<Task> tasks = [];
  static int _counter = 0;

  static String generateId() {
    // Pick max existing numeric ID to avoid collision after app restart
    int max = _counter;
    for (final t in tasks) {
      if (t.id.startsWith('TSK-')) {
        final n = int.tryParse(t.id.substring(4));
        if (n != null && n > max) max = n;
      }
    }
    _counter = max + 1;
    return 'TSK-${_counter.toString().padLeft(3, '0')}';
  }
}
