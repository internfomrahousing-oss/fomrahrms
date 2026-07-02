import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';

const _defaultAllocation = 21; // fallback when no HR-set allocation exists

class MyLeaveBalancePage extends StatefulWidget {
  const MyLeaveBalancePage({super.key});

  @override
  State<MyLeaveBalancePage> createState() => _MyLeaveBalancePage();
}

class _MyLeaveBalancePage extends State<MyLeaveBalancePage> {
  static const _color = Color(0xFF1976D2);
  bool _loading = false;
  int _totalAllocated = _defaultAllocation;
  bool _isOnroll     = false;
  bool _isElEligible = false;
  int  _monthlyCl    = 1;
  int  _monthlyMl    = 0;
  int  _monthlyEl    = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchLeaveApplications().timeout(const Duration(seconds: 8)),
        UserStore.load(),
      ]);

      final leaves = results[0] as List;
      final users  = results[1] as List<AppUser>;

      if (leaves.isNotEmpty) {
        LeaveStore.applications
          ..clear()
          ..addAll(leaves.cast());
        LeaveStore.syncCounter();
      }

      // Find this employee's record set by HR
      final match = users.where((u) => u.name == UserSession.name).toList();
      final user  = match.isNotEmpty ? match.first : null;

      if (mounted) setState(() {
        _totalAllocated = user?.leaveAllocation ?? _defaultAllocation;
        _isOnroll       = user?.isOnroll        ?? false;
        _isElEligible   = user?.isElEligible    ?? false;
        _monthlyCl      = user?.monthlyCl       ?? 1;
        _monthlyMl      = user?.monthlyMl       ?? 0;
        _monthlyEl      = user?.monthlyEl       ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LeaveApplication> get _mine => LeaveStore.applications
      .where((a) => a.employeeName == UserSession.name)
      .toList();

  // Only count leaves that START in the current month — balance resets each month
  bool _isThisMonth(LeaveApplication a) {
    final now = DateTime.now();
    return a.from.year == now.year && a.from.month == now.month;
  }

  double _usedDays(String? type) => _mine
      .where((a) =>
          a.managerStatus == LeaveApprovalStatus.approved &&
          _isThisMonth(a) &&
          (type == null || a.leaveType == type))
      .fold(0.0, (s, a) => s + a.effectiveDays);

  double _pendingDays(String? type) => _mine
      .where((a) =>
          a.managerStatus == LeaveApprovalStatus.pending &&
          _isThisMonth(a) &&
          (type == null || a.leaveType == type))
      .fold(0.0, (s, a) => s + a.effectiveDays);

  double _usedAllTime(String type) => _mine
      .where((a) =>
          a.managerStatus == LeaveApprovalStatus.approved &&
          a.leaveType == type)
      .fold(0.0, (s, a) => s + a.effectiveDays);

  static String _monthName(int m) => const [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ][m];

  @override
  Widget build(BuildContext context) {
    final used      = _usedDays(null);
    final pending   = _pendingDays(null);
    final available = (_totalAllocated - used).clamp(0.0, _totalAllocated.toDouble());

    return Scaffold(
      backgroundColor: null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const NavBackButton(),
                    const SizedBox(width: 8),
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.balance_rounded, color: _color, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Leave Balance',
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text(
                        _monthName(DateTime.now().month),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
                      ),
                    ]),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded, color: _color),
                      onPressed: _load,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Overall summary card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _SummaryCircle('Monthly Limit', Icons.calendar_month_rounded,
                              const Color(0xFF0D47A1), _totalAllocated.toDouble()),
                          _SummaryCircle('Used', Icons.event_busy_rounded,
                              const Color(0xFF1565C0), used),
                          _SummaryCircle('Available', Icons.event_available_rounded,
                              const Color(0xFF2E7D32), available),
                          _SummaryCircle('Pending', Icons.pending_actions_rounded,
                              Colors.orange.shade700, pending),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Leave type blocks — shown based on eligibility
                  Row(children: [
                    _LeaveBlock('CL',
                      used:  _usedAllTime('Casual Leave'),
                      quota: _monthlyCl * 12,
                      color: Colors.teal.shade700),
                    if (_isOnroll || _isElEligible) ...[
                      const SizedBox(width: 8),
                      _LeaveBlock('ML',
                        used:  _usedAllTime('Medical / Sick Leave'),
                        quota: _monthlyMl * 12,
                        color: const Color(0xFF1565C0)),
                    ],
                    if (_isElEligible) ...[
                      const SizedBox(width: 8),
                      _LeaveBlock('EL',
                        used:  _usedAllTime('Earned Leave'),
                        quota: _monthlyEl * 12,
                        color: Colors.purple.shade700),
                    ],
                  ]),
                ],
              ),
            ),
    );
  }
}

class _SummaryCircle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double value;
  const _SummaryCircle(this.label, this.icon, this.color, this.value);

  @override
  Widget build(BuildContext context) {
    final display = value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(1);
    return Column(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 26),
      ),
      const SizedBox(height: 8),
      Text(display,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Color(0xFF78909C))),
    ]);
  }
}

class _LeaveBlock extends StatelessWidget {
  final String type;
  final double used;
  final int quota;
  final Color color;
  const _LeaveBlock(this.type, {required this.used, required this.quota, required this.color});

  static String _fmt(double d) =>
      d % 1 == 0 ? '${d.toInt()}d' : '${d.toStringAsFixed(1)}d';

  @override
  Widget build(BuildContext context) {
    final available = (quota - used).clamp(0.0, quota.toDouble());
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 5),
          Row(children: [
            Icon(Icons.event_available_rounded, size: 11, color: Colors.green.shade700),
            const SizedBox(width: 3),
            Text(_fmt(available),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.green.shade700)),
            const SizedBox(width: 2),
            const Text('available', style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 11, color: Colors.orange.shade700),
            const SizedBox(width: 3),
            Text(_fmt(used),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700)),
            const SizedBox(width: 2),
            const Text('used', style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
          ]),
        ]),
      ),
    );
  }
}
