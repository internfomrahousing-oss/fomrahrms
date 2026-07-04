import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme_toggle.dart';
import 'profile_avatar_button.dart';

class ShellTopBar extends StatelessWidget {
  final bool sidebarOpen;
  final VoidCallback onToggle;
  final String homeRoute;
  final String notificationsRoute;

  const ShellTopBar({
    super.key,
    required this.sidebarOpen,
    required this.onToggle,
    required this.homeRoute,
    required this.notificationsRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF060F1E), Color(0xFF0A2472), Color(0xFF0E52AE)],
          stops: [0.0, 0.55, 1.0],
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
              color: const Color(0xFF90CAF9).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF90CAF9).withValues(alpha: 0.25),
                  width: 0.8),
            ),
            child: Icon(
              sidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
              size: 22,
              color: const Color(0xFF90CAF9),
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
              child: const Icon(Icons.notifications_rounded,
                  color: Colors.white70, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Theme toggle
        const ThemeToggle(),
        const SizedBox(width: 8),
        // Profile avatar + dropdown
        const ProfileAvatarButton(),
        const SizedBox(width: 12),
      ]),
    );
  }
}
