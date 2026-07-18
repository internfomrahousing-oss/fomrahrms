import 'package:flutter/material.dart';
import '../../l10n/staff_strings.dart';
import '../../models/leave_store.dart';
import '../../theme/app_theme.dart';

/// Colored pill badge for a request's decision status — shared by the
/// Leave and Permission history panels in the Staff Portal.
class StaffStatusPill extends StatelessWidget {
  final LeaveApprovalStatus status;
  const StaffStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, key) = switch (status) {
      LeaveApprovalStatus.approved => (const Color(0xFF16A34A), 'status_approved'),
      LeaveApprovalStatus.denied   => (const Color(0xFFDC2626), 'status_denied'),
      LeaveApprovalStatus.pending  => (const Color(0xFFD97706), 'status_pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Text(st(key), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

String staffFmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// A single past request row: date (+ optional subtitle, e.g. permission
/// duration or leave type) on the left, status pill on the right.
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
        color: AppTheme.pageBackground,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(staffFmtDate(date), style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: AppTheme.captionText),
            ],
          ]),
        ),
        StaffStatusPill(status: status),
      ]),
    );
  }
}

/// "History" heading + status filter tabs + list of past requests (or an
/// empty-state message). One shared widget for both the Leave and
/// Permission pages.
class StaffHistorySection extends StatefulWidget {
  final String title;
  final List<LeaveApplication> items; // pre-sorted newest-first
  final String emptyKey;
  final String? Function(LeaveApplication)? subtitleOf;
  const StaffHistorySection({
    super.key,
    required this.title,
    required this.items,
    required this.emptyKey,
    this.subtitleOf,
  });

  @override
  State<StaffHistorySection> createState() => _StaffHistorySectionState();
}

class _StaffHistorySectionState extends State<StaffHistorySection> {
  LeaveApprovalStatus? _filter; // null = All

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == null
        ? widget.items
        : widget.items.where((a) => a.managerStatus == _filter).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.title, style: AppTheme.cardHeading),
      const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FilterChip(label: st('filter_all'), selected: _filter == null, onTap: () => setState(() => _filter = null)),
          const SizedBox(width: 8),
          _FilterChip(
            label: st('status_pending'),
            selected: _filter == LeaveApprovalStatus.pending,
            onTap: () => setState(() => _filter = LeaveApprovalStatus.pending)),
          const SizedBox(width: 8),
          _FilterChip(
            label: st('status_approved'),
            selected: _filter == LeaveApprovalStatus.approved,
            onTap: () => setState(() => _filter = LeaveApprovalStatus.approved)),
          const SizedBox(width: 8),
          _FilterChip(
            label: st('status_denied'),
            selected: _filter == LeaveApprovalStatus.denied,
            onTap: () => setState(() => _filter = LeaveApprovalStatus.denied)),
        ]),
      ),
      const SizedBox(height: 16),
      if (filtered.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          alignment: Alignment.center,
          child: Text(st(widget.emptyKey), style: AppTheme.captionText),
        )
      else
        for (final a in filtered)
          StaffHistoryCard(
            date: a.from,
            subtitle: widget.subtitleOf?.call(a),
            status: a.managerStatus,
          ),
    ]);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      child: AnimatedContainer(
        duration: AppTheme.fastAnim,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : AppTheme.pageBackground,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          border: Border.all(color: selected ? AppTheme.primaryBlue : AppTheme.borderSubtle),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textSecondary)),
      ),
    );
  }
}
