import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/payslip_store.dart';

/// Renders a [Payslip] into a downloadable PDF, matching the breakdown
/// shown on the in-app payslip detail page (earnings, deductions, net pay,
/// leave details).
class PayslipPdfService {
  static const _purple = PdfColor.fromInt(0xFF4F46E5);
  static const _grey = PdfColor.fromInt(0xFF6B7280);

  static String _fmtRs(double v) =>
      'Rs. ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  static String _monthLabel(String monthYear) {
    const months = ['January','February','March','April','May','June',
                     'July','August','September','October','November','December'];
    final p = monthYear.split('-');
    if (p.length != 2) return monthYear;
    final m = int.tryParse(p[1]);
    if (m == null || m < 1 || m > 12) return monthYear;
    return '${months[m - 1]} ${p[0]}';
  }

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Expanded(
              flex: 2,
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _grey))),
          pw.Expanded(
              flex: 3,
              child: pw.Text(value,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
        ]),
      );

  static pw.Widget _amountRow(String label, double value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Text(_fmtRs(value),
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );

  static Future<Uint8List> build(Payslip p) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('FOMRA HOUSING & INFRASTRUCTURE PVT LTD',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _purple)),
            pw.SizedBox(height: 2),
            pw.Text('Pay Slip - ${_monthLabel(p.monthYear)}',
                style: const pw.TextStyle(fontSize: 11, color: _grey)),
            pw.SizedBox(height: 16),
            pw.Divider(color: _purple),
            pw.SizedBox(height: 12),

            _infoRow('Emp Code', p.employeeId),
            _infoRow('Employee Name', p.empName),
            _infoRow('Department', p.department),
            _infoRow('Designation', p.designation),
            if (p.band.isNotEmpty) _infoRow('Band', p.band),
            _infoRow('Date of Joining', p.dateOfJoining),
            _infoRow('No. of Working Days', '${p.workingDays}'),
            _infoRow('No. of Days Worked', '${p.daysWorked}'),
            _infoRow('No. of LOP Days', '${p.lopDays}'),
            _infoRow('Gross Pay', _fmtRs(p.grossPay)),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 12),

            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Earnings',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _purple, fontSize: 11)),
                  pw.SizedBox(height: 6),
                  _amountRow('Basic', p.basic),
                  _amountRow('House Rent Allowance', p.hra),
                  _amountRow('Educational Allowance', p.educationalAllowance),
                  _amountRow('LTA', p.lta),
                  _amountRow('Other Allowance', p.otherAllowance),
                  _amountRow('Conveyance Allowance', p.conveyanceAllowance),
                  if (p.specialAllowance > 0) _amountRow('Special Allowance', p.specialAllowance),
                  pw.Divider(),
                  _amountRow('Actual Gross Pay', p.actualGrossPay, bold: true),
                ]),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Deductions',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _purple, fontSize: 11)),
                  pw.SizedBox(height: 6),
                  _amountRow('EPF', p.epf),
                  _amountRow('Professional Tax', p.professionalTax),
                  _amountRow('TDS', p.tds),
                  _amountRow('Late Deductions', p.lateDeductions),
                  if (p.excessLeaveDeduction > 0)
                    _amountRow('Excess Leave Deduction', p.excessLeaveDeduction),
                  if (p.cug > 0) _amountRow('CUG', p.cug),
                  pw.Divider(),
                  _amountRow('Total Deductions', p.totalDeductions, bold: true),
                ]),
              ),
            ]),

            pw.SizedBox(height: 16),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFEEF2FF),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: _amountRow('Net Pay', p.netPay, bold: true),
            ),

            if (p.leaveDetails.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Leave Details',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _purple, fontSize: 11)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE5E7EB)),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Leave Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Opening', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Taken', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Closing', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    ],
                  ),
                  for (final row in p.leaveDetails)
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(row.type, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${row.opening}', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${row.taken}', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${row.closing}', style: const pw.TextStyle(fontSize: 9))),
                    ]),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    return doc.save();
  }

  /// Generates and triggers a browser/OS download of the payslip PDF.
  static Future<void> download(Payslip p) async {
    final bytes = await build(p);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Payslip-${_monthLabel(p.monthYear).replaceAll(' ', '-')}.pdf',
    );
  }
}
