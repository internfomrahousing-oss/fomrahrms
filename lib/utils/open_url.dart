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

const _officeExts = {'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'};

/// Opens an attachment for viewing without downloading it. Images and PDFs
/// have native browser renderers, so those open as-is; Word/Excel/PowerPoint
/// files have none (the browser would just save them), so those are routed
/// through Microsoft's Office Online viewer, which renders the document
/// in-page from its public URL.
void viewAttachment(String url) {
  if (url.isEmpty) return;
  final ext = Uri.parse(url).path.split('.').last.toLowerCase();
  final target = _officeExts.contains(ext)
      ? 'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(url)}'
      : url;
  launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
}
