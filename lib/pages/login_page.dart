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
  final _newPassCtrl  = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _loading       = false;
  bool _obscure       = true;
  bool _obscureNew    = true;
  bool _obscureConfirm = true;
  String? _error;

  // When non-null, this user needs to set their password for the first time
  AppUser? _pendingUser;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // Fallback system credentials (always work)
  static const _systemCredentials = {
    'hr@fomrahousing.in':         ('Admin@123',  UserRole.hr,               'HR Admin',     'HR001'),
    'manager@fomrahousing.in':    ('Manager@123',UserRole.reportingManager, 'Ravi Kumar',   'MGR001'),
    'employee@fomrahousing.in':   ('Emp@123',    UserRole.employee,         'Priya Sharma', 'EMP001'),
    'management@fomrahousing.in': ('Mgmt@123',   UserRole.management,       'Director',     'MGMT001'),
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
      // First login — no password set yet, prompt user to create one
      if (dynamicUser.password.isEmpty) {
        setState(() { _loading = false; _pendingUser = dynamicUser; });
        return;
      }
      if (password != dynamicUser.password) {
        setState(() { _error = 'Invalid email or password.'; _loading = false; });
        return;
      }
      _completeLogin(AppUser.userRoleFor(dynamicUser.role), dynamicUser.name,
          dynamicUser.employeeId.isNotEmpty ? dynamicUser.employeeId : dynamicUser.email);
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
    _completeLogin(match.$2, match.$3, match.$4);
  }

  Future<void> _savePassword() async {
    final newPass = _newPassCtrl.text;
    final confirm = _confirmCtrl.text;
    if (newPass.isEmpty) {
      setState(() => _error = 'Please enter a password.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    final user = _pendingUser!;
    user.password = newPass;
    await UserStore.upsertOne(user);
    if (!mounted) return;
    _completeLogin(AppUser.userRoleFor(user.role), user.name,
        user.employeeId.isNotEmpty ? user.employeeId : user.email);
  }

  void _completeLogin(UserRole role, String name, String employeeId) {
    UserSession.loggedIn   = true;
    UserSession.role       = role;
    UserSession.name       = name;
    UserSession.employeeId = employeeId;
    setState(() => _loading = false);
    switch (role) {
      case UserRole.hr:               context.go('/dashboard');
      case UserRole.reportingManager: context.go('/manager/dashboard');
      case UserRole.employee:         context.go('/employee/dashboard');
      case UserRole.management:       context.go('/management/dashboard');
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
                child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('FOMRA HRMS',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                      color: _color, letterSpacing: 3)),
              const SizedBox(height: 6),
              const Text('Housing & Infrastructure',
                  style: TextStyle(fontSize: 13, color: Color(0xFF78909C), letterSpacing: 1)),
              const SizedBox(height: 40),

              // Card — either normal login or first-login set-password
              _pendingUser != null ? _buildSetPasswordCard() : _buildLoginCard(),

              const SizedBox(height: 24),
              Text('FOMRA Housing & Infrastructure © 2025',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Email
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration('Email', Icons.email_rounded),
          ),
          const SizedBox(height: 16),

          // Password
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            onSubmitted: (_) => _login(),
            decoration: _inputDecoration('Password', Icons.lock_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: const Color(0xFF78909C)),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),

          _errorBanner(),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _login,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login_rounded),
              label: Text(_loading ? 'Signing in…' : 'Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _color, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _CredentialsHint(),
        ]),
      ),
    );
  }

  Widget _buildSetPasswordCard() {
    final user = _pendingUser!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Welcome header
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_open_rounded, color: _color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome, ${user.name}!',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _color)),
                const Text('Set your password to continue.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
              ]),
            ),
          ]),
          const SizedBox(height: 20),

          // New password
          TextField(
            controller: _newPassCtrl,
            obscureText: _obscureNew,
            decoration: _inputDecoration('Create Password', Icons.lock_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: const Color(0xFF78909C)),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm password
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            onSubmitted: (_) => _savePassword(),
            decoration: _inputDecoration('Confirm Password', Icons.lock_outline_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: const Color(0xFF78909C)),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),

          _errorBanner(),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _savePassword,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_loading ? 'Saving…' : 'Set Password & Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _color, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() { _pendingUser = null; _error = null; }),
              child: const Text('Back to Login',
                  style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
            ),
          ),
        ]),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _color, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }

  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
          ),
        ]),
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
        const Text('Admin Credentials',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
        const SizedBox(height: 2),
        const Text('Users created by Management set their own password on first login.',
            style: TextStyle(fontSize: 10, color: Color(0xFF78909C))),
        const SizedBox(height: 6),
        _cred(Icons.manage_accounts_rounded, 'Management', 'management@fomrahousing.in', 'Mgmt@123'),
        const SizedBox(height: 4),
        _cred(Icons.admin_panel_settings_rounded, 'HR', 'hr@fomrahousing.in', 'Admin@123'),
        const SizedBox(height: 4),
        _cred(Icons.supervisor_account_rounded, 'Manager', 'manager@fomrahousing.in', 'Manager@123'),
      ]),
    );
  }

  Widget _cred(IconData icon, String role, String email, String pass) {
    return Row(children: [
      Icon(icon, size: 13, color: const Color(0xFF0D47A1)),
      const SizedBox(width: 6),
      Text('$role: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
      Expanded(
        child: Text('$email / $pass',
            style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}
