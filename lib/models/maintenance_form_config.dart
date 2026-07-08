class MaintenanceFormConfig {
  // In-memory cache so every page that reads the form shares one fetch per session.
  static Map<String, dynamic>? _cache;
  static Map<String, dynamic>? get cached => _cache;
  static void setCache(Map<String, dynamic> cfg) => _cache = cfg;
  static void invalidate() => _cache = null;

  // ── Defaults ────────────────────────────────────────────────────────────────

  static const defaultIssueForOptions = ['IT', 'HR', 'Admin'];

  static const defaultIssueTypes = [
    'Attendance Issues',
    'Salary & Payroll Issues',
    'Leave Issues',
    'Manager-Related Issues',
    'Team Issues',
    'Workplace Behavior Issues',
    'IT Issues',
  ];

  static Map<String, dynamic> defaults() => {
        'issue_for':   List<String>.from(defaultIssueForOptions),
        'issue_types': List<String>.from(defaultIssueTypes),
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
}
