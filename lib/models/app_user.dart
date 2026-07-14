import 'user_session.dart';

class AppUser {
  String name;
  String email;
  String employeeId;
  String designation;
  String department;
  String role; // 'Employee' | 'Manager' | 'HR' | 'Management'
  bool active;
  String password;            // individual password; empty = use role default
  int leaveAllocation;        // total leave days per year, set by HR
  String reportingManager;    // name of the manager this employee reports to
  String reportingManagerPending;      // proposed new manager name awaiting Management approval; '' = none
  String reportingManagerRequestedAt;  // ISO datetime the change was requested; empty = no pending request
  bool   isReportingManager;           // eligible to be selected as someone's RM
  bool   isReportingManagerPending;    // proposed new flag value awaiting Management approval
  String isReportingManagerRequestedAt; // ISO datetime the change was requested; empty = no pending request
  String mobile;
  String address;
  String dateOfJoining;       // ISO date string, set when management creates the user
  String onrollConfirmedAt;   // ISO datetime when Management approved on-roll; empty = probation
  String onrollRequestedAt;   // ISO datetime when employee requested on-roll confirmation; empty = no pending request
  // On-roll 3-stage review: HR and Reporting Manager decide independently, then Management.
  String onrollHrStatus;           // 'pending' | 'accepted' | 'denied'
  String onrollHrComment;
  String onrollHrDecidedAt;
  String onrollManagerStatus;      // 'pending' | 'accepted' | 'denied'
  String onrollManagerComment;
  String onrollManagerDecidedAt;
  String onrollManagementStatus;   // 'pending' | 'accepted' | 'denied'
  String onrollManagementComment;
  String onrollManagementDecidedAt;
  String elEligibleAt;        // ISO datetime when HR confirmed EL eligibility; empty = not eligible
  String elAvailRequestedAt; // ISO datetime when employee requested EL avail; empty = no pending request
  String elLastAvailedAt;    // ISO datetime when HR confirmed EL avail; empty = never availed
  double grossPay;           // monthly gross pay (Rs); HR sets it once, then changes go through Management
  double grossPayPending;    // proposed new value awaiting Management approval; 0 = none
  String grossPayRequestedAt; // ISO datetime the change was requested; empty = no pending request
  // Work location: 'Office' | 'Onsite'; empty = not yet set. Once set, HR can only
  // request a change — Management approves/denies it (see workLocationPending).
  // Purely an employment attribute now (dashboard breakdowns, records badges) —
  // every employee checks in/out via the app regardless of this value.
  String workLocation;
  String workLocationPending;      // proposed new value awaiting Management approval; empty = none
  String workLocationRequestedAt;  // ISO datetime the change was requested
  // Device Binding — restricts mobile app login/check-in-out to one phone per
  // employee. deviceId is a locally-generated token (see DeviceBindingService),
  // not a hardware id; empty = no device registered (or HR has reset it).
  String deviceId;
  String deviceName;           // e.g. "Samsung Galaxy S24"; best-effort, may be empty
  String devicePlatform;       // 'Android' | 'iPhone' | ''
  String deviceRegisteredAt;   // ISO datetime; empty = not registered
  String deviceLastLogin;      // ISO datetime of the most recent login from the bound device

  AppUser({
    required this.name,
    required this.email,
    required this.employeeId,
    required this.designation,
    this.department = '',
    required this.role,
    this.active = true,
    this.password = '',
    this.leaveAllocation = 21,
    this.reportingManager = '',
    this.reportingManagerPending = '',
    this.reportingManagerRequestedAt = '',
    this.isReportingManager = false,
    this.isReportingManagerPending = false,
    this.isReportingManagerRequestedAt = '',
    this.mobile = '',
    this.address = '',
    this.dateOfJoining = '',
    this.onrollConfirmedAt = '',
    this.onrollRequestedAt = '',
    this.onrollHrStatus = 'pending',
    this.onrollHrComment = '',
    this.onrollHrDecidedAt = '',
    this.onrollManagerStatus = 'pending',
    this.onrollManagerComment = '',
    this.onrollManagerDecidedAt = '',
    this.onrollManagementStatus = 'pending',
    this.onrollManagementComment = '',
    this.onrollManagementDecidedAt = '',
    this.elEligibleAt = '',
    this.elAvailRequestedAt = '',
    this.elLastAvailedAt = '',
    this.grossPay = 0,
    this.grossPayPending = 0,
    this.grossPayRequestedAt = '',
    this.workLocation = '',
    this.workLocationPending = '',
    this.workLocationRequestedAt = '',
    this.deviceId = '',
    this.deviceName = '',
    this.devicePlatform = '',
    this.deviceRegisteredAt = '',
    this.deviceLastLogin = '',
  });

