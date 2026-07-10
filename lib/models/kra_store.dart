/// A single KRA (Key Result Areas) document uploaded for an employee.
/// One employee can have several over time (e.g. one per review cycle) —
/// history is every row for that `employeeEmail`, newest first.
///
/// Approval: HR uploads go in as 'pending' and only become visible to the
/// employee once Management approves. Management's own uploads are
/// auto-approved — no review needed since Management is the approver.
class KraDocument {
  String id;
  String employeeEmail;
  String employeeName;
  String fileName;
  String fileUrl;
  String uploadedBy;
  DateTime uploadedAt;
  String status; // 'pending' | 'approved' | 'rejected'
  String decidedBy;
  String decidedAt; // ISO datetime string; empty = not yet decided
  String reviewNote; // optional reason, mainly used on rejection

  KraDocument({
    required this.id,
    required this.employeeEmail,
    required this.employeeName,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedBy,
    DateTime? uploadedAt,
    this.status = 'pending',
    this.decidedBy = '',
    this.decidedAt = '',
    this.reviewNote = '',
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  Map<String, dynamic> toRow() => {
        'id': id,
        'employee_email': employeeEmail,
        'employee_name': employeeName,
        'file_name': fileName,
        'file_url': fileUrl,
        'uploaded_by': uploadedBy,
        'uploaded_at': uploadedAt.toIso8601String(),
        'status': status,
        'decided_by': decidedBy,
        'decided_at': decidedAt.isEmpty ? null : decidedAt,
        'review_note': reviewNote,
      };

  factory KraDocument.fromRow(Map<String, dynamic> row) => KraDocument(
        id: (row['id'] as String?) ?? '',
        employeeEmail: (row['employee_email'] as String?) ?? '',
        employeeName: (row['employee_name'] as String?) ?? '',
        fileName: (row['file_name'] as String?) ?? '',
        fileUrl: (row['file_url'] as String?) ?? '',
        uploadedBy: (row['uploaded_by'] as String?) ?? '',
        uploadedAt: DateTime.tryParse((row['uploaded_at'] as String?) ?? '') ?? DateTime.now(),
        status: (row['status'] as String?) ?? 'pending',
        decidedBy: (row['decided_by'] as String?) ?? '',
        decidedAt: (row['decided_at'] as String?) ?? '',
        reviewNote: (row['review_note'] as String?) ?? '',
      );
}

class KraStore {
  static String generateId() => 'KRA-${DateTime.now().microsecondsSinceEpoch}';
}
