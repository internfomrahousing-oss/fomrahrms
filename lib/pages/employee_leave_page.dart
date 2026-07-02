import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';

class EmployeeLeavePage extends StatefulWidget {
  final String prefix;
  const EmployeeLeavePage({super.key, this.prefix = '/employee'});

  @override
  State<EmployeeLeavePage> createState() => _EmployeeLeavePageState();
}

class _EmployeeLeavePageState extends State<EmployeeLeavePage> {
  static const _blue = Color(0xFF0D47A1);

  bool _loading = true;
  AppUser? _user;
  bool _elAvailLoading = false;

  // Leave counts
  double _clUsed = 0, _mlUsed = 0, _elUsed = 0;
  double _clAvail = 0, _mlAvail = 0, _elAvail = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        UserStore.load(),
        SupabaseService.fetchLeaveApplications().timeout(const Duration(seconds: 8)),
      ]);
      final users  = results[0] as List<AppUser>;
      final leaves = results[1] as List<LeaveApplication>;

      if (leaves.isNotEmpty) {
        LeaveStore.applications..clear()..addAll(leaves);
        LeaveStore.syncCounter();
      }

      final match = users.where((u) => u.name == UserSession.name).toList();
      final user  = match.isNotEmpty ? match.first : null;

      if (user != null) {
        final now = DateTime.now();
        final mine = leaves.where((a) => a.employeeName == user.name).toList();
        bool isThisMonth(LeaveApplication a) =>
            a.from.year == now.year && a.from.month == now.month;

        double usedMonth(String type) => mine
            .where((a) =>
                a.managerStatus == LeaveApprovalStatus.approved &&
                isThisMonth(a) &&
                a.leaveType == type)
            .fold(0.0, (s, a) => s + a.effectiveDays);

        final elCutoff = user.elLastAvailedAt.isNotEmpty
            ? DateTime.tryParse(user.elLastAvailedAt)
            : null;
        final elUsedVal = mine
            .where((a) =>
                a.managerStatus == LeaveApprovalStatus.approved &&
                a.leaveType == 'Earned Leave' &&
                (elCutoff == null || a.from.isAfter(elCutoff)))
            .fold(0.0, (s, a) => s + a.effectiveDays);

        final clUsedVal = usedMonth('Casual Leave');
        final mlUsedVal = usedMonth('Medical / Sick Leave');

        if (mounted) setState(() {
          _user    = user;
          _clUsed  = clUsedVal;
          _mlUsed  = mlUsedVal;
          _elUsed  = elUsedVal;
          _clAvail = (user.monthlyCl - clUsedVal).clamp(0.0, user.monthlyCl.toDouble());
          _mlAvail = (user.monthlyMl - mlUsedVal).clamp(0.0, user.monthlyMl.toDouble());
          _elAvail = ((user.monthlyEl * 12) - elUsedVal).clamp(0.0, (user.monthlyEl * 12).toDouble());
          _loading = false;
        });
      } else {
        if (mounted) setState(() { _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestElAvail() async {
    if (_user == null) return;
    setState(() => _elAvailLoading = true);
    await SupabaseService.requestElAvail(_user!.email);
    await _load();
  }

  List<_Topic> get _topics => [
    _Topic('Apply Leave',   Icons.event_available_rounded, const Color(0xFF0D47A1), '${widget.prefix}/leave/apply'),
    _Topic('Leave Balance', Icons.balance_rounded,         const Color(0xFF1976D2), '${widget.prefix}/leave/balance'),
    _Topic('Leave History', Icons.history_rounded,         const Color(0xFF283593), '${widget.prefix}/leave/approvals'),
  ];

  static String _fmt(double d) =>
      d % 1 == 0 ? '${d.toInt()}d' : '${d.toStringAsFixed(1)}d';

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.beach_access_rounded, color: _blue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Leave Management',
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, color: _blue),
                onPressed: _load,
              ),
            ]),
            const SizedBox(height: 20),

            // Leave balance summary (shown when data is loaded)
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ))
            else if (user != null) ...[
              // ML / CL / EL blocks
              Row(children: [
                _LeaveBlock('CL', avail: _clAvail, used: _clUsed,
                    color: Colors.teal.shade700, subtitle: 'This month'),
                if (user.isOnroll || user.isElEligible) ...[
                  const SizedBox(width: 8),
                  _LeaveBlock('ML', avail: _mlAvail, used: _mlUsed,
                      color: const Color(0xFF1565C0), subtitle: 'This month'),
                ],
                if (user.isElEligible) ...[
                  const SizedBox(width: 8),
                  _LeaveBlock('EL', avail: _elAvail, used: _elUsed,
                      color: Colors.purple.shade700, subtitle: 'Cumulative'),
                ],
              ]),

              // EL Avail card — only for EL-eligible employees
              if (user.isElEligible) ...[
                const SizedBox(height: 12),
                _ElAvailCard(
                  user: user,
                  loading: _elAvailLoading,
                  onRequest: _requestElAvail,
                ),
              ],

              const SizedBox(height: 20),
            ],

            // Sub-page cards (Apply / Balance / History)
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 600 ? 3 : 2;
              final rows = <Widget>[];
              for (int i = 0; i < _topics.length; i += cols) {
                final end = (i + cols) > _topics.length ? _topics.length : i + cols;
                final rowItems = _topics.sublist(i, end);
                rows.add(Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rowItems.map((t) {
                    final isLast = rowItems.last == t;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: isLast ? 0 : 12, bottom: 12),
                        child: _TopicCard(topic: t),
                      ),
                    );
                  }).toList(),
                ));
              }
              return Column(children: rows);
            }),
          ],
        ),
      ),
    );
  }
}