  bool get isOnroll    => onrollConfirmedAt.isNotEmpty;
  bool get isDeviceBound => deviceId.isNotEmpty;
  bool get isElEligible => elEligibleAt.isNotEmpty;
  bool get hasPendingWorkLocationChange => workLocationPending.isNotEmpty;
  bool get hasPendingGrossPayChange => grossPayRequestedAt.isNotEmpty;
  bool get hasPendingReportingManagerChange => reportingManagerRequestedAt.isNotEmpty;
  bool get hasPendingRmFlagChange => isReportingManagerRequestedAt.isNotEmpty;

  // On-roll 3-stage review helpers
  bool get onrollHrAccepted       => onrollHrStatus == 'accepted';
  bool get onrollHrDenied         => onrollHrStatus == 'denied';
  bool get onrollManagerAccepted  => onrollManagerStatus == 'accepted';
  bool get onrollManagerDenied    => onrollManagerStatus == 'denied';
  bool get onrollManagementDenied => onrollManagementStatus == 'denied';

  /// True once both HR and Manager have accepted and Management hasn't decided yet.
  bool get onrollAwaitingManagement =>
      onrollRequestedAt.isNotEmpty && onrollHrAccepted && onrollManagerAccepted &&
      onrollManagementStatus == 'pending';

  /// True if the request is currently denied by any stage.
  bool get onrollDenied => onrollHrDenied || onrollManagerDenied || onrollManagementDenied;

  /// Which party issued the denial: 'HR' | 'Manager' | 'Management' | ''.
  String get onrollDeniedBy {
    if (onrollHrDenied) return 'HR';
    if (onrollManagerDenied) return 'Manager';
    if (onrollManagementDenied) return 'Management';
    return '';
  }

  /// The comment attached to whichever stage denied it; '' if none.
  String get onrollDeniedComment {
    if (onrollHrDenied) return onrollHrComment;
    if (onrollManagerDenied) return onrollManagerComment;
    if (onrollManagementDenied) return onrollManagementComment;
    return '';
  }

  /// ISO timestamp of whichever stage denied it; drives the 7-day resubmit cooldown.
  String get onrollDeniedAt {
    if (onrollHrDenied) return onrollHrDecidedAt;
    if (onrollManagerDenied) return onrollManagerDecidedAt;
    if (onrollManagementDenied) return onrollManagementDecidedAt;
    return '';
  }

  /// True once 7 days have passed since the denial, i.e. the employee may resubmit.
  bool get onrollCanResubmit {
    if (!onrollDenied) return false;
    final ts = onrollDeniedAt;
    if (ts.isEmpty) return true;
    try {
      return DateTime.now().difference(DateTime.parse(ts)) >= const Duration(days: 7);
    } catch (_) {
      return true;
    }
  }

  /// Overall stage, used to drive UI without duplicating conditionals across pages.
  /// 'not_requested' | 'pending_both' | 'pending_hr' | 'pending_manager' |
  /// 'awaiting_management' | 'denied' | 'confirmed'
  String get onrollStage {
    if (isOnroll) return 'confirmed';
    if (onrollDenied) return 'denied';
    if (onrollRequestedAt.isEmpty) return 'not_requested';
    if (onrollAwaitingManagement) return 'awaiting_management';
    final hrDone = onrollHrStatus != 'pending';
    final mgrDone = onrollManagerStatus != 'pending';
    if (hrDone && !mgrDone) return 'pending_manager';
    if (!hrDone && mgrDone) return 'pending_hr';
    return 'pending_both';
  }

  // Monthly leave allocation per type
  int get monthlyCl => 1;                    // all employees (probation: emergency CL)
  int get monthlyMl => isOnroll ? 1 : 0;    // on-roll and above
  int get monthlyEl => isElEligible ? 1 : 0; // EL eligible (cumulative, not monthly reset)

  String get leaveStatus {
    if (isElEligible) return 'EL Eligible';
    if (isOnroll)     return 'On-Roll';
    return 'Probation';
  }

  // Role-based shared password — all employees use the same password, etc.
  static String passwordForRole(String role) {
    switch (role) {
      case 'HR':         return 'Admin@123';
      case 'Manager':    return 'Manager@123';
      case 'Management': return 'Mgmt@123';
      default:           return 'Emp@123';
    }
  }

  static UserRole userRoleFor(String role) {
    switch (role) {
      case 'HR':         return UserRole.hr;
      case 'Manager':    return UserRole.reportingManager;
      case 'Management': return UserRole.management;
      default:           return UserRole.employee;
    }
  }

