import 'package:flutter/material.dart';

/// Fades + slides [child] in on first build. Pure visual polish for page
/// and section entrances — carries no state relevant to app behavior.
class FadeIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double slideUpPx;
  const FadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.slideUpPx = 12,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * slideUpPx),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
