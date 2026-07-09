/// Exports [csvContent] as a file named [filename] — triggers a browser
/// download on web, opens the OS share sheet on native.
export 'csv_export_native.dart'
  if (dart.library.html) 'csv_export_web.dart';
