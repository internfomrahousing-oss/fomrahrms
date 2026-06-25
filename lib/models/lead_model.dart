class Lead {
  final int leadId;
  final String name;
  final String phone;
  final String project;
  final String source;
  final String status;
  // Extra dynamic columns: label → value
  final Map<String, String> extra;

  const Lead({
    required this.leadId,
    required this.name,
    required this.phone,
    required this.project,
    required this.source,
    required this.status,
    this.extra = const {},
  });

  factory Lead.fromMappedJson(
    Map<String, dynamic> json,
    Map<String, String> mapping,
    List<Map<String, String>> extraCols,
  ) {
    final upper = {
      for (final e in json.entries) e.key.toUpperCase().trim(): e.value
    };

    String? get(String field) {
      final col = mapping[field]?.toUpperCase().trim();
      if (col != null && upper.containsKey(col)) return upper[col]?.toString();
      return upper[field.toUpperCase()]?.toString();
    }

    final extra = <String, String>{};
    for (final col in extraCols) {
      final colName = (col['column'] ?? '').toUpperCase().trim();
      final label   = (col['label']  ?? colName).trim();
      if (colName.isNotEmpty) extra[label] = upper[colName]?.toString() ?? '';
    }

    return Lead(
      leadId:  int.tryParse(get('leadId') ?? get('LEAD ID') ?? '0') ?? 0,
      name:    get('name')    ?? '',
      phone:   get('phone')   ?? '',
      project: get('project') ?? '',
      source:  get('source')  ?? '',
      status:  get('status')  ?? '',
      extra:   extra,
    );
  }

  factory Lead.fromJson(Map<String, dynamic> json) {
    final upper = {
      for (final e in json.entries) e.key.toUpperCase().trim(): e.value
    };
    return Lead(
      leadId:  int.tryParse(upper['LEAD ID']?.toString() ?? '0') ?? 0,
      name:    upper['NAME']?.toString()    ?? '',
      phone:   upper['PHONE']?.toString()   ?? '',
      project: upper['PROJECT']?.toString() ?? '',
      source:  upper['SOURCE']?.toString()  ?? '',
      status:  upper['STATUS']?.toString()  ?? '',
    );
  }

  Lead copyWith({
    int? leadId,
    String? name,
    String? phone,
    String? project,
    String? source,
    String? status,
    Map<String, String>? extra,
  }) {
    return Lead(
      leadId:  leadId  ?? this.leadId,
      name:    name    ?? this.name,
      phone:   phone   ?? this.phone,
      project: project ?? this.project,
      source:  source  ?? this.source,
      status:  status  ?? this.status,
      extra:   extra   ?? Map.from(this.extra),
    );
  }
}
