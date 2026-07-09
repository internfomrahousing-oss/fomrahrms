import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

/// Cross-platform file-picker trigger — replaces the old web-only
/// WebFilePicker (dart:html `<input type="file">` + label overlay trick).
/// [accept] uses the same comma-separated MIME/extension shorthand the old
/// widget took (e.g. 'image/*,.pdf,.doc,.docx,.xls,.xlsx').
/// [builder] receives a callback to invoke the OS file picker — pass it as
/// onPressed on the child button.
class AppFilePicker extends StatelessWidget {
  final String accept;
  final bool multiple;
  final bool enabled;
  final void Function(List<PlatformFile>) onFiles;
  final Widget Function(VoidCallback trigger) builder;

  const AppFilePicker({
    required this.accept,
    required this.builder,
    required this.onFiles,
    this.multiple = false,
    this.enabled = true,
    super.key,
  });

  static const _imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'];

  List<String> _extensions() {
    final out = <String>[];
    for (final part in accept.split(',')) {
      final p = part.trim();
      if (p == 'image/*') {
        out.addAll(_imageExtensions);
      } else if (p.startsWith('.')) {
        out.add(p.substring(1));
      }
    }
    return out;
  }

  Future<void> _trigger() async {
    final extensions = _extensions();
    final result = await FilePicker.platform.pickFiles(
      type: extensions.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: extensions.isEmpty ? null : extensions,
      allowMultiple: multiple,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    onFiles(result.files);
  }

  @override
  Widget build(BuildContext context) {
    final child = builder(_trigger);
    return enabled ? child : IgnorePointer(child: child);
  }
}
