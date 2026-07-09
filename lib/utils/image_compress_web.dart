import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

// Compress image via Canvas API to ≤200 KB.
// Scales to max 1200 px on the long edge, then tries descending quality.
Future<Uint8List?> compressImage(Uint8List bytes, String mime) async {
  try {
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement(src: url);
    await Future.any([
      img.onLoad.first,
      img.onError.first.then((_) => throw Exception('Image load failed')),
    ]);
    html.Url.revokeObjectUrl(url);

    int w = img.naturalWidth;
    int h = img.naturalHeight;
    const maxDim = 1200;
    if (w > maxDim || h > maxDim) {
      if (w > h) { h = (h * maxDim / w).round(); w = maxDim; }
      else        { w = (w * maxDim / h).round(); h = maxDim; }
    }

    const target = 200 * 1024; // 200 KB
    for (final quality in [0.8, 0.6, 0.4, 0.2, 0.1, 0.05]) {
      final canvas = html.CanvasElement(width: w, height: h);
      canvas.context2D.drawImageScaled(img, 0, 0, w.toDouble(), h.toDouble());
      final compressed =
          Uint8List.fromList(base64Decode(canvas.toDataUrl('image/jpeg', quality).split(',').last));
      if (compressed.length <= target) return compressed;
    }
    // Last resort: halve dimensions and use lowest quality
    w = (w * 0.6).round(); h = (h * 0.6).round();
    final canvas = html.CanvasElement(width: w, height: h);
    canvas.context2D.drawImageScaled(img, 0, 0, w.toDouble(), h.toDouble());
    return Uint8List.fromList(
        base64Decode(canvas.toDataUrl('image/jpeg', 0.05).split(',').last));
  } catch (_) {
    return null;
  }
}
