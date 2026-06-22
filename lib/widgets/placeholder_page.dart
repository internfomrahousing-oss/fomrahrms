import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.lightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryBlue, size: 26),
                ),
                const SizedBox(width: 16),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(icon, color: AppTheme.primaryBlue, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
