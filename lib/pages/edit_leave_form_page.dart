import 'package:flutter/material.dart';
import '../models/leave_form_config.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

Color get _blue => AppTheme.primaryBlue;
Color get _purple => AppTheme.primaryBlue;
Color get _teal => AppTheme.accentBlue;
const _green  = Color(0xFF22C55E);

class _Section {
  final String key;
  final String label;
  final IconData icon;
  final String hint;
  const _Section(this.key, this.label, this.icon, this.hint);
}

class _FormGroup {
  final String formName;
  final IconData formIcon;
  final Color color;
  final List<_Section> sections;
  const _FormGroup(this.formName, this.formIcon, this.color, this.sections);
}

List<_FormGroup> get _formGroups => [
  _FormGroup('Apply Leave Form', Icons.event_note_rounded, _purple, [
    _Section('leave_types', 'Leave Types', Icons.event_available_rounded,
        'Dropdown options in the Apply Leave form.'),
  ]),
  _FormGroup('Apply Permission Form', Icons.access_time_rounded, _teal, [
    _Section('permission_durations', 'Duration Options', Icons.hourglass_bottom_rounded,
        '"Off For" dropdown — how long the employee will be away.'),
    _Section('permission_reasons', 'Reason Options', Icons.label_rounded,
        '"Reason" dropdown — why the employee needs permission.'),
  ]),
  _FormGroup('Apply Comp Off Form', Icons.swap_horiz_rounded, _green, [
    _Section('compoff_reasons', 'Reason Options', Icons.label_rounded,
        '"Reason for Request" dropdown in the Comp Off form.'),
  ]),
];

class EditLeaveFormPage extends StatefulWidget {
  const EditLeaveFormPage({super.key});

  @override
  State<EditLeaveFormPage> createState() => _EditLeaveFormPageState();
}

class _EditLeaveFormPageState extends State<EditLeaveFormPage> {
  bool _loading = true;
  bool _saving  = false;

  // working copy of all 4 option lists
  late Map<String, List<String>> _config;

  int _nextVersionNumber = 1;
  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = false;

