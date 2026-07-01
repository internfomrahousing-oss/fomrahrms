import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmployeeAttendancePage extends StatelessWidget {
  /// Route prefix: '/employee', '/manager', or '' (HR uses root-level routes).
  final String prefix;
  const EmployeeAttendancePage({super.key, this.prefix = '/employee'});

  List<_Topic> get _topics => [
    _Topic('Check In',    Icons.login_rounded,       const Color(0xFF0D47A1), '$prefix/attendance/check-in'),
    _Topic('Check Out',   Icons.logout_rounded,      const Color(0xFF1565C0), '$prefix/attendance/check-out'),
    _Topic('Late Coming', Icons.watch_later_rounded, const Color(0xFF283593), '$prefix/attendance/late-coming'),
  ];

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
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.access_time_rounded,
                    color: Color(0xFF0D47A1), size: 22),
              ),
              const SizedBox(width: 14),
              Text('My Attendance',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 600 ? 4 : 2;
              final rows = <Widget>[];
              for (int i = 0; i < _topics.length; i += cols) {
                final end = (i + cols) > _topics.length ? _topics.length : i + cols;
                final rowItems = _topics.sublist(i, end);
                rows.add(Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rowItems.map((t) {
                    final isLast = rowItems.last == t;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: isLast ? 0 : 12, bottom: 12),
                        child: _TopicCard(topic: t),
                      ),
                    );
                  }).toList(),
                ));
              }
              return Column(children: rows);
            }),
          ],
        ),
      ),
    );
  }
}

class _Topic {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Topic(this.title, this.icon, this.color, this.route);
}

class _TopicCard extends StatelessWidget {
  final _Topic topic;
  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(topic.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: topic.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(topic.icon, color: topic.color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(topic.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF1A237E))),
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: topic.color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
