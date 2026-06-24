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
  LeaveApprovalStatus managerStatus = LeaveApprovalStatus.pending;
  String decidedBy = ''; // 'Manager' | 'Management' | ''

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