  bool get _isManagement => UserSession.role == UserRole.management;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final active = await SupabaseService.fetchActiveLeaveFormConfig();
      final cfg = active != null
          ? Map<String, dynamic>.from(active['form_config'] as Map)
          : LeaveFormConfig.defaults();
      _config = {
        'leave_types':          LeaveFormConfig.getLeaveTypes(cfg),
        'permission_durations': LeaveFormConfig.getPermissionDurations(cfg),
        'permission_reasons':   LeaveFormConfig.getPermissionReasons(cfg),
        'compoff_reasons':      LeaveFormConfig.getCompOffReasons(cfg),
      };
      _nextVersionNumber = await SupabaseService.getNextLeaveFormVersionNumber();
    } catch (_) {
      final def = LeaveFormConfig.defaults();
      _config = {
        'leave_types':          LeaveFormConfig.getLeaveTypes(def),
        'permission_durations': LeaveFormConfig.getPermissionDurations(def),
        'permission_reasons':   LeaveFormConfig.getPermissionReasons(def),
        'compoff_reasons':      LeaveFormConfig.getCompOffReasons(def),
      };
    }
    if (mounted) setState(() => _loading = false);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    final versions = await SupabaseService.fetchLeaveFormVersions();
    if (mounted) setState(() { _history = versions; _historyLoading = false; });
  }

  // ── Save actions ─────────────────────────────────────────────────────────

  Future<void> _saveAction() async {
    if (_isManagement) {
      await _publishDirectly();
    } else {
      await _sendForApproval();
    }
  }

  Future<void> _publishDirectly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Update & Publish',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        content: const Text(
            'This will immediately update the Leave, Permission, and Comp Off forms for all employees.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update & Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await SupabaseService.saveLeaveFormVersion({
        'form_config': _config,
        'status': 'approved',
        'version_number': _nextVersionNumber,
        'created_by': UserSession.name.isNotEmpty ? UserSession.name : 'Management',
        'approved_by': UserSession.name.isNotEmpty ? UserSession.name : 'Management',
        'approved_at': DateTime.now().toUtc().toIso8601String(),
      });
      LeaveFormConfig.invalidate(); // clear client-side cache
      if (mounted) {
        setState(() => _nextVersionNumber++);
        _snack('Leave form options published successfully.', _green);
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _sendForApproval() async {
    final pending = _history.where((v) => (v['status'] as String?) == 'pending').length;
    if (pending > 0) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Pending Approval Exists',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange)),
          content: const Text(
              'There is already a version waiting for Management approval. '
              'Please wait for it to be reviewed before submitting another.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Send for Approval',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        content: const Text(
            'The updated form options will be sent to Management for approval. '
            'The current live options remain active until the new version is approved.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send for Approval'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await SupabaseService.saveLeaveFormVersion({
        'form_config': _config,
        'status': 'pending',
        'version_number': _nextVersionNumber,
        'created_by': UserSession.name.isNotEmpty ? UserSession.name : 'HR',
      });
      if (mounted) {
        _snack('Sent to Management for approval.', _green);
        _nextVersionNumber++;
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    }
    if (mounted) setState(() => _saving = false);
  }

  // ── Management: approve / reject a pending version ─────────────────────

  Future<void> _approveVersion(Map<String, dynamic> version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Approve & Publish',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _green)),
        content: const Text(
            'This will approve and immediately apply these form changes for all employees.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await SupabaseService.updateLeaveFormVersionStatus(
        version['id'] as String,
        'approved',
        decidedBy: UserSession.name.isNotEmpty ? UserSession.name : 'Management',
      );
      LeaveFormConfig.invalidate();
      if (mounted) {
        _snack('Version approved and published.', _green);
        await Future.wait([_load(), _loadHistory()]);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _rejectVersion(Map<String, dynamic> version) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reject Version',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
        content: TextField(
          controller: noteCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Reason for rejection (optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    noteCtrl.dispose();
    if (confirmed != true) return;

    try {
      await SupabaseService.updateLeaveFormVersionStatus(
        version['id'] as String,
        'rejected',
        decidedBy: UserSession.name.isNotEmpty ? UserSession.name : 'Management',
        note: noteCtrl.text.trim(),
      );
      if (mounted) {
        _snack('Version rejected.', Colors.red.shade700);
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    }
  }

  // ── Option list editor ────────────────────────────────────────────────────

  Future<void> _editOptions(String key, String label, Color color) async {
    final workingList = List<String>.from(_config[key] ?? []);
    final addCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Edit $label',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hold and drag to reorder · tap × to remove',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ReorderableListView(
                    shrinkWrap: true,
                    onReorder: (oldIdx, newIdx) {
                      setS(() {
                        if (newIdx > oldIdx) newIdx--;
                        final item = workingList.removeAt(oldIdx);
                        workingList.insert(newIdx, item);
                      });
                    },
                    children: workingList.asMap().entries.map((e) => ListTile(
                      key: ValueKey('opt_${e.key}_${e.value}'),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.drag_handle_rounded,
                          size: 16, color: Color(0xFFE5E7EB)),
                      title: Text(e.value, style: const TextStyle(fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                        onPressed: () => setS(() => workingList.removeAt(e.key)),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: addCtrl,
                      decoration: InputDecoration(
                        hintText: 'Add option…',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (val) {
                        val = val.trim();
                        if (val.isNotEmpty) setS(() { workingList.add(val); addCtrl.clear(); });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final val = addCtrl.text.trim();
                      if (val.isNotEmpty) setS(() { workingList.add(val); addCtrl.clear(); });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Add'),
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() => _config[key] = workingList);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    addCtrl.dispose();
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit_note_rounded, color: _blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Edit Leave Forms',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _blue)),
                Text('Customise dropdown options for Leave, Permission & Comp Off',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ]),
            ),
            if (!_loading) ...[
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveAction,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_isManagement ? Icons.publish_rounded : Icons.send_rounded, size: 16),
                label: Text(_saving
                    ? (_isManagement ? 'Publishing…' : 'Sending…')
                    : (_isManagement ? 'Update & Publish' : 'Send for Approval'),
                    style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isManagement ? _blue : _purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
                  : Icon(Icons.refresh_rounded, color: _blue),
            ),
          ]),
        ),
        const Divider(height: 1),

        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: _blue))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.lightBlue,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Row(children: [
                              Icon(Icons.info_outline_rounded, color: _blue, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isManagement
                                      ? 'You can edit and publish changes directly, or approve/reject versions sent by HR.'
                                      : 'Edit dropdown options for each form and tap "Send for Approval". Management will review your changes.',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 24),

                          // ── Section cards ──────────────────────────────
                          const _HeadingRow(label: 'Form Options', icon: Icons.tune_rounded),
                          const SizedBox(height: 12),
                          ..._formGroups.map((g) => _FormGroupCard(
                            group: g,
                            config: _config,
                            onEdit: (key, label) => _editOptions(key, label, g.color),
                          )),

                          const SizedBox(height: 28),

                          // ── Version history ───────────────────────────
                          const _HeadingRow(label: 'Version History', icon: Icons.history_rounded),
                          const SizedBox(height: 12),
                          if (_historyLoading)
                            Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator(color: _blue)),
                            )
                          else if (_history.isEmpty)
                            _emptyHistory()
                          else
                            ..._history.map((v) => _VersionCard(
                              version: v,
                              isManagement: _isManagement,
                              onApprove: () => _approveVersion(v),
                              onReject: () => _rejectVersion(v),
                            )),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _emptyHistory() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history_rounded, size: 38, color: Color(0xFFDBEAFE)),
        SizedBox(height: 10),
        Text('No versions yet',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        SizedBox(height: 4),
        Text('Submitted versions will appear here.',
            style: TextStyle(fontSize: 11, color: Color(0xFFE5E7EB))),
      ]),
    ),
  );
}

// ── Form group card ────────────────────────────────────────────────────────────

class _FormGroupCard extends StatelessWidget {
  final _FormGroup group;
  final Map<String, List<String>> config;
  final void Function(String key, String label) onEdit;
  const _FormGroupCard({required this.group, required this.config, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final c = group.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Coloured header band ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: c.withValues(alpha: 0.18))),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(group.formIcon, color: c, size: 17),
            ),
            const SizedBox(width: 10),
            Text(group.formName,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c)),
          ]),
        ),

        // ── Sub-sections ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: group.sections.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final options = config[s.key] ?? [];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (i > 0) ...[
                  Divider(height: 24, color: c.withValues(alpha: 0.15)),
                ],
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(s.icon, color: c, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
                      Text(s.hint,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                    ]),
                  ),
                  TextButton.icon(
                    onPressed: () => onEdit(s.key, s.label),
                    icon: const Icon(Icons.tune_rounded, size: 13),
                    label: const Text('Edit', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: c,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ]),
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 5,
                    children: options.map((o) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.withValues(alpha: 0.22)),
                      ),
                      child: Text(o, style: TextStyle(fontSize: 11, color: c)),
                    )).toList(),
                  ),
                ],
              ]);
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Version history card ───────────────────────────────────────────────────────

