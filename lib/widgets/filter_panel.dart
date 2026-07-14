import 'package:flutter/material.dart';

const _accent = Color(0xFF2563EB);
const _border = Color(0xFFD1D5DB);
const _labelColor = Color(0xFF111827);
const _mutedColor = Color(0xFF6B7280);

/// Opens a right-anchored slide-in panel that lists every filter for a page
/// together, with a single sticky "Apply" button at the bottom. Selections
/// made inside [builder] are staged (via the given [StateSetter]) and only
/// take effect on the page once "Apply" is tapped and [onApply] runs.
Future<void> showFilterPanel(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, StateSetter setPanelState) builder,
  required VoidCallback onApply,
  VoidCallback? onReset,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) {
      final width = MediaQuery.of(context).size.width;
      final panelWidth = width < 480 ? width : (width * 0.34).clamp(340, 440).toDouble();
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          elevation: 8,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: SafeArea(
              child: StatefulBuilder(builder: (context, setPanelState) {
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(children: [
                      const Icon(Icons.tune_rounded, size: 20, color: _accent),
                      const SizedBox(width: 8),
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _labelColor)),
                      const Spacer(),
                      if (onReset != null)
                        TextButton(
                          onPressed: () { onReset(); setPanelState(() {}); },
                          child: const Text('Reset'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: builder(context, setPanelState),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () { onApply(); Navigator.of(context).pop(); },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

/// A single "Label / All X ▾" field inside a [showFilterPanel] body.
/// Tapping opens a small popup list; the current pick is highlighted and,
/// when non-null, tints the field's border and text to the accent color.
class FilterDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> options;
  final String Function(T option) labelOf;
  final String allLabel;
  final ValueChanged<T?> onChanged;

  const FilterDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.allLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: _mutedColor, fontWeight: FontWeight.w600)),
        ),
        PopupMenuButton<T?>(
          initialValue: value,
          onSelected: onChanged,
          constraints: const BoxConstraints(minWidth: 220),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => [
            PopupMenuItem<T?>(
              value: null,
              child: Text(allLabel, style: TextStyle(
                  fontWeight: value == null ? FontWeight.w700 : FontWeight.w500,
                  color: value == null ? _accent : _labelColor)),
            ),
            ...options.map((o) => PopupMenuItem<T?>(
                  value: o,
                  child: Text(labelOf(o), style: TextStyle(
                      fontWeight: o == value ? FontWeight.w700 : FontWeight.w500,
                      color: o == value ? _accent : _labelColor)),
                )),
          ],
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: value != null ? _accent : _border),
            ),
            child: Row(children: [
              Expanded(
                child: Text(value == null ? allLabel : labelOf(value as T),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: value != null ? _accent : _labelColor)),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: value != null ? _accent : _mutedColor),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// A row of single-select toggle chips inside a [showFilterPanel] body
/// (e.g. the "Stage" row in the reference design). Tapping the already
/// selected chip clears it back to "no filter".
class FilterChipGroup<T> extends StatelessWidget {
  final String? label;
  final T? value;
  final List<T> options;
  final String Function(T option) labelOf;
  final ValueChanged<T?> onChanged;

  const FilterChipGroup({
    super.key,
    this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(label!,
                style: const TextStyle(fontSize: 12, color: _mutedColor, fontWeight: FontWeight.w600)),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
          final selected = o == value;
          return GestureDetector(
            onTap: () => onChanged(selected ? null : o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? _accent : _border),
              ),
              child: Text(labelOf(o),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : _labelColor)),
            ),
          );
        }).toList()),
      ]),
    );
  }
}

/// The single "Filters" trigger button that opens a [showFilterPanel],
/// replacing whatever per-filter controls a page used to scatter in its
/// toolbar. Shows a small dot badge when [hasActiveFilters] is true.
class FilterTriggerButton extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onTap;
  const FilterTriggerButton({super.key, required this.hasActiveFilters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hasActiveFilters ? _accent : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.tune_rounded, size: 16, color: hasActiveFilters ? _accent : _mutedColor),
            const SizedBox(width: 6),
            Text('Filters',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: hasActiveFilters ? _accent : _labelColor)),
          ]),
        ),
      ),
      if (hasActiveFilters)
        Positioned(
          top: -3, right: -3,
          child: Container(
            width: 9, height: 9,
            decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
          ),
        ),
    ]);
  }
}
