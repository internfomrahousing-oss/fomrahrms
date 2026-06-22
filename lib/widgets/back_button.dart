import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavBackButton extends StatelessWidget {
  const NavBackButton({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      final path = GoRouterState.of(context).uri.path;
      if (path.startsWith('/manager/')) {
        context.go('/manager/dashboard');
      } else if (path.startsWith('/employee/')) {
        context.go('/employee/dashboard');
      } else {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _back(context),
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
    );
  }
}
