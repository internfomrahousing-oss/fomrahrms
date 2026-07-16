import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/appraisal_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class PerformanceManagementPage extends StatelessWidget {
  const PerformanceManagementPage({super.key});

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
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.trending_up_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Performance Management', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text('Self-appraisal forms, by employee',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            const PerformanceManagementBody(),
          ],
        ),
      ),
    );
  }
}

/// Employee list scoped to the current role (HR/Management: everyone;
/// Reporting Manager: only their own team), each row showing the latest
/// appraisal status. Embedded here and inside the Task Management tab.
class PerformanceManagementBody extends StatefulWidget {
  const PerformanceManagementBody({super.key});

  @override
  State<PerformanceManagementBody> createState() => _PerformanceManagementBodyState();
}

class _PerformanceManagementBodyState extends State<PerformanceManagementBody> {
  static Color get _color => AppTheme.primaryBlue;
  List<AppUser> _employees = [];
  Map<String, AppraisalForm> _latestByEmail = {};
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      UserStore.load(),
      SupabaseService.fetchAppraisalForms(),
    ]);
    if (!mounted) return;
    final users = results[0] as List<AppUser>;
    final forms = results[1] as List<AppraisalForm>;
    final latest = <String, AppraisalForm>{};
    for (final f in forms) {
      final existing = latest[f.employeeEmail];
      if (existing == null || f.createdAt.isAfter(existing.createdAt)) {
        latest[f.employeeEmail] = f;
      }
    }
    setState(() {
      _employees = visibleEmployeesForAppraisal(users);
      _latestByEmail = latest;
      _loading = false;
    });
  }

  List<AppUser> get _filtered {
    if (_search.trim().isEmpty) return _employees;
    final q = _search.trim().toLowerCase();
    return _employees.where((u) =>
        u.name.toLowerCase().contains(q) ||
        u.employeeId.toLowerCase().contains(q) ||
        u.designation.toLowerCase().contains(q) ||
        u.department.toLowerCase().contains(q)).toList();
  }

  String get _employeeRoute {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/manager')) return '/manager/performance-management/employee';
    if (loc.startsWith('/management')) return '/management/performance-management/employee';
    return '/performance-management/employee';
  }

  Future<void> _openEmployee(AppUser u) async {
    await context.push(_employeeRoute, extra: {'employee': u, 'allUsers': _employees});
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isRestrictedRm = UserSession.role == UserRole.reportingManager;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRestrictedRm && _employees.isEmpty && !_loading)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey.shade500, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'You are not flagged as a Reporting Manager for any employees yet.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ),
              ]),
            ),
          ),
        Row(children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, designation, department...',
                    prefixIcon: Icon(Icons.search_rounded, color: _color, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))),
            child: IconButton(
              tooltip: 'Refresh',
              icon: Icon(Icons.refresh_rounded, color: _color, size: 20),
              onPressed: _load,
            ),
          ),
        ]),
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
                  Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(_employees.isEmpty ? 'No employees to show' : 'No results for "$_search"',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13.5)),
                ]),
              ),
            ),
          )
        else
          ..._filtered.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EmployeeRow(
                  employee: u,
                  latest: _latestByEmail[u.email],
                  onTap: () => _openEmployee(u),
                ),
              )),
      ],
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final AppUser employee;
  final AppraisalForm? latest;
  final VoidCallback onTap;
  const _EmployeeRow({required this.employee, required this.latest, required this.onTap});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final u = employee;
    final color = AppTheme.primaryBlue;
    Widget badge;
    if (latest == null) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
        child: Text('No appraisal yet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
      );
    } else {
      final completed = latest!.status == AppraisalStatus.completed;
      final c = completed ? Colors.green.shade700 : Colors.orange.shade700;
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text('${latest!.statusLabel} · ${_fmt(latest!.updatedAt)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      );
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Text([u.designation, u.department].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            badge,
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }
}
