import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_store.dart';
import '../models/theme_notifier.dart';
import '../models/user_session.dart';
import '../services/push_notification_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import 'fomra_logo.dart';

class _StaffTab {
  final String label;
  final IconData icon;
  final String route;
  const _StaffTab(this.label, this.icon, this.route);
}

const _staffTabs = [
  _StaffTab('Home',       Icons.home_rounded,        '/staff/home'),
  _StaffTab('Leave',      Icons.event_busy_rounded,  '/staff/leave'),
  _StaffTab('Permission', Icons.access_time_rounded, '/staff/permission'),
  _StaffTab('Profile',    Icons.person_rounded,      '/staff/profile'),
];

/// Simplified shell for Housekeeping/Support Staff: a bottom tab bar with
/// large icons and minimal chrome — deliberately not the sidebar/drawer
/// pattern the rest of the app uses, per the Staff Portal's "extremely
/// simple, mobile-first" requirement.
class StaffShell extends StatelessWidget {
  final Widget child;
  final String location;
  const StaffShell({super.key, required this.child, required this.location});

  int get _currentIndex {
    final i = _staffTabs.indexWhere((t) => location.startsWith(t.route));
    return i == -1 ? 0 : i;
  }

  void _logout(BuildContext context) {
    themeNotifier.reset();
    NotificationStore.reset();
    PushNotificationService.unregister();
    SessionStorage.clear();
    UserSession.clear();
    context.go('/login');
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) _logout(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(children: [
          const FomraLogoMark(wordmarkSize: 26),
          const SizedBox(width: 10),
          Text(UserSession.name.isNotEmpty ? UserSession.name : 'Staff',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(top: false, child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i == _currentIndex) return;
          context.go(_staffTabs[i].route);
        },
        destinations: [
          for (final t in _staffTabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
