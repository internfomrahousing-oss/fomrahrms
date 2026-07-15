import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders the Pre-Offer Letter into a PDF, modeled on
/// PayslipPdfService's build/save pattern. Used by the "Send Pre-Offer
/// Letter" flow in interview_process_page.dart — the PDF is uploaded to
/// Supabase Storage and both attached to the offer email and shown on the
/// public /pre-offer/{token} accept page.
class PreOfferPdfService {
  static const _blue = PdfColor.fromInt(0xFF1E3A8A);
  static const _grey = PdfColor.fromInt(0xFF6B7280);

  static Future<Uint8List> build({
    required String candidateName,
    required String letterBody,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text('FOMRA HOUSING & INFRASTRUCTURE PVT LTD',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _blue)),
          pw.SizedBox(height: 2),
          pw.Text('Pre-Offer Letter', style: const pw.TextStyle(fontSize: 10, color: _grey)),
          pw.SizedBox(height: 16),
          pw.Text(letterBody, style: const pw.TextStyle(fontSize: 10, lineSpacing: 3)),
        ],
      ),
    );

    return doc.save();
  }
}
