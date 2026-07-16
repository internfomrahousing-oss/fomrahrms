import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/appraisal_store.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

/// Management's "Appraisals" page: an oversight view of every appraisal
/// request in flight, plus a dedicated "Forwarded from Manager" queue for
/// the ones actually awaiting Management's own stage (15/16/17).
class ManagementAppraisalsPage extends StatefulWidget {
  const ManagementAppraisalsPage({super.key});

  @override
  State<ManagementAppraisalsPage> createState() => _ManagementAppraisalsPageState();
}

enum _Tab { requests, forwarded }

class _ManagementAppraisalsPageState extends State<ManagementAppraisalsPage> {
  static Color get _color => AppTheme.primaryBlueDark;
  List<AppraisalForm> _forms = [];
  List<AppUser> _users = [];
  bool _loading = true;
  String _search = '';
  _Tab _tab = _Tab.forwarded;

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

  List<AppraisalForm> get _filtered {
    final base = _tab == _Tab.forwarded
        ? _forms.where((f) => f.status == AppraisalStatus.withManagement)
        : _forms;
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return base.toList();
    return base.where((f) =>
        f.employeeName.toLowerCase().contains(q) ||
        f.employeeId.toLowerCase().contains(q)).toList();
  }

  int get _forwardedCount => _forms.where((f) => f.status == AppraisalStatus.withManagement).length;

  Future<void> _open(AppraisalForm form) async {
    await context.push('/management/appraisals/form', extra: {'existing': form, 'allUsers': _users});
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
                  Text('Appraisals', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text('Every appraisal in flight, and what needs your sign-off',
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
              _TabChip(
                label: 'Forwarded from Manager ($_forwardedCount)',
                selected: _tab == _Tab.forwarded,
                color: _color,
                onTap: () => setState(() => _tab = _Tab.forwarded),
              ),
              _TabChip(
                label: 'Requests (${_forms.length})',
                selected: _tab == _Tab.requests,
                color: _color,
                onTap: () => setState(() => _tab = _Tab.requests),
              ),
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
                    child: _AppraisalRow(form: f, color: _color, onTap: () => _open(f)),
                  )),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }
}

class _AppraisalRow extends StatelessWidget {
  final AppraisalForm form;
  final Color color;
  final VoidCallback onTap;
  const _AppraisalRow({required this.form, required this.color, required this.onTap});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color get _statusColor {
    switch (form.status) {
      case AppraisalStatus.completed: return Colors.green.shade700;
      case AppraisalStatus.withManagement: return Colors.orange.shade700;
      default: return color;
    }
  }

  @override
  Widget build(BuildContext context) {
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
