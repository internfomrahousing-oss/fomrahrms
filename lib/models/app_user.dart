import 'user_session.dart';

class AppUser {
  String name;
  String email;
  String employeeId;
  String designation;
  String role; // 'Employee' | 'Manager' | 'HR' | 'Management'
  bool active;

  AppUser({
    required this.name,
    required this.email,
    required this.employeeId,
    required this.designation,
    required this.role,
    this.active = true,
  });

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
    'name':        name,
    'email':       email,
    'employeeId':  employeeId,
    'designation': designation,
    'role':        role,
    'active':      active,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    name:        j['name']        as String? ?? '',
    email:       j['email']       as String? ?? '',
    employeeId:  j['employeeId']  as String? ?? '',
    designation: j['designation'] as String? ?? '',
    role:        j['role']        as String? ?? 'Employee',
    active:      j['active']      as bool?   ?? true,
  );
}
