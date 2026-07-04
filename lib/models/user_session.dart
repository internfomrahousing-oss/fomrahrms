enum UserRole { hr, employee, reportingManager, management }

class UserSession {
  static bool     loggedIn        = false;
  static UserRole role            = UserRole.hr;
  static String   name            = '';
  static String   employeeId      = '';
  static String   email           = '';
  static String   designation     = '';
  static String   reportingManager= '';
  static String   photoUrl        = '';

  static String get profileRoute {
    switch (role) {
      case UserRole.hr:               return '/hr/my-profile';
      case UserRole.reportingManager: return '/manager/my-profile';
      case UserRole.management:       return '/management/my-profile';
      case UserRole.employee:         return '/employee/profile';
    }
  }

  static void clear() {
    loggedIn         = false;
    role             = UserRole.hr;
    name             = '';
    employeeId       = '';
    email            = '';
    designation      = '';
    reportingManager = '';
    photoUrl         = '';
  }
}