  Map<String, dynamic> toJson() => {
    'name':                  name,
    'email':                 email,
    'employeeId':            employeeId,
    'designation':           designation,
    'department':            department,
    'role':                  role,
    'active':                active,
    'password':              password,
    'leaveAllocation':       leaveAllocation,
    'reportingManager':      reportingManager,
    'reportingManagerPending':     reportingManagerPending,
    'reportingManagerRequestedAt': reportingManagerRequestedAt,
    'isReportingManager':          isReportingManager,
    'isReportingManagerPending':   isReportingManagerPending,
    'isReportingManagerRequestedAt': isReportingManagerRequestedAt,
    'mobile':                mobile,
    'address':               address,
    'dateOfJoining':         dateOfJoining,
    'onrollConfirmedAt':     onrollConfirmedAt,
    'onrollRequestedAt':     onrollRequestedAt,
    'onrollHrStatus':            onrollHrStatus,
    'onrollHrComment':           onrollHrComment,
    'onrollHrDecidedAt':         onrollHrDecidedAt,
    'onrollManagerStatus':       onrollManagerStatus,
    'onrollManagerComment':      onrollManagerComment,
    'onrollManagerDecidedAt':    onrollManagerDecidedAt,
    'onrollManagementStatus':    onrollManagementStatus,
    'onrollManagementComment':   onrollManagementComment,
    'onrollManagementDecidedAt': onrollManagementDecidedAt,
    'elEligibleAt':          elEligibleAt,
    'elAvailRequestedAt':    elAvailRequestedAt,
    'elLastAvailedAt':       elLastAvailedAt,
    'grossPay':              grossPay,
    'grossPayPending':       grossPayPending,
    'grossPayRequestedAt':   grossPayRequestedAt,
    'workLocation':          workLocation,
    'workLocationPending':   workLocationPending,
    'workLocationRequestedAt': workLocationRequestedAt,
    'deviceId':              deviceId,
    'deviceName':            deviceName,
    'devicePlatform':        devicePlatform,
    'deviceRegisteredAt':    deviceRegisteredAt,
    'deviceLastLogin':       deviceLastLogin,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    name:                 j['name']                 as String? ?? '',
    email:                j['email']                as String? ?? '',
    employeeId:           j['employeeId']           as String? ?? '',
    designation:          j['designation']          as String? ?? '',
    department:           j['department']           as String? ?? '',
    role:                 j['role']                 as String? ?? 'Employee',
    active:               j['active']               as bool?   ?? true,
    password:             j['password']             as String? ?? '',
    leaveAllocation:      j['leaveAllocation']      as int?    ?? 21,
    reportingManager:     j['reportingManager']     as String? ?? '',
    reportingManagerPending:     j['reportingManagerPending']     as String? ?? '',
    reportingManagerRequestedAt: j['reportingManagerRequestedAt'] as String? ?? '',
    isReportingManager:            j['isReportingManager']            as bool?   ?? false,
    isReportingManagerPending:     j['isReportingManagerPending']     as bool?   ?? false,
    isReportingManagerRequestedAt: j['isReportingManagerRequestedAt'] as String? ?? '',
    mobile:               j['mobile']               as String? ?? '',
    address:              j['address']              as String? ?? '',
    dateOfJoining:        j['dateOfJoining']        as String? ?? '',
    onrollConfirmedAt:    j['onrollConfirmedAt']    as String? ?? '',
    onrollRequestedAt:    j['onrollRequestedAt']    as String? ?? '',
    onrollHrStatus:            j['onrollHrStatus']            as String? ?? 'pending',
    onrollHrComment:           j['onrollHrComment']           as String? ?? '',
    onrollHrDecidedAt:         j['onrollHrDecidedAt']         as String? ?? '',
    onrollManagerStatus:       j['onrollManagerStatus']       as String? ?? 'pending',
    onrollManagerComment:      j['onrollManagerComment']      as String? ?? '',
    onrollManagerDecidedAt:    j['onrollManagerDecidedAt']    as String? ?? '',
    onrollManagementStatus:    j['onrollManagementStatus']    as String? ?? 'pending',
    onrollManagementComment:   j['onrollManagementComment']   as String? ?? '',
    onrollManagementDecidedAt: j['onrollManagementDecidedAt'] as String? ?? '',
    elEligibleAt:         j['elEligibleAt']         as String? ?? '',
    elAvailRequestedAt:   j['elAvailRequestedAt']   as String? ?? '',
    elLastAvailedAt:      j['elLastAvailedAt']       as String? ?? '',
    grossPay:             (j['grossPay'] as num?)?.toDouble() ?? 0,
    grossPayPending:      (j['grossPayPending'] as num?)?.toDouble() ?? 0,
    grossPayRequestedAt:  j['grossPayRequestedAt'] as String? ?? '',
    workLocation:            j['workLocation']            as String? ?? '',
    workLocationPending:     j['workLocationPending']     as String? ?? '',
    workLocationRequestedAt: j['workLocationRequestedAt'] as String? ?? '',
    deviceId:               j['deviceId']            as String? ?? '',
    deviceName:             j['deviceName']          as String? ?? '',
    devicePlatform:         j['devicePlatform']      as String? ?? '',
    deviceRegisteredAt:     j['deviceRegisteredAt']  as String? ?? '',
    deviceLastLogin:        j['deviceLastLogin']     as String? ?? '',
  );
}
