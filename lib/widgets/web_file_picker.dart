// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

int _wfpCounter = 0;

/// File-picker widget for Flutter web.
///
/// Architecture:
///   A persistent <input type="file"> is appended to document.body in initState
///   and removed in dispose(). Because it lives outside Flutter's widget tree it
///   is never inadvertently removed from the DOM while a file-chooser dialog is
///   open, which would silently swallow the 'change' event.
///
///   A transparent <label for="id"> is rendered via HtmlElementView and overlays
///   the Flutter button. Clicking the label activates the body-level input via
///   the native browser for-attribute link — no programmatic .click() is needed,
///   so user-activation is always satisfied.
///
///   Fallback: [builder] receives a [trigger] function. Pass it as onPressed on
///   the child button. If the HtmlElementView label did NOT intercept the pointer
///   (e.g. platform-view hit-testing not active), Flutter calls onPressed →
///   trigger() → _input.click(). Because _input is held in state it is never
///   GC-collected, and the programmatic click runs within the user-gesture window.
class WebFilePicker extends StatefulWidget {
  final String accept;
  final bool multiple;
  final bool enabled;
  final void Function(List<html.File>) onRawFiles;
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
  late final html.FileUploadInputElement _input;

  @override
  void initState() {
    super.initState();
    _viewId   = 'wfp-${_wfpCounter++}';
    _callback = widget.onRawFiles;

    // Persistent body-level input — lives in the DOM until dispose().
    // Using _viewId as the element id links it to the HtmlElementView label.
    _input = html.FileUploadInputElement()
      ..id       = _viewId
      ..accept   = widget.accept
      ..multiple = widget.multiple
      ..style.position = 'fixed'
      ..style.top      = '-9999px'
      ..style.left     = '-9999px'
      ..style.opacity  = '0';
    html.document.body!.append(_input);

    _input.onChange.listen((_) {
      final fl = _input.files;
      if (fl == null || fl.isEmpty) return;
      _callback(List.generate(fl.length, (i) => fl[i]));
      _input.value = ''; // allow re-selecting the same file
    });

    // HtmlElementView: transparent <label for="_viewId"> that activates _input
    // via native browser for-attribute — direct user gesture, no .click() needed.
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      return html.LabelElement()
        ..htmlFor        = _viewId
        ..style.display  = 'block'
        ..style.position = 'absolute'
        ..style.top      = '0'
        ..style.left     = '0'
        ..style.width    = '100%'
        ..style.height   = '100%'
        ..style.cursor   = 'pointer'
        ..style.margin   = '0'
        ..style.padding  = '0';
    });
  }

  @override
  void didUpdateWidget(covariant WebFilePicker old) {
    super.didUpdateWidget(old);
    _callback      = widget.onRawFiles;
    _input.accept  = widget.accept;
    _input.multiple = widget.multiple;
  }

  @override
  void dispose() {
    _input.remove();
    super.dispose();
  }

  /// Fallback: called from the button's onPressed when the HtmlElementView
  /// label did not intercept the pointer event.
  void _triggerFallback() {
    _input.click(); // _input is a field — strong reference, never GC-collected
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
