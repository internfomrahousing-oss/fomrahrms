import 'package:flutter/material.dart';

/// Animates a KPI number counting up whenever [value] changes. Falls back to
/// showing [value] verbatim when it isn't a plain integer (e.g. '—').
class AnimatedCounter extends StatelessWidget {
  final String value;
  final TextStyle? style;
  const AnimatedCounter({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    final target = int.tryParse(value);
    if (target == null) {
      return Text(value, style: style);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(target),
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}
