import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/user_session.dart';
import '../../services/user_store.dart';
import '../../theme/app_theme.dart';

/// Staff Portal profile: read-only display of the essentials. No editing,
/// no photo upload, no payslips/on-roll workflow — those belong to the
/// regular employee portal only.
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
    final users = await UserStore.load();
    if (!mounted) return;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        if (designation.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(designation, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
        const SizedBox(height: 28),
        _InfoTile(icon: Icons.badge_rounded, label: 'Employee ID', value: employeeId.isEmpty ? '—' : employeeId),
        _InfoTile(icon: Icons.apartment_rounded, label: 'Department', value: department.isEmpty ? '—' : department),
        _InfoTile(icon: Icons.work_rounded, label: 'Designation', value: designation.isEmpty ? '—' : designation),
        _InfoTile(icon: Icons.supervisor_account_rounded, label: 'Manager', value: manager.isEmpty ? '—' : manager),
        _InfoTile(icon: Icons.phone_rounded, label: 'Phone Number', value: phone.isEmpty ? '—' : phone),
        _InfoTile(icon: Icons.calendar_today_rounded, label: 'Joining Date', value: joining),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}
