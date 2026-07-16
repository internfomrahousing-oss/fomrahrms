import 'package:flutter/foundation.dart';
import '../constants/org_lists.dart';

enum UserRole { hr, employee, reportingManager, management }

class UserSession {
  static bool     loggedIn        = false;
  static UserRole role            = UserRole.hr;
  static String   name            = '';
  static String   employeeId      = '';
  static String   email           = '';
  static String   designation     = '';
  static String   department      = '';
  static String   reportingManager= '';
  static bool     isReportingManager = false;
  static String   workLocation    = ''; // 'Office' | 'Onsite' | ''

  /// Housekeeping/Support Staff employees use a separate, simplified
  /// "Staff Portal" shell instead of the regular employee shell — same
  /// UserRole.employee, just routed differently. See lib/app.dart's guard.
  static bool get isStaffPortal =>
      role == UserRole.employee && kStaffPortalDepartments.contains(department);

  // Backed by a ValueNotifier so widgets built before the background photo
  // fetch (e.g. after a page refresh) can still update once the URL arrives.
  static final ValueNotifier<String> photoUrlNotifier = ValueNotifier<String>('');
  static String get photoUrl => photoUrlNotifier.value;
  static set photoUrl(String value) => photoUrlNotifier.value = value;

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
    department       = '';
    reportingManager = '';
    isReportingManager = false;
    workLocation     = '';
    photoUrl         = '';
  }
}
