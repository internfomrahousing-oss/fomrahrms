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
    return Lead(
      leadId: json['LEAD ID'] is int
          ? json['LEAD ID'] as int
          : int.tryParse(json['LEAD ID'].toString()) ?? 0,
      name: json['NAME']?.toString() ?? '',
      phone: json['PHONE']?.toString() ?? '',
      project: json['PROJECT']?.toString() ?? '',
      source: json['SOURCE']?.toString() ?? '',
      status: json['STATUS']?.toString() ?? '',
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
