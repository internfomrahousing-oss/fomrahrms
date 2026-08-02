import 'package:flutter_test/flutter_test.dart';
import 'package:fomra_hrms/models/payslip_store.dart';

/// Characterisation tests for the payroll maths.
///
/// These pin CURRENT behaviour, including behaviour that is arguably wrong.
/// Tests marked BUG document a defect deliberately: they must fail loudly when
/// someone fixes it, at which point the expectation is updated in the same
/// commit as the fix. That way a fix is never silent and a regression is never
/// missed.
///
/// Every function here is pure — no database, no browser, no device — which is
/// why this file can exist at all.
void main() {
  group('oneDaySalary', () {
    test('divides gross pay by the days in the month', () {
      expect(PayslipCalc.oneDaySalary(grossPay: 30000, daysInMonth: 30), 1000);
    });

    test('guards against a zero or negative divisor', () {
      expect(PayslipCalc.oneDaySalary(grossPay: 30000, daysInMonth: 0), 0);
      expect(PayslipCalc.oneDaySalary(grossPay: 30000, daysInMonth: -1), 0);
    });

    test(
      'BUG: one day costs more in February than in January for the same salary. '
      'Divisor is calendar days, so a single LOP day is ~10.7% dearer in a '
      '28-day month. Most payrolls fix the divisor at 30 precisely so that an '
      "absence is priced the same whenever it falls. Update this test when the "
      'policy is decided.',
      () {
        const gross = 84000.0;
        final jan = PayslipCalc.oneDaySalary(grossPay: gross, daysInMonth: 31);
        final feb = PayslipCalc.oneDaySalary(grossPay: gross, daysInMonth: 28);

        expect(jan, closeTo(2709.68, 0.01));
        expect(feb, closeTo(3000.00, 0.01));
        expect(feb / jan, closeTo(1.107, 0.001));
      },
    );
  });

  group('lateDeduction', () {
    test('the first three grace-window late days are free', () {
      expect(
        PayslipCalc.lateDeduction(
            grossPay: 30000, daysInMonth: 30, graceLateDays: 3, severeLateDays: 0),
        0,
      );
    });

    test('a fourth grace late day costs half a day', () {
      expect(
        PayslipCalc.lateDeduction(
            grossPay: 30000, daysInMonth: 30, graceLateDays: 4, severeLateDays: 0),
        500,
      );
    });

    test('severe lateness is charged from the very first occurrence', () {
      // This is what is already sitting in production: two check-ins past the
      // 09:40 cut-off, with no grace and no approved Permission covering them.
      expect(
        PayslipCalc.lateDeduction(
            grossPay: 30000, daysInMonth: 30, graceLateDays: 0, severeLateDays: 1),
        500,
      );
    });

    test('grace excuses are not consumed by severe days', () {
      expect(
        PayslipCalc.lateDeduction(
            grossPay: 30000, daysInMonth: 30, graceLateDays: 2, severeLateDays: 2),
        1000,
      );
    });

    test('an employee on zero gross pay is deducted nothing', () {
      // Four of five live employees are on gross_pay 0, which is the only
      // reason the deductions above are currently invisible.
      expect(
        PayslipCalc.lateDeduction(
            grossPay: 0, daysInMonth: 31, graceLateDays: 0, severeLateDays: 5),
        0,
      );
    });
  });

  group('excessLeaveDeduction', () {
    test('charges a full day for each day beyond balance', () {
      expect(
        PayslipCalc.excessLeaveDeduction(
            grossPay: 30000, daysInMonth: 30, excessDays: 2),
        2000,
      );
    });

    test('never credits the employee when the balance is unspent', () {
      expect(
        PayslipCalc.excessLeaveDeduction(
            grossPay: 30000, daysInMonth: 30, excessDays: -3),
        0,
      );
    });
  });

  group('statutory deductions', () {
    test('BUG: EPF is a flat 1800 regardless of salary. That figure is the '
        'ceiling (12% of the 15,000 wage limit). An employee on 20,000 gross '
        'has a basic of 10,000, so EPF should be 1,200 — they are over-deducted '
        'by 600 every month, and the error is proportionally worst for the '
        'lowest paid.', () {
      expect(PayslipCalc.epf, 1800);
    });

    test('BUG: professional tax is a flat 208. PT is slab-based and varies by '
        'state, so a constant over-deducts everyone below the top slab.', () {
      expect(PayslipCalc.professionalTax, 208);
    });

    test('BUG: TDS is a cliff, not a slab. At 99,999/month TDS is 0; at '
        '100,000/month it is 10,000/month. A 1-rupee raise costs the employee '
        '1.2 lakh a year.', () {
      expect(PayslipCalc.tds(99999), 0);
      expect(PayslipCalc.tds(100000), 10000);

      final costOfOneRupeeRaise =
          (PayslipCalc.tds(100000) - PayslipCalc.tds(99999)) * 12;
      expect(costOfOneRupeeRaise, 120000);
    });

    test('tdsApplicable turns on at exactly 12 lakh annual', () {
      expect(PayslipCalc.tdsApplicable(99999), isFalse);
      expect(PayslipCalc.tdsApplicable(100000), isTrue);
    });

    test('no ESI is modelled anywhere', () {
      // ESI normally applies below 21,000 gross. There is no ESI field in
      // PayslipCalc at all. Recorded here so the omission is deliberate and
      // visible rather than forgotten.
      expect(PayslipCalc.tds(20000), 0);
    });
  });

  group('earnings components', () {
    test('HRA is half of basic', () {
      expect(PayslipCalc.hra(20000), 10000);
    });

    test('other allowance is 2% of gross', () {
      expect(PayslipCalc.otherAllowance(50000), 1000);
    });
  });
}
