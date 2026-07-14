import 'package:flutter/material.dart';

/// A small pill button with a funnel icon that, when tapped, opens a
/// floating popup card listing the filter options (with a checkmark on the
/// current selection). Used for every single-select filter in the app
/// (department, designation, status, priority, manager, sort order, etc.)
/// so every filter looks and behaves the same way.
///
/// Pass [allLabel] to prepend an "All ..." entry that reports back `null`
/// (for nullable list filters). Omit it for non-nullable toggles like sort
/// order, where every option is a real, always-selected value.
class FilterPopupButton<T> extends StatelessWidget {
  final T? value;
  final List<T> options;
  final String Function(T option) labelOf;
  final ValueChanged<T?> onChanged;
  final String? allLabel;
  final IconData icon;
  final String? tooltip;
  final double maxLabelWidth;

  const FilterPopupButton({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.allLabel,
    this.icon = Icons.filter_alt_outlined,
    this.tooltip,
    this.maxLabelWidth = 140,
  });

  static const _border = Color(0xFFE5E7EB);
  static const _label = Color(0xFF374151);
  static const _muted = Color(0xFF6B7280);

  String get _currentLabel =>
      value == null ? (allLabel ?? '') : labelOf(value as T);

  /// A filter reads as "active" (tinted) only when it has a real, non-default
  /// selection — i.e. a nullable list filter with something picked. Toggles
  /// without an [allLabel] (sort order, rows-per-page) are always neutral.
  bool get _isActive => allLabel != null && value != null;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    PopupMenuItem<T?> item(T? v, String text) => PopupMenuItem<T?>(
          value: v,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 18,
              child: value == v ? Icon(Icons.check_rounded, size: 16, color: accent) : null,
            ),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(
                fontWeight: value == v ? FontWeight.w700 : FontWeight.w500,
                color: value == v ? accent : _label)),
          ]),
        );

    return PopupMenuButton<T?>(
      tooltip: tooltip ?? allLabel ?? 'Filter',
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        if (allLabel != null) item(null, allLabel!),
        ...options.map((o) => item(o, labelOf(o))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _isActive ? accent : _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: _isActive ? accent : _muted),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(_currentLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _isActive ? accent : _label)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _isActive ? accent : _muted),
        ]),
      ),
    );
  }
}
