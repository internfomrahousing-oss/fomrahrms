import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/back_button.dart';

class AttendanceManagementPage extends StatelessWidget {
  const AttendanceManagementPage({super.key});

  static const _topics = [
    _Topic('Check In',         Icons.login_rounded,      Color(0xFF0D47A1), '/attendance/hr/check-in'),
    _Topic('Check Out',        Icons.logout_rounded,     Color(0xFF1565C0), '/attendance/hr/check-out'),
    _Topic('Late Coming',      Icons.watch_later_rounded, Color(0xFF283593), '/attendance/hr/late-coming'),
    _Topic('Employee Records', Icons.people_alt_rounded,  Color(0xFF1E88E5), '/attendance/employee-records'),
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
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.access_time_rounded,
                    color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Text('Attendance Management',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 20),
            _TopicGrid(topics: _topics),
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

class _TopicGrid extends StatelessWidget {
  final List<_Topic> topics;
  const _TopicGrid({required this.topics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 700 ? 5 : constraints.maxWidth > 400 ? 3 : 2;
      final rows = <Widget>[];
      for (int i = 0; i < topics.length; i += cols) {
        final end = (i + cols) > topics.length ? topics.length : i + cols;
        final rowItems = topics.sublist(i, end);
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
    });
  }
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
              Text(
                topic.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
              ),
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
