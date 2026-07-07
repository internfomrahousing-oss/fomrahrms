import 'package:flutter/material.dart';

/// Wraps a card-like [child] with a subtle lift + shadow on hover — pure
/// visual polish, no behavior change. No-ops gracefully on touch devices
/// since [MouseRegion] simply never reports a hover there.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double liftPx;
  final BorderRadius borderRadius;
  const HoverLift({
    super.key,
    required this.child,
    this.liftPx = 3,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovering ? -widget.liftPx : 0, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}
