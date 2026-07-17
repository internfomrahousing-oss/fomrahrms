import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/reports/report_tables.dart';

/// Renders the currently visible Reports & Analytics KPIs + Attendance
/// Overview table into a downloadable PDF — same pw.Document ->
/// Printing.sharePdf two-step static-class pattern as payslip_pdf_service.dart.
class ReportPdfService {
  static const _grey = PdfColor.fromInt(0xFF6B7280);
  static const _border = PdfColor.fromInt(0xFFD1D5DB);
  static const _headerFill = PdfColor.fromInt(0xFFF3F4F6);

  static String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static pw.Widget _kpiTile(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.5)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  static pw.Widget _th(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _grey)),
      );

  static pw.Widget _td(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8.5)),
      );

  static pw.Widget _overviewTable(List<AttendanceOverviewRow> rows) {
    final tableRows = <pw.TableRow>[
      pw.TableRow(decoration: const pw.BoxDecoration(color: _headerFill), children: [
        _th('Date'), _th('Present'), _th('Absent'), _th('Late'), _th('Half Day'), _th('On Leave'), _th('Attendance %'),
      ]),
    ];
    for (final r in rows) {
      tableRows.add(pw.TableRow(children: [
        _td(_fmtDate(r.date)),
        _td('${r.present}'),
        _td('${r.absent}'),
        _td('${r.late}'),
        _td('${r.halfDay}'),
        _td('${r.onLeave}'),
        _td('${(r.attendancePercent * 100).round()}%'),
      ]));
    }
    return pw.Table(border: pw.TableBorder.all(color: _border, width: 0.5), children: tableRows);
  }

  static Future<Uint8List> build({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Map<String, String> kpis,
    required List<AttendanceOverviewRow> overview,
  }) async {
    final doc = pw.Document();
    final logoBytes = (await rootBundle.load('assets/images/fomra_logo.png')).buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);
    final kpiEntries = kpis.entries.toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Image(logo, height: 40),
          pw.SizedBox(height: 8),
          pw.Text('Reports & Analytics', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('${_fmtDate(rangeStart)} - ${_fmtDate(rangeEnd)}',
              style: const pw.TextStyle(fontSize: 9, color: _grey)),
          pw.SizedBox(height: 14),
          pw.GridView(
            crossAxisCount: 4,
            childAspectRatio: 2.2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            children: [for (final e in kpiEntries) _kpiTile(e.key, e.value)],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Attendance Overview', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _overviewTable(overview),
        ],
      ),
    );

    return doc.save();
  }

  /// Generates and triggers a browser/OS download/share of the report PDF.
  static Future<String> download({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Map<String, String> kpis,
    required List<AttendanceOverviewRow> overview,
  }) async {
    final bytes = await build(
      rangeStart: rangeStart, rangeEnd: rangeEnd, kpis: kpis, overview: overview,
    );
    final filename =
        'Reports-${_fmtDate(rangeStart).replaceAll(' ', '-').replaceAll(',', '')}-to-${_fmtDate(rangeEnd).replaceAll(' ', '-').replaceAll(',', '')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
    return filename;
  }
}
