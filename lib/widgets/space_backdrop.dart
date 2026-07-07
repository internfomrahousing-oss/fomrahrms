import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A slowly animated deep-blue "space" graphic — nebula glow, a twinkling
/// starfield, a rotating orbit ring and a HUD-style crosshair with telemetry
/// text. Used as the right-hand panel of the login screen. Pure painting, no
/// image assets, so it stays lightweight and scales to any panel size.
class SpaceBackdrop extends StatefulWidget {
  const SpaceBackdrop({super.key});

  @override
  State<SpaceBackdrop> createState() => _SpaceBackdropState();
}

class _SpaceBackdropState extends State<SpaceBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 48))
      ..repeat();
    final rnd = math.Random(7);
    _stars = List.generate(140, (_) => _Star(
      dx: rnd.nextDouble(),
      dy: rnd.nextDouble(),
      radius: 0.6 + rnd.nextDouble() * 1.6,
      phase: rnd.nextDouble() * math.pi * 2,
      speed: 0.6 + rnd.nextDouble() * 1.4,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        color: const Color(0xFF060A14),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            painter: _SpacePainter(t: _ctrl.value, stars: _stars),
            child: const _Telemetry(),
          ),
          child: null,
        ),
      ),
    );
  }
}

class _Star {
  final double dx, dy, radius, phase, speed;
  _Star({required this.dx, required this.dy, required this.radius,
      required this.phase, required this.speed});
}

class _SpacePainter extends CustomPainter {
  final double t; // 0..1, looping
  final List<_Star> stars;
  _SpacePainter({required this.t, required this.stars});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // ── Base gradient — dark navy, brighter toward the lower-right ──────
    final base = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.65, 0.75),
        radius: 1.2,
        colors: [Color(0xFF11315C), Color(0xFF071224), Color(0xFF030612)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), base);

    // ── Soft diagonal nebula band ─────────────────────────────────────
    final bandCenter = Offset(w * 0.62, h * 0.7);
    final band = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3E8EDE).withValues(alpha: 0.28),
          const Color(0xFF1B4E8C).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: bandCenter, radius: w * 0.75))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(bandCenter, w * 0.75, band);

    // ── Twinkling starfield ────────────────────────────────────────────
    for (final s in stars) {
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * s.speed + s.phase));
      final p = Paint()..color = Colors.white.withValues(alpha: twinkle * 0.8);
      canvas.drawCircle(Offset(s.dx * w, s.dy * h), s.radius, p);
    }

    // ── Rotating orbit ring (comet-trail sweep) ───────────────────────
    final ringCenter = Offset(w * 0.5, h * 0.48);
    final ringRadius = math.max(w, h) * 0.62;
    canvas.save();
    canvas.translate(ringCenter.dx, ringCenter.dy);
    canvas.rotate(t * 2 * math.pi);
    final ringRect = Rect.fromCircle(center: Offset.zero, radius: ringRadius);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF7FB3FF).withValues(alpha: 0.55),
          Colors.transparent,
        ],
        stops: const [0.0, 0.12, 0.32],
      ).createShader(ringRect);
    canvas.drawCircle(Offset.zero, ringRadius, ringPaint);
    canvas.restore();

    // Faint static outline of the same ring, for structure even when the
    // bright sweep has rotated away from a given segment.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawCircle(ringCenter, ringRadius, outline);

    // ── HUD crosshair ──────────────────────────────────────────────────
    final crossX = w * 0.58;
    final crossY = h * 0.42;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(crossX, 0), Offset(crossX, h), line);
    canvas.drawLine(Offset(0, crossY), Offset(w, crossY), line);

    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromCenter(center: Offset(crossX, crossY), width: 16, height: 16), bracket);
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => oldDelegate.t != t;
}

/// Small monospace telemetry readout, anchored near the crosshair.
class _Telemetry extends StatelessWidget {
  const _Telemetry();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final crossX = c.maxWidth * 0.58;
      final crossY = c.maxHeight * 0.42;
      final style = GoogleFonts.robotoMono(
          fontSize: 10, color: Colors.white.withValues(alpha: 0.55), height: 1.6);
      return Stack(children: [
        Positioned(
          left: crossX + 14,
          top: crossY - 26,
          child: Text('module:  hrms\nstatus:   online\nteam:     active', style: style),
        ),
      ]);
    });
  }
}
