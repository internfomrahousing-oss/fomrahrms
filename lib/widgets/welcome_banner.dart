import 'dart:async';
import 'package:flutter/material.dart';
import '../models/color_theme_notifier.dart';
import '../models/user_session.dart';
import '../theme/app_theme.dart';
import 'profile_avatar_button.dart';

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
    return ListenableBuilder(
      listenable: colorThemeNotifier,
      builder: (context, _) => _bannerBody(name, wide),
    );
  }

  Widget _bannerBody(String name, bool wide) {
    final dark = AppTheme.primaryBlueDark;
    final mid = Color.lerp(dark, AppTheme.primaryBlue, 0.55)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [dark, mid, AppTheme.primaryBlue],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -30,
          top: -50,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 14, wide ? 28 : 16, 14),
          child: Row(children: [
            Icon(_greetIcon, color: const Color(0xFFFFD54F), size: wide ? 20 : 17),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_greeting, $name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: wide ? 17 : 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const ProfileAvatarButton(),
            if (widget.onRefresh != null) ...[
              const SizedBox(width: 4),
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
