class Lead {
  final int leadId;
  final String name;
  final String phone;
  final String project;
  final String source;
  final String status;

  const Lead({
    required this.leadId,
    required this.name,
    required this.phone,
    required this.project,
    required this.source,
    required this.status,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    // Normalize all keys to uppercase so column names in the sheet are flexible
    final m = { for (final e in json.entries) e.key.toUpperCase().trim(): e.value };
    return Lead(
      leadId: m['LEAD ID'] is int
          ? m['LEAD ID'] as int
          : int.tryParse(m['LEAD ID']?.toString() ?? '') ?? 0,
      name:    m['NAME']?.toString()    ?? '',
      phone:   m['PHONE']?.toString()   ?? '',
      project: m['PROJECT']?.toString() ?? '',
      source:  m['SOURCE']?.toString()  ?? '',
      status:  m['STATUS']?.toString()  ?? '',
    );
  }

  Lead copyWith({
    int? leadId,
    String? name,
    String? phone,
    String? project,
    String? source,
    String? status,
  }) {
    return Lead(
      leadId: leadId ?? this.leadId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      project: project ?? this.project,
      source: source ?? this.source,
      status: status ?? this.status,
    );
  }
}
