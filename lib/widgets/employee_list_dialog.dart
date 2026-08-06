import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmployeeListItem {
  final String name;
  final String subtitle;
  // Optional classification used to power the filter chips in the popup —
  // 'Office'/'Onsite' and 'FOMRA Developers'/'FOMRA Housing'. Leave blank
  // when a caller doesn't have this data; chips only show up when at least
  // two distinct non-blank values exist across the list.
  final String workLocation;
  final String businessUnit;

  /// Opens this person's profile. Null when the caller could not resolve the
  /// name to an employee record — attendance and leave rows store the NAME,
  /// not the id, so a renamed or removed employee will not match. The row is
  /// then shown plainly, with no chevron: a row that looks tappable and does
  /// nothing is worse than one that plainly is not.
  final VoidCallback? onTap;

  const EmployeeListItem({
    required this.name,
    this.subtitle = '',
    this.onTap,
    this.workLocation = '',
    this.businessUnit = '',
  });
}

// Compact popup listing employee names for a dashboard stat card tap
// (e.g. Total Employees / Present Today / Absent Today) — read-only, no
// data fetching of its own, just renders whatever the caller already has.
void showEmployeeListDialog(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Color color,
  required List<EmployeeListItem> items,
  String emptyLabel = 'No employees to show',
}) {
  // Only offer a filter row for a dimension when the list actually has 2+
  // distinct non-blank values for it — otherwise it'd just be noise.
  final locations = items.map((e) => e.workLocation).where((v) => v.isNotEmpty).toSet().toList()..sort();
  final units = items.map((e) => e.businessUnit).where((v) => v.isNotEmpty).toSet().toList()..sort();

  showDialog(
    context: context,
    builder: (dlgCtx) => _EmployeeListDialogBody(
      title: title,
      icon: icon,
      color: color,
      items: items,
      emptyLabel: emptyLabel,
      locations: locations,
      units: units,
    ),
  );
}

class _EmployeeListDialogBody extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<EmployeeListItem> items;
  final String emptyLabel;
  final List<String> locations;
  final List<String> units;
  const _EmployeeListDialogBody({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.emptyLabel,
    required this.locations,
    required this.units,
  });

  @override
  State<_EmployeeListDialogBody> createState() => _EmployeeListDialogBodyState();
}

class _EmployeeListDialogBodyState extends State<_EmployeeListDialogBody> {
  String? _locationFilter;
  String? _unitFilter;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((e) {
      if (_locationFilter != null && e.workLocation != _locationFilter) return false;
      if (_unitFilter != null && e.businessUnit != _unitFilter) return false;
      return true;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.title, style: AppTheme.cardHeading)),
                Text('${filtered.length}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget.color)),
              ]),
              if (widget.locations.length > 1 || widget.units.length > 1) ...[
                const SizedBox(height: 14),
                if (widget.locations.length > 1)
                  _FilterChipRow(
                    options: widget.locations,
                    selected: _locationFilter,
                    color: widget.color,
                    onChanged: (v) => setState(() => _locationFilter = v),
                  ),
                if (widget.locations.length > 1 && widget.units.length > 1) const SizedBox(height: 8),
                if (widget.units.length > 1)
                  _FilterChipRow(
                    options: widget.units,
                    selected: _unitFilter,
                    color: widget.color,
                    onChanged: (v) => setState(() => _unitFilter = v),
                  ),
              ],
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text(widget.items.isEmpty ? widget.emptyLabel : 'No employees match this filter',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final row = Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: widget.color.withValues(alpha: 0.12),
                            child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.color)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                if (item.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(item.subtitle,
                                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                                ],
                              ],
                            ),
                          ),
                          if (item.onTap != null)
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: AppTheme.textSecondary),
                        ]),
                      );
                      if (item.onTap == null) return row;
                      return InkWell(
                        // Close the list first, so the profile is not stacked
                        // on top of it and back returns to the page rather
                        // than to a list the user has finished with.
                        onTap: () {
                          Navigator.pop(context);
                          item.onTap!();
                        },
                        child: row,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final Color color;
  final ValueChanged<String?> onChanged;
  const _FilterChipRow({
    required this.options,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final opt in ['All', ...options]) ...[
          _chip(opt == 'All' ? selected == null : selected == opt, opt,
              () => onChanged(opt == 'All' ? null : opt)),
          const SizedBox(width: 6),
        ],
      ]),
    );
  }

  Widget _chip(bool active, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: active ? color : AppTheme.borderSubtle),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? color : AppTheme.textSecondary)),
      ),
    );
  }
}
