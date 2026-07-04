import 'package:flutter/material.dart';
import '../models/leave_form_config.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';

const _blue  = Color(0xFF0D47A1);
const _green = Color(0xFF2E7D32);

class FormApprovalsPage extends StatefulWidget {
  const FormApprovalsPage({super.key});

  @override
  State<FormApprovalsPage> createState() => _FormApprovalsPageState();
}

class _FormApprovalsPageState extends State<FormApprovalsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;

  List<Map<String, dynamic>> _leaveVersions       = [];
  List<Map<String, dynamic>> _interviewVersions   = [];
  List<Map<String, dynamic>> _onboardingVersions  = [];
  List<Map<String, dynamic>> _policyVersions      = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchLeaveFormVersions(),
        SupabaseService.fetchFormVersions(),
        SupabaseService.fetchOnboardingFormVersions(),
        SupabaseService.fetchHRPolicyVersions(),
      ]);
      if (mounted) setState(() {
        _leaveVersions      = results[0];
        _interviewVersions  = results[1];
        _onboardingVersions = results[2];
        _policyVersions     = results[3];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Approve / reject per form type ────────────────────────────────────────

  Future<void> _approveLeave(String id) async {
    await SupabaseService.updateLeaveFormVersionStatus(
      id, 'approved', decidedBy: UserSession.name);
    LeaveFormConfig.invalidate();
    _load();
  }

  Future<void> _rejectLeave(String id, String note) async {
    await SupabaseService.updateLeaveFormVersionStatus(
      id, 'rejected', decidedBy: UserSession.name, note: note);
    _load();
  }

  Future<void> _approveInterview(String id) async {
    await SupabaseService.updateFormVersionStatus(
      id, 'approved', decidedBy: UserSession.name);
    _load();
  }

  Future<void> _rejectInterview(String id, String note) async {
    await SupabaseService.updateFormVersionStatus(
      id, 'rejected', decidedBy: UserSession.name, note: note);
    _load();
  }

  Future<void> _approveOnboarding(String id) async {
    await SupabaseService.updateOnboardingFormVersionStatus(
      id, 'approved', decidedBy: UserSession.name);
    _load();
  }

  Future<void> _rejectOnboarding(String id, String note) async {
    await SupabaseService.updateOnboardingFormVersionStatus(
      id, 'rejected', decidedBy: UserSession.name, note: note);
    _load();
  }

  Future<void> _approvePolicy(String id) async {
    await SupabaseService.updateHRPolicyVersionStatus(
      id, 'approved', decidedBy: UserSession.name);
    _load();
  }

  Future<void> _rejectPolicy(String id, String note) async {
    await SupabaseService.updateHRPolicyVersionStatus(
      id, 'rejected', decidedBy: UserSession.name, note: note);
    _load();
  }

  // ── Reject dialog ─────────────────────────────────────────────────────────

  Future<String?> _rejectDialog() async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reject — Reason',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Optional note for HR…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return note;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pendingLeave      = _leaveVersions.where(_isPending).length;
    final pendingInterview  = _interviewVersions.where(_isPending).length;
    final pendingOnboarding = _onboardingVersions.where(_isPending).length;
    final pendingPolicy     = _policyVersions.where(_isPending).length;

    return Scaffold(
      backgroundColor: null,
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.approval_rounded, color: _blue, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Form Change Approvals',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _blue)),
                  Text('Approve or reject HR requests to update employee-facing forms',
                      style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                ]),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: _blue),
              ),
            ]),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabs,
              labelColor: _blue,
              unselectedLabelColor: const Color(0xFF78909C),
              indicatorColor: _blue,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              isScrollable: true,
              tabs: [
                _PendingTab('Leave / Perm / Comp Off', Icons.event_available_rounded, pendingLeave),
                _PendingTab('Interview Form',           Icons.assignment_rounded,       pendingInterview),
                _PendingTab('Onboarding Form',          Icons.how_to_reg_rounded,       pendingOnboarding),
                _PendingTab('HR Policy',                Icons.policy_rounded,           pendingPolicy),
              ],
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _VersionList(
                      versions: _leaveVersions,
                      formLabel: 'Leave / Permission / Comp Off Form',
                      onApprove: (id) => _approveLeave(id),
                      onReject: (id) async {
                        final note = await _rejectDialog();
                        if (note != null) _rejectLeave(id, note);
                      },
                    ),
                    _VersionList(
                      versions: _interviewVersions,
                      formLabel: 'Interview / Application Form',
                      onApprove: (id) => _approveInterview(id),
                      onReject: (id) async {
                        final note = await _rejectDialog();
                        if (note != null) _rejectInterview(id, note);
                      },
                    ),
                    _VersionList(
                      versions: _onboardingVersions,
                      formLabel: 'Onboarding Form',
                      onApprove: (id) => _approveOnboarding(id),
                      onReject: (id) async {
                        final note = await _rejectDialog();
                        if (note != null) _rejectOnboarding(id, note);
                      },
                    ),
                    _PolicyVersionList(
                      versions: _policyVersions,
                      onApprove: (id) => _approvePolicy(id),
                      onReject: (id) async {
                        final note = await _rejectDialog();
                        if (note != null) _rejectPolicy(id, note);
                      },
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}

bool _isPending(Map<String, dynamic> v) => (v['status'] as String?) == 'pending';

// ── Tab with pending badge ────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int pending;
  const _PendingTab(this.label, this.icon, this.pending);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Text(label),
        if (pending > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$pending',
                style: const TextStyle(
                    fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
    );
  }
}

