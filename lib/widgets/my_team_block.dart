import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/appraisal_store.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../theme/app_theme.dart';

/// "My Team" dashboard section for anyone flagged `UserSession.isReportingManager`
/// — team size, and pending counts for the three RM-facing queues (Team Leave
/// Approvals, Interview Review, Appraisal Received). Shown on the HR, Manager,
/// and Employee dashboards; routes are threaded in per shell since each has
/// its own path prefix for these pages.
class MyTeamBlock extends StatefulWidget {
  final String teamLeaveApprovalsRoute;
  final String interviewReviewRoute;
  final String appraisalReceivedRoute;
  const MyTeamBlock({
    super.key,
    required this.teamLeaveApprovalsRoute,
    required this.interviewReviewRoute,
    required this.appraisalReceivedRoute,
  });

  @override
  State<MyTeamBlock> createState() => _MyTeamBlockState();
}

class _MyTeamBlockState extends State<MyTeamBlock> {
  bool _loading = true;
  int _teamSize = 0;
  int _pendingLeave = 0;
  int _pendingInterviews = 0;
  int _pendingAppraisals = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        UserStore.load(),
        SupabaseService.fetchLeaveApplications().timeout(const Duration(seconds: 8)),
        SupabaseService.fetchCandidateApplications().timeout(const Duration(seconds: 8)),
        SupabaseService.fetchAppraisalForms().timeout(const Duration(seconds: 8)),
      ]);
      if (!mounted) return;
      final users = results[0] as List<AppUser>;
      final leaves = results[1] as List<LeaveApplication>;
      final candidates = results[2] as List<Map<String, dynamic>>;
      final forms = results[3] as List<AppraisalForm>;

      final me = UserSession.name.trim();
      final meLower = me.toLowerCase();
      final teamNames = users.where((u) => u.reportingManager == me).map((u) => u.name).toSet();

      setState(() {
        _teamSize = teamNames.length;
        _pendingLeave = leaves
            .where((a) => teamNames.contains(a.employeeName) && a.managerStatus == LeaveApprovalStatus.pending)
            .length;
        _pendingInterviews = candidates.where((r) {
          final hrStatus = ((r['hr_status'] as String?) ?? '').trim().toLowerCase();
          final assigned = ((r['assigned_manager'] as String?) ?? '').trim().toLowerCase();
          final mgrStatus = (r['manager_status'] as String?) ?? 'pending';
          return hrStatus == 'accepted' && assigned == meLower && mgrStatus == 'pending';
        }).length;
        _pendingAppraisals = forms.where((f) => f.rmCanEdit).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Team', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 700;
          final tiles = [
            _TeamTile(
              icon: Icons.groups_rounded,
              label: 'Team Size',
              value: '$_teamSize',
              color: AppTheme.primaryBlue,
              onTap: null,
            ),
            _TeamTile(
              icon: Icons.event_available_rounded,
              label: 'Team Leave Approvals',
              value: '$_pendingLeave pending',
              color: Colors.orange.shade700,
              onTap: () => context.push(widget.teamLeaveApprovalsRoute),
            ),
            _TeamTile(
              icon: Icons.rate_review_rounded,
              label: 'Interview Review',
              value: '$_pendingInterviews pending',
              color: Colors.purple.shade700,
              onTap: () => context.push(widget.interviewReviewRoute),
            ),
            _TeamTile(
              icon: Icons.fact_check_rounded,
              label: 'Appraisal Received',
              value: '$_pendingAppraisals pending',
              color: Colors.green.shade700,
              onTap: () => context.push(widget.appraisalReceivedRoute),
            ),
          ];
          if (!wide) {
            return Column(children: tiles.map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: t)).toList());
          }
          return Row(
            children: tiles
                .map((t) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: t)))
                .toList(),
          );
        }),
      ],
    );
  }
}

class _TeamTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _TeamTile({required this.icon, required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          ]),
        ),
      ),
    );
  }
}
