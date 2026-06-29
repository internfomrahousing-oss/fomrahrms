import 'package:flutter/material.dart';
import '../models/theme_notifier.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.settings_rounded, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Text('Settings',
                      style: Theme.of(context).textTheme.headlineMedium),
                ]),
                const SizedBox(height: 28),

                // ── Appearance ──────────────────────────────────────────
                _SectionLabel('Appearance', Icons.palette_rounded, cs.primary),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E2E4A)
                          : const Color(0xFFE8EAF6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('Choose how FOMRA HRMS looks for you.',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                          child: _ThemeCard(
                            label: 'Light',
                            icon: Icons.light_mode_rounded,
                            selected: !isDark,
                            previewBg: const Color(0xFFF5F7FA),
                            previewCard: Colors.white,
                            previewText: const Color(0xFF0D47A1),
                            onTap: () {
                              themeNotifier.setMode(ThemeMode.light);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ThemeCard(
                            label: 'Dark',
                            icon: Icons.dark_mode_rounded,
                            selected: isDark,
                            previewBg: const Color(0xFF12121C),
                            previewCard: const Color(0xFF252535),
                            previewText: const Color(0xFF90CAF9),
                            onTap: () {
                              themeNotifier.setMode(ThemeMode.dark);
                              setState(() {});
                            },
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color previewBg;
  final Color previewCard;
  final Color previewText;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.previewBg,
    required this.previewCard,
    required this.previewText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : const Color(0xFF9E9EB8),
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          // Mini preview
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: previewBg,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              // Fake header bar
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: previewText.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 6),
              // Fake card
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: previewCard,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: previewText.withValues(alpha: 0.15),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 10,
                width: 60,
                decoration: BoxDecoration(
                  color: previewCard,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: previewText.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          // Label row
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16,
                color: selected ? cs.primary : const Color(0xFF9E9EB8)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.primary : const Color(0xFF9E9EB8),
                )),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle_rounded, size: 14, color: cs.primary),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionLabel(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700)),
      const SizedBox(width: 12),
      const Expanded(child: Divider()),
    ]);
  }
}
