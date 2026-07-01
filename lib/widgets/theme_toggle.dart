import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/theme_notifier.dart';

class ThemeToggle extends StatefulWidget {
  const ThemeToggle({super.key});

  @override
  State<ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<ThemeToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: themeNotifier.value == ThemeMode.dark ? 1.0 : 0.0,
    );
    themeNotifier.addListener(_sync);
  }

  void _sync() {
    if (!mounted) return;
    themeNotifier.value == ThemeMode.dark ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_sync);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return Tooltip(
          message: isDark ? 'Switch to Light' : 'Switch to Dark',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => themeNotifier.setMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              ),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final glowColor = Color.lerp(
                    const Color(0xFFFFCA28), // amber — light mode
                    const Color(0xFF90CAF9), // blue  — dark mode
                    _ctrl.value,
                  )!;
                  return _TorchTile(glowColor: glowColor, isDark: isDark);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TorchTile extends StatelessWidget {
  final Color glowColor;
  final bool isDark;
  const _TorchTile({required this.glowColor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: glowColor.withValues(alpha: 0.3), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.5),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.2),
        child: CustomPaint(
          painter: _TorchPainter(glowColor: glowColor),
          child: Align(
            alignment: const Alignment(0, 0.45),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                key: ValueKey(isDark),
                color: glowColor,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TorchPainter extends CustomPainter {
  final Color glowColor;
  const _TorchPainter({required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Icon sits at Alignment(0, 0.45) → y ≈ 72.5% down
    final iconY = size.height * 0.725;
    final arcRadius = size.width * 0.36;

    // Light cone from icon to top edge
    final conePath = Path()
      ..moveTo(cx, iconY)
      ..lineTo(cx - size.width * 0.48, 0)
      ..lineTo(cx + size.width * 0.48, 0)
      ..close();
    final conePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          glowColor.withValues(alpha: 0.24),
          glowColor.withValues(alpha: 0.03),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, iconY));
    canvas.drawPath(conePath, conePaint);

    // Dotted arc above icon (like the iPhone intensity ring)
    final dotPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    const dotCount = 13;
    const startDeg = 205.0;
    const endDeg = 335.0;
    for (int i = 0; i < dotCount; i++) {
      final frac = i / (dotCount - 1);
      final rad = (startDeg + (endDeg - startDeg) * frac) * math.pi / 180;
      final dx = cx + arcRadius * math.cos(rad);
      final dy = iconY + arcRadius * math.sin(rad);
      canvas.drawCircle(Offset(dx, dy), 1.1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TorchPainter old) => old.glowColor != glowColor;
}
