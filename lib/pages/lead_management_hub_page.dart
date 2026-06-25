import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LeadManagementHubPage extends StatelessWidget {
  /// Route to push when a source card is tapped.
  /// e.g. '/lead-management/meta-leads' or '/manager/lead-management/meta-leads'
  final String leadsRoute;

  const LeadManagementHubPage({super.key, required this.leadsRoute});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.leaderboard_rounded,
                    color: Color(0xFF0D47A1), size: 26),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Lead Management',
                    style: Theme.of(context).textTheme.headlineMedium),
                const Text('Select a lead source',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
              ]),
            ]),
            const SizedBox(height: 32),

            // Source cards grid
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 600 ? 3 : 2;
              return _SourceGrid(
                sources: [
                  _Source(
                    title: 'Meta Leads',
                    subtitle: 'Facebook & Instagram leads',
                    icon: Icons.campaign_rounded,
                    color: const Color(0xFF1877F2),
                    route: leadsRoute,
                  ),
                ],
                cols: cols,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Source {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  const _Source({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _SourceGrid extends StatelessWidget {
  final List<_Source> sources;
  final int cols;
  const _SourceGrid({required this.sources, required this.cols});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < sources.length; i += cols) {
      final end = (i + cols) > sources.length ? sources.length : i + cols;
      final rowItems = sources.sublist(i, end);
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rowItems.map((s) {
            final isLast = rowItems.last == s;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 16, bottom: 16),
                child: _SourceCard(source: s),
              ),
            );
          }),
          // Fill remaining columns with invisible spacers
          ...List.generate(cols - rowItems.length,
              (_) => const Expanded(child: SizedBox())),
        ],
      ));
    }
    return Column(children: rows);
  }
}

class _SourceCard extends StatelessWidget {
  final _Source source;
  const _SourceCard({required this.source});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(source.route),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: source.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(source.icon, color: source.color, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                source.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                source.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF78909C)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: source.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('View Leads',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: source.color)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: source.color),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
