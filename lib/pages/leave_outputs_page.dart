import 'package:flutter/material.dart';

class LeaveOutputsPage extends StatelessWidget {
  const LeaveOutputsPage({super.key});

  static const _color = Color(0xFF0288D1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.output_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Outputs', style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            // Leave Records
            _OutputCard(
              title: 'Leave Records',
              icon: Icons.folder_rounded,
              color: _color,
              subtitle: 'Leaves Taken',
              columns: const ['Employee', 'Leave Type', 'From', 'To', 'Days', 'Status'],
            ),
            const SizedBox(height: 16),

            // Leave Reports
            _OutputCard(
              title: 'Leave Reports',
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF0D47A1),
              subtitle: 'Applied Leave Data',
              columns: const ['Applied On', 'Leave Type', 'No. of Days', 'Reason', 'Manager', 'HR'],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;
  final List<String> columns;

  const _OutputCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ]),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Table header
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(color.withValues(alpha: 0.06)),
              dataRowColor: WidgetStateProperty.all(Colors.white),
              border: TableBorder.all(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
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
          const SizedBox(height: 12),
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
    );
  }
}
