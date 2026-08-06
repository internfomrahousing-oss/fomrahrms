import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A trophy that keeps celebrating.
///
/// The Employee of the Month card showed a static icon, which for the one
/// recognition the company gives is a flat way to present it. This adds a
/// continuous, low-key celebration: a soft glow that breathes, sparkles that
/// orbit the cup, and a slow shimmer across it.
///
/// Deliberately gentle and endless rather than a one-off burst. The existing
/// MilestoneConfetti already does a burst on arrival; a second burst competing
/// with it would be noise. This is ambient — noticeable when you look at the
/// card, not demanding when you are not.
///
/// Respects MediaQuery.disableAnimations, so anyone who has asked their device
/// to reduce motion gets the static trophy instead. An animation that cannot
/// be turned off is an accessibility problem, not a feature.
class CelebratingTrophy extends StatefulWidget {
  final double size;
  final Color color;

  const CelebratingTrophy({super.key, this.size = 36, required this.color});

  @override
  State<CelebratingTrophy> createState() => _CelebratingTrophyState();
}

class _CelebratingTrophyState extends State<CelebratingTrophy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Fixed sparkle positions: a random layout each rebuild would make the
  // sparkles jump whenever the parent rebuilds, which happens on every
  // dashboard refresh.
  static const _sparkles = <_Sparkle>[
    _Sparkle(angle: -0.4, distance: 0.86, phase: 0.00, scale: 1.00),
    _Sparkle(angle: 0.9, distance: 0.95, phase: 0.30, scale: 0.75),
    _Sparkle(angle: 2.1, distance: 0.80, phase: 0.55, scale: 0.90),
    _Sparkle(angle: 3.4, distance: 0.98, phase: 0.15, scale: 0.65),
    _Sparkle(angle: 4.5, distance: 0.84, phase: 0.72, scale: 0.85),
    _Sparkle(angle: 5.6, distance: 0.92, phase: 0.45, scale: 0.70),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trophy = Icon(Icons.emoji_events_rounded,
        size: widget.size, color: widget.color);

    if (MediaQuery.of(context).disableAnimations) return trophy;

    final box = widget.size * 2.1;
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Breathing glow — eased so it lingers at each end rather than
          // pulsing mechanically.
          final glow = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
          final eased = Curves.easeInOut.transform(glow);

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size * (1.5 + eased * 0.35),
                height: widget.size * (1.5 + eased * 0.35),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    widget.color.withValues(alpha: 0.20 + eased * 0.14),
                    widget.color.withValues(alpha: 0.0),
                  ]),
                ),
              ),
              for (final s in _sparkles) _buildSparkle(s, t),
              // Very slight lift, so the cup feels alive without wobbling.
              Transform.translate(
                offset: Offset(0, -1.5 * eased),
                child: trophy,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSparkle(_Sparkle s, double t) {
    // Each sparkle runs its own cycle, offset by phase, so they twinkle
    // independently rather than blinking in unison.
    final local = (t + s.phase) % 1.0;
    final fade = math.sin(local * math.pi); // 0 -> 1 -> 0
    if (fade <= 0.02) return const SizedBox.shrink();

    final drift = s.distance + local * 0.12;
    final r = widget.size * 0.62 * drift;

    return Transform.translate(
      offset: Offset(math.cos(s.angle) * r, math.sin(s.angle) * r),
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0) * 0.9,
        child: Icon(
          Icons.auto_awesome_rounded,
          size: widget.size * 0.26 * s.scale * (0.7 + fade * 0.5),
          color: widget.color,
        ),
      ),
    );
  }
}

class _Sparkle {
  final double angle;     // radians around the trophy
  final double distance;  // base radius, as a fraction of the trophy size
  final double phase;     // offset into the twinkle cycle
  final double scale;
  const _Sparkle({
    required this.angle,
    required this.distance,
    required this.phase,
    required this.scale,
  });
}
