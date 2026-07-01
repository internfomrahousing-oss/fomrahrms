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

const _hrNavItems = [
  _NavItem('Dashboard',              Icons.dashboard_rounded,              '/manager/dashboard'),
  _NavItem('Interview Review',       Icons.rate_review_rounded,            '/manager/interview-review'),
  _NavItem('Team Leave Approvals',   Icons.group_rounded,                  '/manager/leave/team-approvals'),
  _NavItem('Task Management',        Icons.task_alt_rounded,               '/manager/task-management'),
  _NavItem('Payroll Management',     Icons.account_balance_wallet_rounded, '/manager/payroll-management'),
  _NavItem('Employee Onboarding',    Icons.how_to_reg_rounded,             '/manager/employee-onboarding'),
  _NavItem('Approvals',              Icons.approval_rounded,               '/manager/approvals'),
  _NavItem('Notifications',          Icons.notifications_rounded,          '/manager/notifications'),
  _NavItem('Reports & Analytics',    Icons.bar_chart_rounded,              '/manager/reports-analytics'),
  _NavItem('Settings',               Icons.settings_rounded,               '/manager/settings'),
];

const _personalNavItems = [
  _NavItem('My Profile',    Icons.person_rounded,                  '/manager/my-profile'),
  _NavItem('My Attendance', Icons.access_time_rounded,             '/manager/my-attendance'),
  _NavItem('My Leave',      Icons.beach_access_rounded,            '/manager/my-leave'),
  _NavItem('My Tasks',      Icons.task_alt_rounded,                '/manager/my-tasks'),
  _NavItem('My Payslips',   Icons.account_balance_wallet_rounded,  '/manager/my-payslips'),
  _NavItem('Maintenance',   Icons.build_rounded,                   '/manager/maintenance-management'),
];

class ManagerShell extends StatelessWidget {
  final Widget child;
  final String location;
  const ManagerShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    if (isWide) return _WideLayout(child: child, location: location);
    return _NarrowLayout(child: child, location: location);
  }
}

// ── Wide layout ────────────────────────────────────────────────────────────

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

// ── Narrow layout ──────────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final Widget child;
  final String location;
  const _NarrowLayout({required this.child, required this.location});

  String get _currentTitle {
    final all = [..._hrNavItems, ..._personalNavItems];
    final item = all.firstWhere(
      (i) => i.route == location,
      orElse: () => _hrNavItems.first,
    );
    return item.label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          const ThemeToggle(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => context.go('/manager/notifications'),
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

// ── Sidebar ────────────────────────────────────────────────────────────────

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
                  ..._hrNavItems.map((item) => _SidebarTile(
                      item: item, selected: location == item.route)),
                  const _SectionDivider(label: 'My Space'),
                  ..._personalNavItems.map((item) => _SidebarTile(
                      item: item,
                      selected: location == item.route ||
                          location.startsWith('${item.route}/'))),
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

class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      decoration: const BoxDecoration(color: Color(0xFF1A237E)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go('/manager/dashboard'),
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
                    Text('Manager Portal',
                        style:
                            TextStyle(color: Color(0xFFBBDEFB), fontSize: 10)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    Text('Manager',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('Reporting Manager',
                        style: TextStyle(
                            color: Color(0xFFBBDEFB), fontSize: 11)),
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
            color: selected ? Colors.white : const Color(0xFFBBDEFB),
            size: 20),
        title: Text(
          item.label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFBBDEFB),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            Icon(Icons.logout_rounded,
                color: Color(0xFFBBDEFB), size: 18),
            SizedBox(width: 10),
            Text('Sign Out',
                style: TextStyle(
                    color: Color(0xFFBBDEFB), fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ── Mobile Drawer ──────────────────────────────────────────────────────────

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
                ..._hrNavItems.map((item) => _SidebarTile(
                    item: item,
                    selected: location == item.route,
                    closeDrawer: true)),
                const _SectionDivider(label: 'My Space'),
                ..._personalNavItems.map((item) => _SidebarTile(
                    item: item,
                    selected: location == item.route,
                    closeDrawer: true)),
              ],
            ),
          ),
          _SidebarFooter(),
        ],
      ),
    );
  }
}
