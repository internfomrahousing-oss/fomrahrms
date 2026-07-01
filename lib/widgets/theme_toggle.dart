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
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wb_sunny_rounded,
              size: 15,
              color: isDark
                  ? const Color(0xFF546E7A)
                  : Colors.amber.shade400,
            ),
            Transform.scale(
              scale: 0.85,
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
            Icon(
              Icons.dark_mode_rounded,
              size: 15,
              color: isDark
                  ? const Color(0xFFBBDEFB)
                  : const Color(0xFF546E7A),
            ),
          ],
        );
      },
    );
  }
}
