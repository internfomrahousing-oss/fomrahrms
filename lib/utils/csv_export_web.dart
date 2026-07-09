import 'dart:html' as html;

Future<void> exportCsv(String filename, String csvContent) async {
  final blob = html.Blob([csvContent], 'text/csv');
  final url = html.Url.createObjectUrl(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
