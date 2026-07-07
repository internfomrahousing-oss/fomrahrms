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
    final swooshSize = wordmarkSize * 0.9;
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
          right: -swooshSize * 0.32,
          top: -swooshSize * 0.22,
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

class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.2
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF0F6FB8), Color(0xFF35B6E8)],
      ).createShader(rect);
    final path = Path()
      ..addArc(rect.deflate(size.width * 0.12), -1.55, 2.7);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SwooshPainter oldDelegate) => false;
}
