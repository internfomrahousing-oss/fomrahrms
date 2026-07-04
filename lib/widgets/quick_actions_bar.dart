import 'package:flutter/material.dart';

class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key});

  void _show(BuildContext context, String title, IconData icon) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(icon, size: 48, color: const Color(0xFF1565C0)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Coming soon', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFF0A1F6B),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(children: [
        _QBtn(Icons.campaign_rounded,     'Announcements',       () => _show(context, 'Announcements',       Icons.campaign_rounded)),
        _QBtn(Icons.event_rounded,        'Holidays',            () => _show(context, 'Holidays This Year',  Icons.event_rounded)),
        _QBtn(Icons.emoji_events_rounded, 'Employee of Month',   () => _show(context, 'Employee of the Month', Icons.emoji_events_rounded)),
        _QBtn(Icons.cake_rounded,         'Birthdays',           () => _show(context, 'Birthdays This Month', Icons.cake_rounded)),
      ]),
    );
  }
}

class _QBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QBtn(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 9)),
        ]),
      ),
    );
  }
}

/// Four icon buttons for the wide top bar (icon-only with tooltips).
class QuickActionIcons extends StatelessWidget {
  const QuickActionIcons({super.key});

  void _show(BuildContext context, String title, IconData icon) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(icon, size: 48, color: const Color(0xFF1565C0)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Coming soon', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _btn(BuildContext context, IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _btn(context, Icons.campaign_rounded,     'Announcements',          () => _show(context, 'Announcements',          Icons.campaign_rounded)),
      const SizedBox(width: 6),
      _btn(context, Icons.event_rounded,        'Holidays This Year',     () => _show(context, 'Holidays This Year',     Icons.event_rounded)),
      const SizedBox(width: 6),
      _btn(context, Icons.emoji_events_rounded, 'Employee of the Month',  () => _show(context, 'Employee of the Month',  Icons.emoji_events_rounded)),
      const SizedBox(width: 6),
      _btn(context, Icons.cake_rounded,         'Birthdays This Month',   () => _show(context, 'Birthdays This Month',   Icons.cake_rounded)),
    ]);
  }
}
