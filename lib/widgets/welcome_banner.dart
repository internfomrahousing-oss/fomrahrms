import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_session.dart';

class WelcomeBanner extends StatefulWidget {
  final String subtitle;
  final IconData avatarIcon;
  final VoidCallback? onRefresh;

  const WelcomeBanner({
    super.key,
    this.subtitle = 'Fomra Housing & Infrastructure',
    this.avatarIcon = Icons.admin_panel_settings_rounded,
    this.onRefresh,
  });

  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Update greeting at the start of each minute
    _timer = Timer.periodic(const Duration(minutes: 1),
        (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData get _greetIcon {
    final h = _now.hour;
    if (h < 12) return Icons.wb_sunny_rounded;
    if (h < 17) return Icons.light_mode_rounded;
    return Icons.nights_stay_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final name = UserSession.name.isNotEmpty ? UserSession.name : 'Admin';
    final wide = MediaQuery.of(context).size.width > 500;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF060F1E), Color(0xFF0A2472), Color(0xFF0E52AE)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -50,
          top: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          right: 80,
          bottom: -70,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to FOMRA HRMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_greetIcon, color: const Color(0xFFFFD54F), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '$_greeting, $name',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Icon(widget.avatarIcon, color: Colors.white70, size: 30),
              ),
            ],
            if (widget.onRefresh != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Refresh',
                child: InkWell(
                  onTap: widget.onRefresh,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.refresh_rounded, color: Colors.white60, size: 18),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