// ── Leave block ────────────────────────────────────────────────────────────────
class _LeaveBlock extends StatelessWidget {
  final String type;
  final double avail;
  final double used;
  final Color color;
  final String subtitle;
  const _LeaveBlock(this.type, {required this.avail, required this.used,
      required this.color, required this.subtitle});

  static String _fmt(double d) =>
      d % 1 == 0 ? '${d.toInt()}d' : '${d.toStringAsFixed(1)}d';

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(type,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            const Spacer(),
            Text(subtitle,
                style: const TextStyle(fontSize: 9, color: Color(0xFF90A4AE))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.event_available_rounded, size: 11, color: Colors.green.shade700),
            const SizedBox(width: 3),
            Text(_fmt(avail),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.green.shade700)),
            const SizedBox(width: 3),
            const Text('available',
                style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 11, color: Colors.orange.shade700),
            const SizedBox(width: 3),
            Text(_fmt(used),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700)),
            const SizedBox(width: 3),
            const Text('used',
                style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
          ]),
        ]),
      ),
    );
  }
}

// ── EL Avail card ─────────────────────────────────────────────────────────────
class _ElAvailCard extends StatelessWidget {
  final AppUser user;
  final bool loading;
  final VoidCallback onRequest;
  const _ElAvailCard({required this.user, required this.loading, required this.onRequest});

  static const _purple = Color(0xFF6A1B9A);

  @override
  Widget build(BuildContext context) {
    final hasPending  = user.elAvailRequestedAt.isNotEmpty;
    final lastAvailed = user.elLastAvailedAt.isNotEmpty
        ? DateTime.tryParse(user.elLastAvailedAt)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _purple.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.card_giftcard_rounded, color: _purple, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('EL Availed',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _purple)),
            if (lastAvailed != null)
              Text('Last availed: ${_fmtDate(lastAvailed)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF78909C)))
            else if (!hasPending)
              const Text('Not yet availed',
                  style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
            if (hasPending)
              const Text('Awaiting HR confirmation',
                  style: TextStyle(fontSize: 10, color: Colors.orange)),
          ]),
        ),
        if (hasPending)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.hourglass_empty_rounded, size: 12, color: Colors.orange.shade700),
              const SizedBox(width: 4),
              Text('Pending', style: TextStyle(fontSize: 11,
                  color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
            ]),
          )
        else
          ElevatedButton.icon(
            onPressed: loading ? null : onRequest,
            icon: loading
                ? const SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.redeem_rounded, size: 14),
            label: const Text('Avail EL', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ]),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Topic card ─────────────────────────────────────────────────────────────────
class _Topic {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _Topic(this.title, this.icon, this.color, this.route);
}

class _TopicCard extends StatelessWidget {
  final _Topic topic;
  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(topic.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: topic.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(topic.icon, color: topic.color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(topic.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF1A237E))),
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: topic.color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
