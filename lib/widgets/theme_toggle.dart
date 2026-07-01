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
  final _key = GlobalKey();

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

  void _toggle() {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final ctx = _key.currentContext;
    if (ctx == null) {
      themeNotifier.setMode(isDark ? ThemeMode.light : ThemeMode.dark);
      return;
    }

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) {
      themeNotifier.setMode(isDark ? ThemeMode.light : ThemeMode.dark);
      return;
    }

    // Centre of the toggle button in screen coordinates
    final origin = box.localToGlobal(box.size.center(Offset.zero));

    // Radius needed to cover every corner of the screen
    final screen = MediaQuery.of(ctx).size;
    final maxRadius = [
      Offset.zero,
      Offset(screen.width, 0),
      Offset(0, screen.height),
      Offset(screen.width, screen.height),
    ].map((c) => (c - origin).distance).reduce(math.max);

    // Bubble color = the destination theme's background
    final bubbleColor =
        isDark ? Colors.white : const Color(0xFF12121C);
    final targetMode = isDark ? ThemeMode.light : ThemeMode.dark;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: AbsorbPointer(
          child: _BubbleReveal(
            origin: origin,
            maxRadius: maxRadius,
            color: bubbleColor,
            onComplete: () {
              themeNotifier.setMode(targetMode);
              entry.remove();
            },
          ),
        ),
      ),
    );
    Overlay.of(ctx).insert(entry);
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
              onTap: _toggle,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final glowColor = Color.lerp(
                    const Color(0xFFFFCA28),
                    const Color(0xFF90CAF9),
                    _ctrl.value,
                  )!;
                  return Container(
                    key: _key,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: glowColor.withValues(alpha: 0.3), width: 0.8),
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
                              isDark
                                  ? Icons.dark_mode_rounded
                                  : Icons.wb_sunny_rounded,
                              key: ValueKey(isDark),
                              color: glowColor,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Expanding bubble overlay ──────────────────────────────────────────────────

class _BubbleReveal extends StatefulWidget {
  final Offset origin;
  final double maxRadius;
  final Color color;
  final VoidCallback onComplete;

  const _BubbleReveal({
    required this.origin,
    required this.maxRadius,
    required this.color,
    required this.onComplete,
  });

  @override
  State<_BubbleReveal> createState() => _BubbleRevealState();
}

class _BubbleRevealState extends State<_BubbleReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _radius;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _radius = Tween<double>(begin: 0, end: widget.maxRadius).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _radius,
      builder: (_, __) => CustomPaint(
        painter: _BubblePainter(
          origin: widget.origin,
          radius: _radius.value,
          color: widget.color,
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Offset origin;
  final double radius;
  final Color color;

  const _BubblePainter({
    required this.origin,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    // Solid fill
    canvas.drawCircle(origin, radius, Paint()..color = color);
    // Soft glowing edge so it reads as a "bubble"
    canvas.drawCircle(
      origin,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.radius != radius;
}

// ── iPhone-style torch tile painter ──────────────────────────────────────────

class _TorchPainter extends CustomPainter {
  final Color glowColor;
  const _TorchPainter({required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final iconY = size.height * 0.725;
    final arcRadius = size.width * 0.36;

    // Light cone from icon to top edge
    final conePath = Path()
      ..moveTo(cx, iconY)
      ..lineTo(cx - size.width * 0.48, 0)
      ..lineTo(cx + size.width * 0.48, 0)
      ..close();
    canvas.drawPath(
      conePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            glowColor.withValues(alpha: 0.24),
            glowColor.withValues(alpha: 0.03),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, iconY)),
    );

    // Dotted intensity arc
    final dotPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    const dotCount = 13;
    const startDeg = 205.0;
    const endDeg = 335.0;
    for (int i = 0; i < dotCount; i++) {
      final frac = i / (dotCount - 1);
      final rad = (startDeg + (endDeg - startDeg) * frac) * math.pi / 180;
      canvas.drawCircle(
        Offset(cx + arcRadius * math.cos(rad), iconY + arcRadius * math.sin(rad)),
        1.1,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TorchPainter old) => old.glowColor != glowColor;
}
