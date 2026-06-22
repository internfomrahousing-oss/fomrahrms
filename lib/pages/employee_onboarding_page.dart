import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/onboarding_store.dart';
import '../models/user_session.dart';
import '../models/profile_store.dart';

class EmployeeOnboardingPage extends StatefulWidget {
  const EmployeeOnboardingPage({super.key});

  @override
  State<EmployeeOnboardingPage> createState() =>
      _EmployeeOnboardingPageState();
}

class _EmployeeOnboardingPageState extends State<EmployeeOnboardingPage> {
  static const _primary = Color(0xFF0D47A1);

  final _formKey   = GlobalKey<FormState>();
  final _bankCtrl  = TextEditingController();
  final _ifscCtrl  = TextEditingController();

  Uint8List? _aadhaarDocBytes;
  Uint8List? _panDocBytes;
  Uint8List? _resumeBytes;
  Uint8List? _eduBytes;
  Uint8List? _expBytes;
  Uint8List? _passportBytes;
  bool _showImageErrors = false;

  @override
  void dispose() {
    _bankCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, void Function(Uint8List) onPicked) async {
    try {
      final file = await ImagePicker().pickImage(
          source: source, imageQuality: 85, maxWidth: 1200);
      if (file != null) onPicked(await file.readAsBytes());
    } catch (_) {}
  }

