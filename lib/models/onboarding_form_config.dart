class OnboardingFormConfig {
  static const builtInFieldDefs = <String, List<Map<String, String>>>{
    'basic_info': [
      {'id': 'ob_name',          'label': 'Name'},
      {'id': 'ob_phone',         'label': 'Phone Number'},
      {'id': 'ob_father',        'label': 'Father Name'},
      {'id': 'ob_mother',        'label': 'Mother Name'},
      {'id': 'ob_designation',   'label': 'Designation'},
      {'id': 'ob_joining',       'label': 'Date of Joining'},
    ],
    'personal_data': [
      {'id': 'ob_fullname',   'label': 'Full Name'},
      {'id': 'ob_dob',        'label': 'Date of Birth'},
      {'id': 'ob_postal',     'label': 'Postal Address'},
      {'id': 'ob_permanent',  'label': 'Permanent Address'},
    ],
    'family_details': [
      {'id': 'ob_family_table', 'label': 'Family Table (Name / Age / Gender / Relation / Occupation / Aadhar)'},
    ],
    'education': [
      {'id': 'ob_edu_table', 'label': 'Education Table (Qualification / Institute / Year / Marks / Subject)'},
    ],
    'experience': [
      {'id': 'ob_exp_table', 'label': 'Experience Table (Organisation / Period / Designation / Salary / Reason)'},
    ],
    'last_position': [
      {'id': 'ob_last_reporter', 'label': 'Last Reporting Person'},
      {'id': 'ob_last_company',  'label': 'Last Company'},
      {'id': 'ob_ref1',          'label': 'Reference 1'},
      {'id': 'ob_ref2',          'label': 'Reference 2'},
    ],
    'additional_info': [
      {'id': 'ob_esi',       'label': 'ESI Number'},
      {'id': 'ob_pf',        'label': 'PF Number'},
      {'id': 'ob_languages', 'label': 'Languages Known'},
      {'id': 'ob_hobbies',   'label': 'Hobbies'},
      {'id': 'ob_interests', 'label': 'Interests'},
      {'id': 'ob_other',     'label': 'Other Information'},
    ],
    'emergency_details': [
      {'id': 'ob_blood_group',  'label': 'Blood Group'},
      {'id': 'ob_allergic',     'label': 'Allergic To'},
      {'id': 'ob_illness',      'label': 'Major Illness'},
      {'id': 'ob_em_contact',   'label': 'Emergency Contact Name'},
      {'id': 'ob_em_number',    'label': 'Emergency Phone Number'},
      {'id': 'ob_em_aadhar',    'label': 'Emergency Aadhar Copy'},
    ],
    'attachments': [
      {'id': 'ob_att_edu',       'label': 'Educational Certificates'},
      {'id': 'ob_att_aadhar',    'label': 'Aadhar Card'},
      {'id': 'ob_att_pan',       'label': 'PAN Card'},
      {'id': 'ob_att_exp',       'label': 'Experience Letters'},
      {'id': 'ob_att_payslip',   'label': 'Pay Slips'},
      {'id': 'ob_att_photo',     'label': 'Passport Photo'},
    ],
    'declaration': [
      {'id': 'ob_decl_date',  'label': 'Date'},
      {'id': 'ob_decl_place', 'label': 'Place'},
      {'id': 'ob_decl_agree', 'label': 'I Agree checkbox'},
    ],
  };

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
