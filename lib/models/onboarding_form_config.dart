class OnboardingFormConfig {
  static Map<String, dynamic> defaults() => {
    'sections': [
      {'id': 'basic_info',        'title': 'Basic Information',              'enabled': true},
      {'id': 'personal_data',     'title': 'Personal Data Form',            'enabled': true},
      {'id': 'family_details',    'title': 'Family Details',                'enabled': true},
      {'id': 'education',         'title': 'Education Qualification',        'enabled': true},
      {'id': 'experience',        'title': 'Experience',                     'enabled': true},
      {'id': 'last_position',     'title': 'Last Position Held',            'enabled': true},
      {'id': 'additional_info',   'title': 'Additional Information',         'enabled': true},
      {'id': 'emergency_details', 'title': 'EMERGENCY DETAILS OF EMPLOYEE', 'enabled': true},
      {'id': 'attachments',       'title': 'Attachments',                    'enabled': true},
      {'id': 'declaration',       'title': 'Declaration',                    'enabled': true},
    ],
  };

  static List<Map<String, dynamic>> getSections(Map<String, dynamic> config) {
    final raw = config['sections'];
    if (raw == null || raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static bool isSectionEnabled(Map<String, dynamic> config, String sectionId) {
    try {
      final s = getSections(config).firstWhere((s) => s['id'] == sectionId);
      return (s['enabled'] as bool?) ?? true;
    } catch (_) {
      return true;
    }
  }

  static String getSectionTitle(
      Map<String, dynamic> config, String sectionId, String fallback) {
    try {
      final s = getSections(config).firstWhere((s) => s['id'] == sectionId);
      final t = (s['title'] as String?)?.trim();
      return (t != null && t.isNotEmpty) ? t : fallback;
    } catch (_) {
      return fallback;
    }
  }

  static List<Map<String, dynamic>> getCustomFields(
      Map<String, dynamic> section) {
    final raw = section['custom_fields'];
    if (raw == null || raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
