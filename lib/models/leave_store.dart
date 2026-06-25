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

  // ── Manager-level decision ─────────────────────────────────────────────────
  LeaveApprovalStatus managerStatus    = LeaveApprovalStatus.pending;
  String decidedBy                     = '';
  String rejectionComment              = '';

  // ── Management-level decision (FINAL — overrides manager) ─────────────────
  LeaveApprovalStatus managementStatus = LeaveApprovalStatus.pending;
  String managementDecidedBy           = '';
  String managementRejectionComment    = '';

  bool isHalfDay = false;

  /// Actual deduction: 0.5 for half day, full days otherwise.
  double get effectiveDays => isHalfDay ? 0.5 : days.toDouble();

  /// Final visible status: management decision overrides manager if set.
  LeaveApprovalStatus get effectiveStatus {
    if (managementStatus != LeaveApprovalStatus.pending) return managementStatus;
    return managerStatus;
  }

  /// Rejection comment to show employee (management's takes priority).
  String get effectiveComment {
    if (managementStatus == LeaveApprovalStatus.denied &&
        managementRejectionComment.isNotEmpty) {
      return managementRejectionComment;
    }
    return rejectionComment;
  }

  /// True once management has given a final decision (locks manager edits).
  bool get managementLocked =>
      managementStatus != LeaveApprovalStatus.pending;

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
