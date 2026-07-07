import 'package:flutter/material.dart';

/// The real FOMRA company logo (wordmark + swoosh + caption baked into one
/// image), rendered at a given height with the source aspect ratio preserved.
class FomraLogoMark extends StatelessWidget {
  static const double _aspectRatio = 312 / 111;

  final double height;
  const FomraLogoMark({super.key, this.height = 72});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/fomra_logo.png',
      height: height,
      width: height * _aspectRatio,
      fit: BoxFit.contain,
    );
  }
}
