class FormConfig {
  static const _baseUrl =
      'https://fomrahrms-zeta.vercel.app/#/candidate-application';

  static Map<String, dynamic> defaults() => {
        'sections': [
          {
            'id': 'personal_info',
            'title': 'Personal Information',
            'enabled': true,
          },
          {
            'id': 'interview_details',
            'title': 'Interview Details',
            'enabled': true,
            'post_applied_options': [
              'HR',
              'ACCOUNTS',
              'SALES',
              'MARKETING',
              'GMI',
              'PROJECTS',
              'LAND ACQUISITION',
              'DIGITAL MARKETING',
            ],
          },
          {
            'id': 'experience_ctc',
            'title': 'Experience & CTC',
            'enabled': true,
            'notice_period_options': [
              'Immediate',
              '15 Days',
              '30 Days',
              '60 Days or more',
            ],
          },
          {
            'id': 'education',
            'title': 'Educational Qualifications',
            'enabled': true,
          },
          {
            'id': 'employment_history',
            'title': 'Employment History (Current & Previous, if any)',
            'enabled': true,
          },
          {
            'id': 'source',
            'title': 'Source',
            'enabled': true,
            'source_options': [
              'Walk In',
              'Referred by Employee',
              'Consultancy (Specify)',
              'Job Portal / Other (Specify)',
              'Other',
            ],
          },
          {
            'id': 'referrals',
            'title': 'Refer Friends / Relatives Looking for a Job',
            'enabled': true,
          },
          {
            'id': 'previous_application',
            'title': 'Previous Application',
            'enabled': true,
          },
          {
            'id': 'address',
            'title': 'Address for Communication',
            'enabled': true,
          },
          {'id': 'resume', 'title': 'Resume', 'enabled': true},
          {'id': 'declaration', 'title': 'Declaration', 'enabled': true},
        ],
      };

  static String versionedLink(int versionNumber) =>
      '$_baseUrl?v=$versionNumber';

  static String get baseLink => _baseUrl;

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

  static List<String> getSectionOptions(
    Map<String, dynamic> config,
    String sectionId,
    String optionKey,
    List<String> fallback,
  ) {
    try {
      final s = getSections(config).firstWhere((s) => s['id'] == sectionId);
      final opts = s[optionKey];
      if (opts is List && opts.isNotEmpty) {
        return List<String>.from(opts);
      }
    } catch (_) {}
    return fallback;
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
