import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/user_session.dart';
import '../services/user_store.dart';
import '../theme/app_theme.dart';
import '../widgets/back_button.dart';

/// Groups employees by their Reporting Manager and lets HR/Management add or
/// remove people from a manager's team, and flag any employee as RM-eligible.
/// Every mutation here creates a pending request awaiting Management
/// approval — same flow as editing an employee's Reporting Manager field
/// directly (see hr_employee_records_page.dart), just a grouped view of it.
class ReportingManagersPage extends StatefulWidget {
  const ReportingManagersPage({super.key});

  @override
  State<ReportingManagersPage> createState() => _ReportingManagersPageState();
}

class _ReportingManagersPageState extends State<ReportingManagersPage> {
  static Color get _color => AppTheme.primaryBlue;
  List<AppUser> _users = [];
  bool _loading = true;

  bool get _canEdit =>
      UserSession.role == UserRole.hr || UserSession.role == UserRole.management;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final users = await UserStore.load();
    if (!mounted) return;
    setState(() { _users = users; _loading = false; });
  }

  List<AppUser> get _rms => _users
      .where((u) => u.isReportingManager && u.active)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  List<AppUser> _reportsOf(AppUser rm) => _users
      .where((u) => u.reportingManager.trim().toLowerCase() == rm.name.trim().toLowerCase())
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  List<AppUser> get _pendingMgrChanges =>
      _users.where((u) => u.hasPendingReportingManagerChange).toList();
  List<AppUser> get _pendingFlagChanges =>
      _users.where((u) => u.hasPendingRmFlagChange).toList();

  Future<void> _requestManagerChange(AppUser user, String newManagerName) async {
    await UserStore.requestReportingManagerChange(user, newManagerName);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newManagerName.isEmpty
          ? 'Requested removal of ${user.name} — awaiting Management approval'
          : 'Requested ${user.name} → $newManagerName — awaiting Management approval'),
      backgroundColor: _color,
    ));
  }

  Future<void> _requestFlagChange(AppUser user, bool newValue) async {
    await UserStore.requestRmFlagChange(user, newValue);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Requested ${newValue ? 'making' : 'removing'} ${user.name} ${newValue ? 'a Reporting Manager' : 'as a Reporting Manager'} — awaiting Management approval'),
      backgroundColor: _color,
    ));
  }

  Future<void> _pickEmployeeToAdd(AppUser rm) async {
    final candidates = _users
        .where((u) => u.active && u.email != rm.email &&
            u.reportingManager.trim().toLowerCase() != rm.name.trim().toLowerCase())
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (candidates.isEmpty) return;

    final picked = await showDialog<AppUser>(
      context: context,
      builder: (ctx) => _SearchPickerDialog(
        title: 'Add to ${rm.name}\'s team',
        users: candidates,
      ),
    );
    if (picked != null) await _requestManagerChange(picked, rm.name);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canEdit) {
      return const Scaffold(body: Center(child: Text('Not authorized')));
    }
    return Scaffold(
      backgroundColor: null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const NavBackButton(),
                      const SizedBox(width: 8),
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.lightBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_tree_rounded,
                            color: AppTheme.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text('Reporting Managers',
                          style: Theme.of(context).textTheme.headlineMedium),
                    ]),
                    const SizedBox(height: 20),
                    if (_pendingMgrChanges.isNotEmpty || _pendingFlagChanges.isNotEmpty) ...[
                      _PendingCard(
                        mgrChanges: _pendingMgrChanges,
                        flagChanges: _pendingFlagChanges,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _ManageFlagsCard(
                      users: _users.where((u) => u.active).toList(),
                      onToggle: _requestFlagChange,
                    ),
                    const SizedBox(height: 16),
                    Text('Teams', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    if (_rms.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No Reporting Managers yet — flag someone above to get started.',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ),
                        ),
                      )
                    else
                      for (final rm in _rms) ...[
                        _RmTeamCard(
                          rm: rm,
                          reports: _reportsOf(rm),
                          onAdd: () => _pickEmployeeToAdd(rm),
                          onRemove: (u) => _requestManagerChange(u, ''),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final List<AppUser> mgrChanges;
  final List<AppUser> flagChanges;
  const _PendingCard({required this.mgrChanges, required this.flagChanges});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.pending_actions_rounded, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text('Awaiting Management Approval',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
            ]),
            const SizedBox(height: 10),
            for (final u in mgrChanges)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                    '${u.name}: ${u.reportingManager.isEmpty ? '—' : u.reportingManager} → '
                    '${u.reportingManagerPending.isEmpty ? 'None' : u.reportingManagerPending}',
                    style: const TextStyle(fontSize: 12.5)),
              ),
            for (final u in flagChanges)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                    '${u.name}: ${u.isReportingManagerPending ? 'Requested Make RM' : 'Requested Remove RM'}',
                    style: const TextStyle(fontSize: 12.5)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManageFlagsCard extends StatefulWidget {
  final List<AppUser> users;
  final void Function(AppUser user, bool newValue) onToggle;
  const _ManageFlagsCard({required this.users, required this.onToggle});

  @override
  State<_ManageFlagsCard> createState() => _ManageFlagsCardState();
}

class _ManageFlagsCardState extends State<_ManageFlagsCard> {
  bool _expanded = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.users
        .where((u) => u.name.toLowerCase().contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.supervisor_account_rounded, color: AppTheme.primaryBlue),
          title: const Text('Manage Reporting Managers',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Flag any employee as RM-eligible (requires Management approval)',
              style: TextStyle(fontSize: 12)),
          trailing: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search employees…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final u = filtered[i];
                return SwitchListTile(
                  value: u.isReportingManager,
                  activeColor: AppTheme.primaryBlue,
                  title: Text(u.name, style: const TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                      u.hasPendingRmFlagChange
                          ? 'Requested: ${u.isReportingManagerPending ? 'Make RM' : 'Remove RM'} (awaiting Management)'
                          : '${u.role} · ${u.designation}',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: u.hasPendingRmFlagChange ? Colors.orange.shade800 : Colors.grey.shade600)),
                  onChanged: (v) => widget.onToggle(u, v),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],
      ]),
    );
  }
}

class _RmTeamCard extends StatelessWidget {
  final AppUser rm;
  final List<AppUser> reports;
  final VoidCallback onAdd;
  final void Function(AppUser user) onRemove;
  const _RmTeamCard({
    required this.rm,
    required this.reports,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                child: Text(rm.name.isNotEmpty ? rm.name[0].toUpperCase() : '?',
                    style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rm.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text('${rm.role} · ${reports.length} report${reports.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
                ),
              ),
            ]),
            if (reports.isNotEmpty) ...[
              const Divider(height: 20),
              for (final u in reports)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(u.name, style: const TextStyle(fontSize: 13)),
                    ),
                    Text(u.designation,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove from team',
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.red),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onRemove(u),
                    ),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchPickerDialog extends StatefulWidget {
  final String title;
  final List<AppUser> users;
  const _SearchPickerDialog({required this.title, required this.users});

  @override
  State<_SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<_SearchPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.users
        .where((u) => u.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search employees…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No matching employees'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final u = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(u.name),
                        subtitle: Text('${u.role} · ${u.designation}'),
                        onTap: () => Navigator.pop(context, u),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
