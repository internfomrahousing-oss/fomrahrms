import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decorative lotus + infinity motif used as a soft background accent on
/// [WelcomeBanner]. Purely presentational — no state, no interaction.
class LotusMotif extends StatelessWidget {
  final double size;
  const LotusMotif({super.key, this.size = 130});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LotusPainter()),
      ),
    );
  }
}

class _LotusPainter extends CustomPainter {
  static const _petalPink   = Color(0xFFE7BFCB);
  static const _petalLilac  = Color(0xFFC9D2EA);
  static const _gold        = Color(0xFFE3C179);

  void _drawPetals(Canvas canvas, Offset origin, double reach, Color color, double opacity) {
    const count = 7;
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final angle = (-130 + t * 260) * math.pi / 180;
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(reach * 0.24, -reach * 0.55, 0, -reach)
        ..quadraticBezierTo(-reach * 0.24, -reach * 0.55, 0, 0)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: opacity));
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w * 0.60, h * 0.50);

    // Sun glow behind the flower.
    final glowCenter = Offset(w * 0.60, h * 0.20);
    canvas.drawCircle(
      glowCenter,
      w * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [_gold.withValues(alpha: 0.30), _gold.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: w * 0.42)),
    );

    // Infinity glyph, top of the flower.
    final infPaint = Paint()
      ..color = _gold.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final infCenter = Offset(w * 0.58, h * 0.12);
    final r = w * 0.042;
    canvas.drawCircle(infCenter.translate(-r, 0), r, infPaint);
    canvas.drawCircle(infCenter.translate(r, 0), r, infPaint);

    // Lotus: two layered rings of petals + a core.
    _drawPetals(canvas, center, w * 0.32, _petalPink, 0.55);
    _drawPetals(canvas, center, w * 0.20, _petalLilac, 0.55);
    canvas.drawCircle(center, w * 0.045, Paint()..color = _gold.withValues(alpha: 0.75));

    // Faint water reflection below the flower.
    canvas.save();
    canvas.translate(0, center.dy * 2 + 6);
    canvas.scale(1, -0.55);
    _drawPetals(canvas, Offset(center.dx, 0), w * 0.28, _petalPink, 0.16);
    canvas.restore();

    // Ripple lines.
    final ripple = Paint()
      ..color = _petalLilac.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 2; i++) {
      final y = center.dy + h * (0.07 + i * 0.06);
      final half = w * (0.26 + i * 0.08);
      canvas.drawLine(Offset(center.dx - half, y), Offset(center.dx + half, y), ripple);
    }
  }

  @override
  bool shouldRepaint(covariant _LotusPainter oldDelegate) => false;
}
