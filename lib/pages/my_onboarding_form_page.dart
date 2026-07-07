import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';
import '../widgets/back_button.dart';
import 'employee_onboarding_page.dart' show OnboardingFormReadOnlyBody;

const _green = Color(0xFF15803D);

/// Read-only view of the current employee's own onboarding form submission —
/// unlike EmployeeOnboardingPage (the HR/Management review queue), this only
/// ever shows the logged-in user's own record.
class MyOnboardingFormPage extends StatefulWidget {
  const MyOnboardingFormPage({super.key});

  @override
  State<MyOnboardingFormPage> createState() => _MyOnboardingFormPageState();
}

class _MyOnboardingFormPageState extends State<MyOnboardingFormPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final db    = Supabase.instance.client;
      final email = UserSession.email.trim();
      final name  = UserSession.name.trim();

      List<dynamic> rows = [];
      if (email.isNotEmpty) {
        rows = await db
            .from('onboarding_forms')
            .select()
            .eq('assigned_email', email)
            .order('submitted_at', ascending: false)
            .limit(1);
      }
      if (rows.isEmpty && name.isNotEmpty) {
        rows = await db
            .from('onboarding_forms')
            .select()
            .ilike('name', '%$name%')
            .order('submitted_at', ascending: false)
            .limit(1);
      }

      if (mounted) {
        setState(() {
          if (rows.isNotEmpty) {
            final row = Map<String, dynamic>.from(rows.first as Map);
            final fd  = row['form_data'];
            if (fd is Map) row.addAll(Map<String, dynamic>.from(fd));
            _data = row;
          } else {
            _data = null;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad = narrow ? 16.0 : 24.0;
    final d = _data;

    return Material(
      color: null,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.how_to_reg_rounded, color: _green, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Onboarding Form', style: Theme.of(context).textTheme.headlineMedium),
                const Text('The joining details you submitted',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, color: _green),
              onPressed: _fetch,
            ),
          ]),
          const SizedBox(height: 24),

          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: CircularProgressIndicator(color: _green, strokeWidth: 2)))
          else if (d == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.how_to_reg_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No onboarding form found for your account',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                ]),
              ),
            )
          else
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFEFF6FF))),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: OnboardingFormReadOnlyBody(data: d),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
