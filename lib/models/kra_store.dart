/// A single KRA (Key Result Areas) document HR has uploaded for an employee.
/// One employee can have several over time (e.g. one per review cycle) —
/// history is every row for that `employeeEmail`, newest first.
class KraDocument {
  String id;
  String employeeEmail;
  String employeeName;
  String fileName;
  String fileUrl;
  String uploadedBy;
  DateTime uploadedAt;

  KraDocument({
    required this.id,
    required this.employeeEmail,
    required this.employeeName,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedBy,
    DateTime? uploadedAt,
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  Map<String, dynamic> toRow() => {
        'id': id,
        'employee_email': employeeEmail,
        'employee_name': employeeName,
        'file_name': fileName,
        'file_url': fileUrl,
        'uploaded_by': uploadedBy,
        'uploaded_at': uploadedAt.toIso8601String(),
      };

  factory KraDocument.fromRow(Map<String, dynamic> row) => KraDocument(
        id: (row['id'] as String?) ?? '',
        employeeEmail: (row['employee_email'] as String?) ?? '',
        employeeName: (row['employee_name'] as String?) ?? '',
        fileName: (row['file_name'] as String?) ?? '',
        fileUrl: (row['file_url'] as String?) ?? '',
        uploadedBy: (row['uploaded_by'] as String?) ?? '',
        uploadedAt: DateTime.tryParse((row['uploaded_at'] as String?) ?? '') ?? DateTime.now(),
      );
}

class KraStore {
  static String generateId() => 'KRA-${DateTime.now().microsecondsSinceEpoch}';
}
