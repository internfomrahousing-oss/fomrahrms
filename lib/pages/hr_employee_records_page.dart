import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/user_session.dart';
import '../services/user_store.dart';

class HrEmployeeRecordsPage extends StatefulWidget {
  const HrEmployeeRecordsPage({super.key});

  @override
  State<HrEmployeeRecordsPage> createState() => _HrEmployeeRecordsPageState();
}

class _HrEmployeeRecordsPageState extends State<HrEmployeeRecordsPage> {
  static const _color = Color(0xFF0D47A1);
  List<AppUser> _all = [];
  List<AppUser> _filtered = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await UserStore.load();
    if (!mounted) return;
    setState(() {
      _all = _baseList(users);
      _applyFilter();
      _loading = false;
    });
  }

  // Managers see only employees assigned to them; HR/management see everyone.
  List<AppUser> _baseList(List<AppUser> users) {
    if (UserSession.role != UserRole.reportingManager) return users;
    final me = UserSession.name.trim().toLowerCase();
    if (me.isEmpty) return users;
    return users
        .where((u) => u.reportingManager.trim().toLowerCase() == me)
        .toList();
  }

  void _applyFilter() {
    if (_search.trim().isEmpty) {
      _filtered = List.from(_all);
      return;
    }
    final q = _search.toLowerCase();
    _filtered = _all
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.employeeId.toLowerCase().contains(q) ||
            u.designation.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _saveUser(AppUser user) async {
    await UserStore.upsertOne(user);
    if (!mounted) return;
    setState(() {
      final idx = _all.indexWhere((u) => u.email == user.email);
      if (idx >= 0) {
        _all[idx] = user;
      } else {
        _all.add(user);
      }
      _applyFilter();
    });
  }

  void _openProfile(AppUser user) {
    showDialog(
      context: context,
      builder: (_) => _ProfileDialog(user: user, allUsers: _all, onSave: _saveUser),
    );
  }

  void _openCreate() {
    showDialog(
      context: context,
      builder: (_) => _EditDialog(user: null, allUsers: _all, onSave: _saveUser),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people_alt_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Employee Records',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              if (UserSession.role == UserRole.hr ||
                  UserSession.role == UserRole.management)
                ElevatedButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add New'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
            const SizedBox(height: 24),

            // ── Search ───────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (v) => setState(() {
                    _search = v;
                    _applyFilter();
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, designation, email...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _color, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _color, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── List ─────────────────────────────────────────────────────
            if (_loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.people_outline_rounded,
                          size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text(
                        _all.isEmpty
                            ? 'No employee records yet. Tap "Add New" to add one.'
                            : 'No results for "$_search"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14),
                      ),
                    ]),
                  ),
                ),
              )
            else
              ..._filtered.map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UserCard(user: u, onTap: () => _openProfile(u)),
                  )),
          ],
        ),
      ),
    );
  }
}

// ── Employee card ─────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  const _UserCard({required this.user, required this.onTap});

  static Color _roleColor(String role) {
    switch (role) {
      case 'HR':         return const Color(0xFF0D47A1);
      case 'Manager':    return const Color(0xFF1A237E);
      case 'Management': return const Color(0xFF4A148C);
      default:           return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _roleColor(user.role);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: c.withValues(alpha: 0.12),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: c, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                    child: Text(user.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A237E))),
                  ),
                  if (!user.active)
                    _Badge('Inactive', Colors.red.shade50,
                        Colors.red.shade200, Colors.red.shade600),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  if (user.employeeId.isNotEmpty) ...[
                    _IdChip(user.employeeId),
                    const SizedBox(width: 8),
                  ],
                  _RoleChip(user.role, c),
                ]),
                if (user.designation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(user.designation,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF78909C))),
                ],
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF90A4AE))),
                ],
              ]),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Profile detail dialog ─────────────────────────────────────────────────────

class _ProfileDialog extends StatelessWidget {
  final AppUser user;
  final List<AppUser> allUsers;
  final Future<void> Function(AppUser) onSave;
  const _ProfileDialog(
      {required this.user, required this.allUsers, required this.onSave});

