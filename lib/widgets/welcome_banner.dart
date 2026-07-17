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
    if (h < 12) return 'Happy Morning';
    if (h < 17) return 'Happy Afternoon';
    return 'Happy Evening';
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.headerGradient),
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 18, wide ? 28 : 16, 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_greeting, $name \u{1F44B}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(widget.subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.3)),
            ],
          ),
        ),
        if (widget.onRefresh != null) ...[
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
          const SizedBox(width: 4),
        ],
        const ProfileAvatarButton(large: true, avatarRadius: 36),
      ]),
    );
  }
}
