import 'package:flutter/material.dart';
import 'back_button.dart';

class FormField {
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLines;

  const FormField({
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });
}

class FormDetailPage extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<FormField> fields;
  final void Function(List<String> values)? onSave;
  final List<String>? initialValues;

  const FormDetailPage({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.fields,
    this.onSave,
    this.initialValues,
  });

  @override
  State<FormDetailPage> createState() => _FormDetailPageState();
}

class _FormDetailPageState extends State<FormDetailPage> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.fields.length, (i) {
      final initial =
          (widget.initialValues != null && i < widget.initialValues!.length)
              ? widget.initialValues![i]
              : '';
      return TextEditingController(text: initial);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSave() {
    final values = _controllers.map((c) => c.text.trim()).toList();
    widget.onSave?.call(values);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Saved successfully'),
        backgroundColor: widget.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _onClear() {
    for (final c in _controllers) {
      c.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = isDark
        ? Color.lerp(widget.color, Colors.white, 0.55)!
        : widget.color;

    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const NavBackButton(),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: displayColor.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: displayColor, size: 26),
                ),
                const SizedBox(width: 16),
                Text(widget.title,
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...List.generate(widget.fields.length, (i) {
                      final field = widget.fields[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: TextField(
                          controller: _controllers[i],
                          keyboardType: field.keyboardType,
                          maxLines: field.maxLines,
                          decoration: InputDecoration(
                            labelText: field.label,
                            prefixIcon: Icon(field.icon,
                                color: displayColor, size: 20),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: displayColor, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _onClear,
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _onSave,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
