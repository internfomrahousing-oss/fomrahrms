import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_session.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../models/theme_notifier.dart';
import 'shell_top_bar.dart';
import 'theme_toggle.dart';
import 'profile_avatar_button.dart';
import 'quick_actions_bar.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}

typedef _SubItem = ({String label, IconData icon, String route});

const _editFormItems = <_SubItem>[
  (label: 'Form Approvals',       icon: Icons.approval_rounded,         route: '/management/form-approvals'),
  (label: 'Edit Leave Form',      icon: Icons.event_available_rounded,  route: '/management/edit-leave-form'),
  (label: 'Edit Permission Form', icon: Icons.access_time_rounded,      route: '/management/edit-leave-form'),
  (label: 'Edit Comp Off Form',   icon: Icons.swap_horiz_rounded,       route: '/management/edit-leave-form'),
  (label: 'Edit Interview Form',  icon: Icons.assignment_rounded,       route: '/management/edit-form'),
  (label: 'Edit Onboarding Form', icon: Icons.how_to_reg_rounded,       route: '/management/edit-onboarding-form'),
];

const _mgmtColor = AppTheme.primaryBlueDark;

const _navItems = [
  _NavItem('Dashboard',              Icons.dashboard_rounded,              '/management/dashboard'),
  _NavItem('Employee Management',    Icons.people_rounded,                 '/management/employee-management'),
  _NavItem('Attendance Management',  Icons.access_time_rounded,            '/management/attendance-management'),
  _NavItem('Leave Management',       Icons.event_available_rounded,        '/management/leave-management'),
  _NavItem('Team Leave Approvals',   Icons.group_rounded,                  '/management/leave/team-approvals'),
  _NavItem('Task Management',        Icons.task_alt_rounded,               '/management/task-management'),
  _NavItem('Payroll Management',     Icons.account_balance_wallet_rounded, '/management/payroll-management'),
  _NavItem('Interview Process',      Icons.record_voice_over_rounded,      '/management/interview-process'),
  _NavItem('Interview Review',       Icons.admin_panel_settings_rounded,   '/management/interview-review'),
  _NavItem('Employee Onboarding',    Icons.how_to_reg_rounded,             '/management/employee-onboarding'),
  _NavItem('Lead Management',        Icons.leaderboard_rounded,            '/management/lead-management'),
  _NavItem('Maintenance Management', Icons.build_rounded,                  '/management/maintenance-management'),
  _NavItem('Approvals',              Icons.approval_rounded,               '/management/approvals'),
  _NavItem('Notifications',          Icons.notifications_rounded,          '/management/notifications'),
  _NavItem('Reports & Analytics',    Icons.bar_chart_rounded,              '/management/reports-analytics'),
  _NavItem('Administration',         Icons.admin_panel_settings_rounded,   '/management/administration'),
  _NavItem('Settings',               Icons.settings_rounded,               '/management/settings'),
];

const _personalNavItems = [
  _NavItem('My Profile',    Icons.person_rounded,                 '/management/my-profile'),
  _NavItem('My Attendance', Icons.access_time_rounded,            '/management/my-attendance'),
  _NavItem('My Leave',      Icons.beach_access_rounded,           '/management/my-leave'),
  _NavItem('My Tasks',      Icons.task_alt_rounded,               '/management/my-tasks'),
  _NavItem('My Payslips',   Icons.account_balance_wallet_rounded, '/management/my-payslips'),
  _NavItem('Maintenance',   Icons.build_rounded,                  '/management/my-maintenance'),
];

class ManagementShell extends StatelessWidget {
  final Widget child;
  final String location;
  const ManagementShell({super.key, required this.child, required this.location});

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
            homeRoute: '/management/dashboard',
            notificationsRoute: '/management/notifications',
            hideProfile: widget.location == '/management/dashboard',
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
    final all = [..._navItems, ..._personalNavItems];
    return all.firstWhere((i) => i.route == location,
        orElse: () => _navItems.first).label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        backgroundColor: _mgmtColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          const ThemeToggle(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => context.go('/management/notifications'),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      drawer: Drawer(child: _DrawerContent(location: location)),
      body: QuickActionsBody(child: child),
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
                children: [
                  ..._navItems.map((item) => _SidebarTile(
                      item: item,
                      selected: location == item.route ||
                          location.startsWith('${item.route}/'))),
                  const _SectionDivider(label: 'Edit Forms'),
                  _ExpandableNavGroup(
                    label: 'Edit Forms',
                    icon: Icons.edit_note_rounded,
                    items: _editFormItems,
                    location: location,
                  ),
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

class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      decoration: const BoxDecoration(color: _mgmtColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go('/management/dashboard'),
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
                    Text('Management Portal',
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
            child: Row(children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryBlue,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      UserSession.name.isNotEmpty ? UserSession.name : 'Management',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const Text('Management',
                        style: TextStyle(color: Color(0xFFBBDEFB), fontSize: 11)),
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

// ── Expandable nav group ───────────────────────────────────────────────────
class _ExpandableNavGroup extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<_SubItem> items;
  final String location;
  final bool closeDrawer;
  const _ExpandableNavGroup({
    required this.label,
    required this.icon,
    required this.items,
    required this.location,
    this.closeDrawer = false,
  });

  @override
  State<_ExpandableNavGroup> createState() => _ExpandableNavGroupState();
}

class _ExpandableNavGroupState extends State<_ExpandableNavGroup> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.items.any((i) => widget.location == i.route);
  }

  @override
  void didUpdateWidget(_ExpandableNavGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      final active = widget.items.any((i) => widget.location == i.route);
      if (active && !_expanded) setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _expanded ? Colors.white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(widget.icon,
              color: _expanded ? Colors.white : const Color(0xFFBBDEFB),
              size: 20),
          title: Text(widget.label,
              style: TextStyle(
                  color: _expanded ? Colors.white : const Color(0xFFBBDEFB),
                  fontSize: 13,
                  fontWeight: _expanded ? FontWeight.w600 : FontWeight.normal)),
          trailing: Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: const Color(0xFFBBDEFB),
              size: 18),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
      ),
      if (_expanded)
        ...widget.items.map((item) {
          final selected = widget.location == item.route;
          return Container(
            margin: const EdgeInsets.only(left: 20, right: 8, bottom: 2),
            decoration: BoxDecoration(
              color: selected ? AppTheme.sidebarSelectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(item.icon,
                  color: selected ? Colors.white : const Color(0xFFBBDEFB),
                  size: 17),
              title: Text(item.label,
                  style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFBBDEFB),
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () {
                if (widget.closeDrawer) Navigator.of(context).pop();
                GoRouter.of(context).go(item.route);
              },
            ),
          );
        }),
    ]);
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
              children: [
                ..._navItems.map((item) => _SidebarTile(
                    item: item,
                    selected: location == item.route,
                    closeDrawer: true)),
                const _SectionDivider(label: 'Edit Forms'),
                _ExpandableNavGroup(
                  label: 'Edit Forms',
                  icon: Icons.edit_note_rounded,
                  items: _editFormItems,
                  location: location,
                  closeDrawer: true,
                ),
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
