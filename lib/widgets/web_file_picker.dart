// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

int _wfpCounter = 0;

/// Overlays a transparent HTML <input type="file"> on top of [child].
///
/// The user's tap goes directly to the native HTML element, so the browser's
/// user-activation requirement is satisfied on every browser — Chrome, Safari,
/// Firefox, Edge, iOS, and Android — without any programmatic .click().
class WebFilePicker extends StatefulWidget {
  final String accept;
  final bool multiple;
  final bool enabled;
  final Widget child;
  final void Function(List<html.File>) onRawFiles;

  const WebFilePicker({
    required this.accept,
    required this.child,
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
  // Mutable so didUpdateWidget keeps the callback fresh without re-registering.
  late void Function(List<html.File>) _callback;

  @override
  void initState() {
    super.initState();
    _viewId = 'wfp-${_wfpCounter++}';
    _callback = widget.onRawFiles;

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      final el = html.FileUploadInputElement()
        ..accept = widget.accept
        ..multiple = widget.multiple
        ..style.cssText =
            'position:absolute;inset:0;width:100%;height:100%;'
            'opacity:0;cursor:pointer;margin:0;padding:0;border:0;';
      el.onChange.listen((_) {
        final fl = el.files;
        if (fl == null || fl.isEmpty) return;
        _callback(List.generate(fl.length, (i) => fl[i]));
      });
      return el;
    });
  }

  @override
  void didUpdateWidget(covariant WebFilePicker old) {
    super.didUpdateWidget(old);
    _callback = widget.onRawFiles;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(child: HtmlElementView(viewType: _viewId)),
      ],
    );
  }
}
