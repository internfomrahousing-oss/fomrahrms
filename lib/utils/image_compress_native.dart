import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<Uint8List?> compressImage(Uint8List bytes, String mime) async {
  try {
    const target = 200 * 1024; // 200 KB
    for (final quality in [80, 60, 40, 20, 10, 5]) {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1200,
        minHeight: 1200,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed.length <= target) return compressed;
    }
    return null;
  } catch (_) {
    return null;
  }
}
