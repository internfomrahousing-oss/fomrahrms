import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmployeeListItem {
  final String name;
  final String subtitle;
  const EmployeeListItem({required this.name, this.subtitle = ''});
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
  showDialog(
    context: context,
    builder: (dlgCtx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppTheme.cardHeading)),
                Text('${items.length}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
              ]),
              const SizedBox(height: 16),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text(emptyLabel,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
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
                        ]),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
