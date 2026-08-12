class MaintenanceFormConfig {
  // In-memory cache so every page that reads the form shares one fetch per session.
  static Map<String, dynamic>? _cache;
  static Map<String, dynamic>? get cached => _cache;
  static void setCache(Map<String, dynamic> cfg) => _cache = cfg;
  static void invalidate() => _cache = null;

  // ── Defaults ────────────────────────────────────────────────────────────────

  static const defaultIssueForOptions = ['IT', 'HR', 'Admin'];

  /// Issue types PER department. Previously one flat list was shown whatever
  /// you picked, so choosing IT still offered "Salary & Payroll Issues" and
  /// choosing HR still offered "IT Issues" — the reporter had to ignore most
  /// of the list, and tickets landed with the wrong team.
  static const defaultIssueTypesByDepartment = <String, List<String>>{
    'IT': [
      'Laptop / Desktop Issue',
      'Internet / Network Issue',
      'Email / Account Access',
      'Software Installation',
      'Printer / Scanner Issue',
      'Mobile / Device Issue',
      'HRMS Application Issue',
      'Other IT Issue',
    ],
    'HR': [
      'Attendance Issues',
      'Salary & Payroll Issues',
      'Leave Issues',
      'Manager-Related Issues',
      'Team Issues',
      'Workplace Behavior Issues',
      'Policy Clarification',
      'Other HR Issue',
    ],
    'Admin': [
      'Housekeeping',
      'Furniture / Seating',
      'Electrical / Lighting',
      'Air Conditioning',
      'Stationery / Supplies',
      'Pantry / Water',
      'Security / Access Card',
      'Vehicle / Travel',
      'Other Admin Issue',
    ],
  };

  /// Flat list of everything, kept so an existing ticket whose type belongs to
  /// another department still renders instead of throwing.
  static List<String> get defaultIssueTypes => [
        for (final list in defaultIssueTypesByDepartment.values) ...list,
      ];

  static Map<String, dynamic> defaults() => {
        'issue_for':   List<String>.from(defaultIssueForOptions),
        'issue_types': List<String>.from(defaultIssueTypes),
        'issue_types_by_department': {
          for (final e in defaultIssueTypesByDepartment.entries)
            e.key: List<String>.from(e.value),
        },
      };

  // ── Getters from a config map ─────────────────────────────────────────────

  static List<String> getIssueForOptions(Map<String, dynamic> cfg) {
    final raw = cfg['issue_for'];
    if (raw is List && raw.isNotEmpty) return List<String>.from(raw.cast<String>());
    return List<String>.from(defaultIssueForOptions);
  }

  static List<String> getIssueTypes(Map<String, dynamic> cfg) {
    final raw = cfg['issue_types'];
    if (raw is List && raw.isNotEmpty) return List<String>.from(raw.cast<String>());
    return List<String>.from(defaultIssueTypes);
  }

  /// Issue types for one department. Falls back to the full list when the
  /// department is unknown or unset, so nothing becomes unreportable.
  static List<String> getIssueTypesFor(Map<String, dynamic> cfg, String? department) {
    final byDept = cfg['issue_types_by_department'];
    if (byDept is Map && department != null && byDept[department] is List) {
      final list = List<String>.from((byDept[department] as List).cast<String>());
      if (list.isNotEmpty) return list;
    }
    if (department != null && defaultIssueTypesByDepartment.containsKey(department)) {
      return List<String>.from(defaultIssueTypesByDepartment[department]!);
    }
    return getIssueTypes(cfg);
  }
}
