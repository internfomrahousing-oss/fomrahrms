import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../utils/tenure.dart';

/// Wraps dashboard content and — the moment it builds — checks whether
/// today is the logged-in user's birthday or a work-anniversary milestone
/// (6 months, 1 year, 2 years, ...). If so, shows a one-time confetti burst
/// with a small congratulatory banner. Pure celebration, no persisted
/// "already shown today" state — reappears each time the dashboard remounts
/// that day, which is an acceptable trade-off for the simplicity.
class MilestoneConfetti extends StatefulWidget {
  final Widget child;
  const MilestoneConfetti({super.key, required this.child});

  @override
  State<MilestoneConfetti> createState() => _MilestoneConfettiState();
}

class _MilestoneConfettiState extends State<MilestoneConfetti> {
  bool _show = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final name = UserSession.name.trim();
    if (name.isEmpty) return;
    String? message;

    try {
      final users = await UserStore.load();
      final match = users
          .where((u) => u.name.trim().toLowerCase() == name.toLowerCase())
          .toList();
      if (match.isNotEmpty) {
        final label = milestoneLabelForToday(match.first.dateOfJoining);
        if (label != null) message = 'Congratulations on $label with FOMRA! \u{1F389}';
      }
    } catch (_) {}

    if (message == null) {
      try {
        final eom = await SupabaseService.fetchEmployeeOfMonth();
        final eomName = (eom?['employee_name'] as String?)?.trim().toLowerCase() ?? '';
        final announced = DateTime.tryParse((eom?['announced_date'] as String?) ?? '');
        final today = DateTime.now();
        final isAnnouncedToday = announced != null &&
            announced.year == today.year &&
            announced.month == today.month &&
            announced.day == today.day;
        if (eomName == name.toLowerCase() && isAnnouncedToday) {
          message = 'You\'re the Employee of the Month, $name! \u{1F3C6}';
        }
      } catch (_) {}
    }

    if (message == null) {
      try {
        final today = DateTime.now();
        final births = await SupabaseService.fetchBirthdaysForMonth(today.month);
        final isBirthday = births.any((b) {
          final bName = (b['name'] as String?)?.trim().toLowerCase() ?? '';
          if (bName != name.toLowerCase()) return false;
          final d = DateTime.tryParse((b['birthday_date'] as String?) ?? '');
          return d != null && d.day == today.day;
        });
        if (isBirthday) message = 'Happy Birthday, $name! \u{1F382}';
      } catch (_) {}
    }

    if (message != null && mounted) {
      setState(() {
        _message = message;
        _show = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_show) ...[
        Positioned.fill(
          child: IgnorePointer(
            child: _ConfettiLayer(onDone: () {
              if (mounted) setState(() => _show = false);
            }),
          ),
        ),
        if (_message != null)
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(child: _MilestoneBanner(message: _message!)),
            ),
          ),
      ],
    ]);
  }
}

class _MilestoneBanner extends StatelessWidget {
  final String message;
  const _MilestoneBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
      ),
    );
  }
}

class _ConfettiLayer extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiLayer({required this.onDone});

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _particles = List.generate(70, (_) => _Particle(rand));
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ConfettiPainter(particles: _particles, progress: _controller.value),
      size: Size.infinite,
    );
  }
}

class _Particle {
  final double xStart;
  final double speed;
  final double drift;
  final double size;
  final double rotationSpeed;
  final Color color;
  final double delay;

  _Particle(Random r)
      : xStart = r.nextDouble(),
        speed = 0.7 + r.nextDouble() * 0.6,
        drift = (r.nextDouble() - 0.5) * 40,
        size = 6 + r.nextDouble() * 6,
        rotationSpeed = (r.nextDouble() - 0.5) * 8,
        color = _colors[r.nextInt(_colors.length)],
        delay = r.nextDouble() * 0.25;

  static const _colors = [
    Color(0xFF2563EB),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  const _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = t * (size.height + 40) * p.speed - 20;
      final x = p.xStart * size.width + sin(t * pi * 4) * p.drift;
      final angle = t * p.rotationSpeed * pi * 2;
      final opacity = t > 0.85 ? ((1 - t) / 0.15).clamp(0.0, 1.0) : 1.0;

      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
