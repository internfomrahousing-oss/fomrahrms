import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';

class _Item {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Item(this.title, this.icon, this.color, this.route);
}

const _items = [
  _Item('Leave',         Icons.beach_access_rounded,           Color(0xFF1976D2), '/employee/leave-management'),
  _Item('My Payslips',   Icons.account_balance_wallet_rounded, Color(0xFF283593), '/employee/payslips'),
  _Item('Maintenance',   Icons.build_rounded,                  Color(0xFF4E342E), '/employee/maintenance-management'),
  _Item('Onboarding',    Icons.how_to_reg_rounded,             Color(0xFF00695C), '/employee/employee-onboarding'),
  _Item('Notifications', Icons.notifications_rounded,          Color(0xFF0D47A1), '/employee/notifications'),
];

const _blue = Color(0xFF0D47A1);

class EmployeeDashboardPage extends StatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage> {
  Map<String, dynamic>? _onboardingForm;
  Map<String, dynamic>? _interviewApp;
  bool _loadingRecords = false;

  @override
  void initState() {
    super.initState();
    _fetchMyRecords();
  }

  Future<void> _fetchMyRecords() async {
    setState(() => _loadingRecords = true);
    try {
      final db = Supabase.instance.client;
      final name  = UserSession.name.trim();
      final email = UserSession.email.trim();

      // Fetch onboarding form by assigned_email (or name fallback)
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

      // Fetch interview application by name
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
          _loadingRecords = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;
    final name   = UserSession.name;

    return Material(
      color: null,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (!narrow) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('My Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('FOMRA Housing & Infrastructure',
                      style: Theme.of(context).textTheme.bodyMedium),
                ]),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, color: _blue),
                  onPressed: _fetchMyRecords,
                ),
              ]),
              const SizedBox(height: 24),
            ],

            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Welcome back!',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    Text(name.isNotEmpty ? name : 'Employee',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Staff Member',
                          style: TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                  ]),
                ),
              ]),
            ),
            SizedBox(height: narrow ? 16 : 24),

            // My Journey section (interview + onboarding)
            if (_loadingRecords)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2)),
              )
            else if (_interviewApp != null || _onboardingForm != null) ...[
              _SectionLabel(icon: Icons.timeline_rounded, label: 'My Journey'),
              const SizedBox(height: 12),
              _JourneySection(
                interviewApp: _interviewApp,
                onboardingForm: _onboardingForm,
              ),
              SizedBox(height: narrow ? 16 : 24),
            ],

            // Menu grid
            _SectionLabel(icon: Icons.apps_rounded, label: 'Quick Access'),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 600 ? 3 : 2;
              final rows = <Widget>[];
              for (int i = 0; i < _items.length; i += cols) {
                final end =
                    (i + cols) > _items.length ? _items.length : i + cols;
                final rowItems = _items.sublist(i, end);
                rows.add(Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rowItems.map((item) {
                    final isLast = rowItems.last == item;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: isLast ? 0 : 12, bottom: 12),
                        child: _DashCard(item: item),
                      ),
                    );
                  }).toList(),
                ));
              }
              return Column(children: rows);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: cs.primary, size: 18),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface)),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: cs.outlineVariant)),
    ]);
  }
}

// ── Journey section ───────────────────────────────────────────────────────────
class _JourneySection extends StatelessWidget {
  final Map<String, dynamic>? interviewApp;
  final Map<String, dynamic>? onboardingForm;
  const _JourneySection({this.interviewApp, this.onboardingForm});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (interviewApp != null) _InterviewCard(data: interviewApp!),
      if (interviewApp != null && onboardingForm != null)
        const SizedBox(height: 10),
      if (onboardingForm != null) _OnboardingCard(data: onboardingForm!),
    ]);
  }
}

class _InterviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InterviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final post   = (data['post_applied'] ?? '').toString();
    final hrS    = (data['hr_status'] ?? 'pending').toString();
    final mgrS   = (data['manager_status'] ?? 'pending').toString();
    final mgmtS  = (data['management_status'] ?? 'pending').toString();

    Widget _stepChip(String label, String status) {
      final approved = status == 'accepted' || status == 'approved';
      final rejected = status == 'rejected';
      final color = approved
          ? const Color(0xFF2E7D32)
          : rejected
              ? const Color(0xFFC62828)
              : const Color(0xFFE65100);
      final bg = approved
          ? const Color(0xFFE8F5E9)
          : rejected
              ? const Color(0xFFFFEBEE)
              : const Color(0xFFFFF3E0);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            approved ? Icons.check_circle_rounded : rejected ? Icons.cancel_rounded : Icons.hourglass_empty_rounded,
            size: 11, color: color,
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
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
            color: allApproved ? const Color(0xFF2E7D32) : Theme.of(context).colorScheme.outlineVariant,
            width: allApproved ? 1.5 : 1),
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
              child: const Icon(Icons.work_outline_rounded, color: Color(0xFF1565C0), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Interview Application',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
              if (post.isNotEmpty)
                Text(post, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
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
                  Text('Interview Done', style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _stepChip('HR', hrS),
            _stepChip('Manager', mgrS),
            _stepChip('Management', mgmtS),
          ]),
        ]),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OnboardingCard({required this.data});

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':       return 'Pending HR Review';
      case 'hr_approved':   return 'Forwarded to Management';
      case 'hr_denied':     return 'Denied by HR';
      case 'mgmt_approved': return 'Approved by Management';
      case 'mgmt_denied':   return 'Denied by Management';
      case 'access_granted':return 'Account Activated ✓';
      default:              return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'access_granted':return const Color(0xFF6A1B9A);
      case 'mgmt_approved': return const Color(0xFF2E7D32);
      case 'hr_approved':   return const Color(0xFF1565C0);
      case 'hr_denied':
      case 'mgmt_denied':   return const Color(0xFFC62828);
      default:              return const Color(0xFFE65100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status   = (data['status'] ?? 'pending').toString();
    final desig    = (data['designation'] ?? '').toString();
    final color    = _statusColor(status);
    final label    = _statusLabel(status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: status == 'access_granted' ? const Color(0xFF6A1B9A) : Theme.of(context).colorScheme.outlineVariant,
            width: status == 'access_granted' ? 1.5 : 1),
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            if (desig.isNotEmpty)
              Text(desig, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

// ── Dash card ─────────────────────────────────────────────────────────────────
class _DashCard extends StatelessWidget {
  final _Item item;
  const _DashCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(item.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 12)),
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: item.color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
