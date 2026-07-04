import 'package:flutter/material.dart';
import 'back_button.dart';

class SectionDetailPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final Map<String, String>? values;

  const SectionDetailPage({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.values,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = isDark ? Color.lerp(color, Colors.white, 0.55)! : color;

    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const NavBackButton(),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: displayColor.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: displayColor, size: 26),
                ),
                const SizedBox(width: 16),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt_rounded, color: displayColor, size: 20),
                        const SizedBox(width: 8),
                        Text('Summary',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...items.map((item) => _ItemRow(
                          label: item,
                          value: values?[item] ?? '—',
                          color: displayColor,
                          isDark: isDark,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _ItemRow({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDark ? Colors.white12 : const Color(0xFFF0F0F0);
    final textColor = isDark
        ? Theme.of(context).colorScheme.onSurface
        : const Color(0xFF37474F);
    final badgeBorder = isDark ? Colors.white24 : const Color(0xFFE0E0E0);
    final dashColor = isDark ? Colors.white54 : Colors.grey.shade500;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: textColor),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeBorder),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dashColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
