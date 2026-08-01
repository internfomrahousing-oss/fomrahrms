import 'package:flutter_test/flutter_test.dart';
import 'package:fomra_hrms/models/leave_store.dart';

/// Characterisation tests for permMinutesFromReason().
///
/// This function reads a duration out of a free-text string. The string it is
/// given is built in apply_permission_page.dart as:
///
///     'Permission: $duration | $reasonText | $description'
///
/// so it contains the employee's own typed description. That makes the parse
/// steerable by the employee, in both directions:
///
///   * fewer minutes charged  -> quota goes further than it should
///   * fewer minutes credited -> approved Permission no longer covers the
///     late arrival, so checkin_status marks them late and lateDeduction
///     takes half a day's pay
///
/// Tests marked BUG pin current behaviour and must fail when the parse is
/// replaced by a stored integer column.
void main() {
  group('permMinutesFromReason — intended behaviour', () {
    test('reads each of the four standard durations', () {
      expect(LeaveStore.permMinutesFromReason('Permission: 30 Minutes | Bank Work'), 30);
      expect(LeaveStore.permMinutesFromReason('Permission: 1 Hour | Bank Work'), 60);
      expect(LeaveStore.permMinutesFromReason('Permission: 1½ Hours | Bank Work'), 90);
      expect(LeaveStore.permMinutesFromReason('Permission: 2 Hours | Bank Work'), 120);
    });
  });

  group('permMinutesFromReason — defects', () {
    test(
      'BUG: the employee\'s own description decides the charge. A 2-hour '
      'permission whose description mentions "30 Minutes" is charged 30, '
      'because that branch is tested first. 90 minutes of quota conjured out '
      'of a free-text box.',
      () {
        const asWritten = 'Permission: 2 Hours | Personal Work | back in 30 Minutes';
        expect(LeaveStore.permMinutesFromReason(asWritten), 30);
      },
    );

    test(
      'BUG: the same defect docks pay. The employee has an APPROVED 2-hour '
      'permission and arrives 90 minutes late — fully covered. Only 30 minutes '
      'are credited, the arrival is not covered, and lateDeduction charges half '
      'a day. The bug hurts the employee, not just the company.',
      () {
        const approved = 'Permission: 2 Hours | Doctor / Medical | should be back in 30 Minutes';
        final credited = LeaveStore.permMinutesFromReason(approved);
        const actualLatenessMinutes = 90;

        expect(credited, 30);
        expect(credited >= actualLatenessMinutes, isFalse,
            reason: 'approved permission fails to cover the lateness it was granted for');
      },
    );

    test(
      'BUG: "1 Hour" is a substring of "1 Hour 30 Minutes". If HR renames a '
      'duration in the form editor — which the app explicitly allows — the '
      'parse silently changes. Renaming "1½ Hours" to "1 Hour 30 Minutes" '
      'charges 30 instead of 90.',
      () {
        expect(LeaveStore.permMinutesFromReason('Permission: 1 Hour 30 Minutes | X'), 30);
      },
    );

    test(
      'BUG: an unrecognised label silently defaults to 60 minutes rather than '
      'failing. Any new duration HR adds is charged an hour whatever it says.',
      () {
        expect(LeaveStore.permMinutesFromReason('Permission: 45 Minutes | X'), 60);
        expect(LeaveStore.permMinutesFromReason('Permission: 3 Hours | X'), 60);
        expect(LeaveStore.permMinutesFromReason(''), 60);
      },
    );

    test(
      'BUG: quota arithmetic follows the parse, so the monthly cap is '
      'bypassable. Four 2-hour permissions described as "30 Minutes" total 120 '
      'charged minutes — exactly the monthly quota — while 480 minutes were '
      'actually taken.',
      () {
        const sneaky = 'Permission: 2 Hours | Personal Work | 30 Minutes tops';
        final charged = List.filled(4, sneaky)
            .map(LeaveStore.permMinutesFromReason)
            .fold<int>(0, (a, b) => a + b);

        expect(charged, 120);
        expect(charged, lessThan(4 * 120));
      },
    );
  });
}
