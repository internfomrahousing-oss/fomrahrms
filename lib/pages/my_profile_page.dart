import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/user_session.dart' show UserSession;
import '../services/user_store.dart';
import '../widgets/back_button.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  static const _color = Color(0xFF1565C0);
  AppUser? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await UserStore.load();
    final match = users.where((u) => u.name == UserSession.name).toList();
    if (mounted) {
      setState(() {
        _user = match.isNotEmpty ? match.first : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: null,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(children: [
                  const NavBackButton(),
                  const SizedBox(width: 8),
                  const Icon(Icons.person_rounded, color: _color, size: 22),
                  const SizedBox(width: 10),
                  Text('My Profile', style: Theme.of(context).textTheme.headlineMedium),
                ]),
                const SizedBox(height: 16),
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.08),
                    border: Border.all(color: _color.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.person_rounded, color: _color, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('My Profile',
                            style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Your profile is managed by HR. Contact HR to update any details.',
                            style: TextStyle(color: _color, fontSize: 12)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded, color: _color),
                      onPressed: _load,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Avatar + name card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFF283593),
                        child: Text(
                          (_user?.name.isNotEmpty == true)
                              ? _user!.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            _user?.name.isEmpty != false ? 'Employee' : _user!.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?.designation.isEmpty != false ? '—' : _user!.designation,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
                          ),
                          if (_user?.role.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF283593).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_user!.role,
                                  style: const TextStyle(
                                      color: Color(0xFF283593), fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Details card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _Row(Icons.badge_rounded,           'Employee ID',       _user?.employeeId ?? ''),
                      _Row(Icons.email_rounded,           'Email',             _user?.email ?? ''),
                      _Row(Icons.work_rounded,            'Designation',       _user?.designation ?? ''),
                      _Row(Icons.manage_accounts_rounded, 'Reporting Manager', _user?.reportingManager ?? ''),
                      _Row(Icons.calendar_today_rounded,  'Date of Joining',   _user?.dateOfJoining ?? ''),
                    ]),
                  ),
                ),
              ]),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF283593).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF283593), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            const SizedBox(height: 2),
            Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A237E)),
            ),
          ]),
        ),
      ]),
    );
  }
}
