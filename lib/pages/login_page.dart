import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_session.dart';
import '../models/app_user.dart';
import '../models/theme_notifier.dart';
import '../services/user_store.dart';
import '../services/session_storage.dart';
import '../services/supabase_service.dart';
import '../widgets/space_backdrop.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Deep-space navy palette — swapped in for the graphical split-screen login.
  static const _panelBg    = Color(0xFF080C15);
  static const _accent     = Color(0xFF8FB4EE); // soft pastel blue (button, highlights)
  static const _accentDeep = Color(0xFF3E7BDE); // used for focus rings / icons
  static const _border     = Color(0xFF1E2740);
  static const _fieldFill  = Color(0xFF0E1424);
  static const _textMuted  = Color(0xFF8A93AC);

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
          dynamicUser.employeeId.isNotEmpty ? dynamicUser.employeeId : dynamicUser.email,
          email: dynamicUser.email,
          designation: dynamicUser.designation,
          reportingManager: dynamicUser.reportingManager);
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
    final systemEmail = email.toLowerCase();
    await _ensureSystemUserProvisioned(systemEmail, match);
    _completeLogin(match.$2, match.$3, match.$4, email: systemEmail);
  }

  // System-credential logins (HR/Manager/Employee demo accounts) never had a
  // matching AppUser row, so they never showed up as a regular employee
  // record (e.g. in Employee Management, or in the leave/payslip lookups
  // that key off the app_users table) even though HR and Manager are
  // employees too. Management is not an employee record, so it's excluded.
  static String _roleString(UserRole role) => switch (role) {
        UserRole.hr => 'HR',
        UserRole.reportingManager => 'Manager',
        UserRole.management => 'Management',
        UserRole.employee => 'Employee',
      };

  static String _designationFor(UserRole role) => switch (role) {
        UserRole.hr => 'HR Administrator',
        UserRole.reportingManager => 'Reporting Manager',
        UserRole.management => 'Director',
        UserRole.employee => 'Employee',
      };

  Future<void> _ensureSystemUserProvisioned(
      String email, (String, UserRole, String, String) match) async {
    if (match.$2 == UserRole.management) return;
    final existing = await UserStore.findByEmail(email);
    if (existing != null) return;
    final now = DateTime.now().toIso8601String();
    await UserStore.upsertOne(AppUser(
      name: match.$3,
      email: email,
      employeeId: match.$4,
      designation: _designationFor(match.$2),
      role: _roleString(match.$2),
      password: match.$1,
      dateOfJoining: now,
      onrollConfirmedAt: now,
    ));
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
        user.employeeId.isNotEmpty ? user.employeeId : user.email,
        email: user.email);
  }

  void _completeLogin(UserRole role, String name, String employeeId, {
    String email = '',
    String designation = '',
    String reportingManager = '',
  }) {
    UserSession.loggedIn         = true;
    UserSession.role             = role;
    UserSession.name             = name;
    UserSession.employeeId       = employeeId;
    UserSession.email            = email;
    UserSession.designation      = designation;
    UserSession.reportingManager = reportingManager;
    SessionStorage.save();
    themeNotifier.loadForUser(employeeId);
    // Fetch photo URL in background — widgets listen via ValueNotifier pattern
    SupabaseService.fetchCurrentUserPhotoUrl(employeeId).then((url) {
      if (url != null) UserSession.photoUrl = url;
    });
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
      backgroundColor: _panelBg,
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final formPanel = _formPanel(wide);
        if (!wide) return formPanel;
        return Row(children: [
          Expanded(flex: 5, child: formPanel),
          const Expanded(flex: 6, child: SpaceBackdrop()),
        ]);
      }),
    );
  }

  Widget _formPanel(bool wide) {
    return Container(
      color: _panelBg,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _CornerGridPainter())),
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 56 : 28, 40, wide ? 56 : 28, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo ──────────────────────────────────────────
                Row(children: [
                  Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [_accent, _accentDeep],
                      ),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('FOMRA HRMS',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 0.4)),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Text('Housing & Infrastructure',
                      style: GoogleFonts.inter(fontSize: 11, color: _textMuted, letterSpacing: 1.2)),
                ),
                SizedBox(height: wide ? 72 : 48),

                // ── Headline ──────────────────────────────────────
                Text("We're managing your\nworkforce so you\ndon't have to",
                    style: GoogleFonts.inter(
                        fontSize: 30, fontWeight: FontWeight.w600,
                        color: Colors.white, height: 1.28, letterSpacing: -0.3)),
                const SizedBox(height: 36),

                _pendingUser != null ? _buildSetPasswordCard() : _buildLoginCard(),

                const SizedBox(height: 20),
                const _CredentialsHint(),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textMuted)),
      );

  Widget _buildLoginCard() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Email'),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        decoration: _inputDecoration('you@fomrahousing.in'),
      ),
      const SizedBox(height: 16),
      _fieldLabel('Password'),
      TextField(
        controller: _passwordCtrl,
        obscureText: _obscure,
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        onSubmitted: (_) => _login(),
        decoration: _inputDecoration('••••••••').copyWith(
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18, color: _textMuted),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      _errorBanner(),
      const SizedBox(height: 22),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _login,
          icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _panelBg))
              : const Icon(Icons.login_rounded, size: 18, color: _panelBg),
          label: Text(_loading ? 'Signing in…' : 'Continue',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _panelBg)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }

  Widget _buildSetPasswordCard() {
    final user = _pendingUser!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.lock_open_rounded, color: _accent, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome, ${user.name}!',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Set your password to continue.',
                style: GoogleFonts.inter(fontSize: 12, color: _textMuted)),
          ]),
        ),
      ]),
      const SizedBox(height: 22),
      _fieldLabel('Create Password'),
      TextField(
        controller: _newPassCtrl,
        obscureText: _obscureNew,
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        decoration: _inputDecoration('••••••••').copyWith(
          suffixIcon: IconButton(
            icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18, color: _textMuted),
            onPressed: () => setState(() => _obscureNew = !_obscureNew),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _fieldLabel('Confirm Password'),
      TextField(
        controller: _confirmCtrl,
        obscureText: _obscureConfirm,
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        onSubmitted: (_) => _savePassword(),
        decoration: _inputDecoration('••••••••').copyWith(
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18, color: _textMuted),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ),
      _errorBanner(),
      const SizedBox(height: 22),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _savePassword,
          icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _panelBg))
              : const Icon(Icons.check_rounded, size: 18, color: _panelBg),
          label: Text(_loading ? 'Saving…' : 'Set Password & Continue',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _panelBg)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: () => setState(() { _pendingUser = null; _error = null; }),
          child: Text('Back to Login', style: GoogleFonts.inter(fontSize: 12, color: _textMuted)),
        ),
      ),
    ]);
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: _textMuted.withValues(alpha: 0.6)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accentDeep, width: 1.6),
      ),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade700.withValues(alpha: 0.6)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade300),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade200)),
          ),
        ]),
      ),
    );
  }
}

// Faint diagonal cross-hatch in the lower-left corner of the form panel —
// echoes the graphic panel's grid without competing with the form itself.
class _CornerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const spacing = 26.0;
    final mask = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(
          center: Offset(0, size.height), radius: size.height * 0.85));

    final layer = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(layer, Paint());
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
    canvas.drawRect(layer, Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = mask.shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CornerGridPainter oldDelegate) => false;
}

class _CredentialsHint extends StatelessWidget {
  const _CredentialsHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2740)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Admin Credentials',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _LoginPageState._accent)),
        const SizedBox(height: 2),
        Text('Users created by Management set their own password on first login.',
            style: GoogleFonts.inter(fontSize: 10, color: _LoginPageState._textMuted)),
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
      Icon(icon, size: 13, color: _LoginPageState._accent),
      const SizedBox(width: 6),
      Text('$role: ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
          color: Colors.white70)),
      Expanded(
        child: Text('$email / $pass',
            style: GoogleFonts.inter(fontSize: 11, color: _LoginPageState._textMuted),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}
