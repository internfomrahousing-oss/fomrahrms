import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../models/user_session.dart';
import '../services/user_store.dart';
import '../utils/tenure.dart';
import '../widgets/back_button.dart';

enum _SortOrder { newestFirst, oldestFirst, alphabetical, joinOldNew, joinNewOld }

class HrEmployeeRecordsPage extends StatefulWidget {
  const HrEmployeeRecordsPage({super.key});

  @override
  State<HrEmployeeRecordsPage> createState() => _HrEmployeeRecordsPageState();
}

class _HrEmployeeRecordsPageState extends State<HrEmployeeRecordsPage> {
  static const _color = Color(0xFF2563EB);
  List<AppUser> _all = [];
  List<AppUser> _filtered = [];
  bool _loading = true;
  String _search = '';
  _SortOrder _sort = _SortOrder.newestFirst;

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

  static DateTime _parseJoin(AppUser u) {
    try {
      final p = u.dateOfJoining.split('/');
      if (p.length == 3) return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {}
    return DateTime(2099); // unknown → sort to end
  }

  void _applyFilter() {
    List<AppUser> list = List.from(_all);

    // Search
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((u) =>
          u.name.toLowerCase().contains(q) ||
          u.employeeId.toLowerCase().contains(q) ||
          u.designation.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q)).toList();
    }

    // Sort
    switch (_sort) {
      case _SortOrder.newestFirst:
        list = list.reversed.toList();
      case _SortOrder.oldestFirst:
        break; // keep original insertion order
      case _SortOrder.alphabetical:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortOrder.joinOldNew:
        list.sort((a, b) => _parseJoin(a).compareTo(_parseJoin(b)));
      case _SortOrder.joinNewOld:
        list.sort((a, b) => _parseJoin(b).compareTo(_parseJoin(a)));
    }

