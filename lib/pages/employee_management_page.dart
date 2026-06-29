import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class EmployeeManagementPage extends StatelessWidget {
  const EmployeeManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_rounded,
                    color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Text('Employee Management',
                  style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 20),

            // Employee Profile card with ADD NEW button
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 600 ? 2 : 1;
              if (cols == 2) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _ProfileCard()),
                    const SizedBox(width: 12),
                    Expanded(child: _RecordsCard()),
                  ],
                );
              }
              return Column(children: [
                _ProfileCard(),
                const SizedBox(height: 12),
                _RecordsCard(),
              ]);
            }),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/employee-management/profile'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/employee-management/profile'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('ADD NEW',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Color(0xFF0D47A1), size: 24),
              ),
              const SizedBox(height: 10),
              const Text(
                'Employee Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_rounded,
                  size: 14,
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/employee-management/records'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 28), // align with profile card top
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people_alt_rounded,
                    color: Color(0xFF0288D1), size: 24),
              ),
              const SizedBox(height: 10),
              const Text(
                'Employee Records',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_rounded,
                  size: 14,
                  color: const Color(0xFF0288D1).withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
