import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/user_store.dart';

const _mgmtColor = Color(0xFF4A148C);
const _mgmtLight = Color(0xFFF3E5F5);

class _Role {
  String name;
  String description;
  _Role({required this.name, required this.description});
}

// ── Page ──────────────────────────────────────────────────────────────────────

class AdministrationPage extends StatefulWidget {
  const AdministrationPage({super.key});

  @override
  State<AdministrationPage> createState() => _AdministrationPageState();
}

class _AdministrationPageState extends State<AdministrationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<AppUser> _users = [];
  bool _saving = false;

  final List<_Role> _roles = [
    _Role(name: 'Employee',   description: 'Personal attendance, leave, tasks and payslips'),
    _Role(name: 'Manager',    description: 'Team leave approvals, performance, task assignment'),
    _Role(name: 'HR',         description: 'Employee records, payroll, recruitment, reporting'),
    _Role(name: 'Management', description: 'Full system access — overruling authority'),
  ];

  final Map<String, bool> _access = {
    'Employees':   true,
    'Attendance':  true,
    'Payroll':     true,
    'GPS Tracking':true,
    'Reports':     true,
    'Approvals':   true,
  };

  static const _accessIcons = {
    'Employees':    Icons.people_rounded,
    'Attendance':   Icons.access_time_rounded,
    'Payroll':      Icons.account_balance_wallet_rounded,
    'GPS Tracking': Icons.location_on_rounded,
    'Reports':      Icons.bar_chart_rounded,
    'Approvals':    Icons.approval_rounded,
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await UserStore.load();
    if (mounted) setState(() => _users = users);
  }

  Future<void> _upsertUser(AppUser u) async {
    if (_saving) return;
    setState(() => _saving = true);
    await UserStore.upsertOne(u);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _deleteUser(AppUser u) async {
    if (_saving) return;
    setState(() { _users.remove(u); _saving = true; });
    await UserStore.deleteOne(u.email);
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final hPad = narrow ? 16.0 : 24.0;

    return Material(
      color: const Color(0xFFF5F7FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header + tabs ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(hPad, narrow ? 16 : 24, hPad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!narrow) ...[
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _mgmtLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                          color: _mgmtColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Administration',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _mgmtColor)),
                      const Text('Management access only',
                          style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
                    ]),
                  ]),
                  const SizedBox(height: 20),
                ],
                TabBar(
                  controller: _tabs,
                  labelColor: _mgmtColor,
                  unselectedLabelColor: const Color(0xFF78909C),
                  indicatorColor: _mgmtColor,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(icon: Icon(Icons.group_add_rounded, size: 18), text: 'Users'),
                    Tab(icon: Icon(Icons.shield_rounded, size: 18), text: 'Roles'),
                    Tab(icon: Icon(Icons.lock_open_rounded, size: 18), text: 'Access Control'),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab body ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _UsersTab(users: _users, roles: _roles, onUpsert: _upsertUser, onDelete: _deleteUser),
                _RolesTab(roles: _roles, onChange: () => setState(() {})),
                _AccessTab(access: _access, icons: _accessIcons, onChange: () => setState(() {})),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Users tab ─────────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  final List<AppUser> users;
  final List<_Role> roles;
  final Future<void> Function(AppUser) onUpsert;
  final Future<void> Function(AppUser) onDelete;
  const _UsersTab({required this.users, required this.roles, required this.onUpsert, required this.onDelete});

  Color _roleColor(String role) {
    switch (role) {
      case 'HR':         return const Color(0xFF0D47A1);
      case 'Manager':    return const Color(0xFF1A237E);
      case 'Management': return _mgmtColor;
      default:           return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final hPad = narrow ? 16.0 : 24.0;

    return ListView(
      padding: EdgeInsets.all(hPad),
      children: [
        // ── Add user button ──────────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('All Users (${users.length})',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _mgmtColor)),
          ElevatedButton.icon(
            onPressed: () => _showUserDialog(context, null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _mgmtColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // ── Empty state ──────────────────────────────────────────────────
        if (users.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.group_off_rounded, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No users added yet',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Text('Click "Create User" to add the first user.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ]),
            ),
          ),

        // ── User cards ───────────────────────────────────────────────────
        ...users.map((u) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _roleColor(u.role).withValues(alpha: 0.15),
                child: Text(
                  u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: _roleColor(u.role),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(u.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    if (!u.active)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text('Inactive',
                            style: TextStyle(fontSize: 10, color: Colors.red.shade600)),
                      ),
                  ]),
                  const SizedBox(height: 2),
                  Text(u.email,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF78909C))),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (u.designation.isNotEmpty) ...[
                      _Chip(label: u.designation, color: const Color(0xFF546E7A)),
                      const SizedBox(width: 6),
                    ],
                    _Chip(label: u.role, color: _roleColor(u.role)),
                  ]),
                  if ((u.role == 'Employee' || u.role == 'Manager') && u.reportingManager.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.manage_accounts_rounded, size: 11, color: Color(0xFF90A4AE)),
                      const SizedBox(width: 4),
                      Text('Reports to: ${u.reportingManager}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE))),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              // Action buttons
              Column(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Edit User',
                  onPressed: () => _showUserDialog(context, u),
                  icon: const Icon(Icons.edit_rounded, size: 18, color: _mgmtColor),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: u.active ? 'Deactivate User' : 'Activate User',
                  onPressed: () { u.active = !u.active; onUpsert(u); },
                  icon: Icon(
                    u.active ? Icons.person_off_rounded : Icons.person_rounded,
                    size: 18,
                    color: u.active ? Colors.red.shade400 : Colors.green.shade600,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Delete User',
                  onPressed: () => _confirmDelete(context, u, onDelete),
                  icon: const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFB71C1C)),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ]),
          ),
        )),
      ],
    );
  }

  static const _domain = '@fomrahousing.in';

  // Strip domain to get just the username prefix for editing
  static String _emailPrefix(String? email) {
    if (email == null) return '';
    return email.endsWith(_domain)
        ? email.substring(0, email.length - _domain.length)
        : email;
  }

  void _showUserDialog(BuildContext context, AppUser? existing) {
    final nameCtrl  = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: _emailPrefix(existing?.email));
    final empIdCtrl = TextEditingController(text: existing?.employeeId ?? '');
    final desigCtrl = TextEditingController(text: existing?.designation ?? '');
    String selectedRole = existing?.role ?? 'Employee';
    String selectedManager = existing?.reportingManager ?? '';
    final roleNames = ['Employee', 'Manager', 'HR', 'Management'];
    final managerNames = users.where((u) => u.role == 'Manager').map((u) => u.name).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(
            existing == null ? 'Create User' : 'Edit User',
            style: const TextStyle(color: _mgmtColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _DialogField(controller: nameCtrl, label: 'Full Name', icon: Icons.person_rounded),
              const SizedBox(height: 12),
              // Email with fixed @fomrahousing.in domain
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.email_rounded, color: _mgmtColor, size: 20),
                  suffix: const Text('@fomrahousing.in',
                      style: TextStyle(color: _mgmtColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _mgmtColor, width: 2),
                  ),
                  filled: true, fillColor: Colors.white,
                  labelStyle: const TextStyle(color: Color(0xFF78909C)),
                ),
              ),
              const SizedBox(height: 12),
              _DialogField(controller: empIdCtrl, label: 'Employee ID (e.g. EMP001)', icon: Icons.badge_rounded),
              const SizedBox(height: 12),
              _DialogField(controller: desigCtrl, label: 'Designation', icon: Icons.work_rounded),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: InputDecoration(
                  labelText: 'Role',
                  prefixIcon: const Icon(Icons.shield_rounded, color: _mgmtColor, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _mgmtColor, width: 2),
                  ),
                  filled: true, fillColor: Colors.white,
                ),
                items: roleNames.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) { if (v != null) setS(() => selectedRole = v); },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _mgmtLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: _mgmtColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _roleDashboardNote(selectedRole),
                      style: const TextStyle(fontSize: 11, color: _mgmtColor),
                    ),
                  ),
                ]),
              ),
              if ((selectedRole == 'Employee' || selectedRole == 'Manager') && managerNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: managerNames.contains(selectedManager) ? selectedManager : null,
                  decoration: InputDecoration(
                    labelText: 'Reporting Manager',
                    prefixIcon: const Icon(Icons.manage_accounts_rounded, color: _mgmtColor, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _mgmtColor, width: 2),
                    ),
                    filled: true, fillColor: Colors.white,
                  ),
                  hint: const Text('None assigned'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('None')),
                    ...managerNames.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                  ],
                  onChanged: (v) => setS(() => selectedManager = v ?? ''),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
            ),
            ElevatedButton(
              onPressed: () {
                final prefix = emailCtrl.text.trim();
                if (nameCtrl.text.trim().isEmpty || prefix.isEmpty) return;
                final fullEmail = '$prefix$_domain';
                final AppUser target;
                final now = DateTime.now();
                final todayStr =
                    '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

                if (existing == null) {
                  target = AppUser(
                    name:             nameCtrl.text.trim(),
                    email:            fullEmail,
                    employeeId:       empIdCtrl.text.trim(),
                    designation:      desigCtrl.text.trim(),
                    role:             selectedRole,
                    reportingManager: (selectedRole == 'Employee' || selectedRole == 'Manager') ? selectedManager : '',
                    dateOfJoining:    todayStr,
                  );
                  users.add(target);
                } else {
                  existing.name             = nameCtrl.text.trim();
                  existing.email            = fullEmail;
                  existing.employeeId       = empIdCtrl.text.trim();
                  existing.designation      = desigCtrl.text.trim();
                  existing.role             = selectedRole;
                  existing.reportingManager = (selectedRole == 'Employee' || selectedRole == 'Manager') ? selectedManager : '';
                  if (existing.dateOfJoining.isEmpty) existing.dateOfJoining = todayStr;
                  target = existing;
                }
                onUpsert(target);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _mgmtColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppUser u, Future<void> Function(AppUser) onDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User',
            style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.bold)),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Color(0xFF37474F)),
            children: [
              const TextSpan(text: 'Are you sure you want to permanently delete '),
              TextSpan(
                text: u.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete(u);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _roleDashboardNote(String role) {
    switch (role) {
      case 'Employee':   return 'This user will access the Employee Dashboard.';
      case 'Manager':    return 'This user will access the Manager Dashboard.';
      case 'HR':         return 'This user will access the HR Admin Dashboard.';
      case 'Management': return 'This user will access the Management Dashboard with full access.';
      default:           return '';
    }
  }
}

// ── Roles tab ─────────────────────────────────────────────────────────────────

class _RolesTab extends StatelessWidget {
  final List<_Role> roles;
  final VoidCallback onChange;
  const _RolesTab({required this.roles, required this.onChange});

  Color _color(String name) {
    switch (name) {
      case 'HR':         return const Color(0xFF0D47A1);
      case 'Manager':    return const Color(0xFF1A237E);
      case 'Management': return _mgmtColor;
      default:           return const Color(0xFF2E7D32);
    }
  }

  IconData _icon(String name) {
    switch (name) {
      case 'HR':         return Icons.admin_panel_settings_rounded;
      case 'Manager':    return Icons.supervisor_account_rounded;
      case 'Management': return Icons.manage_accounts_rounded;
      default:           return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final hPad = narrow ? 16.0 : 24.0;

    return ListView(
      padding: EdgeInsets.all(hPad),
      children: [
        const Text('System Roles',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _mgmtColor)),
        const SizedBox(height: 4),
        const Text('Edit role names and descriptions as needed.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
        const SizedBox(height: 16),
        ...roles.map((r) {
          final c = _color(r.name);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon(r.name), color: c, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: c)),
                    const SizedBox(height: 3),
                    Text(r.description,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A))),
                  ]),
                ),
                IconButton(
                  tooltip: 'Edit Role',
                  onPressed: () => _showEditDialog(context, r),
                  icon: const Icon(Icons.edit_rounded, size: 18, color: _mgmtColor),
                ),
              ]),
            ),
          );
        }),
      ],
    );
  }

  void _showEditDialog(BuildContext context, _Role role) {
    final nameCtrl = TextEditingController(text: role.name);
    final descCtrl = TextEditingController(text: role.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Role',
            style: TextStyle(color: _mgmtColor, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _DialogField(controller: nameCtrl, label: 'Role Name',   icon: Icons.shield_rounded),
          const SizedBox(height: 12),
          _DialogField(controller: descCtrl, label: 'Description', icon: Icons.description_rounded, maxLines: 2),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              role.name        = nameCtrl.text.trim();
              role.description = descCtrl.text.trim();
              onChange();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _mgmtColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ── Access Control tab ────────────────────────────────────────────────────────

class _AccessTab extends StatelessWidget {
  final Map<String, bool> access;
  final Map<String, IconData?> icons;
  final VoidCallback onChange;
  const _AccessTab({required this.access, required this.icons, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final hPad = narrow ? 16.0 : 24.0;
    final keys = access.keys.toList();

    return ListView(
      padding: EdgeInsets.all(hPad),
      children: [
        const Text('Control Access',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _mgmtColor)),
        const SizedBox(height: 4),
        const Text('Enable or disable module access across the system.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
        const SizedBox(height: 16),
        ...keys.map((key) {
          final enabled = access[key] ?? true;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: enabled
                      ? _mgmtColor.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icons[key] ?? Icons.settings_rounded,
                  color: enabled ? _mgmtColor : Colors.grey.shade400,
                  size: 20,
                ),
              ),
              title: Text(key,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: enabled ? const Color(0xFF1A237E) : Colors.grey.shade500)),
              subtitle: Text(
                enabled ? 'Access enabled for all roles' : 'Access currently disabled',
                style: TextStyle(
                    fontSize: 11,
                    color: enabled ? const Color(0xFF546E7A) : Colors.grey.shade400),
              ),
              trailing: Switch(
                value: enabled,
                activeColor: _mgmtColor,
                onChanged: (v) { access[key] = v; onChange(); },
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _mgmtLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _mgmtColor.withValues(alpha: 0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: _mgmtColor),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Management always retains full access regardless of these settings.',
                style: TextStyle(fontSize: 12, color: _mgmtColor),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final int maxLines;
  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboard,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _mgmtColor, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _mgmtColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Color(0xFF78909C)),
      ),
    );
  }
}
