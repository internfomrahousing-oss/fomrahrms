import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/appraisal_store.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

/// Employee-facing entry point: request a new appraisal, track the active
/// one's stage, and browse past completed appraisals.
class EmployeeAppraisalRequestPage extends StatefulWidget {
  // HR/Manager reuse this same page for their own "request my appraisal"
  // flow (see role_hierarchy notes — both are employees, only Management
  // isn't) but live under their own shells, so the form editor push needs
  // to land on their prefixed route rather than always /employee/....
  final String formRoute;
  const EmployeeAppraisalRequestPage({super.key, this.formRoute = '/employee/appraisal/form'});

  @override
  State<EmployeeAppraisalRequestPage> createState() => _EmployeeAppraisalRequestPageState();
}

class _EmployeeAppraisalRequestPageState extends State<EmployeeAppraisalRequestPage> {
  static Color get _color => AppTheme.primaryBlue;
  List<AppraisalForm> _mine = [];
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await SupabaseService.fetchAppraisalForms();
    if (!mounted) return;
    final me = UserSession.email.trim().toLowerCase();
    setState(() {
      _mine = all.where((f) => f.employeeEmail.trim().toLowerCase() == me).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  static const _activeStatuses = [
    AppraisalStatus.requested,
    AppraisalStatus.withEmployee,
    AppraisalStatus.withRm,
    AppraisalStatus.withManagement,
  ];

  AppraisalForm? get _active {
    for (final f in _mine) {
      if (_activeStatuses.contains(f.status)) return f;
    }
    return null;
  }

  List<AppraisalForm> get _completed =>
      _mine.where((f) => f.status == AppraisalStatus.completed).toList();

  Future<void> _requestAppraisal() async {
    setState(() => _requesting = true);
    final form = AppraisalForm.newRequest(
      id: AppraisalStore.generateId(),
      employeeEmail: UserSession.email,
      employeeId: UserSession.employeeId,
      employeeName: UserSession.name,
      reportingManager: UserSession.reportingManager,
    );
    try {
      await SupabaseService.saveAppraisalForm(form);
      await NotificationService.appraisalRequested(employeeName: UserSession.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send request: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
    if (mounted) _load();
  }

  Future<void> _open(AppraisalForm form) async {
    await context.push(widget.formRoute, extra: {'existing': form});
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
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
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.fact_check_rounded, color: _color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Appraisal', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text('Request and track your self-appraisal',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (active == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Icon(Icons.add_task_rounded, size: 40, color: _color.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('No appraisal in progress',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text('Request one below to start your self-evaluation.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _requesting ? null : _requestAppraisal,
                        icon: _requesting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Request Appraisal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ]),
                  ),
                )
              else
                _ActiveCard(form: active, onTap: () => _open(active)),
              const SizedBox(height: 24),

              Text('Appraisal History',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              if (_completed.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: Text('No completed appraisals yet',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13.5)),
                    ),
                  ),
                )
              else
                ..._completed.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HistoryCard(form: f, onTap: () => _open(f)),
                    )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final AppraisalForm form;
  final VoidCallback onTap;
  const _ActiveCard({required this.form, required this.onTap});

  static const _stages = [
    AppraisalStatus.requested,
    AppraisalStatus.withEmployee,
    AppraisalStatus.withRm,
    AppraisalStatus.withManagement,
  ];

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryBlue;
    final stepIndex = _stages.indexOf(form.status);
    final yourTurn = form.employeeCanEdit;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.hourglass_top_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(form.statusLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  if (yourTurn) ...[
                    const SizedBox(height: 3),
                    Text('It\'s your turn — tap to fill in your self-evaluation',
                        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
            ]),
            const SizedBox(height: 14),
            Row(children: List.generate(_stages.length, (i) {
              final reached = stepIndex >= i;
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == _stages.length - 1 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: reached ? color : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            })),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Requested', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                Text('Self-Eval', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                Text('Manager', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                Text('Management', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AppraisalForm form;
  final VoidCallback onTap;
  const _HistoryCard({required this.form, required this.onTap});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final color = Colors.green.shade700;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.check_circle_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    form.reviewPeriodFrom.isNotEmpty
                        ? 'Review Period: ${form.reviewPeriodFrom} – ${form.reviewPeriodTo}'
                        : 'Untitled review period',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Text('Completed ${_fmt(form.updatedAt)}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }
}
