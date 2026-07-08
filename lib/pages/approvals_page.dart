import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/leave_form_config.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../utils/form_version_label.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

/// Central inbox for Management: every approval type in the system, piled
/// up under its own heading. Each section is actionable inline where the
/// underlying decision is a simple approve/deny; a "View all" link jumps to
/// the dedicated page for deeper history/filtering.
class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  bool _loading = true;
  List<AppUser> _users = [];
  List<Map<String, dynamic>> _leaveVersions = [];
  List<Map<String, dynamic>> _interviewVersions = [];
  List<Map<String, dynamic>> _onboardingVersions = [];
  List<Map<String, dynamic>> _policyVersions = [];
  Map<int, String> _interviewLabels = {};
  Map<int, String> _onboardingLabels = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchLeaveApplications().timeout(const Duration(seconds: 8)),
        UserStore.load(),
        SupabaseService.fetchLeaveFormVersions(),
        SupabaseService.fetchFormVersions(),
        SupabaseService.fetchOnboardingFormVersions(),
        SupabaseService.fetchHRPolicyVersions(),
      ]);
      final leaves = results[0] as List<LeaveApplication>;
      if (leaves.isNotEmpty) {
        LeaveStore.applications
          ..clear()
          ..addAll(leaves);
        LeaveStore.syncCounter();
      }
      if (!mounted) return;
      final interviewVersions = results[3] as List<Map<String, dynamic>>;
      final onboardingVersions = results[4] as List<Map<String, dynamic>>;
      setState(() {
        _users = results[1] as List<AppUser>;
        _leaveVersions = results[2] as List<Map<String, dynamic>>;
        _interviewVersions = interviewVersions;
        _onboardingVersions = onboardingVersions;
        _policyVersions = results[5] as List<Map<String, dynamic>>;
        _interviewLabels = computeFormVersionLabels(interviewVersions);
        _onboardingLabels = computeFormVersionLabels(onboardingVersions);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Pending slices ──────────────────────────────────────────────────────

  bool _isPermCompOff(LeaveApplication a) =>
      a.leaveType == 'Permission' || a.leaveType == 'Comp Off';

  List<LeaveApplication> get _pendingLeave => LeaveStore.applications
      .where((a) => !_isPermCompOff(a) && a.managerStatus == LeaveApprovalStatus.pending)
      .toList();
  List<LeaveApplication> get _pendingPermission => LeaveStore.applications
      .where((a) => a.leaveType == 'Permission' && a.managerStatus == LeaveApprovalStatus.pending)
      .toList();
  List<LeaveApplication> get _pendingCompOff => LeaveStore.applications
      .where((a) => a.leaveType == 'Comp Off' && a.managerStatus == LeaveApprovalStatus.pending)
      .toList();

  List<AppUser> get _pendingOnroll =>
      _users.where((u) => u.onrollAwaitingManagement).toList();
  List<AppUser> get _pendingGrossPay =>
      _users.where((u) => u.hasPendingGrossPayChange).toList();
  List<AppUser> get _pendingWorkLocation =>
      _users.where((u) => u.hasPendingWorkLocationChange).toList();

  List<Map<String, dynamic>> _pendingOf(List<Map<String, dynamic>> versions) =>
      versions.where((v) => (v['status'] as String?) == 'pending').toList();

  int get _totalPending =>
      _pendingLeave.length +
      _pendingPermission.length +
      _pendingCompOff.length +
      _pendingOnroll.length +
      _pendingGrossPay.length +
      _pendingWorkLocation.length +
      _pendingOf(_leaveVersions).length +
      _pendingOf(_interviewVersions).length +
      _pendingOf(_onboardingVersions).length +
      _pendingOf(_policyVersions).length;

  // ── Leave / Permission / Comp Off actions ───────────────────────────────

  Future<void> _approveLeave(LeaveApplication app) async {
    final by = UserSession.name;
    setState(() {
      app.managerStatus = LeaveApprovalStatus.approved;
      app.decidedBy = by;
      app.rejectionComment = '';
      app.decidedAt = DateTime.now();
      app.managementDecided = true;
    });
    await SupabaseService.updateLeaveManagementStatus(
        app.id, LeaveApprovalStatus.approved, decidedBy: by);
  }

  Future<void> _denyLeave(LeaveApplication app) async {
    final comment = await _reasonDialog(
        title: 'Deny Leave', hint: 'e.g. Insufficient notice / Busy period');
    if (comment == null) return;
    final by = UserSession.name;
    setState(() {
      app.managerStatus = LeaveApprovalStatus.denied;
      app.decidedBy = by;
      app.rejectionComment = comment;
      app.decidedAt = DateTime.now();
      app.managementDecided = true;
    });
    await SupabaseService.updateLeaveManagementStatus(
        app.id, LeaveApprovalStatus.denied, decidedBy: by, rejectionComment: comment);
  }

  // ── On-Roll actions ──────────────────────────────────────────────────────

  Future<void> _approveOnroll(AppUser u) async {
    setState(() {
      u.onrollManagementStatus = 'accepted';
      u.onrollManagementComment = '';
      u.onrollManagementDecidedAt = DateTime.now().toIso8601String();
      u.onrollConfirmedAt = DateTime.now().toIso8601String();
    });
    await UserStore.upsertOne(u);
  }

  Future<void> _denyOnroll(AppUser u) async {
    final comment = await _reasonDialog(
        title: 'Deny On-Roll Request', hint: 'e.g. Performance concerns');
    if (comment == null) return;
    setState(() {
      u.onrollManagementStatus = 'denied';
      u.onrollManagementComment = comment;
      u.onrollManagementDecidedAt = DateTime.now().toIso8601String();
    });
    await UserStore.upsertOne(u);
  }

  // ── Gross Pay / Work Location actions ────────────────────────────────────

  Future<void> _decideGrossPay(AppUser u, bool approve) async {
    setState(() {
      if (approve) u.grossPay = u.grossPayPending;
      u.grossPayPending = 0;
      u.grossPayRequestedAt = '';
    });
    await UserStore.upsertOne(u);
  }

  Future<void> _decideWorkLocation(AppUser u, bool approve) async {
    setState(() {
      if (approve) u.workLocation = u.workLocationPending;
      u.workLocationPending = '';
      u.workLocationRequestedAt = '';
    });
    await UserStore.upsertOne(u);
  }

  // ── Form version actions ─────────────────────────────────────────────────

  Future<void> _approveForm(String kind, String id) async {
    switch (kind) {
      case 'leave':
        await SupabaseService.updateLeaveFormVersionStatus(id, 'approved', decidedBy: UserSession.name);
        LeaveFormConfig.invalidate();
      case 'interview':
        await SupabaseService.updateFormVersionStatus(id, 'approved', decidedBy: UserSession.name);
      case 'onboarding':
        await SupabaseService.updateOnboardingFormVersionStatus(id, 'approved', decidedBy: UserSession.name);
      case 'policy':
        await SupabaseService.updateHRPolicyVersionStatus(id, 'approved', decidedBy: UserSession.name);
    }
    _load();
  }

  Future<void> _rejectForm(String kind, String id) async {
    final note = await _reasonDialog(title: 'Reject — Reason', hint: 'Optional note for HR…');
    if (note == null) return;
    switch (kind) {
      case 'leave':
        await SupabaseService.updateLeaveFormVersionStatus(id, 'rejected', decidedBy: UserSession.name, note: note);
      case 'interview':
        await SupabaseService.updateFormVersionStatus(id, 'rejected', decidedBy: UserSession.name, note: note);
      case 'onboarding':
        await SupabaseService.updateOnboardingFormVersionStatus(id, 'rejected', decidedBy: UserSession.name, note: note);
      case 'policy':
        await SupabaseService.updateHRPolicyVersionStatus(id, 'rejected', decidedBy: UserSession.name, note: note);
    }
    _load();
  }

  Future<String?> _reasonDialog({required String title, required String hint}) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    return result == true ? text : null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlueDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.approval_rounded, color: AppTheme.primaryBlueDark, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Approvals', style: Theme.of(context).textTheme.headlineMedium),
                  const Text('Everything awaiting your decision, in one place',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ]),
              ),
              if (!_loading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_totalPending > 0 ? Colors.orange.shade700 : Colors.green.shade700)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$_totalPending pending',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _totalPending > 0 ? Colors.orange.shade700 : Colors.green.shade700)),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Refresh',
                icon: Icon(Icons.refresh_rounded, color: AppTheme.primaryBlueDark),
                onPressed: _load,
              ),
            ]),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_totalPending == 0) _allCaughtUpBanner(),
              _ApprovalSection(
                icon: Icons.event_note_rounded,
                color: const Color(0xFF111827),
                label: 'Leave Applications',
                count: _pendingLeave.length,
                onViewAll: () => context.push('/management/leave/overview'),
                children: _pendingLeave
                    .map((a) => _leaveCard(a, onApprove: () => _approveLeave(a), onDeny: () => _denyLeave(a)))
                    .toList(),
              ),
              _ApprovalSection(
                icon: Icons.access_time_rounded,
                color: AppTheme.accentBlue,
                label: 'Permission Applications',
                count: _pendingPermission.length,
                onViewAll: () => context.push('/management/leave/overview'),
                children: _pendingPermission
                    .map((a) => _leaveCard(a, onApprove: () => _approveLeave(a), onDeny: () => _denyLeave(a)))
                    .toList(),
              ),
              _ApprovalSection(
                icon: Icons.swap_horiz_rounded,
                color: const Color(0xFF22C55E),
                label: 'Comp Off Applications',
                count: _pendingCompOff.length,
                onViewAll: () => context.push('/management/leave/overview'),
                children: _pendingCompOff
                    .map((a) => _leaveCard(a, onApprove: () => _approveLeave(a), onDeny: () => _denyLeave(a)))
                    .toList(),
              ),
              _ApprovalSection(
                icon: Icons.verified_user_rounded,
                color: AppTheme.sidebarSelectedBg,
                label: 'On-Roll Requests',
                count: _pendingOnroll.length,
                onViewAll: () => context.push('/management/onroll-approvals'),
                children: _pendingOnroll
                    .map((u) => _onrollCard(u, onApprove: () => _approveOnroll(u), onDeny: () => _denyOnroll(u)))
                    .toList(),
              ),
              _ApprovalSection(
                icon: Icons.currency_rupee_rounded,
                color: Colors.indigo.shade700,
                label: 'Gross Pay Change Requests',
                count: _pendingGrossPay.length,
                children: _pendingGrossPay
                    .map((u) => _grossPayCard(u,
                        onApprove: () => _decideGrossPay(u, true), onDeny: () => _decideGrossPay(u, false)))
                    .toList(),
              ),
              _ApprovalSection(
                icon: Icons.location_on_rounded,
                color: Colors.teal.shade700,
                label: 'Work Location Change Requests',
                count: _pendingWorkLocation.length,
                children: _pendingWorkLocation
                    .map((u) => _workLocationCard(u,
                        onApprove: () => _decideWorkLocation(u, true), onDeny: () => _decideWorkLocation(u, false)))
                    .toList(),
              ),
              _ApprovalSection(
                icon: Icons.event_available_rounded,
                color: AppTheme.primaryBlue,
                label: 'Leave Form Approvals',
                count: _pendingOf(_leaveVersions).length,
                onViewAll: () => context.push('/management/form-approvals'),
                children: _pendingOf(_leaveVersions)
                    .map((v) => _formCard(v, kind: 'leave', label: null,
                        onApprove: () => _approveForm('leave', v['id'] as String),
                        onDeny: () => _rejectForm('leave', v['id'] as String)))
                    .toList(),
              ),
              _ApprovalSection(
                icon: Icons.assignment_rounded,
                color: AppTheme.primaryBlue,
                label: 'Interview Form Approvals',
                count: _pendingOf(_interviewVersions).length,
                onViewAll: () => context.push('/management/form-approvals'),
                children: _pendingOf(_interviewVersions)
                    .map((v) => _formCard(v, kind: 'interview',
                        label: _interviewLabels[(v['version_number'] as num?)?.toInt()],
                        onApprove: () => _approveForm('interview', v['id'] as String),
                        onDeny: () => _rejectForm('interview', v['id'] as String)))
                    .toList(),
              ),
              _ApprovalSection(
                icon: Icons.how_to_reg_rounded,
                color: AppTheme.primaryBlue,
                label: 'Onboarding Form Approvals',
                count: _pendingOf(_onboardingVersions).length,
                onViewAll: () => context.push('/management/form-approvals'),
                children: _pendingOf(_onboardingVersions)
                    .map((v) => _formCard(v, kind: 'onboarding',
                        label: _onboardingLabels[(v['version_number'] as num?)?.toInt()],
                        onApprove: () => _approveForm('onboarding', v['id'] as String),
                        onDeny: () => _rejectForm('onboarding', v['id'] as String)))
                    .toList(),
              ),
              _ApprovalSection(
                icon: Icons.policy_rounded,
                color: AppTheme.primaryBlue,
                label: 'HR Policy Approvals',
                count: _pendingOf(_policyVersions).length,
                onViewAll: () => context.push('/management/form-approvals'),
                children: _pendingOf(_policyVersions)
                    .map((v) => _formCard(v, kind: 'policy', label: null,
                        onApprove: () => _approveForm('policy', v['id'] as String),
                        onDeny: () => _rejectForm('policy', v['id'] as String)))
                    .toList(),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _allCaughtUpBanner() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(children: [
            Icon(Icons.task_alt_rounded, size: 44, color: Colors.green.shade400),
            const SizedBox(height: 10),
            Text('All caught up — nothing pending your approval',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  // ── Category-specific compact cards ──────────────────────────────────────

  Widget _leaveCard(LeaveApplication a, {required VoidCallback onApprove, required VoidCallback onDeny}) {
    return _ApprovalCard(
      title: a.employeeName,
      subtitle: a.department,
      details: [
        '${a.leaveType} · ${_fmt(a.from)} → ${_fmt(a.to)}',
        '${a.isHalfDay ? '½ day' : '${a.days} day${a.days == 1 ? '' : 's'}'}'
            '${a.reason.isNotEmpty ? ' · ${a.reason}' : ''}',
      ],
      meta: _fmt(a.appliedOn),
      onApprove: onApprove,
      onDeny: onDeny,
    );
  }

  Widget _onrollCard(AppUser u, {required VoidCallback onApprove, required VoidCallback onDeny}) {
    return _ApprovalCard(
      title: u.name,
      subtitle: u.designation,
      details: const ['Accepted by HR and Reporting Manager — awaiting final sign-off'],
      meta: _fmtIso(u.onrollRequestedAt),
      onApprove: onApprove,
      onDeny: onDeny,
    );
  }

  Widget _grossPayCard(AppUser u, {required VoidCallback onApprove, required VoidCallback onDeny}) {
    return _ApprovalCard(
      title: u.name,
      subtitle: u.designation,
      details: [
        '₹${u.grossPay.toStringAsFixed(0)}/month → ₹${u.grossPayPending.toStringAsFixed(0)}/month',
      ],
      meta: _fmtIso(u.grossPayRequestedAt),
      onApprove: onApprove,
      onDeny: onDeny,
    );
  }

  Widget _workLocationCard(AppUser u, {required VoidCallback onApprove, required VoidCallback onDeny}) {
    return _ApprovalCard(
      title: u.name,
      subtitle: u.designation,
      details: ['${u.workLocation.isEmpty ? '—' : u.workLocation} → ${u.workLocationPending}'],
      meta: _fmtIso(u.workLocationRequestedAt),
      onApprove: onApprove,
      onDeny: onDeny,
    );
  }

  Widget _formCard(Map<String, dynamic> v,
      {required String kind, required String? label, required VoidCallback onApprove, required VoidCallback onDeny}) {
    final vNum = (v['version_number'] as num?)?.toInt() ?? 0;
    final vLabel = label ?? 'v$vNum';
    final createdBy = (v['created_by'] as String?) ?? '';
    return _ApprovalCard(
      title: vLabel,
      subtitle: createdBy.isNotEmpty ? 'Submitted by $createdBy' : '',
      details: const [],
      meta: _fmtIso(v['created_at']?.toString() ?? ''),
      onApprove: onApprove,
      onDeny: onDeny,
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _fmtIso(String iso) {
    if (iso.isEmpty) return '';
    try {
      return _fmt(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }
}

// ── Section wrapper ──────────────────────────────────────────────────────

class _ApprovalSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final VoidCallback? onViewAll;
  final List<Widget> children;
  const _ApprovalSection({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    this.onViewAll,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Text('$count',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withValues(alpha: 0.2))),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text('View all', style: TextStyle(fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

// ── Generic compact approval card ────────────────────────────────────────

class _ApprovalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> details;
  final String meta;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  const _ApprovalCard({
    required this.title,
    required this.subtitle,
    required this.details,
    required this.meta,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
            child: Text(title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                ),
                if (meta.isNotEmpty)
                  Text(meta, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ]),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              for (final d in details) ...[
                const SizedBox(height: 4),
                Text(d, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDeny,
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Deny'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
