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
  // iOS system colors (light appearance only).
  static const _iosBlue      = Color(0xFF007AFF);
  static const _iosBg        = Color(0xFFF2F2F7);
  static const _iosLabel     = Color(0xFF1C1C1E);
  static const _iosSecondary = Color(0xFF8E8E93);
  static const _iosSeparator = Color(0xFFE5E5EA);

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
    // loadAll() already ran at cold start with no signed-in user, so this
    // user's muted-category preferences (and unread count) weren't picked up yet.
    SupabaseService.fetchMutedCategories(email).then((muted) {
      NotificationStore.mutedCategories = muted.toSet();
      NotificationStore.recomputeUnread();
    });
    if (role == UserRole.hr) {
      NotificationService.checkDailyHrReminders();
    }
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 860;
          if (!wide) return _formColumn(showCompactLogo: true);
          return Row(children: [
            Expanded(flex: 5, child: _logoPanel()),
            const VerticalDivider(width: 1, thickness: 1, color: _iosSeparator),
            Expanded(flex: 6, child: _formColumn(showCompactLogo: false)),
          ]);
        }),
      ),
    );
  }

  // ── Left panel: the company logo, large and centered ──────────────────
  Widget _logoPanel() {
    return Container(
      color: _iosBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(48),
      child: const FomraLogoMark(wordmarkSize: 64),
    );
  }

  // ── Right panel: the actual sign-in form ───────────────────────────────
  Widget _formColumn({required bool showCompactLogo}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
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
                        fontSize: 26, fontWeight: FontWeight.w700, color: _iosLabel)),
                const SizedBox(height: 4),
                Text('Sign in to continue to your dashboard.',
                    style: GoogleFonts.inter(fontSize: 13.5, color: _iosSecondary)),
                const SizedBox(height: 28),
              ],

              _pendingUser != null ? _buildSetPasswordCard() : _buildLoginCard(),

              const SizedBox(height: 28),
              Text('FOMRA Housing & Infrastructure © 2025',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11, color: _iosSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  // A grouped, inset iOS-style list card: rows separated by hairline
  // dividers, no per-field borders — only the outer card is rounded.
  Widget _groupedCard({required List<Widget> rows}) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Divider(height: 1, thickness: 0.6, color: _iosSeparator),
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _iosSeparator),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _groupedField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: GoogleFonts.inter(fontSize: 15, color: _iosLabel),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 15, color: _iosSecondary),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 6),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: _iosSecondary, letterSpacing: 0.4)),
      );

  Widget _pillButton({required VoidCallback? onPressed, required Widget child}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _iosBlue,
          disabledBackgroundColor: _iosBlue.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }

  Widget _buildLoginCard() {
    return Column(children: [
      _groupedCard(rows: [
        _groupedField(controller: _emailCtrl, hint: 'Email', keyboardType: TextInputType.emailAddress),
        _groupedField(
          controller: _passwordCtrl,
          hint: 'Password',
          obscure: _obscure,
          onSubmitted: (_) => _login(),
          suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 19, color: _iosSecondary),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ]),
      _errorBanner(),
      const SizedBox(height: 22),
      _pillButton(
        onPressed: _loading ? null : _login,
        child: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('Sign In',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _buildSetPasswordCard() {
    final user = _pendingUser!;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _iosSeparator),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _iosBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_open_rounded, color: _iosBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome, ${user.name}!',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _iosLabel)),
              Text('Set your password to continue.',
                  style: GoogleFonts.inter(fontSize: 12, color: _iosSecondary)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      _sectionLabel('New password'),
      _groupedCard(rows: [
        _groupedField(
          controller: _newPassCtrl,
          hint: 'Create Password',
          obscure: _obscureNew,
          suffix: IconButton(
            icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 19, color: _iosSecondary),
            onPressed: () => setState(() => _obscureNew = !_obscureNew),
          ),
        ),
        _groupedField(
          controller: _confirmCtrl,
          hint: 'Confirm Password',
          obscure: _obscureConfirm,
          onSubmitted: (_) => _savePassword(),
          suffix: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 19, color: _iosSecondary),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ]),
      _errorBanner(),
      const SizedBox(height: 22),
      _pillButton(
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
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _iosBlue)),
      ),
    ]);
  }

  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFFF3B30)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(_error!,
              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFFF3B30))),
        ),
      ]),
    );
  }
}
