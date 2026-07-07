import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reports hover state to [builder] — pure visual polish, no behavior
/// change. No-ops gracefully on touch devices since [MouseRegion] simply
/// never reports a hover there.
class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovering) builder;
  const HoverBuilder({super.key, required this.builder});

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: widget.builder(context, _hovering),
    );
  }
}

/// Wraps a card-like [child] with a subtle 4px lift + deeper shadow on
/// hover, always showing a faint resting shadow — pure visual polish, no
/// behavior change.
class HoverLift extends StatelessWidget {
  final Widget child;
  final double liftPx;
  final BorderRadius borderRadius;
  const HoverLift({
    super.key,
    required this.child,
    this.liftPx = 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppTheme.cardRadius)),
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovering) => AnimatedContainer(
        duration: AppTheme.fastAnim,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, hovering ? -liftPx : 0, 0),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: hovering ? AppTheme.cardShadowHover : AppTheme.cardShadow,
        ),
        child: child,
      ),
    );
  }
}
