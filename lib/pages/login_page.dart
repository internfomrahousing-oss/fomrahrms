import 'dart:math' as math;
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
  static const _infinityBlue = Color(0xFFA9BEE0);

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

  // ── Left panel: infinity motif, Infinitheism tagline, and a mountain /
  // lake / lotus scene — the spiritual backdrop behind the FOMRA wordmark ──
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
          left: 0, right: 0, bottom: 0, height: 320,
          child: CustomPaint(painter: _InfinitheismScenePainter(), size: Size.infinite),
        ),
        Positioned(
          top: 0, left: 0, right: 0, bottom: 200,
          child: Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: _brandBlock(compact: false),
          )),
        ),
      ]),
    );
  }

  // Infinity glyph + Infinitheism tagline + divider + FOMRA wordmark.
  // Shared between the wide left panel and the compact mobile header.
  Widget _brandBlock({required bool compact}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.all_inclusive_rounded, size: compact ? 24 : 30, color: _infinityBlue),
      SizedBox(height: compact ? 12 : 18),
      Text('YOU ARE NOT THE BODY, YOU ARE NOT THE MIND,',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: _textMuted)),
      const SizedBox(height: 4),
      Text('YOU ARE INFINITY ITSELF.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: compact ? 11.5 : 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: _textDark)),
      SizedBox(height: compact ? 14 : 18),
      Container(width: 36, height: 2, color: _infinityBlue.withValues(alpha: 0.7)),
      SizedBox(height: compact ? 20 : 28),
      FomraLogoMark(wordmarkSize: compact ? 40 : 46),
    ]);
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
                Center(child: _brandBlock(compact: true)),
                const SizedBox(height: 36),
              ],

              if (_pendingUser == null) ...[
                Center(
                  child: Icon(Icons.spa_rounded, size: 32, color: _navy.withValues(alpha: 0.55)),
                ),
                const SizedBox(height: 14),
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

  Widget _infinityDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(children: [
          Icon(Icons.all_inclusive_rounded, size: 14, color: _textMuted),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: _borderGray, thickness: 1)),
          const SizedBox(width: 10),
          Icon(Icons.all_inclusive_rounded, size: 14, color: _textMuted),
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
      _infinityDivider(),
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

// A serene mountain range mirrored in a still lake, with a soft glow and a
// blossoming lotus resting on the waterline — the Infinitheism motif behind
// the sign-in form's "you are infinity itself" tagline.
class _InfinitheismScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizonY = h * 0.34;

    // Warm glow behind the peaks, radiating down onto the water.
    final glowRect = Rect.fromCircle(center: Offset(w / 2, horizonY), radius: w * 0.55);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0)],
        ).createShader(glowRect),
    );

    // Layered mountain silhouettes, lightest (furthest) to darkest (nearest).
    final layers = [
      (color: const Color(0xFFC3CEE6), alpha: 0.45, amp: 0.16, freq: 3.2, phase: 0.4),
      (color: const Color(0xFF9DAFD6), alpha: 0.55, amp: 0.13, freq: 4.1, phase: 1.7),
      (color: const Color(0xFF6E82B8), alpha: 0.65, amp: 0.10, freq: 5.3, phase: 3.1),
    ];
    for (final layer in layers) {
      final path = _mountainPath(w, horizonY, layer.amp * h, layer.freq, layer.phase);
      canvas.drawPath(path, Paint()..color = layer.color.withValues(alpha: layer.alpha));
    }

    // Still water beneath the horizon, fading toward the bottom edge.
    final waterRect = Rect.fromLTWH(0, horizonY, w, h - horizonY);
    canvas.drawRect(
      waterRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFDCE4F4).withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.05)],
        ).createShader(waterRect),
    );

    // Mirrored, softened reflection of the mountains in the water.
    canvas.save();
    canvas.clipRect(waterRect);
    for (final layer in layers) {
      final path = _mountainPath(w, horizonY, layer.amp * h, layer.freq, layer.phase);
      canvas.save();
      canvas.translate(0, 2 * horizonY);
      canvas.scale(1, -1);
      canvas.drawPath(path, Paint()..color = layer.color.withValues(alpha: layer.alpha * 0.35));
      canvas.restore();
    }
    canvas.restore();

    _drawLotus(canvas, Offset(w / 2, horizonY), math.min(w, h) * 0.30);
  }

  Path _mountainPath(double w, double horizonY, double amp, double freq, double phase) {
    final path = Path()..moveTo(0, horizonY);
    const steps = 40;
    for (int i = 0; i <= steps; i++) {
      final x = w * i / steps;
      final y = horizonY - amp * (0.5 + 0.5 * math.sin(freq * i / steps * math.pi + phase)).abs();
      path.lineTo(x, y);
    }
    path.lineTo(w, horizonY);
    path.close();
    return path;
  }

  void _drawLotus(Canvas canvas, Offset center, double scale) {
    final outerPaint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    final innerPaint = Paint()..color = Colors.white.withValues(alpha: 0.92);

    Path petal(double length, double width) {
      return Path()
        ..moveTo(0, 0)
        ..cubicTo(-width, -length * 0.42, -width * 0.55, -length * 0.85, 0, -length)
        ..cubicTo(width * 0.55, -length * 0.85, width, -length * 0.42, 0, 0)
        ..close();
    }

    void drawRing(List<double> anglesDeg, Path shape, Paint paint) {
      for (final deg in anglesDeg) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(deg * math.pi / 180);
        canvas.drawPath(shape, paint);
        canvas.restore();
      }
    }

    drawRing([-72, -43, -14, 14, 43, 72], petal(scale * 0.62, scale * 0.22), outerPaint);
    drawRing([-28, -9, 9, 28], petal(scale * 0.82, scale * 0.16), innerPaint);
    drawRing([0], petal(scale * 0.52, scale * 0.11), innerPaint);
  }

  @override
  bool shouldRepaint(covariant _InfinitheismScenePainter oldDelegate) => false;
}
