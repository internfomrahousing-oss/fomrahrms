import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/color_theme_notifier.dart';
import '../models/user_session.dart';
import '../theme/app_theme.dart';
import 'profile_avatar_button.dart';

class WelcomeBanner extends StatefulWidget {
  final String subtitle;
  final IconData avatarIcon;
  final VoidCallback? onRefresh;
  // Optional quick-access icon buttons — each is hidden if its route/route
  // is left null, so pages can opt in to only the ones that make sense.
  final String? calendarRoute;
  final String? performanceRoute;
  final String? notificationsRoute;
  final String? searchRoute;

  const WelcomeBanner({
    super.key,
    this.subtitle = 'Fomra Housing & Infrastructure',
    this.avatarIcon = Icons.admin_panel_settings_rounded,
    this.onRefresh,
    this.calendarRoute,
    this.performanceRoute,
    this.notificationsRoute,
    this.searchRoute,
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

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['January', 'February', 'March', 'April', 'May', 'June',
                           'July', 'August', 'September', 'October', 'November', 'December'];

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _dateLabel =>
      '${_weekdays[_now.weekday - 1]}, ${_now.day} ${_months[_now.month - 1]} ${_now.year}';

  @override
  Widget build(BuildContext context) {
    final name = UserSession.name.isNotEmpty ? UserSession.name : 'Admin';
    final wide = MediaQuery.of(context).size.width > 900;
    return ListenableBuilder(
      listenable: colorThemeNotifier,
      builder: (context, _) => _bannerBody(name, wide),
    );
  }

  Widget _bannerBody(String name, bool wide) {
    return Container(
      width: double.infinity,
      color: AppTheme.white,
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 16, wide ? 28 : 16, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_greeting, $name \u{1F44B}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(_dateLabel,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.3)),
              Text(widget.subtitle,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.3)),
            ],
          ),
        ),
        if (wide && widget.searchRoute != null) ...[
          SizedBox(
            width: 260,
            child: TextField(
              onSubmitted: (_) => context.push(widget.searchRoute!),
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search employees, reports...',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.pageBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (widget.calendarRoute != null)
          _HeaderIconButton(icon: Icons.calendar_month_rounded, tooltip: 'Calendar',
              onTap: () => context.push(widget.calendarRoute!)),
        if (widget.performanceRoute != null) ...[
          const SizedBox(width: 8),
          _HeaderIconButton(icon: Icons.emoji_events_rounded, tooltip: 'Performance',
              onTap: () => context.push(widget.performanceRoute!)),
        ],
        if (widget.notificationsRoute != null) ...[
          const SizedBox(width: 8),
          _HeaderIconButton(icon: Icons.notifications_rounded, tooltip: 'Notifications',
              onTap: () => context.push(widget.notificationsRoute!)),
        ],
        if (widget.onRefresh != null) ...[
          const SizedBox(width: 8),
          _HeaderIconButton(icon: Icons.refresh_rounded, tooltip: 'Refresh', onTap: widget.onRefresh!),
        ],
        const SizedBox(width: 10),
        const ProfileAvatarButton(light: true),
      ]),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppTheme.pageBackground,
            borderRadius: BorderRadius.circular(AppTheme.controlRadius),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Icon(icon, size: 19, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
