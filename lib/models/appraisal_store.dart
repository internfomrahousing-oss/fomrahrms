import 'dart:convert';
import 'app_user.dart';
import 'user_session.dart';

/// One row in a rating table (KRA / Functional & Operational / Behavioural).
class AppraisalRatingRow {
  String description;
  int selfRating; // 0 = unset, 1-5
  String selfRemarks;
  String rmRemarks;

  AppraisalRatingRow({
    this.description = '',
    this.selfRating = 0,
    this.selfRemarks = '',
    this.rmRemarks = '',
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'self_rating': selfRating,
        'self_remarks': selfRemarks,
        'rm_remarks': rmRemarks,
      };

  factory AppraisalRatingRow.fromJson(Map<String, dynamic> j) => AppraisalRatingRow(
        description: (j['description'] as String?) ?? '',
        selfRating: (j['self_rating'] as num?)?.toInt() ?? 0,
        selfRemarks: (j['self_remarks'] as String?) ?? '',
        rmRemarks: (j['rm_remarks'] as String?) ?? '',
      );
}

/// Default Behavioural Competency rows, seeded on every new form — generic
/// to every employee, matching the paper template's section 5.
List<AppraisalRatingRow> defaultBehaviouralRows() => [
      AppraisalRatingRow(description: 'Leadership & team management'),
      AppraisalRatingRow(description: 'Communication & interpersonal skills'),
      AppraisalRatingRow(description: 'Problem-solving & decision making'),
      AppraisalRatingRow(description: 'Confidentiality & integrity'),
      AppraisalRatingRow(description: 'Time management & accountability'),
      AppraisalRatingRow(description: 'Builds strong rapport with employees'),
    ];

class AppraisalRecommendation {
  bool confirmedInRole;
  bool salaryRevision;
  bool promotion;
  bool trainingPlan;
  bool performanceImprovement;

  AppraisalRecommendation({
    this.confirmedInRole = false,
    this.salaryRevision = false,
    this.promotion = false,
    this.trainingPlan = false,
    this.performanceImprovement = false,
  });

  Map<String, dynamic> toJson() => {
        'confirmed_in_role': confirmedInRole,
        'salary_revision': salaryRevision,
        'promotion': promotion,
        'training_plan': trainingPlan,
        'performance_improvement': performanceImprovement,
      };

  factory AppraisalRecommendation.fromJson(Map<String, dynamic> j) => AppraisalRecommendation(
        confirmedInRole: (j['confirmed_in_role'] as bool?) ?? false,
        salaryRevision: (j['salary_revision'] as bool?) ?? false,
        promotion: (j['promotion'] as bool?) ?? false,
        trainingPlan: (j['training_plan'] as bool?) ?? false,
        performanceImprovement: (j['performance_improvement'] as bool?) ?? false,
      );
}

class AppraisalForm {
  String id;
  String employeeEmail;
  String employeeId;
  String employeeName;
  String status; // 'draft' | 'completed'
  bool movedToSalaryHike;
  String createdBy;
  String lastEditedBy;
  DateTime createdAt;
  DateTime updatedAt;

  // Section 1 — snapshot, editable.
  String designation;
  String department;
  String dateOfJoining;
  String reportingManager;
  String reviewPeriodFrom;
  String reviewPeriodTo;
  String selfAppraisalSubmissionDate;

  // Sections 3 / 4 / 5.
  List<AppraisalRatingRow> kra;
  List<AppraisalRatingRow> functional;
  List<AppraisalRatingRow> behavioural;

  // Sections 6-12 (numbered free-text lines).
  List<String> achievements;
  List<String> challenges;
  List<String> trainingSupport;
  List<String> goals;
  List<String> professionalAspects;
  List<String> expectationsFromOrg;
  List<String> thingsLoveAboutOrg;

  // Section 14.
  double scoreKra;
  double scoreFunctional;
  double scoreBehavioural;
  double scoreAchievements;

  // Section 15.
  AppraisalRecommendation recommendation;

  // Section 16.
  String recommendedDesignation;
  String recommendedSalaryIncrease;

  // Section 17.
  List<String> mdCeoRemarks;

