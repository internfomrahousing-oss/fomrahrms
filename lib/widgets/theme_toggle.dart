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
        final bg = isDark
            ? const Color(0xFF1E1E2A).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85);
        final shadow = isDark ? Colors.black38 : Colors.black12;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: shadow, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wb_sunny_rounded, size: 15,
                  color: isDark ? const Color(0xFF546E7A) : Colors.amber.shade500),
              Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: isDark,
                  onChanged: (val) => themeNotifier.setMode(
                    val ? ThemeMode.dark : ThemeMode.light,
                  ),
                  activeColor: const Color(0xFF1A237E),
                  activeTrackColor: const Color(0xFF5C6BC0),
                  inactiveThumbColor: Colors.amber.shade500,
                  inactiveTrackColor: Colors.amber.withValues(alpha: 0.3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Icon(Icons.dark_mode_rounded, size: 15,
                  color: isDark ? const Color(0xFFBBDEFB) : const Color(0xFF90A4AE)),
            ],
          ),
        );
      },
    );
  }
}
