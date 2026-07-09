import 'package:url_launcher/url_launcher.dart';

/// Opens a hosted URL (attachment, external link) in the browser/OS handler
/// for viewing — images and PDFs preview inline instead of downloading.
/// Works on both web and native — replaces the old dart:html AnchorElement/
/// window.open tricks, which only worked on web.
void openUrl(String url) {
  if (url.isEmpty) return;
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Opens a hosted URL with Supabase Storage's `download` query param, which
/// forces a `Content-Disposition: attachment` response so the browser saves
/// the file instead of previewing it inline.
void downloadUrl(String url) {
  if (url.isEmpty) return;
  final uri = Uri.parse(url);
  final withDownload = uri.replace(queryParameters: {
    ...uri.queryParameters,
    'download': '',
  });
  launchUrl(withDownload, mode: LaunchMode.externalApplication);
}
