import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';

class PayrollManagementPage extends StatefulWidget {
  const PayrollManagementPage({super.key});

  @override
  State<PayrollManagementPage> createState() => _PayrollManagementPageState();
}

class _PayrollManagementPageState extends State<PayrollManagementPage> {
  static const _color  = Color(0xFF0D47A1);
  static const _purple = Color(0xFF6A1B9A);

  bool _loading = true;
  bool _elExpanded = false;
  List<AppUser> _employees = [];
  List<LeaveApplication> _leaves = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        UserStore.load(),
        SupabaseService.fetchLeaveApplications().timeout(const Duration(seconds: 8)),
      ]);
      final users  = results[0] as List<AppUser>;
      final leaves = results[1] as List<LeaveApplication>;
      if (mounted) {
        setState(() {
          _employees = users
              .where((u) => u.role == 'Employee' || u.role == 'Manager')
              .toList();
          _leaves = leaves;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _elUsed(AppUser u) {
    final refStr = u.elLastAvailedAt.isNotEmpty ? u.elLastAvailedAt : u.elEligibleAt;
    final cutoff = refStr.isNotEmpty ? DateTime.tryParse(refStr) : null;
    return _leaves.where((a) =>
        a.employeeName == u.name &&
        a.leaveType == 'Earned Leave' &&
        a.managerStatus == LeaveApprovalStatus.approved &&
        (cutoff == null || a.from.isAfter(cutoff)))
    .fold(0.0, (s, a) => s + a.effectiveDays);
  }

  int _elAccrued(AppUser u) {
    final refStr = u.elLastAvailedAt.isNotEmpty ? u.elLastAvailedAt : u.elEligibleAt;
    if (refStr.isEmpty) return 0;
    final ref = DateTime.tryParse(refStr);
    if (ref == null) return 0;
    final now = DateTime.now();
    final months = (now.year - ref.year) * 12 + (now.month - ref.month);
    return (months * u.monthlyEl).clamp(0, 9999);
  }

  Future<void> _confirmAvail(AppUser user) async {
    await SupabaseService.confirmElAvail(user.email);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final elEmployees = _employees.where((u) => u.isElEligible).toList();
    final pendingCount = elEmployees.where((u) => u.elAvailRequestedAt.isNotEmpty).length;

    return Scaffold(
      backgroundColor: null,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: _color, size: 26),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Payroll Management', style: Theme.of(context).textTheme.headlineMedium),
              const Text('HR Management', style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
            ]),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, color: _color),
              onPressed: _reload,
            ),
          ]),
        ),
        const Divider(height: 1),

        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // ── EL Encashment button/section ─────────────────────
                    GestureDetector(
                      onTap: () => setState(() => _elExpanded = !_elExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: _elExpanded
                              ? _purple.withValues(alpha: 0.1)
                              : _purple.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _purple.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: _purple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.card_giftcard_rounded, color: _purple, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('EL Encashment',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _purple)),
                              Text(
                                elEmployees.isEmpty
                                    ? 'No EL-eligible employees'
                                    : pendingCount > 0
                                        ? '$pendingCount pending request${pendingCount > 1 ? 's' : ''} · ${elEmployees.length} eligible'
                                        : '${elEmployees.length} eligible employee${elEmployees.length > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
                              ),
                            ]),
                          ),
                          if (pendingCount > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Text('$pendingCount pending',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                      color: Colors.orange.shade800)),
                            ),
                          Icon(
                            _elExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: _purple, size: 22,
                          ),
                        ]),
                      ),
                    ),

                    // ── EL-eligible employees (expanded) ─────────────────
                    if (_elExpanded) ...[
                      const SizedBox(height: 10),
                      if (elEmployees.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _purple.withValues(alpha: 0.15)),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline_rounded, color: Colors.grey.shade400, size: 20),
                            const SizedBox(width: 10),
                            Text('No employees have EL eligibility yet.',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ]),
                        )
                      else
                        ...elEmployees.map((u) {
                          final accrued   = _elAccrued(u);
                          final used      = _elUsed(u);
                          final available = (accrued - used).clamp(0.0, accrued.toDouble());
                          final hasPending = u.elAvailRequestedAt.isNotEmpty;
                          final lastAvailed = u.elLastAvailedAt.isNotEmpty
                              ? DateTime.tryParse(u.elLastAvailedAt) : null;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _purple.withValues(alpha: 0.15)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              // Employee row
                              Row(children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _purple.withValues(alpha: 0.12),
                                  child: Text(
                                    u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: _purple,
                                        fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(u.name,
                                      style: const TextStyle(fontSize: 13,
                                          fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
                                  Text(
                                    u.designation.isEmpty ? u.role : '${u.designation} · ${u.role}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
                                  ),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _purple.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _purple.withValues(alpha: 0.25)),
                                  ),
                                  child: const Text('EL Eligible',
                                      style: TextStyle(fontSize: 10, color: _purple,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              const SizedBox(height: 12),

                              // EL balance row
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _purple.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(children: [
                                  _BalanceStat(
                                    label: 'Accrued',
                                    value: '$accrued d',
                                    color: const Color(0xFF546E7A),
                                  ),
                                  _Divider(),
                                  _BalanceStat(
                                    label: 'Used',
                                    value: used % 1 == 0
                                        ? '${used.toInt()} d'
                                        : '${used.toStringAsFixed(1)} d',
                                    color: Colors.orange.shade700,
                                  ),
                                  _Divider(),
                                  _BalanceStat(
                                    label: 'Available',
                                    value: available % 1 == 0
                                        ? '${available.toInt()} d'
                                        : '${available.toStringAsFixed(1)} d',
                                    color: Colors.green.shade700,
                                  ),
                                  if (lastAvailed != null) ...[
                                    _Divider(),
                                    _BalanceStat(
                                      label: 'Last Encashed',
                                      value: _fmtDate(lastAvailed),
                                      color: const Color(0xFF78909C),
                                    ),
                                  ],
                                ]),
                              ),
                              const SizedBox(height: 10),

                              // Encashment action
                              if (hasPending)
                                Row(children: [
                                  Icon(Icons.hourglass_empty_rounded,
                                      size: 14, color: Colors.orange.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text('Encash EL request pending confirmation',
                                        style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                                  ),
                                  _ConfirmButton(
                                    onConfirm: () => _confirmAvail(u),
                                  ),
                                ])
                              else
                                Text('No pending encashment request',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                            ]),
                          );
                        }),
                    ],

                    const SizedBox(height: 20),

                    // ── All employees list ────────────────────────────────
                    Text('All Employees',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600)),
                    const SizedBox(height: 10),
                    ..._employees.map((u) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _color.withValues(alpha: 0.12),
                            child: Text(
                              u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: _color,
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(u.name,
                                style: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
                            Text(
                              u.designation.isEmpty ? u.role : '${u.designation} · ${u.role}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
                            ),
                          ])),
                          _StatusChip(u.leaveStatus),
                        ]),
                      ),
                    )),
                  ]),
                ),
        ),
      ]),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Balance stat ───────────────────────────────────────────────────────────────
class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BalanceStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF90A4AE))),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
          margin: const EdgeInsets.symmetric(horizontal: 4));
}

// ── Confirm button with loading ────────────────────────────────────────────────
class _ConfirmButton extends StatefulWidget {
  final Future<void> Function() onConfirm;
  const _ConfirmButton({required this.onConfirm});

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  static const _purple = Color(0xFF6A1B9A);
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : () async {
        setState(() => _loading = true);
        await widget.onConfirm();
        if (mounted) setState(() => _loading = false);
      },
      icon: _loading
          ? const SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.check_rounded, size: 14),
      label: const Text('Confirm', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      'EL Eligible' => const Color(0xFF6A1B9A),
      'On-Roll'     => const Color(0xFF2E7D32),
      _             => const Color(0xFF78909C),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