    // Active on top, deactivated at bottom
    final active   = list.where((u) =>  u.active).toList();
    final inactive = list.where((u) => !u.active).toList();
    _filtered = [...active, ...inactive];
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
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
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
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, color: _color),
                onPressed: _load,
              ),
              const SizedBox(width: 4),
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
                          const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _color, width: 2),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Sort chips ───────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _SortChip(
                  label: 'Recently Added',
                  icon: Icons.new_releases_rounded,
                  selected: _sort == _SortOrder.newestFirst,
                  onTap: () => setState(() { _sort = _SortOrder.newestFirst; _applyFilter(); }),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Added First',
                  icon: Icons.history_rounded,
                  selected: _sort == _SortOrder.oldestFirst,
                  onTap: () => setState(() { _sort = _SortOrder.oldestFirst; _applyFilter(); }),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'A → Z',
                  icon: Icons.sort_by_alpha_rounded,
                  selected: _sort == _SortOrder.alphabetical,
                  onTap: () => setState(() { _sort = _SortOrder.alphabetical; _applyFilter(); }),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Join Date ↑',
                  icon: Icons.calendar_today_rounded,
                  selected: _sort == _SortOrder.joinOldNew,
                  onTap: () => setState(() { _sort = _SortOrder.joinOldNew; _applyFilter(); }),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Join Date ↓',
                  icon: Icons.calendar_month_rounded,
                  selected: _sort == _SortOrder.joinNewOld,
                  onTap: () => setState(() { _sort = _SortOrder.joinNewOld; _applyFilter(); }),
                ),
              ]),
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
      case 'HR':         return const Color(0xFF2563EB);
      case 'Manager':    return const Color(0xFF111827);
      case 'Management': return const Color(0xFF1D4ED8);
      default:           return const Color(0xFF22C55E);
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
                            color: Color(0xFF111827))),
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
                  const SizedBox(width: 6),
                  _StatusPill(user.leaveStatus),
                  if (user.onrollRequestedAt.isNotEmpty && !user.isOnroll) ...[
                    const SizedBox(width: 6),
                    _Badge('On-Roll Requested', Colors.orange.shade50,
                        Colors.orange.shade200, Colors.orange.shade800),
                  ],
                ]),
                if (user.designation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(user.designation,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
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

class _ProfileDialog extends StatefulWidget {
  final AppUser user;
  final List<AppUser> allUsers;
  final Future<void> Function(AppUser) onSave;
  const _ProfileDialog(
      {required this.user, required this.allUsers, required this.onSave});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  static const _undoWindow = Duration(minutes: 10);
  late AppUser _user;
  Timer? _onrollTimer;
  Timer? _elTimer;
  bool _saving = false;

  static Color _roleColor(String role) {
    switch (role) {
      case 'HR':         return const Color(0xFF2563EB);
      case 'Manager':    return const Color(0xFF111827);
      case 'Management': return const Color(0xFF1D4ED8);
      default:           return const Color(0xFF22C55E);
    }
  }

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _startTimers();
  }

  @override
  void dispose() {
    _onrollTimer?.cancel();
    _elTimer?.cancel();
    super.dispose();
  }

  void _startTimers() {
    if (_canUndoHr || _canUndoManager || _canUndoConfirmed) {
      _onrollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (!_canUndoHr && !_canUndoManager && !_canUndoConfirmed) _onrollTimer?.cancel();
      });
    }
    if (_canUndoEl) {
      _elTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (!_canUndoEl) _elTimer?.cancel();
      });
    }
  }

  bool _canUndo(String status, String decidedAt) {
    if (status == 'pending' || decidedAt.isEmpty) return false;
    try {
      return DateTime.now().difference(DateTime.parse(decidedAt)) < _undoWindow;
    } catch (_) { return false; }
  }

  bool get _canUndoHr => _canUndo(_user.onrollHrStatus, _user.onrollHrDecidedAt);
  bool get _canUndoManager => _canUndo(_user.onrollManagerStatus, _user.onrollManagerDecidedAt);

  bool get _canUndoConfirmed {
    if (_user.onrollConfirmedAt.isEmpty) return false;
    try {
      return DateTime.now().difference(DateTime.parse(_user.onrollConfirmedAt)) < _undoWindow;
    } catch (_) { return false; }
  }

  bool get _canUndoEl {
    if (_user.elEligibleAt.isEmpty) return false;
    try {
      return DateTime.now().difference(DateTime.parse(_user.elEligibleAt)) < _undoWindow;
    } catch (_) { return false; }
  }

  String _countdown(String ts) {
    try {
      final remaining = _undoWindow - DateTime.now().difference(DateTime.parse(ts));
      if (remaining.isNegative) return '';
      final m = remaining.inMinutes;
      final s = remaining.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  Future<String?> _promptDenyComment(String title) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Reason for denial (optional):',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Attendance concerns / Performance',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text('Deny'),
          ),
        ],
      ),
    );
    final result = (ok == true) ? ctrl.text.trim() : null;
    ctrl.dispose();
    return result;
  }

  Future<void> _decideHr(bool accept, {String comment = ''}) async {
    setState(() => _saving = true);
    _user.onrollHrStatus = accept ? 'accepted' : 'denied';
    _user.onrollHrComment = comment;
    _user.onrollHrDecidedAt = DateTime.now().toIso8601String();
    await widget.onSave(_user);
    if (mounted) { setState(() => _saving = false); _startTimers(); }
  }

  Future<void> _decideManager(bool accept, {String comment = ''}) async {
    setState(() => _saving = true);
    _user.onrollManagerStatus = accept ? 'accepted' : 'denied';
    _user.onrollManagerComment = comment;
    _user.onrollManagerDecidedAt = DateTime.now().toIso8601String();
    await widget.onSave(_user);
    if (mounted) { setState(() => _saving = false); _startTimers(); }
  }

  Future<void> _undoOnrollStage(String stage) async {
    setState(() => _saving = true);
    _onrollTimer?.cancel();
    if (stage == 'hr') {
      _user.onrollHrStatus = 'pending';
      _user.onrollHrComment = '';
      _user.onrollHrDecidedAt = '';
    } else if (stage == 'manager') {
      _user.onrollManagerStatus = 'pending';
      _user.onrollManagerComment = '';
      _user.onrollManagerDecidedAt = '';
    }
    await widget.onSave(_user);
    if (mounted) { setState(() => _saving = false); _startTimers(); }
  }

  Future<void> _undoFinalOnroll() async {
    setState(() => _saving = true);
    _onrollTimer?.cancel();
    _elTimer?.cancel();
    _user.onrollConfirmedAt = '';
    _user.onrollManagementStatus = 'pending';
    _user.onrollManagementComment = '';
    _user.onrollManagementDecidedAt = '';
    _user.elEligibleAt = '';
    await widget.onSave(_user);
    if (mounted) setState(() => _saving = false);
  }

  String _resubmitDate(String deniedAtIso) {
    try {
      final d = DateTime.parse(deniedAtIso).add(const Duration(days: 7));
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _onrollStageBlock({
    required String label,
    required String status,
    required String comment,
    required bool canAct,
    required bool canUndo,
    required String countdown,
    required VoidCallback onAccept,
    required VoidCallback onDeny,
    required VoidCallback onUndo,
  }) {
    if (status == 'pending') {
      if (!canAct) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            Icon(Icons.pending_actions_rounded, size: 15, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Awaiting $label review',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800)),
            ),
          ]),
        );
      }
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : onDeny,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Deny'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saving ? null : onAccept,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text('Accept as $label'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]);
    }

    final accepted = status == 'accepted';
    final color = accepted ? Colors.green : Colors.red;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.shade200),
            ),
            child: Row(children: [
              Icon(accepted ? Icons.verified_rounded : Icons.cancel_rounded,
                  size: 15, color: color.shade700),
              const SizedBox(width: 8),
              Text('$label: ${accepted ? 'Accepted' : 'Denied'}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.shade700)),
            ]),
          ),
        ),
        if (canUndo && canAct) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _saving ? null : onUndo,
            icon: const Icon(Icons.undo_rounded, size: 14),
            label: Text('Undo ($countdown)', style: const TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
          ),
        ],
      ]),
      if (!accepted && comment.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(comment, style: TextStyle(fontSize: 12, color: Colors.red.shade800)),
          ),
        ),
    ]);
  }

  Future<void> _confirmEl() async {
    setState(() => _saving = true);
    _user.elEligibleAt = DateTime.now().toIso8601String();
    await widget.onSave(_user);
    _elTimer?.cancel();
    if (mounted) { setState(() => _saving = false); _startTimers(); }
  }

  Future<void> _undoEl() async {
    setState(() => _saving = true);
    _elTimer?.cancel();
    _user.elEligibleAt = '';
    await widget.onSave(_user);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = _roleColor(_user.role);
    final canEdit = UserSession.role == UserRole.hr ||
        UserSession.role == UserRole.management;
    final isHr = UserSession.role == UserRole.hr;
    final isManagement = UserSession.role == UserRole.management;
    // On-roll requests go to HR and the employee's own reporting manager, independently.
    // Management only acts on the separate On-Roll Approvals page once both have accepted.
    final isReportingManager = UserSession.role == UserRole.reportingManager &&
        UserSession.name.trim().toLowerCase() == _user.reportingManager.trim().toLowerCase();
    final canActHr = isHr;
    final canActManager = isReportingManager;
    final canSeeOnrollSection = isHr || isManagement || isReportingManager;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: c.withValues(alpha: 0.12),
                child: Text(
                  _user.name.isNotEmpty ? _user.name[0].toUpperCase() : '?',
                  style: TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_user.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF111827))),
                  if (_user.designation.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(_user.designation,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                  const SizedBox(height: 5),
                  Row(children: [
                    _RoleChip(_user.role, c),
                    const SizedBox(width: 6),
                    _StatusPill(_user.leaveStatus),
                    if (!_user.active) ...[
                      const SizedBox(width: 6),
                      _Badge('Inactive', Colors.red.shade50,
                          Colors.red.shade200, Colors.red.shade600),
                    ],
                  ]),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            _InfoRow(Icons.badge_rounded,           'Employee ID',       _user.employeeId),
            _InfoRow(Icons.email_rounded,           'Email',             _user.email),
            _InfoRow(Icons.phone_rounded,           'Mobile',            _user.mobile),
            _InfoRow(Icons.location_on_rounded,     'Address',           _user.address),
            _InfoRow(Icons.calendar_today_rounded,  'Date of Joining',   _user.dateOfJoining),
            _InfoRow(Icons.hourglass_bottom_rounded, 'Time with Company', tenureLabel(_user.dateOfJoining)),
            _InfoRow(Icons.manage_accounts_rounded, 'Reporting Manager', _user.reportingManager),

            // ── Employment status management ──────────────────────────────
            if (canSeeOnrollSection &&
                (_user.onrollRequestedAt.isNotEmpty || _user.isOnroll)) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.work_history_rounded, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                const Text('Employment Status',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280))),
              ]),
              const SizedBox(height: 10),

              // On-Roll — 3-stage review: HR + Reporting Manager independently, then Management.
              _onrollStageBlock(
                label: 'HR',
                status: _user.onrollHrStatus,
                comment: _user.onrollHrComment,
                canAct: canActHr,
                canUndo: _canUndoHr,
                countdown: _countdown(_user.onrollHrDecidedAt),
                onAccept: () => _decideHr(true),
                onDeny: () async {
                  final c = await _promptDenyComment('Deny HR On-Roll Request');
                  if (c != null) await _decideHr(false, comment: c);
                },
                onUndo: () => _undoOnrollStage('hr'),
              ),
              const SizedBox(height: 8),
              _onrollStageBlock(
                label: 'Reporting Manager',
                status: _user.onrollManagerStatus,
                comment: _user.onrollManagerComment,
                canAct: canActManager,
                canUndo: _canUndoManager,
                countdown: _countdown(_user.onrollManagerDecidedAt),
                onAccept: () => _decideManager(true),
                onDeny: () async {
                  final c = await _promptDenyComment('Deny Manager On-Roll Request');
                  if (c != null) await _decideManager(false, comment: c);
                },
                onUndo: () => _undoOnrollStage('manager'),
              ),
              const SizedBox(height: 8),

              // Management stage — read-only here; actioned from the On-Roll Approvals page.
              if (_user.isOnroll)
                Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.verified_rounded, size: 15, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text('On-Roll confirmed (unlocks ML + CL)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: Colors.green.shade700)),
                      ]),
                    ),
                  ),
                  if (_canUndoConfirmed && canEdit) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _saving ? null : _undoFinalOnroll,
                      icon: const Icon(Icons.undo_rounded, size: 14),
                      label: Text('Undo (${_countdown(_user.onrollConfirmedAt)})',
                          style: const TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                    ),
                  ],
                ])
              else if (_user.onrollManagementDenied)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.cancel_rounded, size: 15, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _user.onrollManagementComment.isNotEmpty
                            ? 'Denied by Management: "${_user.onrollManagementComment}"'
                            : 'Denied by Management',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                            color: Colors.red.shade700),
                      ),
                    ),
                  ]),
                )
              else if (_user.onrollAwaitingManagement)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.hourglass_top_rounded, size: 15, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Awaiting Management review',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700)),
                    ),
                  ]),
                ),

              if (_user.onrollDenied && !_user.onrollCanResubmit)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Employee can resubmit on ${_resubmitDate(_user.onrollDeniedAt)}.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ),

              // EL Eligibility (HR/Management only, once on-roll)
              if (_user.isOnroll && canEdit) ...[
                const SizedBox(height: 8),
                if (!_user.isElEligible)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _confirmEl,
                      icon: const Icon(Icons.event_available_rounded, size: 16),
                      label: const Text('Confirm EL Eligibility (1 year on-roll)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple.shade700,
                        side: BorderSide(color: Colors.purple.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                else
                  Row(children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.event_available_rounded, size: 15, color: Colors.purple.shade700),
                          const SizedBox(width: 8),
                          Text('EL eligible',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: Colors.purple.shade700)),
                        ]),
                      ),
                    ),
                    if (_canUndoEl) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _saving ? null : _undoEl,
                        icon: const Icon(Icons.undo_rounded, size: 14),
                        label: Text('Undo (${_countdown(_user.elEligibleAt)})',
                            style: const TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                      ),
                    ],
                  ]),
              ],
              const SizedBox(height: 4),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _FullProfileDialog(user: _user),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: const Text('Interview & Onboarding Records'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (canEdit) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _user.active = !_user.active;
                    widget.onSave(_user);
                    Navigator.pop(context);
                  },
                  icon: Icon(_user.active ? Icons.person_off_rounded : Icons.person_rounded, size: 16),
                  label: Text(_user.active ? 'Deactivate Account' : 'Activate Account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _user.active ? Colors.red : Colors.green,
                    side: BorderSide(color: _user.active ? Colors.red : Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => _EditDialog(
                        user: _user,
                        allUsers: widget.allUsers,
                        onSave: widget.onSave,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

// ── Full profile: interview + onboarding data ─────────────────────────────────

class _FullProfileDialog extends StatefulWidget {
  final AppUser user;
  const _FullProfileDialog({required this.user});
  @override
  State<_FullProfileDialog> createState() => _FullProfileDialogState();
}

class _FullProfileDialogState extends State<_FullProfileDialog>
    with SingleTickerProviderStateMixin {
  static const _c = Color(0xFF2563EB);
  late final TabController _tabs;
  Map<String, dynamic>? _onboarding;
  Map<String, dynamic>? _interview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    final db = Supabase.instance.client;
    final name = widget.user.name;
    final email = widget.user.email;
    try {
      final ob = await db.from('onboarding_forms').select().or('name.ilike.%$name%,phone_number.eq.$email').limit(1);
      final ca = await db.from('candidate_applications').select().or('name.ilike.%$name%,email.eq.$email').limit(1);
      setState(() {
        _onboarding = (ob as List).isNotEmpty ? ob.first : null;
        _interview  = (ca as List).isNotEmpty ? ca.first : null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Widget _row(String label, dynamic value) {
    final v = (value?.toString() ?? '').trim();
    if (v.isEmpty || v == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 170,
            child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12, color: Color(0xFF111827)))),
      ]),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    final nonEmpty = rows.whereType<Padding>().toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _c)),
      const Divider(height: 8),
      ...rows,
    ]);
  }

  Widget _onboardingView(Map<String, dynamic> d) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _section('Basic Info', [
        _row('Name', d['name']), _row('Phone', d['phone_number']),
        _row('Designation', d['designation']), _row('Date of Joining', d['date_of_joining']),
      ]),
      _section('Personal', [
        _row('Full Name', d['full_name']), _row('Date of Birth', d['date_of_birth']),
        _row('Father Name', d['father_name']),
        _row('Postal Address', d['postal_address']), _row('Permanent Address', d['permanent_address']),
      ]),
      _section('Emergency', [
        _row('Blood Group', d['blood_group']), _row('Allergic To', d['allergic_to']),
        _row('Emergency Contact', d['emergency_contact_name']),
        _row('Emergency Number', d['emergency_contact_number']),
        _row('Aadhar Number', d['aadhar_number']),
      ]),
      _section('Additional', [
        _row('ESI Number', d['esi_number']), _row('PF Number', d['pf_number']),
        _row('Languages', d['languages_known']), _row('Hobbies', d['hobbies']),
      ]),
    ],
  );

  Widget _interviewView(Map<String, dynamic> d) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _section('Application', [
        _row('Name', d['name']), _row('Post Applied', d['post_applied']),
        _row('Interview Date', d['interview_date']), _row('Mobile', d['mobile']),
        _row('Email', d['email']), _row('Place', d['place']),
        _row('Date of Birth', d['dob']), _row('Gender', d['gender']),
        _row('Nationality', d['nationality']), _row('Marital Status', d['marital_status']),
      ]),
      _section('Experience', [
        _row('Total Experience', d['total_experience']),
        _row('Relevant Experience', d['relevant_experience']),
        _row('Reason for Change', d['reason_for_change']),
        _row('Current CTC', d['current_ctc']), _row('Expected CTC', d['expected_ctc']),
        _row('Notice Period', d['notice_period']),
      ]),
      _section('HR Review', [
        _row('HR Status', d['hr_status']), _row('HR Comment', d['hr_comment']),
        _row('Manager Status', d['manager_status']), _row('Manager Comment', d['manager_comment']),
        _row('Management Status', d['management_status']),
      ]),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _c,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.user.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(widget.user.designation,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          TabBar(
            controller: _tabs,
            indicatorColor: _c,
            labelColor: _c,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.assignment_ind_rounded, size: 18), text: 'Onboarding'),
              Tab(icon: Icon(Icons.work_history_rounded, size: 18), text: 'Interview'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _c))
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _onboarding != null
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: _onboardingView(_onboarding!))
                          : const Center(child: Text('No onboarding form found for this employee.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey))),
                      _interview != null
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: _interviewView(_interview!))
                          : const Center(child: Text('No interview application found for this employee.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey))),
                    ],
                  ),
          ),
        ]),
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
  static const _color = Color(0xFF2563EB);
  static const _domain = '@fomrahousing.in';

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _empIdCtrl;
  late final TextEditingController _bioIdCtrl;
  late final TextEditingController _desigCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _joiningCtrl;
  late final TextEditingController _leaveCtrl;
  late final TextEditingController _grossPayCtrl;
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
    _bioIdCtrl   = TextEditingController(text: u?.biometricId ?? '');
    _desigCtrl   = TextEditingController(text: u?.designation ?? '');
    _mobileCtrl  = TextEditingController(text: u?.mobile ?? '');
    _addressCtrl = TextEditingController(text: u?.address ?? '');
    _joiningCtrl = TextEditingController(text: u?.dateOfJoining ?? '');
    _leaveCtrl   = TextEditingController(
        text: (u?.leaveAllocation ?? 21).toString());
    _grossPayCtrl = TextEditingController(
        text: u != null && u.grossPay > 0 ? u.grossPay.toStringAsFixed(0) : '');
    _role    = u?.role ?? 'Employee';
    _manager = u?.reportingManager ?? '';
    _active  = u?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _emailCtrl, _empIdCtrl, _bioIdCtrl, _desigCtrl,
      _mobileCtrl, _addressCtrl, _joiningCtrl, _leaveCtrl, _grossPayCtrl,
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
      biometricId:      _bioIdCtrl.text.trim(),
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
      onrollConfirmedAt:  widget.user?.onrollConfirmedAt ?? '',
      elEligibleAt:       widget.user?.elEligibleAt ?? '',
      elAvailRequestedAt: widget.user?.elAvailRequestedAt ?? '',
      elLastAvailedAt:    widget.user?.elLastAvailedAt ?? '',
      grossPay:         double.tryParse(_grossPayCtrl.text.trim()) ??
                        (widget.user?.grossPay ?? 0),
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
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _color, width: 2),
          ),
          filled: true,
          fillColor: fillColor ?? Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        ),
      ),
    );
  }

  InputDecoration _dropDeco(BuildContext context, String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _color, size: 20),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _color, width: 2),
    ),
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
    labelStyle: const TextStyle(color: Color(0xFF6B7280)),
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
                        const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: _color, width: 2),
                  ),
                  filled: true,
                  fillColor:
                      isNew ? Colors.white : const Color(0xFFF8FAFC),
                  labelStyle:
                      const TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            ),

            _field(_empIdCtrl,   'Employee ID',               Icons.badge_rounded),
            _field(_bioIdCtrl,   'Biometric ID (Device PIN)', Icons.fingerprint_rounded),
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
                  color: Color(0xFF6B7280)),
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

            _field(_grossPayCtrl, 'Gross Pay (Rs / month)',
                Icons.account_balance_wallet_rounded,
                keyboard: TextInputType.number),

            // Role dropdown
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: _role,
                decoration: _dropDeco(context, 'Role', Icons.shield_rounded),
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
                      context, 'Reporting Manager',
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
              color: null,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side:
                    const BorderSide(color: Color(0xFFE5E7EB)),
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
              style: TextStyle(color: Color(0xFF6B7280))),
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

// ── Sort chip ─────────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.icon,
      required this.selected, required this.onTap});

  static const _color = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _color : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13,
              color: selected ? Colors.white : const Color(0xFF6B7280)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);

  Color get _color => switch (status) {
    'EL Eligible' => const Color(0xFF2563EB),
    'On-Roll'     => const Color(0xFF22C55E),
    _             => const Color(0xFF6B7280),
  };

  IconData get _icon => switch (status) {
    'EL Eligible' => Icons.event_available_rounded,
    'On-Roll'     => Icons.verified_rounded,
    _             => Icons.timelapse_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

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
        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(id,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB))),
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
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        SizedBox(
          width: 140,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280))),
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
