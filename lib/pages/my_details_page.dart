import 'package:flutter/material.dart';
import '../models/profile_store.dart';

class MyDetailsPage extends StatelessWidget {
  const MyDetailsPage({super.key});

  static const _color = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    final p = ProfileStore.current;

    final fields = [
      _Field('Employee ID',       Icons.badge_rounded,               p.employeeId),
      _Field('Full Name',         Icons.person_outline_rounded,      p.fullName),
      _Field('Mobile',            Icons.phone_rounded,               p.mobile),
      _Field('Email',             Icons.email_rounded,               p.email),
      _Field('Address',           Icons.location_on_rounded,         p.address),
      _Field('Department',        Icons.account_tree_rounded,        p.department),
      _Field('Designation',       Icons.work_rounded,                p.designation),
      _Field('Reporting Manager', Icons.manage_accounts_rounded,     p.reportingManager),
      _Field('Date of Joining',   Icons.calendar_today_rounded,      p.dateOfJoining),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('My Details',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 24),

            // Profile avatar card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: _color.withValues(alpha: 0.1),
                    child: const Icon(Icons.person_rounded, color: _color, size: 40),
                  ),
                  const SizedBox(width: 20),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      p.fullName.isEmpty ? '—' : p.fullName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p.designation.isEmpty ? '—' : p.designation,
                        style: const TextStyle(
                            fontSize: 12, color: _color,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: fields.map((f) => _DetailRow(field: f)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field {
  final String label;
  final IconData icon;
  final String value;
  const _Field(this.label, this.icon, this.value);
}

class _DetailRow extends StatelessWidget {
  final _Field field;
  const _DetailRow({required this.field});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(field.icon, color: const Color(0xFF0D47A1), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(field.label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            const SizedBox(height: 2),
            Text(
              field.value.isEmpty ? '—' : field.value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: field.value.isEmpty
                      ? const Color(0xFFB0BEC5)
                      : const Color(0xFF263238)),
            ),
          ]),
        ),
      ]),
    );
  }
}
