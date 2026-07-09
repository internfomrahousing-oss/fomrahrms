/// Compresses an image toward ~200 KB, capped at 1200px on the long edge.
/// Returns null if compression isn't possible/needed — caller keeps the
/// original bytes in that case.
export 'image_compress_native.dart'
  if (dart.library.html) 'image_compress_web.dart';
