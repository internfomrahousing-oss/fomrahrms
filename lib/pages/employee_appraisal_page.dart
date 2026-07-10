import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/appraisal_store.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class EmployeeAppraisalPage extends StatefulWidget {
  final AppUser employee;
  const EmployeeAppraisalPage({super.key, required this.employee});

  @override
  State<EmployeeAppraisalPage> createState() => _EmployeeAppraisalPageState();
}

class _EmployeeAppraisalPageState extends State<EmployeeAppraisalPage> {
  static Color get _color => AppTheme.primaryBlue;
  List<AppraisalForm> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await SupabaseService.fetchAppraisalForms();
    if (!mounted) return;
    setState(() {
      _history = all.where((f) => f.employeeEmail == widget.employee.email).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  String get _formRoute {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/manager')) return '/manager/performance-management/form';
    if (loc.startsWith('/management')) return '/management/performance-management/form';
    return '/performance-management/form';
  }

  Future<void> _openForm({AppraisalForm? existing}) async {
    await context.push(_formRoute, extra: {'employee': widget.employee, 'existing': existing});
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.employee;
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
              CircleAvatar(
                radius: 22,
                backgroundColor: _color.withValues(alpha: 0.12),
                child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                    style: TextStyle(color: _color, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text(
                      [u.designation, u.department].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ]),
              ),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Appraisal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            Text('Appraisal History',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
            const SizedBox(height: 12),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_history.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.fact_check_outlined, size: 44, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No appraisal forms yet',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text('Tap "New Appraisal" to start one',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ]),
                  ),
                ),
              )
            else
              ..._history.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoryCard(form: f, onTap: () => _openForm(existing: f)),
                  )),
          ],
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
    final completed = form.status == 'completed';
    final color = completed ? Colors.green.shade700 : Colors.orange.shade700;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(completed ? Icons.check_circle_rounded : Icons.edit_note_rounded, color: color, size: 20),
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
                Text('Created ${_fmt(form.createdAt)} · Updated ${_fmt(form.updatedAt)}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(completed ? 'Completed' : 'Draft',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }
}
