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
}

class TaskStore {
  static final List<Task> tasks = [];
  static int _counter = 0;

  static String generateId() =>
      'TSK-${(++_counter).toString().padLeft(3, '0')}';
}
