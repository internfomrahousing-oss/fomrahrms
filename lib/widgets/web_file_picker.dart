// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

int _wfpCounter = 0;

/// Overlays a transparent HTML <label> (containing a hidden <input type="file">)
/// on top of [child].
///
/// The browser treats a click on a <label> that owns a <input type="file"> as
/// a direct user gesture, satisfying the user-activation requirement on Chrome,
/// Safari, Firefox, Edge, iOS and Android — no programmatic .click() needed.
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
  late void Function(List<html.File>) _callback;

  @override
  void initState() {
    super.initState();
    _viewId = 'wfp-${_wfpCounter++}';
    _callback = widget.onRawFiles;

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      // Hidden file input — the label click triggers it without any .click() call.
      final input = html.FileUploadInputElement()
        ..accept = widget.accept
        ..multiple = widget.multiple
        ..style.display = 'none';

      // Label fills the entire platform-view slot and acts as the click target.
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
      });

      return label;
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
