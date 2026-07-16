import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/staff_strings.dart';
import '../models/language_notifier.dart';
import '../models/notification_store.dart';
import '../models/theme_notifier.dart';
import '../models/user_session.dart';
import '../services/audit_log_service.dart';
import '../services/push_notification_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import 'fomra_logo.dart';

class _StaffTab {
  final String labelKey;
  final IconData icon;
  final String route;
  const _StaffTab(this.labelKey, this.icon, this.route);
}

const _staffTabs = [
  _StaffTab('tab_home',       Icons.home_rounded,        '/staff/home'),
  _StaffTab('tab_leave',      Icons.event_busy_rounded,  '/staff/leave'),
  _StaffTab('tab_permission', Icons.access_time_rounded, '/staff/permission'),
  _StaffTab('tab_profile',    Icons.person_rounded,      '/staff/profile'),
];

/// Simplified shell for Housekeeping/Support Staff: a bottom tab bar with
/// large icons and minimal chrome — deliberately not the sidebar/drawer
/// pattern the rest of the app uses, per the Staff Portal's "extremely
/// simple, mobile-first" requirement.
///
/// Also owns the Staff Portal's language switcher (English/Hindi/Tamil) —
/// the choice persists per employee (see LanguageNotifier) so it's only
/// picked once, and can be changed anytime from the globe icon here.
class StaffShell extends StatelessWidget {
  final Widget child;
  final String location;
  const StaffShell({super.key, required this.child, required this.location});

  int get _currentIndex {
    final i = _staffTabs.indexWhere((t) => location.startsWith(t.route));
    return i == -1 ? 0 : i;
  }

  void _logout(BuildContext context) {
    AuditLogService.log('logout');
    themeNotifier.reset();
    staffLanguageNotifier.reset();
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
        title: Text(st('logout_title')),
        content: Text(st('logout_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(st('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text(st('log_out')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) _logout(context);
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final picked = await showDialog<AppLanguage>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(st('choose_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in AppLanguage.values)
              RadioListTile<AppLanguage>(
                value: lang,
                groupValue: staffLanguageNotifier.value,
                activeColor: AppTheme.primaryBlue,
                title: Text(languageDisplayName(lang),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(st('cancel'))),
        ],
      ),
    );
    if (picked != null) staffLanguageNotifier.setLanguage(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: staffLanguageNotifier,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 20,
          title: Row(children: [
            const FomraLogoMark(wordmarkSize: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(UserSession.name.isNotEmpty ? UserSession.name : 'Staff',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ]),
          actions: [
            IconButton(
              tooltip: st('language'),
              icon: const Icon(Icons.translate_rounded),
              onPressed: () => _pickLanguage(context),
            ),
            IconButton(
              tooltip: st('logout_tooltip'),
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
              NavigationDestination(icon: Icon(t.icon), label: st(t.labelKey)),
          ],
        ),
      ),
    );
  }
}
