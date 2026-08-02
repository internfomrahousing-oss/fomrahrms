import 'package:flutter_test/flutter_test.dart';
import 'package:fomra_hrms/utils/attendance_cycle.dart';

/// The attendance cycle runs 26th -> 25th. These pin the boundary, because
/// every "per month" allowance in the system now depends on it and an
/// off-by-one here silently doubles or halves someone's entitlement.
void main() {
  group('cycle boundaries', () {
    test('the 25th is the LAST day of its cycle', () {
      expect(attendanceCycleStart(DateTime(2026, 7, 25)), DateTime(2026, 6, 26));
      expect(attendanceCycleEnd(DateTime(2026, 7, 25)), DateTime(2026, 7, 25));
    });

    test('the 26th is the FIRST day of the next cycle', () {
      expect(attendanceCycleStart(DateTime(2026, 7, 26)), DateTime(2026, 7, 26));
      expect(attendanceCycleEnd(DateTime(2026, 7, 26)), DateTime(2026, 8, 25));
    });

    test('25th and 26th of the same month are in DIFFERENT cycles', () {
      expect(sameAttendanceCycle(DateTime(2026, 7, 25), DateTime(2026, 7, 26)), isFalse);
    });

    test('26 July and 3 August are in the SAME cycle', () {
      // The bug this replaces: a calendar-month comparison treated these as
      // different windows, so a full 120-minute permission allowance could be
      // spent twice in eleven days.
      expect(sameAttendanceCycle(DateTime(2026, 7, 26), DateTime(2026, 8, 3)), isTrue);
    });

    test('24 July and 26 July are in different cycles', () {
      expect(sameAttendanceCycle(DateTime(2026, 7, 24), DateTime(2026, 7, 26)), isFalse);
    });
  });

  group('year rollover', () {
    test('31 December falls in the January cycle', () {
      expect(attendanceCycleStart(DateTime(2026, 12, 31)), DateTime(2026, 12, 26));
      expect(attendanceCycleEnd(DateTime(2026, 12, 31)), DateTime(2027, 1, 25));
      expect(attendanceCycleLabel(DateTime(2026, 12, 31)), '2027-01');
    });

    test('5 January falls in the cycle that began 26 December', () {
      expect(attendanceCycleStart(DateTime(2027, 1, 5)), DateTime(2026, 12, 26));
    });

    test('31 Dec and 5 Jan are the same cycle, across the year boundary', () {
      expect(sameAttendanceCycle(DateTime(2026, 12, 31), DateTime(2027, 1, 5)), isTrue);
    });

    test('20 January and 5 January are the same cycle but different years of start', () {
      expect(sameAttendanceCycle(DateTime(2027, 1, 20), DateTime(2027, 1, 5)), isTrue);
    });
  });

  group('short months', () {
    test('February: 26 Feb starts the March cycle', () {
      expect(attendanceCycleStart(DateTime(2026, 2, 26)), DateTime(2026, 2, 26));
      expect(attendanceCycleEnd(DateTime(2026, 2, 26)), DateTime(2026, 3, 25));
    });

    test('1 March still belongs to the cycle that began 26 February', () {
      expect(attendanceCycleStart(DateTime(2026, 3, 1)), DateTime(2026, 2, 26));
    });
  });

  group('labelling', () {
    test('a cycle is named for the month it ENDS in', () {
      expect(attendanceCycleLabel(DateTime(2026, 7, 26)), '2026-08');
      expect(attendanceCycleLabel(DateTime(2026, 8, 25)), '2026-08');
      expect(attendanceCycleLabel(DateTime(2026, 8, 26)), '2026-09');
    });

    test('range renders readably', () {
      expect(attendanceCycleRange(DateTime(2026, 8, 3)), '26 Jul – 25 Aug');
    });
  });

  group('isInCurrentCycle', () {
    test('uses the supplied now, so it is testable', () {
      final now = DateTime(2026, 8, 3);
      expect(isInCurrentCycle(DateTime(2026, 7, 26), now: now), isTrue);
      expect(isInCurrentCycle(DateTime(2026, 7, 25), now: now), isFalse);
      expect(isInCurrentCycle(DateTime(2026, 8, 25), now: now), isTrue);
      expect(isInCurrentCycle(DateTime(2026, 8, 26), now: now), isFalse);
    });
  });
}
