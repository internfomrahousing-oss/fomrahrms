import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ManagementLeavePage extends StatelessWidget {
  const ManagementLeavePage({super.key});

  static const _color = Color(0xFF283593);

  static const _topics = [
    _Topic(
      'Leave Management',
      Icons.folder_shared_rounded,
      Color(0xFF0D47A1),
      '/management/leave/overview',
      'All employee leaves — approve, deny, or edit any decision company-wide.',
    ),
    _Topic(
      'Team Leave Approvals',
      Icons.group_rounded,
      Color(0xFF283593),
      '/management/leave/team-approvals',
      'Leave requests from employees reporting directly to you.',
    ),
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
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.beach_access_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Leave Management',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.8,
              children: _topics.map((t) => _TopicCard(topic: t)).toList(),
            ),
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
  final String subtitle;
  const _Topic(this.title, this.icon, this.color, this.route, this.subtitle);
}

class _TopicCard extends StatelessWidget {
  final _Topic topic;
  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(topic.route),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: topic.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(topic.icon, color: topic.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(topic.title,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: topic.color)),
                const SizedBox(height: 3),
                Text(topic.subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: topic.color.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
  }
}
