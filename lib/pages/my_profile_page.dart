import 'package:flutter/material.dart';
import '../models/profile_store.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LockedView(profile: ProfileStore.current);
  }
}

// ── Locked read-only view ─────────────────────────────────────────────────────
class _LockedView extends StatelessWidget {
  final ProfileData profile;
  const _LockedView({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
              border: Border.all(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.person_rounded,
                  color: Color(0xFF1565C0), size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('My Profile',
                      style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  SizedBox(height: 4),
                  Text(
                      'Your profile is managed by HR. '
                      'Contact HR to update any details.',
                      style: TextStyle(
                          color: Color(0xFF1565C0), fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Profile header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFF283593),
                  child: Icon(Icons.person_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        profile.fullName.isEmpty
                            ? 'Employee'
                            : profile.fullName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E))),
                    const SizedBox(height: 4),
                    Text(
                        profile.designation.isEmpty
                            ? '—'
                            : profile.designation,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF546E7A))),
                    if (profile.department.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF283593)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(profile.department,
                            style: const TextStyle(
                                color: Color(0xFF283593),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _Row(Icons.badge_rounded,          'Employee ID',       profile.employeeId),
                _Row(Icons.phone_rounded,          'Mobile',            profile.mobile),
                _Row(Icons.email_rounded,          'Email',             profile.email),
                _Row(Icons.location_on_rounded,    'Address',           profile.address),
                _Row(Icons.manage_accounts_rounded,'Reporting Manager', profile.reportingManager),
                _Row(Icons.calendar_today_rounded, 'Date of Joining',   profile.dateOfJoining),
              ]),
            ),
          ),
          const SizedBox(height: 16),
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
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF78909C))),
            const SizedBox(height: 2),
            Text(value.isEmpty ? '—' : value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A237E))),
          ]),
        ),
      ]),
    );
  }
}