  void _showImageOptions(BuildContext context, void Function(Uint8List) onPicked) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Upload Document',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF0D47A1),
              child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            ),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera, (bytes) {
                onPicked(bytes);
                setState(() {});
              });
            },
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF1565C0),
              child: Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
            ),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery, (bytes) {
                onPicked(bytes);
                setState(() {});
              });
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    final imagesValid =
        _aadhaarDocBytes != null && _panDocBytes != null &&
        _resumeBytes != null && _eduBytes != null &&
        _expBytes != null && _passportBytes != null;

    if (!imagesValid) setState(() => _showImageErrors = true);
    if (!formValid || !imagesValid) return;

    final empId = UserSession.employeeId;
    if (empId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please complete your profile first — Employee ID is required.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    OnboardingStore.save(OnboardingData(
      employeeId:              empId,
      employeeName:            ProfileStore.current.fullName,
      aadhaarDoc:              _aadhaarDocBytes!,
      panDoc:                  _panDocBytes!,
      resume:                  _resumeBytes!,
      educationalCertificates: _eduBytes!,
      experienceLetters:       _expBytes!,
      bankAccount:             _bankCtrl.text.trim(),
      ifscCode:                _ifscCtrl.text.trim(),
      passportPhoto:           _passportBytes!,
      submittedAt:             DateTime.now(),
    ));

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Onboarding documents submitted successfully!'),
      backgroundColor: Color(0xFF2E7D32),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isHr = UserSession.role == UserRole.hr;
    if (isHr) return _HrView();

    final empId    = UserSession.employeeId;
    final existing = empId.isNotEmpty ? OnboardingStore.forId(empId) : null;
    if (existing != null) return _ViewOnly(data: existing);
    return _buildForm(context);
  }

  // ── Form ──────────────────────────────────────────────────────────────────
  Widget _buildForm(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_primary, Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.how_to_reg_rounded,
                      color: Colors.white, size: 28),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Employee Onboarding',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Fill all details and upload your documents once.',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Identity
            _SectionLabel(icon: Icons.badge_rounded, label: 'Identity Documents'),
            const SizedBox(height: 12),
            _ImagePickerField(
              label: 'Aadhaar Card',
              icon: Icons.credit_card_rounded,
              imageBytes: _aadhaarDocBytes,
              hasError: _showImageErrors && _aadhaarDocBytes == null,
              onTap: () => _showImageOptions(
                  context, (b) => setState(() => _aadhaarDocBytes = b)),
            ),
            const SizedBox(height: 12),
            _ImagePickerField(
              label: 'PAN Card',
              icon: Icons.article_rounded,
              imageBytes: _panDocBytes,
              hasError: _showImageErrors && _panDocBytes == null,
              onTap: () => _showImageOptions(
                  context, (b) => setState(() => _panDocBytes = b)),
            ),
            const SizedBox(height: 20),

            // Documents
            _SectionLabel(icon: Icons.folder_rounded, label: 'Documents & Certificates'),
            const SizedBox(height: 12),
            _ImagePickerField(
              label: 'Resume',
              icon: Icons.description_rounded,
              imageBytes: _resumeBytes,
              hasError: _showImageErrors && _resumeBytes == null,
              onTap: () => _showImageOptions(
                  context, (b) => setState(() => _resumeBytes = b)),
            ),
            const SizedBox(height: 12),
            _ImagePickerField(
              label: 'Educational Certificates',
              icon: Icons.school_rounded,
              imageBytes: _eduBytes,
              hasError: _showImageErrors && _eduBytes == null,
              onTap: () => _showImageOptions(
                  context, (b) => setState(() => _eduBytes = b)),
            ),
            const SizedBox(height: 12),
            _ImagePickerField(
              label: 'Experience Letters',
              icon: Icons.work_rounded,
              imageBytes: _expBytes,
              hasError: _showImageErrors && _expBytes == null,
              onTap: () => _showImageOptions(
                  context, (b) => setState(() => _expBytes = b)),
            ),
            const SizedBox(height: 12),
            _ImagePickerField(
              label: 'Passport Photo',
              icon: Icons.photo_camera_rounded,
              imageBytes: _passportBytes,
              hasError: _showImageErrors && _passportBytes == null,
              onTap: () => _showImageOptions(
                  context, (b) => setState(() => _passportBytes = b)),
            ),
            const SizedBox(height: 20),

            // Bank
            _SectionLabel(icon: Icons.account_balance_rounded, label: 'Bank Details'),
            const SizedBox(height: 12),
            _TextField(
              controller: _bankCtrl,
              label: 'Bank Account Number',
              icon: Icons.numbers_rounded,
              hint: 'Enter account number',
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _TextField(
              controller: _ifscCtrl,
              label: 'IFSC Code',
              icon: Icons.code_rounded,
              hint: 'e.g. SBIN0001234',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Submit Onboarding Documents',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Documents can only be submitted once.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

// ── HR view ────────────────────────────────────────────────────────────────────
class _HrView extends StatelessWidget {
  static const _primary = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    final all = OnboardingStore.all;
    return Material(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_primary, Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Icon(Icons.how_to_reg_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Employee Onboarding',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      '${all.length} submission${all.length == 1 ? '' : 's'} received',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _SectionLabel(icon: Icons.people_rounded, label: 'Submitted Documents'),
          const SizedBox(height: 12),
          if (all.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.inbox_rounded,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No submissions yet',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ]),
                ),
              ),
            )
          else
            ...all.map((data) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HrCard(data: data),
                )),
        ]),
      ),
    );
  }
}

class _HrCard extends StatefulWidget {
  final OnboardingData data;
  const _HrCard({required this.data});

  @override
  State<_HrCard> createState() => _HrCardState();
}

class _HrCardState extends State<_HrCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final submitted =
        '${d.submittedAt.day}/${d.submittedAt.month}/${d.submittedAt.year}';
    return Card(
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF0D47A1),
                child: Icon(Icons.person_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(d.employeeName.isEmpty ? d.employeeId : d.employeeName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A237E))),
                  const SizedBox(height: 2),
                  Text('ID: ${d.employeeId}  •  Submitted $submitted',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF78909C))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Submitted',
                    style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: const Color(0xFF78909C)),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const SizedBox(height: 8),
              _SectionLabel(icon: Icons.folder_rounded, label: 'Documents'),
              const SizedBox(height: 8),
              _ImageRow(label: 'Aadhaar Card',             bytes: d.aadhaarDoc),
              _ImageRow(label: 'PAN Card',                 bytes: d.panDoc),
              _ImageRow(label: 'Resume',                   bytes: d.resume),
              _ImageRow(label: 'Educational Certificates', bytes: d.educationalCertificates),
              _ImageRow(label: 'Experience Letters',       bytes: d.experienceLetters),
              _ImageRow(label: 'Passport Photo',           bytes: d.passportPhoto),
              const SizedBox(height: 8),
              _SectionLabel(icon: Icons.account_balance_rounded, label: 'Bank'),
              const SizedBox(height: 8),
              _InfoRow(label: 'Bank Account', value: d.bankAccount, isText: true),
              _InfoRow(label: 'IFSC Code',    value: d.ifscCode,    isText: true),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── View-only (after submission) ───────────────────────────────────────────────
