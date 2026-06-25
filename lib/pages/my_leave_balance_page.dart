import 'package:flutter/material.dart';
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
      final users  = results[1] as List;

      if (leaves.isNotEmpty) {
        LeaveStore.applications
          ..clear()
          ..addAll(leaves.cast());
        LeaveStore.syncCounter();
      }

      // Find this employee's allocation set by HR
      final match = users.cast<dynamic>().where((u) => u.name == UserSession.name).toList();
      final allocated = match.isNotEmpty ? (match.first.leaveAllocation as int) : _defaultAllocation;

      if (mounted) setState(() { _totalAllocated = allocated; _loading = false; });
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

  static String _fmtDays(double d) =>
      d % 1 == 0 ? '${d.toInt()}' : d.toStringAsFixed(1);

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
      backgroundColor: const Color(0xFFF5F7FA),
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

                  // Per-type usage breakdown
                  ...const [
                    ('Casual Leave',          Icons.event_available_rounded,        Color(0xFF0D47A1)),
                    ('Medical / Sick Leave',  Icons.local_hospital_rounded,         Color(0xFF1565C0)),
                    ('Earned Leave',          Icons.card_giftcard_rounded,          Color(0xFF1976D2)),
                    ('Maternity Leave',       Icons.pregnant_woman_rounded,         Color(0xFF0288D1)),
                    ('Paternity Leave',       Icons.family_restroom_rounded,        Color(0xFF283593)),
                    ('To Vote',               Icons.how_to_vote_rounded,            Color(0xFF00838F)),
                    ('Personal Leave',        Icons.person_rounded,                 Color(0xFF558B2F)),
                    ('Funeral / Bereavement', Icons.sentiment_very_dissatisfied_rounded, Color(0xFF546E7A)),
                    ('LOP or Others',         Icons.more_horiz_rounded,            Color(0xFF6A1B9A)),
                  ].map((e) {
                    final typeUsed    = _usedDays(e.$1);
                    final typePending = _pendingDays(e.$1);
                    if (typeUsed == 0 && typePending == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BalanceCard(
                        type: e.$1,
                        icon: e.$2,
                        color: e.$3,
                        used: typeUsed,
                        pending: typePending,
                      ),
                    );
                  }),

                  // Empty state for per-type section
                  if (_mine.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text('No leave applications yet.',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        ),
                      ),
                    ),
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

class _BalanceCard extends StatelessWidget {
  final String type;
  final IconData icon;
  final Color color;
  final double used;
  final double pending;
  const _BalanceCard({
    required this.type,
    required this.icon,
    required this.color,
    required this.used,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(type,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E))),
          ),
          _LeaveCount('Used',    used,    Colors.orange.shade700),
          const SizedBox(width: 20),
          _LeaveCount('Pending', pending, Colors.red.shade700),
        ]),
      ),
    );
  }
}

class _LeaveCount extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _LeaveCount(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final display = value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(1);
    return Column(children: [
      Text(display,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF78909C))),
    ]);
  }
}
