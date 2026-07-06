import 'package:flutter/material.dart';
import '../models/color_theme_notifier.dart';
import 'dashboard_info_blocks.dart';

/// Management-only control: picks the app's active color theme. The choice is
/// persisted globally (Supabase `app_settings`), so every role's dashboard
/// picks it up — immediately for this session, on next load for others.
class ThemePickerBlock extends StatelessWidget {
  const ThemePickerBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: colorThemeNotifier,
      builder: (context, _) => InfoCard(
        icon: Icons.palette_rounded,
        title: 'App Theme',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppColorTheme.values.map((t) {
            return _ThemeSwatch(
              tokens: kColorThemes[t]!,
              selected: colorThemeNotifier.value == t,
              onTap: () => colorThemeNotifier.setTheme(t),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final ColorThemeTokens tokens;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatch({
    required this.tokens,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 112,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? tokens.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? tokens.primary : cs.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(color: tokens.primary, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(color: tokens.accent, shape: BoxShape.circle),
              ),
              const Spacer(),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 16, color: tokens.primary),
            ]),
            const SizedBox(height: 8),
            Text(tokens.label,
                maxLines: 2,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}
