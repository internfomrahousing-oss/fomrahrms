import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_session.dart';
import '../models/app_user.dart';
import '../models/notification_store.dart';
import '../models/theme_notifier.dart';
import '../services/notification_service.dart';
import '../services/user_store.dart';
import '../services/session_storage.dart';
import '../services/supabase_service.dart';
import '../widgets/fomra_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _navy       = Color(0xFF1D3F91);
  static const _panelBgTop = Color(0xFFEDF0F8);
  static const _panelBgBot = Color(0xFFFAFBFD);
  static const _textDark   = Color(0xFF0F172A);
  static const _textMuted  = Color(0xFF64748B);
  static const _borderGray = Color(0xFFE2E8F0);
  static const _errorRed   = Color(0xFFDC2626);

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
          reportingManager: dynamicUser.reportingManager,
          isReportingManager: dynamicUser.isReportingManager);
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
    _completeLogin(match.$2, match.$3, match.$4, email: systemEmail,
        isReportingManager: match.$2 == UserRole.reportingManager);
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
      isReportingManager: match.$2 == UserRole.reportingManager,
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
        email: user.email,
        isReportingManager: user.isReportingManager);
  }

  void _completeLogin(UserRole role, String name, String employeeId, {
    String email = '',
    String designation = '',
    String reportingManager = '',
    bool isReportingManager = false,
  }) {
    UserSession.loggedIn         = true;
    UserSession.role             = role;
    UserSession.name             = name;
    UserSession.employeeId       = employeeId;
    UserSession.email            = email;
    UserSession.designation      = designation;
    UserSession.reportingManager = reportingManager;
    UserSession.isReportingManager = isReportingManager;
    SessionStorage.save();
    themeNotifier.loadForUser(employeeId);
    // Fetch photo URL in background — widgets listen via ValueNotifier pattern
    SupabaseService.fetchCurrentUserPhotoUrl(employeeId).then((url) {
      if (url != null) UserSession.photoUrl = url;
    });
    // loadAll() already ran at cold start with no signed-in user, so this
    // user's muted-category preferences (and unread count) weren't picked up yet.
    SupabaseService.fetchMutedCategories(email).then((muted) {
      NotificationStore.mutedCategories = muted.toSet();
      NotificationStore.recomputeUnread();
    });
    NotificationService.checkDailyTaskReminders();
    if (role == UserRole.hr || role == UserRole.management) {
      NotificationService.checkDailyReminders();
    }
    setState(() => _loading = false);
    switch (role) {
      case UserRole.hr:               context.go('/dashboard');
      case UserRole.reportingManager: context.go('/manager/dashboard');
      case UserRole.employee:         context.go('/employee/dashboard');
      case UserRole.management:       context.go('/management/dashboard');
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Forgot password?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _textDark)),
        content: Text(
          'Please contact your HR administrator to have your password reset.',
          style: GoogleFonts.inter(fontSize: 14, color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _navy)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 860;
          if (!wide) return _formColumn(showCompactLogo: true);
          return Row(children: [
            Expanded(flex: 5, child: _logoPanel()),
            Expanded(flex: 6, child: _formColumn(showCompactLogo: false)),
          ]);
        }),
      ),
    );
  }

  // ── Left panel: gradient backdrop, logo, and a building-wireframe motif ──
  Widget _logoPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_panelBgTop, _panelBgBot],
        ),
      ),
      child: Stack(children: [
        Positioned(
          top: -70, right: -70,
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0, height: 280,
          child: CustomPaint(painter: _BuildingPainter()),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: FomraLogoMark(wordmarkSize: 64),
          ),
        ),
      ]),
    );
  }

  // ── Right panel: the actual sign-in form ───────────────────────────────
  Widget _formColumn({required bool showCompactLogo}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showCompactLogo) ...[
                const Center(child: FomraLogoMark(wordmarkSize: 40)),
                const SizedBox(height: 36),
              ],

              if (_pendingUser == null) ...[
                Text('Welcome back',
                    style: GoogleFonts.inter(
                        fontSize: 28, fontWeight: FontWeight.w800, color: _textDark)),
                const SizedBox(height: 6),
                Text('Sign in to continue to your dashboard.',
                    style: GoogleFonts.inter(fontSize: 14, color: _textMuted)),
                const SizedBox(height: 32),
              ],

              _pendingUser != null ? _buildSetPasswordCard() : _buildLoginCard(),

              const SizedBox(height: 28),
              Text('© 2026 FOMRA. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11.5, color: _textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: _textDark)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderGray),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          style: GoogleFonts.inter(fontSize: 15, color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 15, color: _textMuted),
            prefixIcon: Icon(icon, size: 20, color: _textMuted),
            suffixIcon: suffix,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
          ),
        ),
      ),
    ]);
  }

  Widget _obscureToggle(bool obscure, VoidCallback onPressed) => IconButton(
        icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 19, color: _textMuted),
        onPressed: onPressed,
      );

  Widget _primaryButton({required VoidCallback? onPressed, required Widget child}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
          disabledBackgroundColor: _navy.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }

  Widget _orDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(children: [
          const Expanded(child: Divider(color: _borderGray, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: GoogleFonts.inter(fontSize: 13, color: _textMuted)),
          ),
          const Expanded(child: Divider(color: _borderGray, thickness: 1)),
        ]),
      );

  Widget _securityNote() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.verified_user_rounded, size: 20, color: _navy),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your data is secure with us',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: _textDark)),
            const SizedBox(height: 2),
            Text('We use enterprise-grade security to protect your information.',
                style: GoogleFonts.inter(fontSize: 12, color: _textMuted)),
          ]),
        ),
      ]);

  Widget _buildLoginCard() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _labeledField(
        label: 'Email',
        controller: _emailCtrl,
        hint: 'Enter your email',
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 18),
      _labeledField(
        label: 'Password',
        controller: _passwordCtrl,
        hint: 'Enter your password',
        icon: Icons.lock_outline_rounded,
        obscure: _obscure,
        onSubmitted: (_) => _login(),
        suffix: _obscureToggle(_obscure, () => setState(() => _obscure = !_obscure)),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text('Forgot password?',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
          ),
        ),
      ),
      _errorBanner(),
      const SizedBox(height: 14),
      _primaryButton(
        onPressed: _loading ? null : _login,
        child: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('Sign In',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      _orDivider(),
      _securityNote(),
    ]);
  }

  Widget _buildSetPasswordCard() {
    final user = _pendingUser!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderGray),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_open_rounded, color: _navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome, ${user.name}!',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
              Text('Set your password to continue.',
                  style: GoogleFonts.inter(fontSize: 12, color: _textMuted)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 22),
      _labeledField(
        label: 'New password',
        controller: _newPassCtrl,
        hint: 'Create Password',
        icon: Icons.lock_outline_rounded,
        obscure: _obscureNew,
        suffix: _obscureToggle(_obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
      ),
      const SizedBox(height: 18),
      _labeledField(
        label: 'Confirm password',
        controller: _confirmCtrl,
        hint: 'Confirm Password',
        icon: Icons.lock_outline_rounded,
        obscure: _obscureConfirm,
        onSubmitted: (_) => _savePassword(),
        suffix: _obscureToggle(_obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
      ),
      _errorBanner(),
      const SizedBox(height: 22),
      _primaryButton(
        onPressed: _loading ? null : _savePassword,
        child: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('Set Password & Continue',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => setState(() { _pendingUser = null; _error = null; }),
        child: Text('Back to Login',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
      ),
    ]);
  }

  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, size: 15, color: _errorRed),
        const SizedBox(width: 6),
        Expanded(
          child: Text(_error!,
              style: GoogleFonts.inter(fontSize: 12.5, color: _errorRed)),
        ),
      ]),
    );
  }
}

// A faint skyscraper wireframe — a tapered tower silhouette filled with a
// thin grid — anchored to the bottom-left corner of the logo panel.
class _BuildingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.32)
      ..lineTo(size.width * 0.6, size.height * 0.04)
      ..lineTo(size.width * 0.6, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFF3B6FB0).withValues(alpha: 0.05));

    canvas.save();
    canvas.clipPath(path);
    final linePaint = Paint()
      ..color = const Color(0xFF3B6FB0).withValues(alpha: 0.16)
      ..strokeWidth = 1;
    const step = 18.0;
    for (double x = 0; x < size.width * 0.6; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.6, y), linePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BuildingPainter oldDelegate) => false;
}
