import 'user_session.dart';

enum MaintenanceStatus { open, assigned, inProgress, resolved, closed }

extension MaintenanceStatusX on MaintenanceStatus {
  String get label {
    switch (this) {
      case MaintenanceStatus.open:       return 'Open';
      case MaintenanceStatus.assigned:   return 'Assigned';
      case MaintenanceStatus.inProgress: return 'In Progress';
      case MaintenanceStatus.resolved:   return 'Resolved';
      case MaintenanceStatus.closed:     return 'Closed';
    }
  }
}

const List<String> kMaintenancePriorities = ['Low', 'Medium', 'High'];

class MaintenanceTicket {
  final String id;
  final UserRole reportedByRole;
  final String reportedBy;
  final String issueFor;
  final String issueType;
  final String description;
  final String priority; // 'Low' | 'Medium' | 'High'
  MaintenanceStatus status;
  bool sentToManagement;
  bool managementReviewed;
  String? resolutionNote;
  DateTime? resolvedAt;
  final DateTime createdAt;

  MaintenanceTicket({
    required this.id,
    required this.reportedByRole,
    required this.reportedBy,
    required this.issueFor,
    required this.issueType,
    required this.description,
    this.priority = 'Medium',
    this.status = MaintenanceStatus.open,
    this.sentToManagement = false,
    this.managementReviewed = false,
    this.resolutionNote,
    this.resolvedAt,
    required this.createdAt,
  });
}

class MaintenanceStore {
  static final List<MaintenanceTicket> tickets = [];
  static int _counter = 0;

  static String generateId() =>
      'MNT-${(++_counter).toString().padLeft(3, '0')}';

  static void syncCounter() {
    for (final t in tickets) {
      final n = int.tryParse(t.id.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > _counter) _counter = n;
    }
  }
}