class _VersionCard extends StatelessWidget {
  final Map<String, dynamic> version;
  final bool isManagement;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _VersionCard({
    required this.version,
    required this.isManagement,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final vNum        = (version['version_number'] as int?) ?? 0;
    final status      = (version['status'] as String?) ?? 'pending';
    final createdBy   = (version['created_by'] as String?) ?? '';
    final approvedBy  = (version['approved_by'] as String?) ?? '';
    final rejection   = (version['rejection_note'] as String?) ?? '';

    String dateStr = '';
    try {
      final raw = version['created_at'];
      if (raw != null) {
        final dt = DateTime.parse(raw.toString()).toLocal();
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    Color statusBg, statusFg;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusBg = const Color(0xFFDCFCE7); statusFg = const Color(0xFF22C55E);
        statusIcon = Icons.check_circle_rounded; statusLabel = 'Approved';
      case 'rejected':
        statusBg = const Color(0xFFFEE2E2); statusFg = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded; statusLabel = 'Rejected';
      default:
        statusBg = const Color(0xFFFEF3C7); statusFg = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_empty_rounded; statusLabel = 'Pending Approval';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('v$vNum',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blue)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (createdBy.isNotEmpty)
                Text('By $createdBy',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              if (dateStr.isNotEmpty)
                Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 12, color: statusFg),
              const SizedBox(width: 4),
              Text(statusLabel,
                  style: TextStyle(fontSize: 11, color: statusFg, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),

        if (approvedBy.isNotEmpty && status == 'approved') ...[
          const SizedBox(height: 6),
          Text('Approved by $approvedBy',
              style: const TextStyle(fontSize: 11, color: Color(0xFF22C55E))),
        ],

        if (rejection.isNotEmpty && status == 'rejected') ...[
          const SizedBox(height: 6),
          Text('Reason: $rejection',
              style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
        ],

        // Management can approve or reject pending versions
        if (isManagement && status == 'pending') ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),
          Row(children: [
            OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded, size: 14),
              label: const Text('Reject', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_rounded, size: 14),
              label: const Text('Approve & Publish', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── Heading row ───────────────────────────────────────────────────────────────

class _HeadingRow extends StatelessWidget {
  final String label;
  final IconData icon;
  const _HeadingRow({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: _blue, size: 15),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: Color(0xFF111827))),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
    ]);
  }
}
