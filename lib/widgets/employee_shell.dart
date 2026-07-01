import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_session.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../models/theme_notifier.dart';
import 'shell_top_bar.dart';
import 'theme_toggle.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}

const _empNavItems = [
  _NavItem('Dashboard',            Icons.dashboard_rounded,               '/employee/dashboard'),
  _NavItem('My Profile',           Icons.person_rounded,                  '/employee/profile'),
  _NavItem('My Attendance',        Icons.access_time_rounded,             '/employee/attendance-management'),
  _NavItem('My Leave',             Icons.beach_access_rounded,            '/employee/leave-management'),
  _NavItem('My Tasks',             Icons.task_alt_rounded,                '/employee/tasks'),
  _NavItem('My Payslips',          Icons.account_balance_wallet_rounded,  '/employee/payslips'),
  _NavItem('Maintenance',          Icons.build_rounded,                   '/employee/maintenance-management'),
  _NavItem('Onboarding',           Icons.how_to_reg_rounded,              '/employee/employee-onboarding'),
  _NavItem('My Notifications',     Icons.notifications_rounded,           '/employee/notifications'),
  _NavItem('Settings',             Icons.settings_rounded,                '/employee/settings'),
];

class EmployeeShell extends StatelessWidget {
  final Widget child;
  final String location;
  const EmployeeShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    if (isWide) return _WideLayout(child: child, location: location);
    return _NarrowLayout(child: child, location: location);
  }
}

class _WideLayout extends StatefulWidget {
  final Widget child;
  final String location;
  const _WideLayout({required this.child, required this.location});

  @override
  State<_WideLayout> createState() => _WideLayoutState();
}

class _WideLayoutState extends State<_WideLayout> {
  bool _sidebarOpen = false;

  @override
  void didUpdateWidget(_WideLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location && _sidebarOpen) {
      setState(() => _sidebarOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ShellTopBar(
            sidebarOpen: _sidebarOpen,
            onToggle: () => setState(() => _sidebarOpen = !_sidebarOpen),
            homeRoute: '/employee/dashboard',
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: widget.child),
                IgnorePointer(
                  ignoring: !_sidebarOpen,
                  child: AnimatedOpacity(
                    opacity: _sidebarOpen ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: GestureDetector(
                      onTap: () => setState(() => _sidebarOpen = false),
                      child: Container(color: Colors.black54),
                    ),
                  ),
                ),
                AnimatedSlide(
                  offset: _sidebarOpen ? Offset.zero : const Offset(-1, 0),
                  duration: const Duration(milliseconds: 280),
                  curve: _sidebarOpen ? Curves.easeOut : Curves.easeIn,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 260,
                      child: _Sidebar(location: widget.location),
                    ),
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

class _NarrowLayout extends StatelessWidget {
  final Widget child;
  final String location;
  const _NarrowLayout({required this.child, required this.location});

  String get _currentTitle {
    final item = _empNavItems.firstWhere(
      (i) => i.route == location,
      orElse: () => _empNavItems.first,
    );
    return item.label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          const ThemeToggle(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => context.go('/employee/notifications'),
          ),
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
      drawer: Drawer(child: _DrawerContent(location: location)),
      body: child,
    );
  }
}

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
                children: _empNavItems.map((item) {
                  final selected = location == item.route ||
                      location.startsWith('${item.route}/');
                  return _SidebarTile(item: item, selected: selected);
                }).toList(),
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
      decoration: const BoxDecoration(color: AppTheme.primaryBlueDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go('/employee/dashboard'),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: AppTheme.primaryBlue, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FOMRA',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    Text('Employee Portal',
                        style: TextStyle(color: Color(0xFFBBDEFB), fontSize: 10)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
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
                    Text('Employee',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('Staff Member',
                        style:
                            TextStyle(color: Color(0xFFBBDEFB), fontSize: 11)),
                  ],
                ),
              ),
            ]),
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
  const _SidebarTile(
      {required this.item, required this.selected, this.closeDrawer = false});

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
        leading: Icon(item.icon,
            color: selected ? Colors.white : const Color(0xFFBBDEFB), size: 20),
        title: Text(
          item.label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFBBDEFB),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          if (closeDrawer) Navigator.of(context).pop();
          context.go(item.route);
        },
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12))),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () { themeNotifier.reset(); SessionStorage.clear(); UserSession.clear(); context.go('/login'); },
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(Icons.logout_rounded, color: Color(0xFFBBDEFB), size: 18),
            SizedBox(width: 10),
            Text('Sign Out',
                style: TextStyle(color: Color(0xFFBBDEFB), fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

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
              children: _empNavItems.map((item) {
                final selected = location == item.route;
                return _SidebarTile(
                    item: item, selected: selected, closeDrawer: true);
              }).toList(),
            ),
          ),
          _SidebarFooter(),
        ],
      ),
    );
  }
}
