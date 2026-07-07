import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Recreation of the FOMRA wordmark (bold "FOMRA" + a blue swoosh accent)
/// with the "HOUSING & INFRASTRUCTURE PVT. LTD." caption underneath — drawn
/// with text + a CustomPainter rather than a bundled image, so it stays
/// crisp at any size and needs no asset file.
class FomraLogoMark extends StatelessWidget {
  final double wordmarkSize;
  final bool showCaption;
  const FomraLogoMark({super.key, this.wordmarkSize = 56, this.showCaption = true});

  @override
  Widget build(BuildContext context) {
    final swooshSize = wordmarkSize * 0.78;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        Text('FOMRA',
            style: GoogleFonts.inter(
                fontSize: wordmarkSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF161616),
                letterSpacing: -1.2,
                height: 1)),
        Positioned(
          right: -swooshSize * 0.5,
          top: -swooshSize * 0.36,
          child: IgnorePointer(
            child: CustomPaint(
              size: Size(swooshSize, swooshSize),
              painter: _SwooshPainter(),
            ),
          ),
        ),
      ]),
      if (showCaption) ...[
        SizedBox(height: wordmarkSize * 0.16),
        Text('HOUSING & INFRASTRUCTURE PVT. LTD.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: wordmarkSize * 0.155,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2B2B2B),
                letterSpacing: wordmarkSize * 0.012)),
      ],
    ]);
  }
}

// A tapered wing/flame silhouette — wide at the base, curling up to a point
// — rather than a uniform-width stroked arc, so it reads as a deliberate
// mark instead of a stray comma.
class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    final path = Path()
      ..moveTo(w * 0.20, h * 0.94)
      ..cubicTo(w * 0.02, h * 0.58, w * 0.22, h * 0.10, w * 0.86, h * 0.02)
      ..cubicTo(w * 0.52, h * 0.14, w * 0.28, h * 0.40, w * 0.40, h * 0.70)
      ..cubicTo(w * 0.44, h * 0.80, w * 0.32, h * 0.88, w * 0.20, h * 0.94)
      ..close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF0B6AB3), Color(0xFF4FC3F0)],
      ).createShader(rect);
    canvas.drawPath(path, fill);

    // Thin light gap near the base, echoing the ribbon-fold in the real mark.
    final gap = Path()
      ..moveTo(w * 0.30, h * 0.80)
      ..cubicTo(w * 0.22, h * 0.66, w * 0.26, h * 0.48, w * 0.40, h * 0.36)
      ..cubicTo(w * 0.32, h * 0.52, w * 0.32, h * 0.68, w * 0.40, h * 0.80)
      ..close();
    canvas.drawPath(gap, Paint()..color = Colors.white.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(covariant _SwooshPainter oldDelegate) => false;
}
