import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'inline_progress_bar.dart';
import 'report_card_shell.dart';

String fmtRupees(double v) =>
    '₹${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

/// HR/Management-only card — total payroll for the selected month, sourced
/// from SupabaseService.fetchPayslipsForMonth (payslips RLS is self/HR/
/// Management only, no RM access, so this card is gated the same way on the
/// page itself).
class PayrollSummaryCard extends StatelessWidget {
  final double grossPay;
  final double deductions;
  final double netPay;
  final int employeesProcessed;
  final int totalEmployees;
  const PayrollSummaryCard({
    super.key,
    required this.grossPay,
    required this.deductions,
    required this.netPay,
    required this.employeesProcessed,
    required this.totalEmployees,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalEmployees == 0 ? 0.0 : employeesProcessed / totalEmployees;
    return ReportCardShell(
      title: 'Payroll Summary',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(fmtRupees(netPay),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const Text('Total Payroll (Net)',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _figure('Gross Salary', fmtRupees(grossPay))),
          Expanded(child: _figure('Deductions', fmtRupees(deductions))),
        ]),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Employees Processed',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          Text('$employeesProcessed / $totalEmployees',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 8),
        InlineProgressBar(percent: ratio, color: AppTheme.success, width: null),
      ]),
    );
  }

  Widget _figure(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ],
      );
}