class _ViewOnly extends StatelessWidget {
  final OnboardingData data;
  const _ViewOnly({required this.data});

  @override
  Widget build(BuildContext context) {
    final submitted =
        '${data.submittedAt.day}/${data.submittedAt.month}/${data.submittedAt.year}';
    return Material(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
              border: Border.all(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Documents Submitted',
                      style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text('Submitted on $submitted · HR can view your documents.',
                      style: const TextStyle(
                          color: Color(0xFF2E7D32), fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          _SectionLabel(icon: Icons.badge_rounded, label: 'Identity Documents'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _ImageRow(label: 'Aadhaar Card', bytes: data.aadhaarDoc),
                _ImageRow(label: 'PAN Card', bytes: data.panDoc),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          _SectionLabel(icon: Icons.folder_rounded, label: 'Documents & Certificates'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _ImageRow(label: 'Aadhaar Card',             bytes: data.aadhaarDoc),
                _ImageRow(label: 'PAN Card',                 bytes: data.panDoc),
                _ImageRow(label: 'Resume',                   bytes: data.resume),
                _ImageRow(label: 'Educational Certificates', bytes: data.educationalCertificates),
                _ImageRow(label: 'Experience Letters',       bytes: data.experienceLetters),
                _ImageRow(label: 'Passport Photo',           bytes: data.passportPhoto),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          _SectionLabel(icon: Icons.account_balance_rounded, label: 'Bank Details'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _InfoRow(label: 'Bank Account Number', value: data.bankAccount, isText: true),
                _InfoRow(label: 'IFSC Code',           value: data.ifscCode,   isText: true),
              ]),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: const Color(0xFF0D47A1), size: 16),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E))),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
    ]);
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String hint;
  final TextInputType keyboardType;
  final String? Function(String?) validator;

  const _TextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    required this.validator,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF0D47A1), size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF0D47A1), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        labelStyle: const TextStyle(color: Color(0xFF546E7A)),
      ),
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Uint8List? imageBytes;
  final bool hasError;
  final VoidCallback onTap;

  const _ImagePickerField({
    required this.label,
    required this.icon,
    required this.imageBytes,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? Colors.red
        : imageBytes != null
            ? const Color(0xFF0D47A1)
            : const Color(0xFFE0E0E0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: imageBytes != null ? 1.5 : 1),
        ),
        child: imageBytes != null ? _preview() : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF0D47A1), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Color(0xFF546E7A), fontSize: 14)),
        ),
        const Icon(Icons.upload_rounded, color: Color(0xFF0D47A1), size: 18),
        const SizedBox(width: 6),
        const Text('Upload',
            style: TextStyle(
                color: Color(0xFF0D47A1),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _preview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Stack(children: [
        Image.memory(
          imageBytes!,
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
        ),
        Positioned(
          top: 8, right: 8,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('Change',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
            ),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF81C784), size: 16),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ImageRow extends StatelessWidget {
  final String label;
  final Uint8List bytes;
  const _ImageRow({required this.label, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF546E7A))),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 80,
              color: const Color(0xFFF0F0F0),
              child: const Center(
                child: Text('Image not available',
                    style: TextStyle(color: Color(0xFF78909C))),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isText;
  const _InfoRow({required this.label, required this.value, required this.isText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 160,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF546E7A))),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1A237E))),
        ),
      ]),
    );
  }
}
