import 'package:flutter_test/flutter_test.dart';
import 'package:fomra_hrms/models/app_user.dart';
import 'package:fomra_hrms/models/user_session.dart';

void main() {
  group('AppUser.userRoleFor', () {
    test('maps lowercase management role to management dashboard', () {
      expect(AppUser.userRoleFor('management'), UserRole.management);
    });

    test('maps lowercase manager role to reporting manager dashboard', () {
      expect(AppUser.userRoleFor('manager'), UserRole.reportingManager);
    });

    test('maps lowercase hr role to hr dashboard', () {
      expect(AppUser.userRoleFor('hr'), UserRole.hr);
    });
  });
}
