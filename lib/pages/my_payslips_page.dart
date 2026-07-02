import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';

class MyPayslipsPage extends StatefulWidget {
  const MyPayslipsPage({super.key});

  @override
  State<MyPayslipsPage> createState() => _MyPayslipsPageState();
}

class _MyPayslipsPageState extends State<MyPayslipsPage> {
  static const _color  = Color(0xFF0D47A1);
  static const _purple = Color(0xFF6A1B9A);

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
      if (mounted) setState(() {
        _appUser = match.isNotEmpty ? match.first : null;
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
    await _load();
  }

  // EL accrued = whole months since (elLastAvailedAt ?? elEligibleAt) × 1/month
  int _elAccrued(AppUser user) {
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

  // EL used = approved EL leaves since the same reference date
  double _elUsed(AppUser user) {
    final refStr = user.elLastAvailedAt.isNotEmpty
        ? user.elLastAvailedAt
        : user.elEligibleAt;
    final cutoff = refStr.isNotEmpty ? DateTime.tryParse(refStr) : null;
    return LeaveStore.applications
        .where((a) =>
            a.employeeName == user.name &&
            a.leaveType == 'Earned Leave' &&
            a.managerStatus == LeaveApprovalStatus.approved &&
            (cutoff == null || a.from.isAfter(cutoff)))
        .fold(0.0, (s, a) => s + a.effectiveDays);
  }

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
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: _color, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Text('My Payslips',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded, color: _color),
                      onPressed: _load,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  if (user == null)
                    const Text('Employee record not found.',
                        style: TextStyle(color: Color(0xFF78909C)))
                  else if (user.isElEligible) ...[
                    // ── EL section ──────────────────────────────────────────
                    _ElBalanceCard(
                      accrued: _elAccrued(user),
                      used:    _elUsed(user),
                      user:    user,
                      loading: _elAvailLoading,
                      onRequest: _requestElAvail,
                    ),
                  ] else ...[
                    // ── Placeholder for non-EL employees ────────────────────
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Payslips will be available here.',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14)),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── EL Balance card ────────────────────────────────────────────────────────────
class _ElBalanceCard extends StatelessWidget {
  final int    accrued;
  final double used;
  final AppUser user;
  final bool   loading;
  final VoidCallback onRequest;
  const _ElBalanceCard({
    required this.accrued,
    required this.used,
    required this.user,
    required this.loading,
    required this.onRequest,
  });

  static const _purple = Color(0xFF6A1B9A);

  static String _fmt(double d) =>
      d % 1 == 0 ? '${d.toInt()}' : d.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final available   = (accrued - used).clamp(0.0, accrued.toDouble());
    final hasPending  = user.elAvailRequestedAt.isNotEmpty;
    final lastAvailed = user.elLastAvailedAt.isNotEmpty
        ? DateTime.tryParse(user.elLastAvailedAt)
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _purple.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title row
        Row(children: [
          const Icon(Icons.card_giftcard_rounded, color: _purple, size: 20),
          const SizedBox(width: 8),
          const Text('Earned Leave (EL)',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _purple)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _purple.withValues(alpha: 0.2)),
            ),
            child: const Text('EL Eligible',
                style: TextStyle(
                    fontSize: 10, color: _purple, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 20),

        // Big balance display
        Row(children: [
          // Available
          Expanded(
            child: Column(children: [
              Text(_fmt(available),
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.green.shade700)),
              const SizedBox(height: 2),
              Text('day${available == 1 ? '' : 's'} available',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF78909C))),
            ]),
          ),
          Container(width: 1, height: 48, color: _purple.withValues(alpha: 0.15)),
          // Accrued
          Expanded(
            child: Column(children: [
              Text('$accrued',
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w800,
                      color: Color(0xFF546E7A))),
              const SizedBox(height: 2),
              const Text('days accrued',
                  style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
            ]),
          ),
          Container(width: 1, height: 48, color: _purple.withValues(alpha: 0.15)),
          // Used
          Expanded(
            child: Column(children: [
              Text(_fmt(used),
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.orange.shade700)),
              const SizedBox(height: 2),
              const Text('days used',
                  style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
            ]),
          ),
        ]),

        if (lastAvailed != null) ...[
          const SizedBox(height: 12),
          Text('Last availed: ${_fmtDate(lastAvailed)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE))),
        ],

        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),

        // Avail EL section
        if (hasPending)
          Row(children: [
            Icon(Icons.hourglass_empty_rounded,
                size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Avail EL request submitted. Awaiting HR confirmation.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text('Pending',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600)),
            ),
          ])
        else
          Row(children: [
            Expanded(
              child: Text(
                available > 0
                    ? 'You have ${_fmt(available)} EL day${available == 1 ? '' : 's'} to avail. Once confirmed by HR, your balance will reset.'
                    : 'No EL days available to avail yet.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
              ),
            ),
            const SizedBox(width: 12),
            if (available > 0)
              ElevatedButton.icon(
                onPressed: loading ? null : onRequest,
                icon: loading
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.redeem_rounded, size: 16),
                label: const Text('Avail EL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ]),
      ]),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
