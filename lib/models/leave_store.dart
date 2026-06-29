enum LeaveApprovalStatus { pending, approved, denied }

class LeaveApplication {
  final String id;
  final String employeeName;
  final String department;
  final String leaveType;
  final DateTime from;
  final DateTime to;
  final int days;
  final String reason;
  final DateTime appliedOn;

  // Single shared decision — editable by both manager and management
  LeaveApprovalStatus managerStatus = LeaveApprovalStatus.pending;
  String decidedBy        = '';
  String rejectionComment = '';
  bool   isHalfDay        = false;

  // True once management (HR/admin) has made a decision — locks manager's controls
  bool managementDecided = false;

  // Set when a decision is made; cleared on undo. Used for the 10-min undo window.
  DateTime? decidedAt;

  /// Actual deduction: 0.5 for half day, full days otherwise.
  double get effectiveDays => isHalfDay ? 0.5 : days.toDouble();

  // Aliases used by employee view (same field, kept for clarity)
  LeaveApprovalStatus get effectiveStatus => managerStatus;
  String get effectiveComment => rejectionComment;

  LeaveApplication({
    required this.id,
    required this.employeeName,
    required this.department,
    required this.leaveType,
    required this.from,
    required this.to,
    required this.days,
    required this.reason,
    required this.appliedOn,
  });
}

class LeaveStore {
  static final List<LeaveApplication> applications = [];
  static int _counter = 0;

  static String generateId() =>
      'LV-${(++_counter).toString().padLeft(3, '0')}';

  static void syncCounter() {
    for (final a in applications) {
      final n = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > _counter) _counter = n;
    }
  }
}
