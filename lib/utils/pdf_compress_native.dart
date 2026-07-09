import 'dart:typed_data';

// No client-side PDF compression library on native — upload the original
// bytes as-is rather than chasing a package that replicates pdf-lib.js.
Future<Uint8List?> compressPdf(Uint8List bytes) async => null;
