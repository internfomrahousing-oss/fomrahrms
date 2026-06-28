class FormConfig {
  static const _baseUrl =
      'https://fomrahrms-zeta.vercel.app/#/candidate-application';

  // Field IDs and display labels for every built-in field per section.
  // Used by the edit page (chip display + toggle) and the candidate form (hide check).
  static const builtInFieldDefs = <String, List<Map<String, String>>>{
    'personal_info': [
      {'id': 'name',           'label': 'Full Name'},
      {'id': 'mobile',         'label': 'Mobile Number'},
      {'id': 'place',          'label': 'Place'},
      {'id': 'nationality',    'label': 'Nationality'},
      {'id': 'email',          'label': 'Email ID'},
      {'id': 'age',            'label': 'Age'},
      {'id': 'dob',            'label': 'Date of Birth'},
      {'id': 'gender',         'label': 'Gender'},
      {'id': 'marital_status', 'label': 'Marital Status'},
    ],
    'interview_details': [
      {'id': 'interview_date', 'label': 'Interview Date'},
      {'id': 'post_applied',   'label': 'Post Applied'},
    ],
    'experience_ctc': [
      {'id': 'total_exp',     'label': 'Total Experience'},
      {'id': 'relevant_exp',  'label': 'Relevant Experience'},
      {'id': 'reason_change', 'label': 'Reason for Change'},
      {'id': 'current_ctc',   'label': 'Current CTC'},
      {'id': 'expected_ctc',  'label': 'Expected CTC'},
      {'id': 'notice_period', 'label': 'Notice Period'},
    ],
    'education': [
      {'id': 'education_table',  'label': 'Education Table'},
      {'id': 'standing_arrears', 'label': 'Standing Arrears'},
    ],
    'employment_history': [
      {'id': 'employment_table', 'label': 'Employment History Table'},
    ],
    'source': [
      {'id': 'source',      'label': 'Source'},
      {'id': 'job_portal',  'label': 'Job Portal'},
      {'id': 'referred_by', 'label': 'Referred by Employee'},
      {'id': 'related_emp', 'label': 'Related to Employee'},
    ],
    'referrals': [
      {'id': 'referrals_table', 'label': 'Referrals Table'},
    ],
    'previous_application': [
      {'id': 'applied_before', 'label': 'Applied Before?'},
    ],
    'address': [
      {'id': 'address', 'label': 'Full Address'},
    ],
    'resume': [
      {'id': 'resume', 'label': 'Resume Upload (PDF / DOC)'},
    ],
    'declaration': [
      {'id': 'declaration_name',  'label': 'Full Name'},
      {'id': 'declaration_date',  'label': 'Date'},
      {'id': 'declaration_agree', 'label': 'I Agree checkbox'},
    ],
  };

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
              'ADMIN',
              'OPERATION',
              'CRM',
              'PROJECTS',
              'LAND ACQUISITION',
              'ACCOUNTS',
              'SALES',
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

  static List<String> getHiddenFieldIds(Map<String, dynamic> section) {
    final raw = section['hidden_field_ids'];
    if (raw == null || raw is! List) return [];
    return raw.whereType<String>().toList();
  }

  static bool isFieldHidden(Map<String, dynamic> section, String fieldId) {
    final raw = section['hidden_field_ids'];
    if (raw == null || raw is! List) return false;
    return raw.contains(fieldId);
  }

  static Map<String, dynamic>? getSection(
      Map<String, dynamic> config, String sectionId) {
    try {
      return getSections(config).firstWhere((s) => s['id'] == sectionId);
    } catch (_) {
      return null;
    }
  }
}
