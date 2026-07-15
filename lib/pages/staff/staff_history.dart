import 'package:flutter/material.dart';
import '../../l10n/staff_strings.dart';
import '../../models/leave_store.dart';

/// Green check for approved, red cross for denied, amber clock while
/// still awaiting HR's decision — shared by the Leave and Permission
/// history sections in the Staff Portal.
class StaffStatusTick extends StatelessWidget {
  final LeaveApprovalStatus status;
  const StaffStatusTick({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color, key) = switch (status) {
      LeaveApprovalStatus.approved => (Icons.check_circle_rounded, const Color(0xFF16A34A), 'status_approved'),
      LeaveApprovalStatus.denied   => (Icons.cancel_rounded, const Color(0xFFDC2626), 'status_denied'),
      LeaveApprovalStatus.pending  => (Icons.schedule_rounded, const Color(0xFFD97706), 'status_pending'),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Text(st(key), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

String staffFmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// A single past request row: date (+ optional subtitle, e.g. permission
/// duration) on the left, status tick on the right.
class StaffHistoryCard extends StatelessWidget {
  final DateTime date;
  final String? subtitle;
  final LeaveApprovalStatus status;
  const StaffHistoryCard({super.key, required this.date, this.subtitle, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(staffFmtDate(date),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            ],
          ]),
        ),
        StaffStatusTick(status: status),
      ]),
    );
  }
}

/// "History" heading + list of past requests, or an empty-state message.
class StaffHistorySection extends StatelessWidget {
  final List<LeaveApplication> items; // pre-filtered, pre-sorted newest-first
  final String emptyKey;
  final String? Function(LeaveApplication)? subtitleOf;
  const StaffHistorySection({super.key, required this.items, required this.emptyKey, this.subtitleOf});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(st('history'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
      const SizedBox(height: 12),
      if (items.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          alignment: Alignment.center,
          child: Text(st(emptyKey), style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        )
      else
        for (final a in items)
          StaffHistoryCard(
            date: a.from,
            subtitle: subtitleOf?.call(a),
            status: a.managerStatus,
          ),
    ]);
  }
}
