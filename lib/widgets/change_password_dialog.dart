import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Self-service "change my password" dialog — opened from the profile
/// dropdown (see profile_avatar_button.dart). Distinct from the token-gated
/// forgot-password flow: this requires the current password and works for
/// any already-logged-in user.
Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    final result = await SupabaseService.changeOwnPassword(
        _currentCtrl.text, _newCtrl.text);
    if (!mounted) return;
    if (result == true) {
      setState(() { _saving = false; _done = true; });
    } else if (result == false) {
      setState(() { _saving = false; _error = 'Current password is incorrect.'; });
    } else {
      setState(() { _saving = false; _error = 'Could not change password — please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Change Password'),
      content: SizedBox(
        width: 380,
        child: _done
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(child: Text('Your password has been changed.')),
                ]),
              )
            : Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _currentCtrl,
                    obscureText: !_showCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showCurrent
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded, size: 18),
                        onPressed: () => setState(() => _showCurrent = !_showCurrent),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your current password' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newCtrl,
                    obscureText: !_showNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showNew
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded, size: 18),
                        onPressed: () => setState(() => _showNew = !_showNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a new password';
                      if (v.length < 6) return 'Must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: !_showConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showConfirm
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded, size: 18),
                        onPressed: () => setState(() => _showConfirm = !_showConfirm),
                      ),
                    ),
                    validator: (v) =>
                        v != _newCtrl.text ? 'Passwords do not match' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(color: Color(0xFFE53935), fontSize: 12.5)),
                  ],
                ]),
              ),
      ),
      actions: _done
          ? [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                child: const Text('Done'),
              ),
            ]
          : [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                child: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Change Password'),
              ),
            ],
    );
  }
}
