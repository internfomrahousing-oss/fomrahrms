import 'package:flutter/material.dart';

class HrAttendanceDetailPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> columns;

  const HrAttendanceDetailPage({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            // Search bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search employee...',
                        prefixIcon: Icon(Icons.search_rounded, color: color, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: color, width: 2),
                        ),
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list_rounded, size: 16),
                    label: const Text('Filter'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.table_rows_rounded, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text('$title Records',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(color.withValues(alpha: 0.06)),
                      border: TableBorder.all(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8)),
                      columns: columns
                          .map((c) => DataColumn(
                                label: Text(c,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: color)),
                              ))
                          .toList(),
                      rows: const [],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(children: [
                      Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 6),
                      Text('No records yet',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
