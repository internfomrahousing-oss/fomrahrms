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

  // Reads JSON using a saved column mapping (field → sheet column name).
  // Falls back to uppercase normalization if a mapped column isn't found.
  factory Lead.fromMappedJson(
      Map<String, dynamic> json, Map<String, String> mapping) {
    // The script returns UPPERCASE column names. Normalise all keys so lookups
    // work regardless of what the script actually returned.
    final upper = {
      for (final e in json.entries) e.key.toUpperCase().trim(): e.value
    };

    String? get(String field) {
      final col = mapping[field]?.toUpperCase().trim();
      if (col != null && upper.containsKey(col)) return upper[col]?.toString();
      // Fallback: try the default uppercase name
      return upper[field.toUpperCase()]?.toString();
    }

    return Lead(
      leadId:  int.tryParse(get('leadId')  ?? get('LEAD ID') ?? '0') ?? 0,
      name:    get('name')    ?? '',
      phone:   get('phone')   ?? '',
      project: get('project') ?? '',
      source:  get('source')  ?? '',
      status:  get('status')  ?? '',
    );
  }

  // Legacy convenience — used when no mapping is available.
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
  }) {
    return Lead(
      leadId:  leadId  ?? this.leadId,
      name:    name    ?? this.name,
      phone:   phone   ?? this.phone,
      project: project ?? this.project,
      source:  source  ?? this.source,
      status:  status  ?? this.status,
    );
  }
}