// ── Version list for one form type ────────────────────────────────────────────

class _VersionList extends StatelessWidget {
  final List<Map<String, dynamic>> versions;
  final String formLabel;
  final void Function(String id) onApprove;
  final void Function(String id) onReject;
  const _VersionList({
    required this.versions,
    required this.formLabel,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (versions.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No change requests for $formLabel',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ]),
      );
    }

    final pending  = versions.where(_isPending).toList();
    final resolved = versions.where((v) => !_isPending(v)).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (pending.isNotEmpty) ...[
          _SectionLabel('Pending Approval', Colors.orange.shade700, Icons.hourglass_empty_rounded),
          const SizedBox(height: 8),
          ...pending.map((v) => _VersionCard(
            version: v,
            onApprove: () => onApprove(v['id'] as String),
            onReject: () => onReject(v['id'] as String),
          )),
          const SizedBox(height: 20),
        ],
        if (resolved.isNotEmpty) ...[
          const _SectionLabel('History', Color(0xFF78909C), Icons.history_rounded),
          const SizedBox(height: 8),
          ...resolved.map((v) => _VersionCard(version: v)),
        ],
        if (pending.isEmpty && resolved.isEmpty)
          Center(
            child: Text('No versions yet for $formLabel',
                style: const TextStyle(fontSize: 13, color: Color(0xFF90A4AE))),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _SectionLabel(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: color, letterSpacing: 0.5)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: color.withValues(alpha: 0.2))),
    ]);
  }
}

// ── Version card ──────────────────────────────────────────────────────────────

class _VersionCard extends StatelessWidget {
  final Map<String, dynamic> version;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _VersionCard({required this.version, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final vNum       = (version['version_number'] as int?) ?? 0;
    final status     = (version['status'] as String?) ?? 'pending';
    final createdBy  = (version['created_by'] as String?) ?? '';
    final approvedBy = (version['approved_by'] as String?) ?? '';
    final rejection  = (version['rejection_note'] as String?) ?? '';

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
        statusBg = const Color(0xFFE8F5E9); statusFg = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle_rounded; statusLabel = 'Approved';
      case 'rejected':
        statusBg = const Color(0xFFFFEBEE); statusFg = const Color(0xFFC62828);
        statusIcon = Icons.cancel_rounded; statusLabel = 'Rejected';
      default:
        statusBg = const Color(0xFFFFF3E0); statusFg = const Color(0xFFE65100);
        statusIcon = Icons.hourglass_empty_rounded; statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: status == 'pending'
              ? Colors.orange.shade200
              : const Color(0xFFE0E0E0),
          width: status == 'pending' ? 1.5 : 1,
        ),
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
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _blue)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (createdBy.isNotEmpty)
                Text('By $createdBy',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A))),
              if (dateStr.isNotEmpty)
                Text(dateStr,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration:
                BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 12, color: statusFg),
              const SizedBox(width: 4),
              Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11, color: statusFg, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),

        if (approvedBy.isNotEmpty && status == 'approved') ...[
          const SizedBox(height: 5),
          Text('Approved by $approvedBy',
              style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32))),
        ],

        if (rejection.isNotEmpty && status == 'rejected') ...[
          const SizedBox(height: 5),
          Text('Reason: $rejection',
              style: const TextStyle(fontSize: 11, color: Color(0xFFC62828))),
        ],

        if (status == 'pending' && onApprove != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
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
                backgroundColor: _green,
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

// ── HR Policy version list ────────────────────────────────────────────────────
class _PolicyVersionList extends StatelessWidget {
  final List<Map<String, dynamic>> versions;
  final void Function(String id) onApprove;
  final void Function(String id) onReject;

  const _PolicyVersionList({
    required this.versions,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (versions.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.policy_rounded, size: 48, color: Color(0xFFBBDEFB)),
          SizedBox(height: 12),
          Text('No HR Policy versions yet.',
              style: TextStyle(color: Color(0xFF78909C))),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: versions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final v          = versions[i];
        final id         = v['id']?.toString() ?? '';
        final vNum       = v['version_number'] ?? '';
        final status     = (v['status'] as String?) ?? 'pending';
        final createdBy  = (v['created_by'] as String?) ?? '';
        final createdAt  = (v['created_at'] as String?) ?? '';
        final approvedBy = (v['approved_by'] as String?) ?? '';
        final rejNote    = (v['rejection_note'] as String?) ?? '';
        final content    = (v['content'] as String?) ?? '';
        final isPending  = status == 'pending';
        final isApproved = status == 'approved';

        final Color statusColor = isPending
            ? const Color(0xFFF57F17)
            : isApproved
                ? _green
                : Colors.red.shade700;
        final String statusLabel = isPending
            ? 'Pending'
            : isApproved
                ? 'Approved'
                : 'Rejected';

        return Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.policy_rounded, color: statusColor, size: 20),
            ),
            title: Text('HR Policy v$vNum',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'By $createdBy  •  ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
            children: [
              // Preview of policy text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  content.length > 300
                      ? '${content.substring(0, 300)}…'
                      : content,
                  style: const TextStyle(fontSize: 12, height: 1.5,
                      color: Color(0xFF546E7A)),
                ),
              ),
              if (approvedBy.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Decision by: $approvedBy',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF78909C))),
              ],
              if (rejNote.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Note: $rejNote',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.red)),
              ],
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onReject(id),
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Reject', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onApprove(id),
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: const Text('Approve & Publish',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }
}
