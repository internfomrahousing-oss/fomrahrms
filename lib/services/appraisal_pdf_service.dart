import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/appraisal_store.dart';

/// Renders an [AppraisalForm] into a downloadable PDF, matching the
/// "Employee – Self Appraisal Form" paper template.
class AppraisalPdfService {
  static const _blue = PdfColor.fromInt(0xFF2563EB);
  static const _grey = PdfColor.fromInt(0xFF6B7280);
  static const _headerFill = PdfColor.fromInt(0xFFF8FAFC);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _blue)),
      );

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(children: [
          pw.SizedBox(
              width: 140,
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _grey))),
          pw.Expanded(
              child: pw.Text(value.isEmpty ? '-' : value,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
        ]),
      );

  static pw.Widget _th(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
      );

  static pw.Widget _td(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text.isEmpty ? '-' : text, style: const pw.TextStyle(fontSize: 8.5)),
      );

  static pw.Widget _ratingTable(String title, List<AppraisalRatingRow> rows) {
    if (rows.isEmpty) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _sectionTitle(title),
        pw.Text('No items recorded.', style: const pw.TextStyle(fontSize: 9, color: _grey)),
      ]);
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionTitle(title),
      pw.Table(
        border: pw.TableBorder.all(color: _border),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(2.5),
          3: pw.FlexColumnWidth(2.5),
        },
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _headerFill), children: [
            _th('Description'), _th('Self Rating'), _th('Self Remarks'), _th('RM Remarks'),
          ]),
          for (final r in rows)
            pw.TableRow(children: [
              _td(r.description),
              _td(r.selfRating == 0 ? '-' : '${r.selfRating}/5'),
              _td(r.selfRemarks),
              _td(r.rmRemarks),
            ]),
        ],
      ),
    ]);
  }

  static pw.Widget _numberedLines(String title, List<String> lines) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          for (var i = 0; i < lines.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text('${i + 1}. ${lines[i].isEmpty ? '-' : lines[i]}',
                  style: const pw.TextStyle(fontSize: 9.5)),
            ),
        ],
      );

  static pw.Widget _header(AppraisalForm f) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('FOMRA HOUSING & INFRASTRUCTURE PVT LTD',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _blue)),
          pw.SizedBox(height: 2),
          pw.Text('Employee – Self Appraisal Form', style: const pw.TextStyle(fontSize: 11, color: _grey)),
          pw.SizedBox(height: 12),
          pw.Divider(color: _blue),
          pw.SizedBox(height: 10),
          _sectionTitle('1. Employee Information'),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _infoRow('Employee Name', f.employeeName),
                _infoRow('Employee ID', f.employeeId),
                _infoRow('Designation', f.designation),
                _infoRow('Department', f.department),
              ]),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _infoRow('Date of Joining', f.dateOfJoining),
                _infoRow('Review Period', '${f.reviewPeriodFrom} to ${f.reviewPeriodTo}'),
                _infoRow('Reporting Manager', f.reportingManager),
                _infoRow('Submission Date', f.selfAppraisalSubmissionDate),
              ]),
            ),
          ]),
        ],
      );

  static pw.Widget _scoreSummary(AppraisalForm f) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('14. Final Score Summary'),
          pw.Table(
            border: pw.TableBorder.all(color: _border),
            columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1)},
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: _headerFill), children: [
                _th('Section'), _th('Weightage'), _th('Score Obtained'),
              ]),
              pw.TableRow(children: [_td('KRAs / Job Responsibilities'), _td('60%'), _td('${f.scoreKra}')]),
              pw.TableRow(children: [_td('Functional Competencies'), _td('20%'), _td('${f.scoreFunctional}')]),
              pw.TableRow(children: [_td('Behavioural Competencies'), _td('15%'), _td('${f.scoreBehavioural}')]),
              pw.TableRow(children: [_td('Achievements / Initiatives'), _td('5%'), _td('${f.scoreAchievements}')]),
              pw.TableRow(decoration: const pw.BoxDecoration(color: _headerFill), children: [
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5))),
                _td('100%'),
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${f.totalScore}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5))),
              ]),
            ],
          ),
        ],
      );

  static pw.Widget _recommendation(AppraisalForm f) {
    final r = f.recommendation;
    String tick(bool v) => v ? 'Yes' : '-';
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionTitle('15. Final Recommendation of Reporting Manager'),
      _infoRow('Confirmed in Role', tick(r.confirmedInRole)),
      _infoRow('Salary Revision Recommended', tick(r.salaryRevision)),
      _infoRow('Promotion Recommended', tick(r.promotion)),
      _infoRow('Training / Development Plan Required', tick(r.trainingPlan)),
      _infoRow('Performance Improvement Required', tick(r.performanceImprovement)),
      _sectionTitle('16. Recommended'),
      _infoRow('Designation', f.recommendedDesignation),
      _infoRow('Salary Increase', f.recommendedSalaryIncrease),
    ]);
  }

  /// Full 17-section form.
  static Future<Uint8List> build(AppraisalForm f) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _header(f),
          _ratingTable('3. Key Responsibility Areas (KRA) – Core Job Responsibilities (60%)', f.kra),
          _ratingTable('4. Functional & Operational Competencies (20%)', f.functional),
          _ratingTable('5. Behavioural Competencies (15%)', f.behavioural),
          _numberedLines('6. Key Achievements During the Review Period', f.achievements),
          _numberedLines('7. Challenges Faced During the Review Period', f.challenges),
          _numberedLines('8. Training / Support Required', f.trainingSupport),
          _numberedLines('9. Goals & Action Plan for Next Review Period', f.goals),
          _numberedLines('10. Where Do You See Yourself (3 Professional Aspects)', f.professionalAspects),
          _numberedLines('11. Expectations from the Organization', f.expectationsFromOrg),
          _numberedLines('12. Things You Love About the Organization', f.thingsLoveAboutOrg),
          _scoreSummary(f),
          _recommendation(f),
          _numberedLines('17. MD & CEO Remarks', f.mdCeoRemarks),
        ],
      ),
    );
    return doc.save();
  }

  /// Condensed PDF for Salary Hike Engine: section 1 + 14-17 only.
  static Future<Uint8List> buildSummary(AppraisalForm f) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _header(f),
          _scoreSummary(f),
          _recommendation(f),
          _numberedLines('17. MD & CEO Remarks', f.mdCeoRemarks),
        ],
      ),
    );
    return doc.save();
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '-');

  static Future<void> download(AppraisalForm f) async {
    final bytes = await build(f);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Appraisal-${_safe(f.employeeName)}-${_safe(f.reviewPeriodFrom)}.pdf',
    );
  }

  static Future<void> downloadSummary(AppraisalForm f) async {
    final bytes = await buildSummary(f);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'SalaryHike-${_safe(f.employeeName)}.pdf',
    );
  }
}
