import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_session.dart';
import '../models/app_user.dart';
import '../services/user_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _color = Color(0xFF0D47A1);

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // Fallback system credentials (always work)
  static const _systemCredentials = {
    'hr@fomrahousing.in':         ('Admin@123',  UserRole.hr,               'HR Admin',  'HR001'),
    'manager@fomrahousing.in':    ('Manager@123',UserRole.reportingManager, 'Ravi Kumar','MGR001'),
    'employee@fomrahousing.in':   ('Emp@123',    UserRole.employee,         'Priya Sharma','EMP001'),
    'management@fomrahousing.in': ('Mgmt@123',   UserRole.management,       'Director',  'MGMT001'),
  };

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter email and password.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    if (!mounted) return;

    // 1. Check dynamic users created by Management
    final dynamicUser = await UserStore.findByEmail(email);
    if (dynamicUser != null) {
      final expected = AppUser.passwordForRole(dynamicUser.role);
      if (password != expected) {
        setState(() { _error = 'Invalid email or password.'; _loading = false; });
        return;
      }
      UserSession.loggedIn   = true;
      UserSession.role       = AppUser.userRoleFor(dynamicUser.role);
      UserSession.name       = dynamicUser.name;
      UserSession.employeeId = dynamicUser.employeeId.isNotEmpty ? dynamicUser.employeeId : dynamicUser.email;
      if (!mounted) return;
      setState(() => _loading = false);
      _navigateForRole(UserSession.role);
      return;
    }

    // 2. Fall back to system credentials
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final match = _systemCredentials[email.toLowerCase()];
    if (match == null || match.$1 != password) {
      setState(() { _error = 'Invalid email or password.'; _loading = false; });
      return;
    }
    UserSession.loggedIn   = true;
    UserSession.role       = match.$2;
    UserSession.name       = match.$3;
    UserSession.employeeId = match.$4;
    setState(() => _loading = false);
    _navigateForRole(UserSession.role);
  }

  void _navigateForRole(UserRole role) {
    switch (role) {
      case UserRole.hr:         context.go('/dashboard');
      case UserRole.reportingManager: context.go('/manager/dashboard');
      case UserRole.employee:   context.go('/employee/dashboard');
      case UserRole.management: context.go('/management/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _color.withValues(alpha: 0.3),
                      blurRadius: 24, offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('FOMRA HRMS',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold,
                      color: _color, letterSpacing: 3)),
              const SizedBox(height: 6),
              const Text('Housing & Infrastructure',
                  style: TextStyle(fontSize: 13, color: Color(0xFF78909C),
                      letterSpacing: 1)),
              const SizedBox(height: 40),

              // Login card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    // Email
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_rounded,
                            color: _color, size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _color, width: 2),
                        ),
                        filled: true, fillColor: Colors.white,
                        labelStyle: const TextStyle(color: Color(0xFF78909C)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_rounded,
                            color: _color, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_rounded
                                     : Icons.visibility_rounded,
                            size: 18, color: const Color(0xFF78909C),
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _color, width: 2),
                        ),
                        filled: true, fillColor: Colors.white,
                        labelStyle: const TextStyle(color: Color(0xFF78909C)),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline_rounded,
                              size: 16, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.red.shade700)),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _login,
                        icon: _loading
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_loading ? 'Signing in…' : 'Sign In'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CredentialsHint(),
                  ]),
                ),
              ),

              const SizedBox(height: 24),
              Text('FOMRA Housing & Infrastructure © 2025',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialsHint extends StatelessWidget {
  const _CredentialsHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBCCF0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Demo Credentials',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D47A1))),
        const SizedBox(height: 2),
        const Text('Users added by Management use role password below.',
            style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
        const SizedBox(height: 6),
        _cred(Icons.manage_accounts_rounded, 'Management',
            'management@fomrahousing.in', 'Mgmt@123'),
        const SizedBox(height: 4),
        _cred(Icons.admin_panel_settings_rounded, 'HR',
            'hr@fomrahousing.in', 'Admin@123'),
        const SizedBox(height: 4),
        _cred(Icons.supervisor_account_rounded, 'Manager',
            'manager@fomrahousing.in', 'Manager@123'),
        const SizedBox(height: 4),
        _cred(Icons.person_rounded, 'Employee',
            'employee@fomrahousing.in', 'Emp@123'),
      ]),
    );
  }

  Widget _cred(IconData icon, String role, String email, String pass) {
    return Row(children: [
      Icon(icon, size: 13, color: const Color(0xFF0D47A1)),
      const SizedBox(width: 6),
      Text('$role: ',
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37474F))),
      Expanded(
        child: Text('$email / $pass',
            style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}
