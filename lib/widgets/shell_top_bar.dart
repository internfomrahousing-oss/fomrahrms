import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/color_theme_notifier.dart';
import '../theme/app_theme.dart';
import 'theme_toggle.dart';
import 'profile_avatar_button.dart';
import 'quick_actions_bar.dart';
import 'notification_bell_icon.dart';

class ShellTopBar extends StatelessWidget {
  final bool sidebarOpen;
  final VoidCallback onToggle;
  final String homeRoute;
  final String notificationsRoute;
  final bool hideProfile;
  final String? searchRoute;

  const ShellTopBar({
    super.key,
    required this.sidebarOpen,
    required this.onToggle,
    required this.homeRoute,
    required this.notificationsRoute,
    this.hideProfile = false,
    this.searchRoute,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: colorThemeNotifier,
      builder: (context, _) => _bar(context),
    );
  }

  Widget _bar(BuildContext context) {
    final dark = AppTheme.primaryBlueDark;
    final mid = Color.lerp(dark, AppTheme.primaryBlue, 0.55)!;
    final toggleAccent = AppTheme.accentBlue;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [dark, mid, AppTheme.primaryBlue],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        // Sidebar toggle
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: toggleAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: toggleAccent.withValues(alpha: 0.25),
                  width: 0.8),
            ),
            child: Icon(
              sidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
              size: 22,
              color: toggleAccent,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Logo + name as home button
        InkWell(
          onTap: () => context.go(homeRoute),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FOMRA HRMS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  Text('Human Resource Management',
                      style: TextStyle(color: Colors.white54, fontSize: 9)),
                ],
              ),
            ]),
          ),
        ),
        const Spacer(),
        if (searchRoute != null && MediaQuery.of(context).size.width > 900) ...[
          SizedBox(
            width: 220,
            height: 38,
            child: TextField(
              onSubmitted: (_) => context.go(searchRoute!),
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search employees, reports...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Colors.white60),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white60),
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.10),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Quick actions
        const QuickActionIcons(),
        const SizedBox(width: 8),
        // Notifications bell
        Tooltip(
          message: 'Notifications',
          child: InkWell(
            onTap: () => context.go(notificationsRoute),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: NotificationBellIcon(badgeBorderColor: AppTheme.primaryBlueDark),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Theme toggle
        const ThemeToggle(),
        const SizedBox(width: 8),
        // Profile avatar + dropdown
        if (!hideProfile) const ProfileAvatarButton(),
        if (!hideProfile) const SizedBox(width: 12),
      ]),
    );
  }
}
