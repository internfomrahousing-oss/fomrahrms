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
  static const _color = Color(0xFF0D47A1);
  bool _loading = true;
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
    return Scaffold(
      backgroundColor: null,
      body: Column(children: [
        // Header
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

        // Body
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _employees.isEmpty
                  ? Center(
                      child: Text('No employees found.',
                          style: TextStyle(color: Colors.grey.shade400)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _employees.length,
                      itemBuilder: (context, i) => _EmployeePayrollCard(
                        user: _employees[i],
                        elUsed:    _elUsed(_employees[i]),
                        elAccrued: _elAccrued(_employees[i]),
                        onConfirmAvail: () => _confirmAvail(_employees[i]),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ── Per-employee card ──────────────────────────────────────────────────────────
class _EmployeePayrollCard extends StatefulWidget {
  final AppUser user;
  final double elUsed;
  final int    elAccrued;
  final VoidCallback onConfirmAvail;
  const _EmployeePayrollCard({
    required this.user,
    required this.elUsed,
    required this.elAccrued,
    required this.onConfirmAvail,
  });

  @override
  State<_EmployeePayrollCard> createState() => _EmployeePayrollCardState();
}

class _EmployeePayrollCardState extends State<_EmployeePayrollCard> {
  static const _color  = Color(0xFF0D47A1);
  static const _purple = Color(0xFF6A1B9A);
  bool _confirming = false;

  Future<void> _doConfirm() async {
    setState(() => _confirming = true);
    widget.onConfirmAvail();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final elAccrued   = widget.elAccrued;
    final elAvailable = (elAccrued - widget.elUsed).clamp(0.0, elAccrued.toDouble());
    final hasPending  = u.elAvailRequestedAt.isNotEmpty;
    final lastAvailed = u.elLastAvailedAt.isNotEmpty
        ? DateTime.tryParse(u.elLastAvailedAt)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Employee info row
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _color.withValues(alpha: 0.12),
              child: Text(
                u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                style: const TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
              Text(u.designation.isEmpty ? u.role : '${u.designation} · ${u.role}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            ])),
            _StatusChip(u.leaveStatus),
          ]),

          // EL section — only for EL-eligible employees
          if (u.isElEligible) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(children: [
              // EL balance
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _purple.withValues(alpha: 0.18)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('EL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _purple)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.event_available_rounded, size: 11, color: Colors.green.shade700),
                      const SizedBox(width: 3),
                      Text('${elAvailable % 1 == 0 ? elAvailable.toInt() : elAvailable.toStringAsFixed(1)}d',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                      const SizedBox(width: 3),
                      const Text('available', style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.check_circle_outline_rounded, size: 11, color: Colors.orange.shade700),
                      const SizedBox(width: 3),
                      Text('${widget.elUsed % 1 == 0 ? widget.elUsed.toInt() : widget.elUsed.toStringAsFixed(1)}d',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange.shade700)),
                      const SizedBox(width: 3),
                      const Text('used since last avail', style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
                    ]),
                    if (lastAvailed != null) ...[
                      const SizedBox(height: 2),
                      Text('Last availed: ${_fmtDate(lastAvailed)}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF78909C))),
                    ],
                  ]),
                ),
              ),
              const SizedBox(width: 12),

              // EL availed column
              if (hasPending)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('EL Availed', style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    onPressed: _confirming ? null : _doConfirm,
                    icon: _confirming
                        ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 14),
                    label: const Text('Confirm', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ])
              else
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('EL Availed', style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
                  const SizedBox(height: 6),
                  Text(
                    lastAvailed != null ? _fmtDate(lastAvailed) : '—',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
                  ),
                ]),
            ]),
          ],
        ]),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

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
      child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
