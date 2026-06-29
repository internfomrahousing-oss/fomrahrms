// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

int _wfpCounter = 0;

/// File-picker widget for Flutter web.
///
/// Primary path: a transparent HTML <label> (with a hidden <input type="file">)
///   is overlaid via HtmlElementView. The user's tap goes directly to the
///   native label → no programmatic .click() needed → user-activation satisfied.
///
/// Fallback path: the [builder] callback receives a [trigger] function.
///   Pass it as [onPressed] on the child button. If the HtmlElementView label
///   did NOT catch the click (pointer fell through to Flutter), Flutter calls
///   onPressed → trigger() → programmatic .click() with off-screen positioning,
///   which works in every desktop browser from a Flutter button tap.
///
/// Together these two paths ensure the file dialog opens on all browsers.
class WebFilePicker extends StatefulWidget {
  final String accept;
  final bool multiple;
  final bool enabled;
  /// Called with the selected [html.File] objects.
  final void Function(List<html.File>) onRawFiles;
  /// Build the child button. [trigger] is the programmatic fallback — pass it
  /// as the button's onPressed.
  final Widget Function(VoidCallback trigger) builder;

  const WebFilePicker({
    required this.accept,
    required this.builder,
    required this.onRawFiles,
    this.multiple = false,
    this.enabled = true,
    super.key,
  });

  @override
  State<WebFilePicker> createState() => _WebFilePickerState();
}

class _WebFilePickerState extends State<WebFilePicker> {
  late final String _viewId;
  late void Function(List<html.File>) _callback;

  @override
  void initState() {
    super.initState();
    _viewId = 'wfp-${_wfpCounter++}';
    _callback = widget.onRawFiles;

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      final input = html.FileUploadInputElement()
        ..accept = widget.accept
        ..multiple = widget.multiple
        ..style.display = 'none';

      final label = html.LabelElement()
        ..style.display = 'block'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.cursor = 'pointer'
        ..style.margin = '0'
        ..style.padding = '0';
      label.append(input);

      input.onChange.listen((_) {
        final fl = input.files;
        if (fl == null || fl.isEmpty) return;
        _callback(List.generate(fl.length, (i) => fl[i]));
        // Reset so the same file can be re-selected later.
        input.value = '';
      });

      return label;
    });
  }

  @override
  void didUpdateWidget(covariant WebFilePicker old) {
    super.didUpdateWidget(old);
    _callback = widget.onRawFiles;
  }

  /// Programmatic fallback: called from the button's onPressed when the
  /// HtmlElementView label did not intercept the pointer event.
  void _triggerFallback() {
    final input = html.FileUploadInputElement()
      ..accept = widget.accept
      ..multiple = widget.multiple
      ..style.position = 'fixed'
      ..style.top = '-9999px'
      ..style.left = '-9999px'
      ..style.opacity = '0';
    html.document.body!.append(input);
    input.onChange.listen((_) {
      final fl = input.files;
      input.remove();
      if (fl == null || fl.isEmpty) return;
      _callback(List.generate(fl.length, (i) => fl[i]));
    });
    input.click();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(_triggerFallback);
    if (!widget.enabled) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(child: HtmlElementView(viewType: _viewId)),
      ],
    );
  }
}
