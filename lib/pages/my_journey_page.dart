import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';
import '../widgets/back_button.dart';

class MyJourneyPage extends StatefulWidget {
  const MyJourneyPage({super.key});

  @override
  State<MyJourneyPage> createState() => _MyJourneyPageState();
}

class _MyJourneyPageState extends State<MyJourneyPage> {
  Map<String, dynamic>? _onboardingForm;
  Map<String, dynamic>? _interviewApp;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final db    = Supabase.instance.client;
      final name  = UserSession.name.trim();
      final email = UserSession.email.trim();

      List<dynamic> obRows = [];
      if (email.isNotEmpty) {
        obRows = await db
            .from('onboarding_forms')
            .select('name, designation, status, submitted_at, phone_number')
            .eq('assigned_email', email)
            .limit(1);
      }
      if (obRows.isEmpty && name.isNotEmpty) {
        obRows = await db
            .from('onboarding_forms')
            .select('name, designation, status, submitted_at, phone_number')
            .ilike('name', '%$name%')
            .limit(1);
      }

      List<dynamic> caRows = [];
      if (name.isNotEmpty) {
        caRows = await db
            .from('candidate_applications')
            .select('name, post_applied, hr_status, manager_status, management_status, submitted_at, hr_comment, manager_comment, management_comment')
            .ilike('name', '%$name%')
            .limit(1);
      }

      if (mounted) {
        setState(() {
          _onboardingForm = obRows.isNotEmpty ? (obRows.first as Map<String, dynamic>) : null;
          _interviewApp   = caRows.isNotEmpty ? (caRows.first as Map<String, dynamic>) : null;
          _loading        = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: null,
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timeline_rounded,
                    color: Color(0xFF1565C0), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('My Journey',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const Text('Interview & onboarding status',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
                ]),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1565C0)),
                onPressed: _fetch,
              ),
            ]),
            const SizedBox(height: 24),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: CircularProgressIndicator(color: Color(0xFF1565C0), strokeWidth: 2),
                ),
              )
            else if (_interviewApp == null && _onboardingForm == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.timeline_rounded, size: 48,
                        color: cs.onSurface.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Text('No journey records found',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4),
                            fontSize: 14)),
                  ]),
                ),
              )
            else ...[
              if (_interviewApp != null) _InterviewCard(data: _interviewApp!),
              if (_interviewApp != null && _onboardingForm != null)
                const SizedBox(height: 12),
              if (_onboardingForm != null) _OnboardingCard(data: _onboardingForm!),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Interview card ────────────────────────────────────────────────────────────
class _InterviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InterviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final post  = (data['post_applied'] ?? '').toString();
    final hrS   = (data['hr_status'] ?? 'pending').toString();
    final mgrS  = (data['manager_status'] ?? 'pending').toString();
    final mgmtS = (data['management_status'] ?? 'pending').toString();

    Widget stepChip(String label, String status) {
      final approved = status == 'accepted' || status == 'approved';
      final rejected = status == 'rejected';
      final color = approved
          ? const Color(0xFF2E7D32)
          : rejected ? const Color(0xFFC62828) : const Color(0xFFE65100);
      final bg = approved
          ? const Color(0xFFE8F5E9)
          : rejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            approved ? Icons.check_circle_rounded
                : rejected ? Icons.cancel_rounded
                : Icons.hourglass_empty_rounded,
            size: 11, color: color,
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    final allApproved = (hrS == 'accepted' || hrS == 'approved') &&
        (mgrS == 'accepted' || mgrS == 'approved') &&
        (mgmtS == 'accepted' || mgmtS == 'approved');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: allApproved
              ? const Color(0xFF2E7D32)
              : Theme.of(context).colorScheme.outlineVariant,
          width: allApproved ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.work_outline_rounded,
                  color: Color(0xFF1565C0), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Interview Application',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface)),
              if (post.isNotEmpty)
                Text(post, style: TextStyle(fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ])),
            if (allApproved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF2E7D32)),
                  SizedBox(width: 4),
                  Text('Interview Done',
                      style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            stepChip('HR', hrS),
            stepChip('Manager', mgrS),
            stepChip('Management', mgmtS),
          ]),
        ]),
      ),
    );
  }
}

// ── Onboarding card ───────────────────────────────────────────────────────────
class _OnboardingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OnboardingCard({required this.data});

  String _label(String s) {
    switch (s) {
      case 'pending':        return 'Pending HR Review';
      case 'hr_approved':    return 'Forwarded to Management';
      case 'hr_denied':      return 'Denied by HR';
      case 'mgmt_approved':  return 'Approved by Management';
      case 'mgmt_denied':    return 'Denied by Management';
      case 'access_granted': return 'Account Activated ✓';
      default:               return s;
    }
  }

  Color _color(String s) {
    switch (s) {
      case 'access_granted': return const Color(0xFF6A1B9A);
      case 'mgmt_approved':  return const Color(0xFF2E7D32);
      case 'hr_approved':    return const Color(0xFF1565C0);
      case 'hr_denied':
      case 'mgmt_denied':    return const Color(0xFFC62828);
      default:               return const Color(0xFFE65100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString();
    final desig  = (data['designation'] ?? '').toString();
    final color  = _color(status);
    final label  = _label(status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: status == 'access_granted'
              ? const Color(0xFF6A1B9A)
              : Theme.of(context).colorScheme.outlineVariant,
          width: status == 'access_granted' ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.how_to_reg_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Onboarding Form',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface)),
            if (desig.isNotEmpty)
              Text(desig, style: TextStyle(fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label, style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
