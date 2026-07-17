import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/appraisal_store.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

/// HR's single "Appraisals" page — every appraisal in the pipeline, with a
/// "Requests" filter as the actionable queue (HR sets up the form and sends
/// it on to the employee). Mirrors interview_process_page.dart's
/// filter-chip + search list pattern.
class HrAppraisalsPage extends StatefulWidget {
  const HrAppraisalsPage({super.key});

  @override
  State<HrAppraisalsPage> createState() => _HrAppraisalsPageState();
}

enum _Filter { requests, withEmployee, withRm, withManagement, completed, all }

class _HrAppraisalsPageState extends State<HrAppraisalsPage> {
  static Color get _color => AppTheme.primaryBlue;
  List<AppraisalForm> _forms = [];
  List<AppUser> _users = [];
  bool _loading = true;
  String _search = '';
  _Filter _filter = _Filter.requests;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      SupabaseService.fetchAppraisalForms(),
      UserStore.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _forms = (results[0] as List<AppraisalForm>)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _users = results[1] as List<AppUser>;
      _loading = false;
    });
  }

  bool _matches(AppraisalForm f, _Filter filter) {
    switch (filter) {
      case _Filter.requests: return f.status == AppraisalStatus.requested;
      case _Filter.withEmployee: return f.status == AppraisalStatus.withEmployee;
      case _Filter.withRm: return f.status == AppraisalStatus.withRm;
      case _Filter.withManagement: return f.status == AppraisalStatus.withManagement;
      case _Filter.completed: return f.status == AppraisalStatus.completed;
      case _Filter.all: return true;
    }
  }

  int _countFor(_Filter f) => _forms.where((form) => _matches(form, f)).length;

  List<AppraisalForm> get _filtered {
    final base = _forms.where((f) => _matches(f, _filter));
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return base.toList();
    return base.where((f) =>
        f.employeeName.toLowerCase().contains(q) ||
        f.employeeId.toLowerCase().contains(q)).toList();
  }

  Future<void> _open(AppraisalForm form) async {
    await context.push('/appraisals/form', extra: {'existing': form, 'allUsers': _users});
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
                  Text('Appraisals',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text('Employee-requested appraisals, through every stage',
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
              _FilterChip(label: 'Requests', count: _countFor(_Filter.requests), selected: _filter == _Filter.requests, onTap: () => setState(() => _filter = _Filter.requests)),
              _FilterChip(label: 'With Employee', count: _countFor(_Filter.withEmployee), selected: _filter == _Filter.withEmployee, onTap: () => setState(() => _filter = _Filter.withEmployee)),
              _FilterChip(label: 'With Manager', count: _countFor(_Filter.withRm), selected: _filter == _Filter.withRm, onTap: () => setState(() => _filter = _Filter.withRm)),
              _FilterChip(label: 'With Management', count: _countFor(_Filter.withManagement), selected: _filter == _Filter.withManagement, onTap: () => setState(() => _filter = _Filter.withManagement)),
              _FilterChip(label: 'Completed', count: _countFor(_Filter.completed), selected: _filter == _Filter.completed, onTap: () => setState(() => _filter = _Filter.completed)),
              _FilterChip(label: 'All', count: _countFor(_Filter.all), selected: _filter == _Filter.all, onTap: () => setState(() => _filter = _Filter.all)),
            ]),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by employee name or ID...',
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
                      Text('Nothing here', style: TextStyle(color: Colors.grey.shade400, fontSize: 13.5)),
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
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap});

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
        child: Text('$label ($count)',
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
      case AppraisalStatus.requested: return Colors.orange.shade700;
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
