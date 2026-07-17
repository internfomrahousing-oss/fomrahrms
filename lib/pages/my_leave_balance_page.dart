import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class MyLeaveBalancePage extends StatefulWidget {
  const MyLeaveBalancePage({super.key});

  @override
  State<MyLeaveBalancePage> createState() => _MyLeaveBalancePage();
}

class _MyLeaveBalancePage extends State<MyLeaveBalancePage> {
  static Color get _color => AppTheme.primaryBlue;
  bool _loading = false;
  bool _elAvailLoading = false;
  AppUser? _appUser;

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

      final match = users.where((u) => u.name == UserSession.name).toList();
      final user  = match.isNotEmpty ? match.first : null;

      if (mounted) setState(() {
        _appUser = user;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestElAvail() async {
    if (_appUser == null) return;
    setState(() => _elAvailLoading = true);
    await SupabaseService.requestElAvail(_appUser!.email);
    NotificationService.elEncashmentRequested(employeeName: _appUser!.name);
    await _load();
  }

  List<LeaveApplication> get _mine => LeaveStore.applications
      .where((a) => a.employeeName == UserSession.name)
      .toList();

  bool _isThisMonth(LeaveApplication a) {
    final now = DateTime.now();
    return a.from.year == now.year && a.from.month == now.month;
  }

  double _usedBucket(String bucket) => _mine
      .where((a) =>
          a.managerStatus == LeaveApprovalStatus.approved &&
          _isThisMonth(a) &&
          a.bucket == bucket)
      .fold(0.0, (s, a) => s + a.effectiveDays);

  double _usedElSinceAvail() {
    final user = _appUser;
    if (user == null) return 0;
    final refStr = user.elLastAvailedAt.isNotEmpty
        ? user.elLastAvailedAt
        : user.elEligibleAt;
    final cutoff = refStr.isNotEmpty ? DateTime.tryParse(refStr) : null;
    return _mine
        .where((a) =>
            a.managerStatus == LeaveApprovalStatus.approved &&
            a.leaveType == 'Earned Leave' &&
            (cutoff == null || a.from.isAfter(cutoff)))
        .fold(0.0, (s, a) => s + a.effectiveDays);
  }

  // Months since last avail (or since becoming EL eligible) × 1/month
  int _elAccrued() {
    final user = _appUser;
    if (user == null) return 0;
    final refStr = user.elLastAvailedAt.isNotEmpty
        ? user.elLastAvailedAt
        : user.elEligibleAt;
    if (refStr.isEmpty) return 0;
    final ref = DateTime.tryParse(refStr);
    if (ref == null) return 0;
    final now = DateTime.now();
    final months = (now.year - ref.year) * 12 + (now.month - ref.month);
    return (months * user.monthlyEl).clamp(0, 9999);
  }

  static String _monthName(int m) => const [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ][m];

  @override
  Widget build(BuildContext context) {
    final user = _appUser;

    return Scaffold(
      backgroundColor: null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    const NavBackButton(),
                    const SizedBox(width: 8),
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.balance_rounded, color: _color, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Leave Balance',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text(_monthName(DateTime.now().month),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ]),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: Icon(Icons.refresh_rounded, color: _color),
                      onPressed: _load,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  if (user == null)
                    const Text('Employee record not found.',
                        style: TextStyle(color: Color(0xFF6B7280)))
                  else ...[
                    // Status chip
                    _StatusChip(user.leaveStatus),
                    const SizedBox(height: 16),

                    // Leave type blocks — only what's applicable
                    Row(children: [
                      _LeaveBlock('CL',
                        used:  _usedBucket('CL'),
                        quota: user.monthlyCl,
                        color: Colors.teal.shade700,
                        subtitle: 'This month'),
                      if (user.isOnroll || user.isElEligible) ...[
                        const SizedBox(width: 8),
                        _LeaveBlock('ML',
                          used:  _usedBucket('ML'),
                          quota: user.monthlyMl,
                          color: AppTheme.accentBlue,
                          subtitle: 'This month'),
                      ],
                      if (user.isElEligible) ...[
                        const SizedBox(width: 8),
                        _LeaveBlock('EL',
                          used:  _usedElSinceAvail(),
                          quota: _elAccrued(),
                          color: Colors.purple.shade700,
                          subtitle: 'Cumulative'),
                      ],
                    ]),

                    // EL avail card — only for EL-eligible
                    if (user.isElEligible) ...[
                      const SizedBox(height: 12),
                      _ElAvailCard(
                        user: user,
                        loading: _elAvailLoading,
                        onRequest: _requestElAvail,
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'EL Eligible' => AppTheme.primaryBlue,
      'On-Roll'     => const Color(0xFF22C55E),
      _             => const Color(0xFF6B7280),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Leave block ────────────────────────────────────────────────────────────────
class _LeaveBlock extends StatelessWidget {
  final String type;
  final double used;
  final int quota;
  final Color color;
  final String subtitle;
  const _LeaveBlock(this.type,
      {required this.used, required this.quota, required this.color, required this.subtitle});

  static String _fmt(double d) =>
      d % 1 == 0 ? '${d.toInt()}d' : '${d.toStringAsFixed(1)}d';

  @override
  Widget build(BuildContext context) {
    final available = (quota - used).clamp(0.0, quota.toDouble());
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
                style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.event_available_rounded, size: 11, color: Colors.green.shade700),
            const SizedBox(width: 3),
            Text(_fmt(available),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.green.shade700)),
            const SizedBox(width: 3),
            const Text('available',
                style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
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
                style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
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
  const _ElAvailCard(
      {required this.user, required this.loading, required this.onRequest});

  static Color get _purple => AppTheme.primaryBlue;

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
        Icon(Icons.card_giftcard_rounded, color: _purple, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('EL Encashment',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _purple)),
            if (hasPending)
              const Text('Awaiting HR confirmation',
                  style: TextStyle(fontSize: 10, color: Colors.orange))
            else if (lastAvailed != null)
              Text('Last encashed: ${_fmtDate(lastAvailed)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)))
            else
              const Text('Not yet encashed',
                  style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
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
              Icon(Icons.hourglass_empty_rounded,
                  size: 12, color: Colors.orange.shade700),
              const SizedBox(width: 4),
              Text('Pending',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600)),
            ]),
          )
        else
          ElevatedButton.icon(
            onPressed: loading ? null : onRequest,
            icon: loading
                ? const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.redeem_rounded, size: 14),
            label: const Text('Encash EL', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ]),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
