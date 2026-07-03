import 'package:flutter/material.dart';

const _announcementColor = Color(0xFF6A1B9A);
const _holidayColor      = Color(0xFF6A1B9A);
const _birthdayColor     = Color(0xFF6A1B9A);
const _emptyColor        = Color(0xFF6A1B9A);

// ── Public widget ─────────────────────────────────────────────────────────────
class DashboardInfoBlocks extends StatelessWidget {
  const DashboardInfoBlocks({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 700;
      if (wide) {
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Expanded(child: _AnnouncementsBlock()),
            const SizedBox(width: 12),
            const Expanded(child: _HolidaysBlock()),
            const SizedBox(width: 12),
            const Expanded(child: _EmptyBlock()),
            const SizedBox(width: 12),
            const Expanded(child: _BirthdaysBlock()),
          ]),
        );
      } else {
        return const Column(children: [
          _AnnouncementsBlock(),
          SizedBox(height: 12),
          _HolidaysBlock(),
          SizedBox(height: 12),
          _EmptyBlock(),
          SizedBox(height: 12),
          _BirthdaysBlock(),
        ]);
      }
    });
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final Widget child;
  const _InfoCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.18), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Announcements ─────────────────────────────────────────────────────────────
class _AnnouncementsBlock extends StatefulWidget {
  const _AnnouncementsBlock();

  @override
  State<_AnnouncementsBlock> createState() => _AnnouncementsBlockState();
}

class _AnnouncementsBlockState extends State<_AnnouncementsBlock> {
  static const List<List<String>> _items = [
    ['27 Jan', 'The office will remain closed on June 28 due to a public holiday.'],
    ['27 Jan', 'New onboarding session for recently hired employees will take place on June 18 at 10:00 AM.'],
    ['27 Jan', 'Ahmed Khan submitted a leave request.'],
    ['27 Jan', 'Updated attendance policy effective from next month.'],
  ];

  int? _expanded;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      color: _announcementColor,
      icon: Icons.campaign_rounded,
      title: 'Announcements',
      child: Column(
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final isExpanded = _expanded == i;
          return _AnnouncementTile(
            date: item[0],
            text: item[1],
            expanded: isExpanded,
            onTap: () => setState(() => _expanded = isExpanded ? null : i),
          );
        }),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final String date;
  final String text;
  final bool expanded;
  final VoidCallback onTap;
  const _AnnouncementTile({
    required this.date,
    required this.text,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _announcementColor)),
                    const SizedBox(height: 2),
                    Text(text,
                        maxLines: expanded ? null : 1,
                        overflow: expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ]),
          ),
        ),
        Divider(height: 1, color: _announcementColor.withValues(alpha: 0.12)),
      ],
    );
  }
}

// ── Holidays ──────────────────────────────────────────────────────────────────
class _HolidaysBlock extends StatelessWidget {
  const _HolidaysBlock();

  static const List<List<String>> _holidays = [
    ['26 Jan', 'Republic Day'],
    ['14 Apr', 'Dr. Ambedkar Jayanti'],
    ['18 Apr', 'Good Friday'],
    ['21 Apr', 'Ram Navami'],
    ['12 May', 'Buddha Purnima'],
    ['27 Aug', 'Janmashtami'],
    ['02 Oct', 'Gandhi Jayanti'],
    ['02 Oct', 'Dussehra'],
    ['20 Nov', 'Diwali'],
    ['25 Dec', 'Christmas Day'],
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _InfoCard(
      color: _holidayColor,
      icon: Icons.event_rounded,
      title: 'Holidays This Year',
      child: Column(
        children: _holidays.map((h) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _holidayColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(h[0],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _holidayColor)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(h[1],
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.8))),
            ),
          ]),
        )).toList(),
      ),
    );
  }
}

// ── Birthdays ─────────────────────────────────────────────────────────────────
class _BirthdaysBlock extends StatelessWidget {
  const _BirthdaysBlock();

  static const List<List<String>> _birthdays = [
    ['Saba Shuaib',    '01 June', 'SS'],
    ['Idrees Majid',   '06 June', 'IM'],
    ['Abdul Hannan',   '17 June', 'AH'],
    ['Muhammad Hamza', '26 June', 'MH'],
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _InfoCard(
      color: _birthdayColor,
      icon: Icons.cake_rounded,
      title: 'Birthdays This Month',
      child: Column(
        children: _birthdays.map((b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _birthdayColor.withValues(alpha: 0.18),
              child: Text(b[2],
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _birthdayColor)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(b[0],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface)),
            ),
            Text(b[1],
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5))),
          ]),
        )).toList(),
      ),
    );
  }
}

// ── Empty block ───────────────────────────────────────────────────────────────
class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _InfoCard(
      color: _emptyColor,
      icon: Icons.widgets_rounded,
      title: 'Coming Soon',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.construction_rounded,
                size: 42,
                color: _emptyColor.withValues(alpha: 0.3)),
            const SizedBox(height: 10),
            Text('More features coming soon',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.38))),
          ]),
        ),
      ),
    );
  }
}
