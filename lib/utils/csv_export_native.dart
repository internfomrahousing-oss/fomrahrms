import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

Future<void> exportCsv(String filename, String csvContent) async {
  final bytes = Uint8List.fromList(csvContent.codeUnits);
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')],
  );
}
