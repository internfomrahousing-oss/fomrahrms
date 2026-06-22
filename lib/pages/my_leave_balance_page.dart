import 'package:flutter/material.dart';
import '../widgets/back_button.dart';

class MyLeaveBalancePage extends StatelessWidget {
  const MyLeaveBalancePage({super.key});

  static const _color = Color(0xFF1976D2);

  static const _balances = [
    _Balance('Casual Leave',   Icons.event_available_rounded, Color(0xFF0D47A1)),
    _Balance('Sick Leave',     Icons.local_hospital_rounded,  Color(0xFF1565C0)),
    _Balance('Earned Leave',   Icons.card_giftcard_rounded,   Color(0xFF1976D2)),
    _Balance('House Visit',    Icons.home_rounded,            Color(0xFF0288D1)),
    _Balance('Outdoor Duty',   Icons.directions_walk_rounded, Color(0xFF283593)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
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
              Text('Leave Balance',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            // Overall summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryCircle('Total Allocated', Icons.calendar_month_rounded, const Color(0xFF0D47A1)),
                    _SummaryCircle('Used',            Icons.event_busy_rounded,     const Color(0xFF1565C0)),
                    _SummaryCircle('Available',       Icons.event_available_rounded,const Color(0xFF2E7D32)),
                    _SummaryCircle('Pending',         Icons.pending_actions_rounded, Colors.orange.shade700),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Per-type breakdown
            ..._balances.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BalanceCard(balance: b),
                )),
          ],
        ),
      ),
    );
  }
}

class _Balance {
  final String type;
  final IconData icon;
  final Color color;
  const _Balance(this.type, this.icon, this.color);
}

class _SummaryCircle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SummaryCircle(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
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
      const Text('—',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E))),
      const SizedBox(height: 2),
      Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Color(0xFF78909C))),
    ]);
  }
}

class _BalanceCard extends StatelessWidget {
  final _Balance balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: balance.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(balance.icon, color: balance.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(balance.type,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E))),
          ),
          _LeaveCount('Avail.', Colors.green.shade700),
          const SizedBox(width: 16),
          _LeaveCount('Used',   Colors.orange.shade700),
          const SizedBox(width: 16),
          _LeaveCount('Pending',Colors.red.shade700),
        ]),
      ),
    );
  }
}

class _LeaveCount extends StatelessWidget {
  final String label;
  final Color color;
  const _LeaveCount(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('—',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF78909C))),
    ]);
  }
}
