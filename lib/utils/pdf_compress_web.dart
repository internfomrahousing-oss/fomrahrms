import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

// Best-effort PDF compression via pdf-lib (loaded from CDN in web/index.html):
// re-serializes the PDF with object-stream compression. This shrinks
// redundant objects/streams but can't guarantee hitting an exact target for
// image-heavy/scanned PDFs without re-rendering pages, which this does not do.
Future<Uint8List?> compressPdf(Uint8List bytes) async {
  try {
    final pdfLib   = js_util.getProperty(html.window, 'PDFLib');
    final docClass = js_util.getProperty(pdfLib, 'PDFDocument');
    final doc = await js_util.promiseToFuture(
        js_util.callMethod(docClass, 'load', [bytes]));
    final opts = js_util.newObject();
    js_util.setProperty(opts, 'useObjectStreams', true);
    final saved = await js_util.promiseToFuture<Uint8List>(
        js_util.callMethod(doc, 'save', [opts]));
    return saved;
  } catch (_) {
    return null;
  }
}
