import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/appraisal_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

/// The Reporting Manager's "Appraisal Received" queue — every appraisal
/// routed to them, with "Pending" as the actionable filter (status ==
/// with_rm). Reused verbatim by the Manager shell, and by HR/Employee when
/// flagged isReportingManager. Mirrors manager_interview_review_page.dart's
/// search + filter-chip structure.
class AppraisalReceivedPage extends StatefulWidget {
  const AppraisalReceivedPage({super.key});

  @override
  State<AppraisalReceivedPage> createState() => _AppraisalReceivedPageState();
}

enum _Filter { pending, all }

class _AppraisalReceivedPageState extends State<AppraisalReceivedPage> {
  static Color get _color => AppTheme.primaryBlue;
  List<AppraisalForm> _mine = [];
  bool _loading = true;
  String _search = '';
  _Filter _filter = _Filter.pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await SupabaseService.fetchAppraisalForms();
    if (!mounted) return;
    final me = UserSession.name.trim().toLowerCase();
    setState(() {
      _mine = all.where((f) => f.reportingManager.trim().toLowerCase() == me && me.isNotEmpty).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _loading = false;
    });
  }

  List<AppraisalForm> get _filtered {
    final base = _filter == _Filter.pending
        ? _mine.where((f) => f.status == AppraisalStatus.withRm)
        : _mine;
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return base.toList();
    return base.where((f) => f.employeeName.toLowerCase().contains(q)).toList();
  }

  int get _pendingCount => _mine.where((f) => f.status == AppraisalStatus.withRm).length;

  String get _formRoute {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/manager')) return '/manager/appraisal-received/form';
    if (loc.startsWith('/employee')) return '/employee/my-team/appraisal-received/form';
    return '/hr/appraisal-received/form';
  }

  Future<void> _open(AppraisalForm form) async {
    await context.push(_formRoute, extra: {'existing': form});
    if (mounted) _load();
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
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.fact_check_rounded, color: _color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Appraisal Received', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text('Appraisals from your team awaiting your review',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ]),
              ),
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))),
                child: IconButton(
                  tooltip: 'Refresh',
                  icon: Icon(Icons.refresh_rounded, color: _color, size: 20),
                  onPressed: _load,
                ),
              ),
            ]),
            const SizedBox(height: 20),

            Wrap(spacing: 8, runSpacing: 8, children: [
              _FilterChip(label: 'Pending ($_pendingCount)', selected: _filter == _Filter.pending, onTap: () => setState(() => _filter = _Filter.pending)),
              _FilterChip(label: 'All (${_mine.length})', selected: _filter == _Filter.all, onTap: () => setState(() => _filter = _Filter.all)),
            ]),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by employee name...',
                    prefixIcon: Icon(Icons.search_rounded, color: _color, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.fact_check_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text(
                          _mine.isEmpty ? 'No appraisals from your team yet' : 'Nothing here',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13.5)),
                    ]),
                  ),
                ),
              )
            else
              ..._filtered.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AppraisalRow(form: f, onTap: () => _open(f)),
                  )),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryBlue;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }
}

class _AppraisalRow extends StatelessWidget {
  final AppraisalForm form;
  final VoidCallback onTap;
  const _AppraisalRow({required this.form, required this.onTap});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color get _statusColor {
    switch (form.status) {
      case AppraisalStatus.completed: return Colors.green.shade700;
      case AppraisalStatus.withRm: return Colors.orange.shade700;
      default: return AppTheme.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryBlue;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(form.employeeName.isNotEmpty ? form.employeeName[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(form.employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Text('Updated ${_fmt(form.updatedAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(form.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }
}