  // Guards the one-time HR<->RM cross-notification when KRA filling starts.
  bool kraStartNotified;

  AppraisalForm({
    required this.id,
    required this.employeeEmail,
    required this.employeeId,
    required this.employeeName,
    this.status = 'draft',
    this.movedToSalaryHike = false,
    this.createdBy = '',
    this.lastEditedBy = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.designation = '',
    this.department = '',
    this.dateOfJoining = '',
    this.reportingManager = '',
    this.reviewPeriodFrom = '',
    this.reviewPeriodTo = '',
    this.selfAppraisalSubmissionDate = '',
    List<AppraisalRatingRow>? kra,
    List<AppraisalRatingRow>? functional,
    List<AppraisalRatingRow>? behavioural,
    List<String>? achievements,
    List<String>? challenges,
    List<String>? trainingSupport,
    List<String>? goals,
    List<String>? professionalAspects,
    List<String>? expectationsFromOrg,
    List<String>? thingsLoveAboutOrg,
    this.scoreKra = 0,
    this.scoreFunctional = 0,
    this.scoreBehavioural = 0,
    this.scoreAchievements = 0,
    AppraisalRecommendation? recommendation,
    this.recommendedDesignation = '',
    this.recommendedSalaryIncrease = '',
    List<String>? mdCeoRemarks,
    this.kraStartNotified = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        kra = kra ?? [],
        functional = functional ?? [],
        behavioural = behavioural ?? defaultBehaviouralRows(),
        achievements = achievements ?? List.filled(3, '', growable: true),
        challenges = challenges ?? List.filled(3, '', growable: true),
        trainingSupport = trainingSupport ?? List.filled(3, '', growable: true),
        goals = goals ?? List.filled(4, '', growable: true),
        professionalAspects = professionalAspects ?? List.filled(3, '', growable: true),
        expectationsFromOrg = expectationsFromOrg ?? List.filled(3, '', growable: true),
        thingsLoveAboutOrg = thingsLoveAboutOrg ?? List.filled(3, '', growable: true),
        recommendation = recommendation ?? AppraisalRecommendation(),
        mdCeoRemarks = mdCeoRemarks ?? List.filled(3, '', growable: true);

  /// Builds a brand-new draft pre-filled from the employee's current record.
  factory AppraisalForm.newFor(AppUser u, String id) => AppraisalForm(
        id: id,
        employeeEmail: u.email,
        employeeId: u.employeeId,
        employeeName: u.name,
        designation: u.designation,
        department: u.department,
        dateOfJoining: u.dateOfJoining,
        reportingManager: u.reportingManager,
        createdBy: UserSession.name,
        lastEditedBy: UserSession.name,
      );

  double get totalScore => scoreKra + scoreFunctional + scoreBehavioural + scoreAchievements;

  Map<String, dynamic> _dataJson() => {
        'designation': designation,
        'department': department,
        'date_of_joining': dateOfJoining,
        'reporting_manager': reportingManager,
        'review_period_from': reviewPeriodFrom,
        'review_period_to': reviewPeriodTo,
        'self_appraisal_submission_date': selfAppraisalSubmissionDate,
        'kra': kra.map((e) => e.toJson()).toList(),
        'functional': functional.map((e) => e.toJson()).toList(),
        'behavioural': behavioural.map((e) => e.toJson()).toList(),
        'achievements': achievements,
        'challenges': challenges,
        'training_support': trainingSupport,
        'goals': goals,
        'professional_aspects': professionalAspects,
        'expectations_from_org': expectationsFromOrg,
        'things_love_about_org': thingsLoveAboutOrg,
        'score_kra': scoreKra,
        'score_functional': scoreFunctional,
        'score_behavioural': scoreBehavioural,
        'score_achievements': scoreAchievements,
        'recommendation': recommendation.toJson(),
        'recommended_designation': recommendedDesignation,
        'recommended_salary_increase': recommendedSalaryIncrease,
        'md_ceo_remarks': mdCeoRemarks,
        'kra_start_notified': kraStartNotified,
      };

  Map<String, dynamic> toRow() => {
        'id': id,
        'employee_email': employeeEmail,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'status': status,
        'moved_to_salary_hike': movedToSalaryHike,
        'created_by': createdBy,
        'last_edited_by': lastEditedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'data': _dataJson(),
      };

  static List<String> _strList(dynamic v, int fallbackLength) {
    if (v is List) {
      final list = v.map((e) => e?.toString() ?? '').toList();
      while (list.length < fallbackLength) {
        list.add('');
      }
      return list;
    }
    return List.filled(fallbackLength, '', growable: true);
  }

  static List<AppraisalRatingRow> _rowList(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => AppraisalRatingRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  factory AppraisalForm.fromRow(Map<String, dynamic> row) {
    final rawData = row['data'];
    final data = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData) as Map)
        : Map<String, dynamic>.from(rawData as Map? ?? {});
    return AppraisalForm(
      id: (row['id'] as String?) ?? '',
      employeeEmail: (row['employee_email'] as String?) ?? '',
      employeeId: (row['employee_id'] as String?) ?? '',
      employeeName: (row['employee_name'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'draft',
      movedToSalaryHike: (row['moved_to_salary_hike'] as bool?) ?? false,
      createdBy: (row['created_by'] as String?) ?? '',
      lastEditedBy: (row['last_edited_by'] as String?) ?? '',
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((row['updated_at'] as String?) ?? '') ?? DateTime.now(),
      designation: (data['designation'] as String?) ?? '',
      department: (data['department'] as String?) ?? '',
      dateOfJoining: (data['date_of_joining'] as String?) ?? '',
      reportingManager: (data['reporting_manager'] as String?) ?? '',
      reviewPeriodFrom: (data['review_period_from'] as String?) ?? '',
      reviewPeriodTo: (data['review_period_to'] as String?) ?? '',
      selfAppraisalSubmissionDate: (data['self_appraisal_submission_date'] as String?) ?? '',
      kra: _rowList(data['kra']),
      functional: _rowList(data['functional']),
      behavioural: data['behavioural'] != null ? _rowList(data['behavioural']) : defaultBehaviouralRows(),
      achievements: _strList(data['achievements'], 3),
      challenges: _strList(data['challenges'], 3),
      trainingSupport: _strList(data['training_support'], 3),
      goals: _strList(data['goals'], 4),
      professionalAspects: _strList(data['professional_aspects'], 3),
      expectationsFromOrg: _strList(data['expectations_from_org'], 3),
      thingsLoveAboutOrg: _strList(data['things_love_about_org'], 3),
      scoreKra: (data['score_kra'] as num?)?.toDouble() ?? 0,
      scoreFunctional: (data['score_functional'] as num?)?.toDouble() ?? 0,
      scoreBehavioural: (data['score_behavioural'] as num?)?.toDouble() ?? 0,
      scoreAchievements: (data['score_achievements'] as num?)?.toDouble() ?? 0,
      recommendation: data['recommendation'] is Map
          ? AppraisalRecommendation.fromJson(Map<String, dynamic>.from(data['recommendation'] as Map))
          : AppraisalRecommendation(),
      recommendedDesignation: (data['recommended_designation'] as String?) ?? '',
      recommendedSalaryIncrease: (data['recommended_salary_increase'] as String?) ?? '',
      mdCeoRemarks: _strList(data['md_ceo_remarks'], 3),
      kraStartNotified: (data['kra_start_notified'] as bool?) ?? false,
    );
  }
}

class AppraisalStore {
  static String generateId() => 'APR-${DateTime.now().microsecondsSinceEpoch}';
}

/// Employees visible to the current user in Performance Management / Salary
/// Hike Engine: HR & Management see everyone; a flagged Reporting Manager
/// sees only their own team. Mirrors `_HrEmployeeRecordsPageState._baseList`.
List<AppUser> visibleEmployeesForAppraisal(List<AppUser> users) {
  final isHrOrMgmt = UserSession.role == UserRole.hr || UserSession.role == UserRole.management;
  if (isHrOrMgmt) return users;
  if (!UserSession.isReportingManager) return const [];
  final me = UserSession.name.trim().toLowerCase();
  if (me.isEmpty) return const [];
  return users.where((u) => u.reportingManager.trim().toLowerCase() == me).toList();
}
