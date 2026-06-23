enum UserRole { hr, employee, reportingManager, management }

class UserSession {
  static bool     loggedIn   = false;
  static UserRole role       = UserRole.hr;
  static String   name       = '';
  static String   employeeId = '';

  static void clear() {
    loggedIn   = false;
    role       = UserRole.hr;
    name       = '';
    employeeId = '';
  }
}
