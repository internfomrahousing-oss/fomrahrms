import 'user_session.dart';

class AppUser {
  String name;
  String email;
  String employeeId;
  String designation;
  String role; // 'Employee' | 'Manager' | 'HR' | 'Management'
  bool active;
  String password;            // individual password; empty = use role default
  int leaveAllocation;        // total leave days per year, set by HR
  String reportingManager;    // name of the manager this employee reports to
  String mobile;
  String address;
  String dateOfJoining;       // ISO date string, set when management creates the user
  String onrollConfirmedAt;   // ISO datetime when HR confirmed on-roll; empty = probation
  String onrollRequestedAt;   // ISO datetime when employee requested on-roll confirmation; empty = no pending request
  String elEligibleAt;        // ISO datetime when HR confirmed EL eligibility; empty = not eligible
  String biometricId;         // PIN programmed on biometric device (x990); empty = not enrolled
  String elAvailRequestedAt; // ISO datetime when employee requested EL avail; empty = no pending request
  String elLastAvailedAt;    // ISO datetime when HR confirmed EL avail; empty = never availed
  double grossPay;           // monthly gross pay (Rs), set by HR, used to generate payslips

  AppUser({
    required this.name,
    required this.email,
    required this.employeeId,
    required this.designation,
    required this.role,
    this.active = true,
    this.password = '',
    this.leaveAllocation = 21,
    this.reportingManager = '',
    this.mobile = '',
    this.address = '',
    this.dateOfJoining = '',
    this.onrollConfirmedAt = '',
    this.onrollRequestedAt = '',
    this.elEligibleAt = '',
    this.biometricId = '',
    this.elAvailRequestedAt = '',
    this.elLastAvailedAt = '',
    this.grossPay = 0,
  });

  bool get isOnroll    => onrollConfirmedAt.isNotEmpty;
  bool get isElEligible => elEligibleAt.isNotEmpty;

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
    'role':                  role,
    'active':                active,
    'password':              password,
    'leaveAllocation':       leaveAllocation,
    'reportingManager':      reportingManager,
    'mobile':                mobile,
    'address':               address,
    'dateOfJoining':         dateOfJoining,
    'onrollConfirmedAt':     onrollConfirmedAt,
    'onrollRequestedAt':     onrollRequestedAt,
    'elEligibleAt':          elEligibleAt,
    'biometricId':           biometricId,
    'elAvailRequestedAt':    elAvailRequestedAt,
    'elLastAvailedAt':       elLastAvailedAt,
    'grossPay':              grossPay,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    name:                 j['name']                 as String? ?? '',
    email:                j['email']                as String? ?? '',
    employeeId:           j['employeeId']           as String? ?? '',
    designation:          j['designation']          as String? ?? '',
    role:                 j['role']                 as String? ?? 'Employee',
    active:               j['active']               as bool?   ?? true,
    password:             j['password']             as String? ?? '',
    leaveAllocation:      j['leaveAllocation']      as int?    ?? 21,
    reportingManager:     j['reportingManager']     as String? ?? '',
    mobile:               j['mobile']               as String? ?? '',
    address:              j['address']              as String? ?? '',
    dateOfJoining:        j['dateOfJoining']        as String? ?? '',
    onrollConfirmedAt:    j['onrollConfirmedAt']    as String? ?? '',
    onrollRequestedAt:    j['onrollRequestedAt']    as String? ?? '',
    elEligibleAt:         j['elEligibleAt']         as String? ?? '',
    biometricId:          j['biometricId']          as String? ?? '',
    elAvailRequestedAt:   j['elAvailRequestedAt']   as String? ?? '',
    elLastAvailedAt:      j['elLastAvailedAt']       as String? ?? '',
    grossPay:             (j['grossPay'] as num?)?.toDouble() ?? 0,
  );
}
