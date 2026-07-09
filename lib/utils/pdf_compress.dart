/// Best-effort PDF compression. Returns null if compression isn't
/// available/possible — caller keeps the original bytes in that case.
export 'pdf_compress_native.dart'
  if (dart.library.html) 'pdf_compress_web.dart';
