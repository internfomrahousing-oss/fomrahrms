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
    'hr_policy': [
      {'id': 'ob_policy_agree', 'label': 'I have read and agree to the HR Policy (mandatory)'},
    ],
    'declaration': [
      {'id': 'ob_decl_date',  'label': 'Date'},
      {'id': 'ob_decl_place', 'label': 'Place'},
      {'id': 'ob_decl_agree', 'label': 'I Agree checkbox'},
    ],
  };

  static const _defaultPolicyText = '''FOMRA HOUSING & INFRASTRUCTURE PVT LTD
Human Resource Policy – 2026

1. WORKING HOURS & ATTENDANCE

1.1 Work Days & Timings
• 6-day work week (Monday to Saturday), 9:30 AM – 6:30 PM
• Property Sourcing employees: 9:00 AM – 6:30 PM
• Sales employees: Monday to Sunday; weekly off on Tuesday or Thursday (predefined by reporting manager – cannot be changed)

1.2 Attendance Requirements
• All employees must record attendance using the FOMRA HRMS app from date of joining
• Field employees mark attendance via WhatsApp location sharing; Land Acquisition employees must keep live location active during working hours
• Failure to record attendance = treated as Absent = Loss of Pay (LOP)
• Leaving premises during working hours requires prior Reporting Manager approval; failure results in LOP

1.3 Late Arrival Policy
• Maximum 3 late arrivals per month (10-minute grace period per instance)
• Beyond 3 late arrivals: each subsequent instance = Half-Day LOP or adjusted against available leave balance

1.4 Permission Policy
• Maximum 2 hours of permission per month (applicable to confirmed employees and probationers)
• Can be split into instances of minimum 30 minutes each
• Permissions cannot be clubbed with late arrival or early departure
• Permission beyond monthly limit: adjusted against Casual Leave balance

1.5 Lunch Hours
• 30-minute lunch break (1:00 PM – 2:00 PM)
• 15-minute bio break (once in morning, once in evening)
• Repeated violations: 4 formal warnings per month; if exceeded, Half-Day LOP or termination

2. HOLIDAYS

• Company declares maximum 9 paid holidays annually
• 2026 Holiday List:
  1 Jan  – New Year's Day
  14 Jan – Pongal
  15 Jan – Thiruvalluvar Day
  26 Jan – Republic Day
  14 Apr – Tamil New Year's Day
  15 Aug – Independence Day
  2 Oct  – Gandhi Jayanthi
  20 Oct – Ayutha Pooja
  8 Nov  – Diwali
  25 Dec – Christmas
• Employees required to work on public holidays are eligible for compensatory off with prior written/WhatsApp approval from Reporting Manager/Head of Operations/MD

3. LEAVE POLICY

3.1 General Rules
• Leave can be availed in half-day units
• CL, ML, and EL cannot be clubbed together
• All requests must be approved by Reporting Manager and forwarded to HR at least one day in advance
• Reporting Manager can approve up to 2 days; more than 2 days requires MD & Head of Operations approval
• Sales Team: Reporting Manager can approve 1 day; beyond 1 day requires MD approval

3.2 Casual Leave (CL)
• 12 days per year (1 per month) for on-role employees
• Maximum 2 days at a time
• Cannot be carried forward; lapses at year-end and upon resignation

3.3 Medical Leave (ML)
• 12 days per year for on-role employees
• Beyond 3 consecutive days: medical certificate required
• Cannot be carried forward; lapses upon resignation

3.4 Probation Leave
• 1 day per month for emergencies only
• No CL, EL, or ML during probation period
• Cannot be accumulated or carried forward

3.5 Earned Leave (EL)
• Eligible after completing probation + 1 year continuous service: 12 days/year (1 per month)
• Maximum accumulation: 20 days
• Encashment allowed for 2+ years of service (minimum 10 EL days must remain in account)
• Encashment formula: (Last Drawn Basic Salary ÷ Total days in month) × No. of days

3.6 Sandwich Leave Policy
• If leave is taken on both sides of Sunday or a declared holiday, the weekly off/holiday is also counted as leave
• If leave is taken only before OR after the weekly off/holiday, it is not counted as leave

3.7 Compensatory Off (Comp Off)
• Must be availed within the subsequent month; otherwise lapses
• Prior Reporting Manager approval is mandatory
• Working more than 6 hours on an approved holiday = eligible for comp off
• Working less than 6 hours = not eligible

3.8 Wedding Leave
• 7 days paid leave for first legal marriage (minimum 2 years continuous service)
• Wedding gift of ₹25,000 for employees with more than 2 years continuous service

3.9 Maternity Leave
• 60 days (2 months) paid leave for female employees with 3+ years continuous service
• Miscarriage/medical termination: 42 days (6 weeks) for 3+ years service
• Medical certificate and written notification mandatory

3.10 Paternity Leave
• 3 days paid leave for male employees with 3+ years continuous service
• Must be availed within one month from date of childbirth

3.11 Leave During Notice Period
• Only 1 day of leave permitted during notice period with prior approval
• CL/ML lapses upon resignation; EL can be encashed as per policy

4. GRATUITY POLICY
• Minimum 5 years continuous service required
• Formula: (Basic Salary × 15 × Completed Years of Service) ÷ 30
• Processed within 30 days of official relieving date
• May be forfeited for disciplinary action, misconduct, or unauthorized exit

5. DRESS CODE POLICY
• Professional, modest attire required at all times
• Male employees: Formal attire with formal shoes
• Female employees: Formal Indian or Western wear; sarees must be professional in appearance

6. SEPARATION POLICY

6.1 Notice Period Structure
• Deputy General Manager & Above: 60 Days
• Jr. Executive to Senior Manager: 30 Days
• Probationers: 15 Days

6.2 Full & Final Settlement (F&F)
• Processed within 3 days after exit
• All company property must be returned; clearances completed
• Deductions apply for loss or damage beyond normal wear and tear

6.3 Termination
• May occur for non-performance, misconduct, unethical behaviour, or falsification of information
• Salary paid only for actual days worked up to date of termination

7. WORKPLACE CONDUCT & SAFETY
• All visitors must sign in and be escorted by an authorized employee at all times
• Possession or consumption of alcohol, tobacco, or illegal substances on company premises or during work hours is strictly prohibited

8. HARASSMENT & DISCRIMINATION POLICY
• The Company maintains zero tolerance for harassment or discrimination of any kind
• Harassment includes: demeaning remarks, unwelcome sexual advances, offensive jokes, hostile work environment
• Discrimination based on gender, race, caste, religion, age, disability, or marital status is strictly prohibited
• Retaliation against anyone who files a complaint is strictly forbidden
• Employees experiencing harassment should report to ICC or HR within 15 days

9. VIOLATION POLICY
The following may lead to disciplinary action, including termination:
• Falsifying documents, records, or timesheets
• Using threatening, abusive, or coercive language
• Violating safety protocols
• Theft, fraud, or misuse of company property
• Repeated absenteeism, tardiness, or negligence
• Insubordination or refusal to follow instructions

This policy is subject to revision at the sole discretion of the management of FOMRA HOUSING & INFRASTRUCTURE PVT LTD. From the date of revision, the new policy becomes applicable.

For queries, contact HR: info@fomrahousing.in
Prepared by: Jose Jenin Jeevi J (HR Manager)
Verified by: Ronak Surana (Head of Operations)
Approved by: Sharad Fomra (CEO & MD)''';

  static String getPolicyTextFromSections(List<Map<String, dynamic>> sections) {
    try {
      final s = sections.firstWhere((s) => s['id'] == 'hr_policy');
      final t = (s['policy_text'] as String?)?.trim();
      return (t != null && t.isNotEmpty) ? t : _defaultPolicyText;
    } catch (_) {
      return _defaultPolicyText;
    }
  }

  static String get defaultPolicyText => _defaultPolicyText;

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
      {'id': 'hr_policy',        'title': 'HR Policy',                      'enabled': true, 'policy_text': ''},
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
