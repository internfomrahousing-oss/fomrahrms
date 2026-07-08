import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/color_theme_notifier.dart';
import '../theme/app_theme.dart';
import 'animated_counter.dart';
import 'hover_lift.dart';

// ── Public card ───────────────────────────────────────────────────────────────

/// Single stat card. Pass [gaugePercent] (0.0–1.0) to show a gauge needle,
/// or omit to show a decorative bar-chart (used for totals/counts with no %).
/// Leave [color] unset to follow the active app color theme.
class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final double? gaugePercent;
  final VoidCallback? onTap;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.gaugePercent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: colorThemeNotifier,
      builder: (context, _) => _card(color ?? AppTheme.primaryBlue),
    );
  }

  Widget _card(Color color) {
    return HoverLift(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Card(
        color: AppTheme.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 156),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // ── header ────────────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    HoverBuilder(
                      builder: (context, hovering) => AnimatedScale(
                        scale: hovering ? 1.12 : 1.0,
                        duration: AppTheme.fastAnim,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.12),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // ── value + visual ───────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedCounter(
                        value: value,
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            height: 1)),
                    const Spacer(),
                    if (gaugePercent != null)
                      _GaugeWidget(percent: gaugePercent!.clamp(0.0, 1.0),
                          color: color)
                    else
                      _BarChartWidget(color: color),
                  ],
                ),
                const SizedBox(height: 6),
                // Reserve the same height whether or not a percentage is
                // shown, so the number row above lines up at the same
                // vertical position across every card in the strip.
                Visibility(
                  visible: gaugePercent != null,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.pie_chart_rounded, size: 13, color: color.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text('${((gaugePercent ?? 0).clamp(0.0, 1.0) * 100).round()}% of total',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: color.withValues(alpha: 0.75))),
                  ]),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

// ── 4-card responsive strip ───────────────────────────────────────────────────

class AppStatStrip extends StatelessWidget {
  final List<AppStatCard> cards;
  const AppStatStrip({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final narrow = constraints.maxWidth < 520;
      if (narrow) {
        final rows = <Widget>[];
        for (int i = 0; i < cards.length; i += 2) {
          final end = (i + 2).clamp(0, cards.length);
          rows.add(IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int j = i; j < end; j++) ...[
                  if (j > i) const SizedBox(width: 12),
                  Expanded(child: cards[j]),
                ],
              ],
            ),
          ));
          if (end < cards.length) rows.add(const SizedBox(height: 12));
        }
        return Column(children: rows);
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    });
  }
}

// ── Gauge (semicircle needle) ─────────────────────────────────────────────────

class _GaugeWidget extends StatelessWidget {
  final double percent;
  final Color color;
  const _GaugeWidget({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72, height: 40,
      child: CustomPaint(painter: _GaugePainter(percent: percent, color: color)),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  const _GaugePainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height; // arc center sits at the bottom edge
    final r  = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Background track — left to right via TOP (clockwise in canvas coords)
    canvas.drawArc(
      rect, math.pi, math.pi, false,
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (percent > 0) {
      canvas.drawArc(
        rect, math.pi, math.pi * percent, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Needle
    final angle  = math.pi + math.pi * percent;
    final needleEnd = Offset(
      cx + r * 0.70 * math.cos(angle),
      cy + r * 0.70 * math.sin(angle),
    );
    canvas.drawLine(
      Offset(cx, cy), needleEnd,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // Center pivot dot
    canvas.drawCircle(Offset(cx, cy), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GaugePainter o) =>
      o.percent != percent || o.color != color;
}

// ── Mini bar chart (decorative, for count-only cards) ────────────────────────

class _BarChartWidget extends StatelessWidget {
  final Color color;
  const _BarChartWidget({required this.color});

  static const _hts    = [0.35, 0.50, 1.0, 0.60, 0.75, 0.55];
  static const _labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  static const _maxH   = 38.0;
  static const _barW   = 9.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_hts.length, (i) => Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
            child: Container(
              width: _barW,
              height: _maxH * _hts[i],
              decoration: BoxDecoration(
                color: i == 2 ? color : color.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          )),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_labels.length, (i) => Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
            child: SizedBox(
              width: _barW,
              child: Text(_labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 6,
                      color: color.withValues(alpha: 0.5))),
            ),
          )),
        ),
      ],
    );
  }
}
