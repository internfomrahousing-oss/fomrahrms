import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A filter that accepts SEVERAL selections rather than one or all.
///
/// The single-value dropdowns could express "everyone", "one department" or
/// "one person" — but not "Ronak, Sijo and Jose". Comparing an arbitrary
/// handful meant looking at each in turn and holding the numbers in your head.
///
/// Selections are shown as removable chips beneath the field, so what is
/// currently included is visible without opening the menu — a count alone
/// ("3 selected") leaves you guessing which three.
class MultiSelectFilterField extends StatelessWidget {
  final String label;

  /// Empty means everyone — the same meaning as "All" on the single-value
  /// dropdowns, so an untouched filter behaves exactly as before.
  final Set<String> selected;
  final List<String> options;
  final String allLabel;
  final ValueChanged<Set<String>> onChanged;
  final IconData icon;

  const MultiSelectFilterField({
    super.key,
    required this.label,
    required this.selected,
    required this.options,
    required this.allLabel,
    required this.onChanged,
    this.icon = Icons.person_outline_rounded,
  });

  Future<void> _open(BuildContext context) async {
    final working = Set<String>.from(selected);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final narrow = MediaQuery.of(ctx).size.width < 520;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
            title: Row(children: [
              Icon(icon, size: 18, color: AppTheme.primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Select $label',
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
              // Clearing means "everyone", which is the more useful default
              // than an empty result showing nothing.
              TextButton(
                onPressed: () => setLocal(working.clear),
                child: const Text('Clear'),
              ),
            ]),
            contentPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            content: SizedBox(
              width: narrow ? double.maxFinite : 420,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                ),
                child: Scrollbar(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final o in options)
                        CheckboxListTile(
                          dense: true,
                          value: working.contains(o),
                          title: Text(o, style: const TextStyle(fontSize: 13.5)),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) => setLocal(() {
                            if (v ?? false) {
                              working.add(o);
                            } else {
                              working.remove(o);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(working),
                child: Text(working.isEmpty
                    ? 'Show everyone'
                    : 'Show ${working.length} selected'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
            ),
            child: Text(
              selected.isEmpty
                  ? allLabel
                  : '${selected.length} selected',
              style: TextStyle(
                fontSize: 13.5,
                color: selected.isEmpty
                    ? Colors.grey.shade600
                    : AppTheme.textPrimary,
                fontWeight: selected.isEmpty ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 6),
          // Names, not just a count: "3 selected" does not say which three,
          // and a filter you cannot read is a filter you stop trusting.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selected
                .map((s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 11.5)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted: () =>
                          onChanged(Set<String>.from(selected)..remove(s)),
                      deleteIconColor: Colors.grey.shade600,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
