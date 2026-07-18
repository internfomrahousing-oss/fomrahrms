import 'package:flutter/material.dart';
import '../../l10n/staff_strings.dart';
import '../../models/app_user.dart';
import '../../models/language_notifier.dart';
import '../../models/leave_store.dart';
import '../../models/user_session.dart';
import '../../services/supabase_service.dart';
import '../../services/user_store.dart';
import '../../theme/app_theme.dart';

/// Staff Portal profile: read-only display of the essentials. No editing,
/// no photo upload, no payslips/on-roll workflow — those belong to the
/// regular employee portal only; Staff Portal data is HR-owned.
class StaffProfilePage extends StatefulWidget {
  const StaffProfilePage({super.key});

  @override
  State<StaffProfilePage> createState() => _StaffProfilePageState();
}

class _StaffProfilePageState extends State<StaffProfilePage> {
  AppUser? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      UserStore.load(),
      SupabaseService.fetchLeaveApplications(),
    ]);
    if (!mounted) return;
    final users = results[0] as List<AppUser>;
    final apps = results[1] as List<LeaveApplication>;
    if (apps.isNotEmpty) {
      LeaveStore.applications..clear()..addAll(apps);
      LeaveStore.syncCounter();
    }
    final match = users.where((u) => u.name == UserSession.name).toList();
    setState(() {
      _user = match.isNotEmpty ? match.first : null;
      _loading = false;
    });
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final u = _user;
    final color = AppTheme.primaryBlue;
    final name        = u?.name.isNotEmpty == true ? u!.name : UserSession.name;
    final employeeId  = u?.employeeId.isNotEmpty == true ? u!.employeeId : UserSession.employeeId;
    final department  = u?.department.isNotEmpty == true ? u!.department : UserSession.department;
    final designation = u?.designation.isNotEmpty == true ? u!.designation : UserSession.designation;
    final manager     = u?.reportingManager.isNotEmpty == true ? u!.reportingManager : UserSession.reportingManager;
    final phone       = u?.mobile ?? '';
    final joining     = u != null ? _fmtDate(u.dateOfJoining) : '—';
    final usedThisMonth = LeaveStore.staffLeaveCountThisMonth(name);
    final holidayValue = st('leave_allowance_note')
        .replaceFirst('{used}', '$usedThisMonth/${LeaveStore.staffMonthlyHolidayAllowance}');

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: staffLanguageNotifier,
      builder: (context, _, __) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 640;

            final avatarCard = Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                child: Column(children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(name, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  if (designation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(designation, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary)),
                  ],
                  if (department.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                      ),
                      child: Text(department,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                    ),
                  ],
                ]),
              ),
            );

            final detailsCard = Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(st('my_profile'), style: AppTheme.cardHeading),
                  const SizedBox(height: 16),
                  _DetailRow(icon: Icons.badge_rounded, label: st('employee_id'), value: employeeId.isEmpty ? '—' : employeeId),
                  _DetailRow(icon: Icons.apartment_rounded, label: st('department'), value: department.isEmpty ? '—' : department),
                  _DetailRow(icon: Icons.work_rounded, label: st('designation'), value: designation.isEmpty ? '—' : designation),
                  _DetailRow(icon: Icons.supervisor_account_rounded, label: st('manager'), value: manager.isEmpty ? '—' : manager),
                  _DetailRow(icon: Icons.phone_rounded, label: st('phone_number'), value: phone.isEmpty ? '—' : phone),
                  _DetailRow(icon: Icons.calendar_today_rounded, label: st('joining_date'), value: joining),
                  _DetailRow(icon: Icons.event_available_rounded, label: st('holiday_allowance'), value: holidayValue, isLast: true),
                ]),
              ),
            );

            if (!wide) {
              return Column(children: [avatarCard, const SizedBox(height: 20), detailsCard]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 260, child: avatarCard),
              const SizedBox(width: 20),
              Expanded(child: detailsCard),
            ]);
          }),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  const _DetailRow({required this.icon, required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: AppTheme.captionText.copyWith(fontWeight: FontWeight.w600)),
        ),
        Flexible(
          flex: 2,
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ),
      ]),
    );
  }
}
