import 'package:flutter/material.dart';

const _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String monthLabel(DateTime d) => '${_kMonths[d.month - 1]} ${d.year}';

Future<DateTime?> showMonthPicker(BuildContext context, DateTime? current) {
  int year = current?.year ?? DateTime.now().year;

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setLocal(() => year--),
          ),
          Expanded(
            child: Text(
              '$year',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => setLocal(() => year++),
          ),
        ]),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 2.2,
            children: List.generate(12, (i) {
              final m = i + 1;
              final isSelected = current != null &&
                  current.month == m &&
                  current.year == year;
              return TextButton(
                onPressed: () => Navigator.pop(ctx, DateTime(year, m)),
                style: TextButton.styleFrom(
                  backgroundColor: isSelected
                      ? Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.15)
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  _kMonths[i],
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        isSelected ? Theme.of(ctx).colorScheme.primary : null,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
