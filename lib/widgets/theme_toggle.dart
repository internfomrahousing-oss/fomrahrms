import 'package:flutter/material.dart';
import '../models/theme_notifier.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        final color = isDark ? const Color(0xFF90CAF9) : const Color(0xFF3B82F6);

        return Tooltip(
          message: isDark ? 'Switch to Light' : 'Switch to Dark',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => themeNotifier.setMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: color.withValues(alpha: 0.4), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.75, end: 1.0).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOut),
                    ),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.star_border_rounded : Icons.star_rounded,
                    key: ValueKey(isDark),
                    color: color,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
