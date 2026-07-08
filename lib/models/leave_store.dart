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
  // Sickness proof attachment (Medical / Sick Leave) — URL in Supabase storage, empty if none.
  String proofUrl         = '';

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

  /// Maps any leave-type label to its balance bucket (CL / ML / EL / LOP).
  /// All display-facing labels (Personal Leave, To Vote, Funeral, etc.) that
  /// should deduct from CL return 'CL'.
  ///
  /// HR can freely rename/add entries in the "Leave Types" dropdown config
  /// (see edit_leave_form_page.dart), so this matches by keyword rather than
  /// exact label text — an exact match breaks the moment HR edits a label
  /// (e.g. it silently miscategorizes Medical Leave as CL and hides the
  /// sickness-proof upload).
  static String effectiveBucket(String leaveType) {
    final t = leaveType.toLowerCase();
    if (t.contains('medical') || t.contains('sick')) return 'ML';
    if (t.contains('earned')) return 'EL';
    if (t.contains('lop')) return 'LOP';
    return 'CL'; // Casual, Personal, To Vote, Funeral, Maternity, Paternity…
  }

  static int permMinutesFromReason(String reason) {
    if (reason.contains('30 Minutes')) return 30;
    if (reason.contains('1½ Hours')) return 90;
    if (reason.contains('2 Hours')) return 120;
    if (reason.contains('1 Hour')) return 60;
    return 60;
  }

  static int permUsedThisMonth(String employeeName) {
    final now = DateTime.now();
    return applications
        .where((a) =>
            a.leaveType == 'Permission' &&
            a.employeeName == employeeName &&
            a.from.year == now.year &&
            a.from.month == now.month &&
            a.managerStatus != LeaveApprovalStatus.denied)
        .fold<int>(0, (sum, a) => sum + permMinutesFromReason(a.reason));
  }
}
