import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_session.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../models/theme_notifier.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}

const _navItems = [
  _NavItem('Dashboard', Icons.dashboard_rounded, '/dashboard'),
  _NavItem('Employee Management', Icons.people_rounded, '/employee-management'),
  _NavItem('Attendance Management', Icons.access_time_rounded, '/attendance-management'),
  _NavItem('Leave Management', Icons.event_available_rounded, '/leave-management'),
  _NavItem('Task Management', Icons.task_alt_rounded, '/task-management'),
  _NavItem('Payroll Management', Icons.account_balance_wallet_rounded, '/payroll-management'),
  _NavItem('Interview Process', Icons.record_voice_over_rounded, '/interview-process'),
  _NavItem('Employee Onboarding', Icons.how_to_reg_rounded, '/employee-onboarding'),
  _NavItem('Lead Management', Icons.leaderboard_rounded, '/lead-management'),
  _NavItem('Maintenance Management', Icons.build_rounded, '/maintenance-management'),
  _NavItem('Approvals', Icons.approval_rounded, '/approvals'),
  _NavItem('Notifications', Icons.notifications_rounded, '/notifications'),
  _NavItem('Reports & Analytics', Icons.bar_chart_rounded, '/reports-analytics'),
  _NavItem('Settings', Icons.settings_rounded, '/settings'),
];

const _personalNavItems = [
  _NavItem('My Profile',    Icons.person_rounded,                 '/hr/my-profile'),
  _NavItem('My Attendance', Icons.access_time_rounded,            '/hr/my-attendance'),
  _NavItem('My Leave',      Icons.beach_access_rounded,           '/hr/my-leave'),
  _NavItem('My Tasks',      Icons.task_alt_rounded,               '/hr/my-tasks'),
  _NavItem('My Payslips',   Icons.account_balance_wallet_rounded, '/hr/my-payslips'),
  _NavItem('Maintenance',   Icons.build_rounded,                  '/hr/maintenance-management'),
];

class AppShell extends StatelessWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    if (isWide) {
      return _WideLayout(child: child, location: location);
    }
    return _NarrowLayout(child: child, location: location);
  }
}

// ── Wide layout (web): permanent left sidebar ──────────────────────────────
class _WideLayout extends StatelessWidget {
  final Widget child;
  final String location;
  const _WideLayout({required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(location: location),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Narrow layout (mobile): hamburger + drawer ─────────────────────────────
class _NarrowLayout extends StatelessWidget {
  final Widget child;
  final String location;
  const _NarrowLayout({required this.child, required this.location});

  String get _currentTitle {
    final item = _navItems.firstWhere(
      (i) => i.route == location,
      orElse: () => _navItems.first,
    );
    return item.label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => context.go('/notifications'),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: AppTheme.accentBlue,
              radius: 16,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: _DrawerContent(location: location),
      ),
      body: child,
    );
  }
}

// ── Sidebar widget ─────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final String location;
  const _Sidebar({required this.location});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Material(
        color: AppTheme.sidebarBg,
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SidebarHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ..._navItems.map((item) {
                    final selected = location == item.route;
                    return _SidebarTile(item: item, selected: selected);
                  }),
                  const _SectionDivider(label: 'My Space'),
                  ..._personalNavItems.map((item) {
                    final selected = location == item.route ||
                        location.startsWith('${item.route}/');
                    return _SidebarTile(item: item, selected: selected);
                  }),
                ],
              ),
            ),
            _SidebarFooter(),
          ],
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      decoration: const BoxDecoration(
        color: AppTheme.primaryBlueDark,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go('/dashboard'),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.apartment_rounded, color: AppTheme.primaryBlue, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOMRA',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      Text(
                        'Housing & Infrastructure',
                        style: TextStyle(color: Color(0xFFBBDEFB), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.accentBlue,
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin User', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Administrator', style: TextStyle(color: Color(0xFFBBDEFB), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool closeDrawer;
  const _SidebarTile({required this.item, required this.selected, this.closeDrawer = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AppTheme.sidebarSelectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.icon,
          color: selected ? Colors.white : const Color(0xFFBBDEFB),
          size: 20,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFBBDEFB),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selectedTileColor: AppTheme.sidebarSelectedBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          final router = GoRouter.of(context);
          if (closeDrawer) Navigator.of(context).pop();
          router.go(item.route);
        },
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        const Expanded(child: Divider(color: Colors.white12, height: 1)),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF78909C), fontSize: 10, letterSpacing: 1)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Colors.white12, height: 1)),
      ]),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () { themeNotifier.reset(); SessionStorage.clear(); UserSession.clear(); context.go('/login'); },
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(Icons.logout_rounded, color: Color(0xFFBBDEFB), size: 18),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(color: Color(0xFFBBDEFB), fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ── Drawer for mobile ──────────────────────────────────────────────────────
class _DrawerContent extends StatelessWidget {
  final String location;
  const _DrawerContent({required this.location});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ..._navItems.map((item) {
                  final selected = location == item.route;
                  return _SidebarTile(
                      item: item, selected: selected, closeDrawer: true);
                }),
                const _SectionDivider(label: 'My Space'),
                ..._personalNavItems.map((item) {
                  final selected = location == item.route;
                  return _SidebarTile(
                      item: item, selected: selected, closeDrawer: true);
                }),
              ],
            ),
          ),
          _SidebarFooter(),
        ],
      ),
    );
  }
}