  static Color _roleColor(String role) {
    switch (role) {
      case 'HR':         return const Color(0xFF0D47A1);
      case 'Manager':    return const Color(0xFF1A237E);
      case 'Management': return const Color(0xFF4A148C);
      default:           return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _roleColor(user.role);
    final canEdit = UserSession.role == UserRole.hr ||
        UserSession.role == UserRole.management;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Avatar + name header
            Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: c.withValues(alpha: 0.12),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: c, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(user.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E))),
                  if (user.designation.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(user.designation,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF546E7A))),
                  ],
                  const SizedBox(height: 5),
                  Row(children: [
                    _RoleChip(user.role, c),
                    if (!user.active) ...[
                      const SizedBox(width: 6),
                      _Badge('Inactive', Colors.red.shade50,
                          Colors.red.shade200, Colors.red.shade600),
                    ],
                  ]),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: Color(0xFF78909C)),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            _InfoRow(Icons.badge_rounded,           'Employee ID',       user.employeeId),
            _InfoRow(Icons.email_rounded,           'Email',             user.email),
            _InfoRow(Icons.phone_rounded,           'Mobile',            user.mobile),
            _InfoRow(Icons.location_on_rounded,     'Address',           user.address),
            _InfoRow(Icons.calendar_today_rounded,  'Date of Joining',   user.dateOfJoining),
            _InfoRow(Icons.manage_accounts_rounded, 'Reporting Manager', user.reportingManager),
            _InfoRow(Icons.event_note_rounded,      'Leave Allocation',
                user.leaveAllocation > 0
                    ? '${user.leaveAllocation} days / year'
                    : ''),

            if (canEdit) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => _EditDialog(
                        user: user,
                        allUsers: allUsers,
                        onSave: onSave,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Edit / Create dialog ──────────────────────────────────────────────────────

class _EditDialog extends StatefulWidget {
  final AppUser? user; // null = creating new
  final List<AppUser> allUsers;
  final Future<void> Function(AppUser) onSave;
  const _EditDialog(
      {required this.user, required this.allUsers, required this.onSave});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  static const _color = Color(0xFF0D47A1);
  static const _domain = '@fomrahousing.in';

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _empIdCtrl;
  late final TextEditingController _desigCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _joiningCtrl;
  late final TextEditingController _leaveCtrl;
  late String _role;
  late String _manager;
  late bool _active;
  bool _saving = false;

  static String _prefix(String email) => email.endsWith(_domain)
      ? email.substring(0, email.length - _domain.length)
      : email;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl    = TextEditingController(text: u?.name ?? '');
    _emailCtrl   = TextEditingController(text: u != null ? _prefix(u.email) : '');
    _empIdCtrl   = TextEditingController(text: u?.employeeId ?? '');
    _desigCtrl   = TextEditingController(text: u?.designation ?? '');
    _mobileCtrl  = TextEditingController(text: u?.mobile ?? '');
    _addressCtrl = TextEditingController(text: u?.address ?? '');
    _joiningCtrl = TextEditingController(text: u?.dateOfJoining ?? '');
    _leaveCtrl   = TextEditingController(
        text: (u?.leaveAllocation ?? 21).toString());
    _role    = u?.role ?? 'Employee';
    _manager = u?.reportingManager ?? '';
    _active  = u?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _emailCtrl, _empIdCtrl, _desigCtrl,
      _mobileCtrl, _addressCtrl, _joiningCtrl, _leaveCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name   = _nameCtrl.text.trim();
    final prefix = _emailCtrl.text.trim();
    if (name.isEmpty || prefix.isEmpty) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    final today =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final joiningVal = _joiningCtrl.text.trim();
    final existingJoining = widget.user?.dateOfJoining ?? '';
    final reportingMgr =
        (['Employee', 'Manager'].contains(_role)) ? _manager : '';

    final updated = AppUser(
      name:             name,
      email:            '$prefix$_domain',
      employeeId:       _empIdCtrl.text.trim(),
      designation:      _desigCtrl.text.trim(),
      role:             _role,
      active:           _active,
      password:         widget.user?.password ?? '',
      leaveAllocation:  int.tryParse(_leaveCtrl.text.trim()) ??
                        (widget.user?.leaveAllocation ?? 21),
      reportingManager: reportingMgr,
      mobile:           _mobileCtrl.text.trim(),
      address:          _addressCtrl.text.trim(),
      dateOfJoining:    joiningVal.isNotEmpty
                            ? joiningVal
                            : (existingJoining.isNotEmpty
                                ? existingJoining
                                : today),
    );

    await widget.onSave(updated);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.user == null
              ? '${updated.name} added successfully'
              : 'Profile updated'),
          backgroundColor: _color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  List<String> get _managerNames => widget.allUsers
      .where((u) => u.role == 'Manager')
      .map((u) => u.name)
      .toList();

  Widget _field(TextEditingController ctrl, String label, IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffix,
    Color? fillColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _color, size: 20),
          suffixIcon: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _color, width: 2),
          ),
          filled: true,
          fillColor: fillColor ?? Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF78909C)),
        ),
      ),
    );
  }

  InputDecoration _dropDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _color, size: 20),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _color, width: 2),
    ),
    filled: true,
    fillColor: Colors.white,
    labelStyle: const TextStyle(color: Color(0xFF78909C)),
  );

  @override
  Widget build(BuildContext context) {
    final isNew = widget.user == null;
    final mgrs  = _managerNames;

    return AlertDialog(
      title: Text(
        isNew ? 'Add Employee' : 'Edit Profile',
        style:
            const TextStyle(color: _color, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(_nameCtrl, 'Full Name', Icons.person_rounded),

            // Email with @fomrahousing.in suffix
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                readOnly: !isNew,
                decoration: InputDecoration(
                  labelText: isNew ? 'Username' : 'Email',
                  prefixIcon: const Icon(Icons.email_rounded,
                      color: _color, size: 20),
                  suffix: const Text('@fomrahousing.in',
                      style: TextStyle(
                          color: _color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: _color, width: 2),
                  ),
                  filled: true,
                  fillColor:
                      isNew ? Colors.white : const Color(0xFFF5F5F5),
                  labelStyle:
                      const TextStyle(color: Color(0xFF78909C)),
                ),
              ),
            ),

            _field(_empIdCtrl,   'Employee ID',               Icons.badge_rounded),
            _field(_desigCtrl,   'Designation',               Icons.work_rounded),
            _field(_mobileCtrl,  'Mobile',                    Icons.phone_rounded,
                keyboard: TextInputType.phone),
            _field(_addressCtrl, 'Address',                   Icons.location_on_rounded,
                maxLines: 2),

            // Date of joining
            _field(
              _joiningCtrl, 'Date of Joining',
              Icons.calendar_today_rounded,
              readOnly: true,
              suffix: const Icon(Icons.arrow_drop_down_rounded,
                  color: Color(0xFF78909C)),
              onTap: () async {
                DateTime initial = DateTime.now();
                if (_joiningCtrl.text.isNotEmpty) {
                  final p = _joiningCtrl.text.split('/');
                  if (p.length == 3) {
                    try {
                      initial = DateTime(
                          int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
                    } catch (_) {}
                  }
                }
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  _joiningCtrl.text =
                      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                }
              },
            ),

            _field(_leaveCtrl, 'Leave Allocation (days / year)',
                Icons.event_note_rounded,
                keyboard: TextInputType.number),

            // Role dropdown
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: _role,
                decoration: _dropDeco('Role', Icons.shield_rounded),
                items: ['Employee', 'Manager', 'HR', 'Management']
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _role = v);
                },
              ),
            ),

            // Reporting manager (only for Employee / Manager roles)
            if (['Employee', 'Manager'].contains(_role) &&
                mgrs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  value: mgrs.contains(_manager) ? _manager : null,
                  decoration: _dropDeco(
                      'Reporting Manager',
                      Icons.manage_accounts_rounded),
                  hint: const Text('None assigned'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('None')),
                    ...mgrs.map((m) =>
                        DropdownMenuItem(value: m, child: Text(m))),
                  ],
                  onChanged: (v) => setState(() => _manager = v ?? ''),
                ),
              ),
            ],

            // Active toggle
            Card(
              color: const Color(0xFFF5F7FA),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side:
                    const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              child: SwitchListTile(
                value: _active,
                activeColor: _color,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('Active',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(
                    _active ? 'User can log in' : 'Login disabled',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF78909C))),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(isNew ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String label;
  final Color color;
  const _RoleChip(this.label, this.color);

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
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _IdChip extends StatelessWidget {
  final String id;
  const _IdChip(this.id);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(id,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D47A1))),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color text;
  const _Badge(this.label, this.bg, this.border, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: text, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF0D47A1)),
        const SizedBox(width: 10),
        SizedBox(
          width: 140,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF78909C))),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF263238))),
        ),
      ]),
    );
  }
}
