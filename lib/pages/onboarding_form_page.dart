// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AttachFile {
  final String name;
  Uint8List bytes;
  String mime;
  _AttachFile({required this.name, required this.bytes, required this.mime});
}

class OnboardingFormPage extends StatefulWidget {
  const OnboardingFormPage({super.key});

  @override
  State<OnboardingFormPage> createState() => _OnboardingFormPageState();
}

class _OnboardingFormPageState extends State<OnboardingFormPage> {
  static const _primary = Color(0xFF0D47A1);
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;
  bool _saving = false;

  // ── Section 1: Basic Info
  final _name        = TextEditingController();
  final _phone       = TextEditingController();
  final _fatherName  = TextEditingController();
  final _motherName  = TextEditingController();
  final _designation = TextEditingController();
  DateTime? _dateJoiningDate;

  // ── Section 2: Personal Data
  final _fullName         = TextEditingController();
  DateTime? _dobDate;
  final _postalAddress    = TextEditingController();
  final _permanentAddress = TextEditingController();

  // ── Section 3: Family Details (dynamic rows + parallel state)
  List<Map<String, TextEditingController>> _familyRows = [];
  List<String?> _familyGenders   = [];
  List<String?> _familyRelations = [];
  List<_AttachFile?> _familyAadhars = [];

  // ── Section 4: Education (dynamic rows)
  List<Map<String, TextEditingController>> _educationRows = [];

  // ── Section 5: Experience (dynamic rows)
  List<Map<String, TextEditingController>> _experienceRows = [];

  // ── Section 6: Last Position
  final _lastReportingName  = TextEditingController();
  final _lastReportingDesig = TextEditingController();
  final _lastCompany        = TextEditingController();
  final _ref1               = TextEditingController();
  final _ref2               = TextEditingController();

  // ── Section 7: Additional Info
  final _esiNumber          = TextEditingController();
  final _pfNumber           = TextEditingController();
  final _languages          = TextEditingController();
  final _hobbies            = TextEditingController();
  final _interests          = TextEditingController();
  final _relatedToEmployee  = TextEditingController();
  final _professionalMember = TextEditingController();
  final _specializedTraining= TextEditingController();
  final _otherInfo          = TextEditingController();

  // ── Section 8: Emergency Details
  String? _bloodGroupValue;
  final _allergicTo       = TextEditingController();
  final _majorIllness     = TextEditingController();
  final _emergencyName    = TextEditingController();
  final _emergencyNumber  = TextEditingController();
  final _emergencyAddress = TextEditingController();
  _AttachFile? _emergencyAadharFile;

  // ── Declaration
  DateTime? _declarationDateVal;
  final _declarationPlace = TextEditingController();
  bool _declarationAgreed = false;

  // ── Attachments (6 doc types, each can have multiple files)
  static const _docLabels = [
    'Photocopies of all Educational certificates & degree mark sheets etc.',
    'Aadhar Card',
    'PAN Card',
    'Experience & Relieving letters of Previous employment\'s',
    'Pay Slips or Bank Statement of Previous employment\'s',
    'Passport Size Photo (2)',
  ];
  final List<List<_AttachFile>> _attachments = List.generate(6, (_) => []);

  @override
  void initState() {
    super.initState();
    _addFamilyRow();
    _addEducationRow();
    _addExperienceRow();
  }

  // ── Row management ────────────────────────────────────────────────────────

  void _addFamilyRow() {
    _familyRows.add({
      'name':       TextEditingController(),
      'age':        TextEditingController(),
      'occupation': TextEditingController(),
    });
    _familyGenders.add(null);
    _familyRelations.add(null);
    _familyAadhars.add(null);
    setState(() {});
  }

  void _addEducationRow() {
    _educationRows.add({
      'qualification': TextEditingController(),
      'university':    TextEditingController(),
      'year':          TextEditingController(),
      'marks':         TextEditingController(),
      'subject':       TextEditingController(),
    });
    setState(() {});
  }

  void _addExperienceRow() {
    _experienceRows.add({
      'organisation':   TextEditingController(),
      'from':           TextEditingController(),
      'to':             TextEditingController(),
      'desig_joining':  TextEditingController(),
      'desig_relieving':TextEditingController(),
      'job_resp':       TextEditingController(),
      'superior':       TextEditingController(),
      'salary':         TextEditingController(),
      'reason':         TextEditingController(),
    });
    setState(() {});
  }

  void _removeFamilyRow(int i) {
    for (final c in _familyRows[i].values) c.dispose();
    _familyRows.removeAt(i);
    _familyGenders.removeAt(i);
    _familyRelations.removeAt(i);
    _familyAadhars.removeAt(i);
    setState(() {});
  }

  void _removeEducationRow(int i) {
    for (final c in _educationRows[i].values) c.dispose();
    _educationRows.removeAt(i);
    setState(() {});
  }

  void _removeExperienceRow(int i) {
    for (final c in _experienceRows[i].values) c.dispose();
    _experienceRows.removeAt(i);
    setState(() {});
  }

  // ── Date helpers ──────────────────────────────────────────────────────────

  String _fmt(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<DateTime?> _pickDate({
    DateTime? initial,
    DateTime? first,
    DateTime? last,
  }) =>
      showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: first ?? DateTime(1950),
        lastDate: last ?? DateTime(2100),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _primary)),
          child: child!,
        ),
      );

  // ── File helpers ──────────────────────────────────────────────────────────

  // Pick a single file (for aadhar uploads). Auto-compresses images > 1 MB.
  Future<_AttachFile?> _pickSingleFile(
      {String accept = 'image/*,.pdf'}) async {
    final input = html.FileUploadInputElement()..accept = accept;
    input.click();
    await input.onChange.first;
    final fileList = input.files;
    if (fileList == null || fileList.isEmpty) return null;
    final file = fileList[0];
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    var bytes = (reader.result as ByteBuffer).asUint8List();
    var mime = file.type.isEmpty ? 'application/octet-stream' : file.type;
    if (bytes.length > 1024 * 1024 && mime.startsWith('image/')) {
      final compressed = await _compressImage(bytes, mime);
      if (compressed != null) {
        bytes = compressed;
        mime = 'image/jpeg';
      }
    }
    return _AttachFile(name: file.name, bytes: bytes, mime: mime);
  }

  // Pick multiple files (for attachment section). Auto-compresses images > 1 MB.
  void _pickFiles(int docIndex) {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*,.pdf,.doc,.docx,.xls,.xlsx'
      ..multiple = true;
    input.click();
    input.onChange.listen((_) async {
      final fileList = input.files;
      if (fileList == null || fileList.isEmpty) return;
      for (int fi = 0; fi < fileList.length; fi++) {
        final file = fileList[fi];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        var bytes = (reader.result as ByteBuffer).asUint8List();
        var mime = file.type.isEmpty ? 'application/octet-stream' : file.type;
        // Auto-compress images > 1 MB
        if (bytes.length > 1024 * 1024 && file.type.startsWith('image/')) {
          final compressed = await _compressImage(bytes, file.type);
          if (compressed != null) {
            bytes = compressed;
            mime = 'image/jpeg';
          }
        }
        if (mounted) {
          setState(() => _attachments[docIndex]
              .add(_AttachFile(name: file.name, bytes: bytes, mime: mime)));
        }
      }
    });
  }

  // Compress image using Canvas API until it's under 1 MB.
  Future<Uint8List?> _compressImage(Uint8List bytes, String mime) async {
    try {
      final blob = html.Blob([bytes], mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final img = html.ImageElement(src: url);
      await img.onLoad.first;
      html.Url.revokeObjectUrl(url);

      int w = img.naturalWidth;
      int h = img.naturalHeight;
      const maxDim = 1920;
      if (w > maxDim || h > maxDim) {
        if (w > h) {
          h = (h * maxDim / w).round();
          w = maxDim;
        } else {
          w = (w * maxDim / h).round();
          h = maxDim;
        }
      }

      for (final quality in [0.7, 0.5, 0.3, 0.15]) {
        final canvas = html.CanvasElement(width: w, height: h);
        canvas.context2D
            .drawImageScaled(img, 0, 0, w.toDouble(), h.toDouble());
        final dataUrl = canvas.toDataUrl('image/jpeg', quality);
        final compressed =
            Uint8List.fromList(base64Decode(dataUrl.split(',').last));
        if (compressed.length <= 1024 * 1024) return compressed;
      }
      // Last resort at minimum quality
      final canvas = html.CanvasElement(width: w, height: h);
      canvas.context2D.drawImageScaled(img, 0, 0, w.toDouble(), h.toDouble());
      return Uint8List.fromList(
          base64Decode(canvas.toDataUrl('image/jpeg', 0.1).split(',').last));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _uploadSingleFile(_AttachFile file, String path) async {
    try {
      await Supabase.instance.client.storage
          .from('onboarding-attachments')
          .uploadBinary(path, file.bytes,
              fileOptions: FileOptions(contentType: file.mime));
      return Supabase.instance.client.storage
          .from('onboarding-attachments')
          .getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _uploadAttachments(String ts) async {
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < _attachments.length; i++) {
      for (final file in _attachments[i]) {
        final path = '$ts/doc${i + 1}_${file.name}';
        final url = await _uploadSingleFile(file, path) ?? '';
        result.add({'doc_type': _docLabels[i], 'name': file.name, 'url': url});
      }
    }
    return result;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_declarationAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please agree to the declaration before submitting.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _saving = true);

    final ts = DateTime.now().millisecondsSinceEpoch.toString();

    // Upload family aadhar files
    final familyAadharUrls = <String?>[];
    for (int i = 0; i < _familyAadhars.length; i++) {
      final f = _familyAadhars[i];
      familyAadharUrls.add(f != null
          ? await _uploadSingleFile(f, '$ts/family_aadhar_${i}_${f.name}')
          : null);
    }

    // Upload emergency aadhar
    String? emergencyAadharUrl;
    if (_emergencyAadharFile != null) {
      emergencyAadharUrl = await _uploadSingleFile(
          _emergencyAadharFile!,
          '$ts/emergency_aadhar_${_emergencyAadharFile!.name}');
    }

    // Build family data
    final familyData = _familyRows.asMap().entries.map((e) {
      final i = e.key;
      final row = e.value;
      return {
        'name':       row['name']!.text.trim(),
        'age':        row['age']!.text.trim(),
        'occupation': row['occupation']!.text.trim(),
        'gender':     _familyGenders[i] ?? '',
        'relation':   _familyRelations[i] ?? '',
        'aadhar_url': familyAadharUrls[i] ?? '',
      };
    }).toList();

    final uploadedFiles = await _uploadAttachments(ts);

    final payload = {
      'name':                       _name.text.trim(),
      'phone_number':               _phone.text.trim(),
      'father_name':                _fatherName.text.trim(),
      'mother_name':                _motherName.text.trim(),
      'designation':                _designation.text.trim(),
      'date_of_joining':            _fmt(_dateJoiningDate),
      'full_name':                  _fullName.text.trim(),
      'date_of_birth':              _fmt(_dobDate),
      'postal_address':             _postalAddress.text.trim(),
      'permanent_address':          _permanentAddress.text.trim(),
      'family_details':             familyData,
      'education':                  _educationRows.map(_rowToMap).toList(),
      'experience':                 _experienceRows.map(_rowToMap).toList(),
      'last_reporting_name':        _lastReportingName.text.trim(),
      'last_reporting_designation': _lastReportingDesig.text.trim(),
      'last_company':               _lastCompany.text.trim(),
      'reference1':                 _ref1.text.trim(),
      'reference2':                 _ref2.text.trim(),
      'esi_number':                 _esiNumber.text.trim(),
      'pf_number':                  _pfNumber.text.trim(),
      'languages_known':            _languages.text.trim(),
      'hobbies':                    _hobbies.text.trim(),
      'interests':                  _interests.text.trim(),
      'related_to_employee':        _relatedToEmployee.text.trim(),
      'professional_membership':    _professionalMember.text.trim(),
      'specialized_training':       _specializedTraining.text.trim(),
      'other_information':          _otherInfo.text.trim(),
      'blood_group':                _bloodGroupValue ?? '',
      'allergic_to':                _allergicTo.text.trim(),
      'major_illness':              _majorIllness.text.trim(),
      'emergency_contact_name':     _emergencyName.text.trim(),
      'emergency_contact_number':   _emergencyNumber.text.trim(),
      'emergency_contact_address':  _emergencyAddress.text.trim(),
      'aadhar_url':                 emergencyAadharUrl ?? '',
      'declaration_date':           _fmt(_declarationDateVal),
      'declaration_place':          _declarationPlace.text.trim(),
      'attachments':                uploadedFiles,
    };

    try {
      await Supabase.instance.client.from('onboarding_forms').insert(payload);
      if (mounted) setState(() { _saving = false; _submitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error submitting form: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Map<String, dynamic> _rowToMap(Map<String, TextEditingController> row) =>
      row.map((k, v) => MapEntry(k, v.text.trim()));

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _fatherName, _motherName, _designation,
      _fullName, _postalAddress, _permanentAddress,
      _lastReportingName, _lastReportingDesig, _lastCompany, _ref1, _ref2,
      _esiNumber, _pfNumber, _languages, _hobbies, _interests,
      _relatedToEmployee, _professionalMember, _specializedTraining, _otherInfo,
      _allergicTo, _majorIllness,
      _emergencyName, _emergencyNumber, _emergencyAddress,
      _declarationPlace,
    ]) { c.dispose(); }
    for (final row in _familyRows)    { for (final c in row.values) c.dispose(); }
    for (final row in _educationRows) { for (final c in row.values) c.dispose(); }
    for (final row in _experienceRows){ for (final c in row.values) c.dispose(); }
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccess();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSection1(),
                const SizedBox(height: 20),
                _buildSection2(),
                const SizedBox(height: 20),
                _buildFamilySection(),
                const SizedBox(height: 20),
                _buildEducationSection(),
                const SizedBox(height: 20),
                _buildExperienceSection(),
                const SizedBox(height: 20),
                _buildLastPositionSection(),
                const SizedBox(height: 20),
                _buildAdditionalSection(),
                const SizedBox(height: 20),
                _buildEmergencySection(),
                const SizedBox(height: 20),
                _buildAttachmentsSection(),
                const SizedBox(height: 20),
                _buildDeclarationSection(),
                const SizedBox(height: 28),
                _buildSubmitButton(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() => Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16)],
          ),
          child: const Column(children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 64),
            SizedBox(height: 16),
            Text('Form Submitted Successfully!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            SizedBox(height: 8),
            Text('Your joining form has been submitted.\nHR will review your details.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF546E7A), fontSize: 14)),
          ]),
        ),
      ]),
    ),
  );

  Widget _buildHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [_primary, Color(0xFF1565C0)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text('Fomra Housing & Infrastructure Pvt Ltd',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 4),
      Text('(Corporate Office)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13)),
      SizedBox(height: 12),
      Text('EMPLOYEE JOINING FORM',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    ]),
  );

  // ── Section 1: Basic Info ─────────────────────────────────────────────────

  Widget _buildSection1() => _card(
    title: 'Basic Information',
    icon: Icons.person_rounded,
    child: Column(children: [
      _field(_name, 'Name *', required: true),
      _field(_phone, 'Phone Number *', required: true,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
      _field(_fatherName, 'Father Name'),
      _field(_motherName, 'Mother Name'),
      _field(_designation, 'Designation'),
      _dateField(
        label: 'Date of Joining',
        value: _fmt(_dateJoiningDate),
        onTap: () async {
          final d = await _pickDate(initial: _dateJoiningDate);
          if (d != null) setState(() => _dateJoiningDate = d);
        },
      ),
    ]),
  );

  // ── Section 2: Personal Data ──────────────────────────────────────────────

  Widget _buildSection2() => _card(
    title: 'Personal Data Form',
    icon: Icons.assignment_ind_rounded,
    child: Column(children: [
      _field(_fullName, 'Full Name'),
      _dateField(
        label: 'Date of Birth',
        value: _fmt(_dobDate),
        onTap: () async {
          final d = await _pickDate(
              initial: _dobDate,
              first: DateTime(1950),
              last: DateTime.now());
          if (d != null) setState(() => _dobDate = d);
        },
      ),
      _field(_postalAddress,    'Postal Address',    maxLines: 3),
      _field(_permanentAddress, 'Permanent Address', maxLines: 3),
    ]),
  );

  // ── Family section ────────────────────────────────────────────────────────

  Widget _buildFamilySection() => _card(
    title: 'Family Details',
    icon: Icons.family_restroom_rounded,
    child: Column(children: [
      ..._familyRows.asMap().entries.map((e) => _buildFamilyRow(e.key, e.value)),
      const SizedBox(height: 8),
      _addRowButton('Add Family Member', _addFamilyRow),
    ]),
  );

  Widget _buildFamilyRow(int i, Map<String, TextEditingController> row) =>
      Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Member ${i + 1}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: _primary, fontSize: 13)),
        const Spacer(),
        if (i > 0)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.red, size: 20),
            onPressed: () => _removeFamilyRow(i),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(row['name']!, 'Name', compact: true)),
        const SizedBox(width: 8),
        Expanded(
          child: _field(row['age']!, 'Age', compact: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dropdownField(
            value: _familyGenders[i],
            label: 'Gender',
            items: const ['Male', 'Female'],
            onChanged: (v) => setState(() => _familyGenders[i] = v),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: _dropdownField(
            value: _familyRelations[i],
            label: 'Relation',
            items: const ['Mother', 'Father', 'Child', 'Spouse'],
            onChanged: (v) => setState(() => _familyRelations[i] = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _field(row['occupation']!, 'Occupation', compact: true)),
        const SizedBox(width: 8),
        Expanded(
          child: _fileUploadTile(
            label: 'Aadhar Copy',
            file: _familyAadhars[i],
            onPick: () async {
              final f = await _pickSingleFile();
              if (f != null) setState(() => _familyAadhars[i] = f);
            },
            onRemove: () => setState(() => _familyAadhars[i] = null),
          ),
        ),
      ]),
    ]),
  );

  // ── Education section ─────────────────────────────────────────────────────

  Widget _buildEducationSection() => _card(
    title: 'Education Qualification',
    icon: Icons.school_rounded,
    subtitle: 'Start with School, College, Any Certification Course',
    child: Column(children: [
      ..._educationRows.asMap().entries.map((e) => _buildEducationRow(e.key, e.value)),
      const SizedBox(height: 8),
      _addRowButton('Add Education', _addEducationRow),
    ]),
  );

  Widget _buildEducationRow(int i, Map<String, TextEditingController> row) =>
      Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Entry ${i + 1}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: _primary, fontSize: 13)),
        const Spacer(),
        if (i > 0)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.red, size: 20),
            onPressed: () => _removeEducationRow(i),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(row['qualification']!, 'Qualification', compact: true)),
        const SizedBox(width: 8),
        Expanded(child: _field(row['university']!, 'University / Institute', compact: true)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: _field(row['year']!, 'Year of Passing', compact: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _field(row['marks']!, '% Marks', compact: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
        ),
        const SizedBox(width: 8),
        Expanded(child: _field(row['subject']!, 'Major Subject', compact: true)),
      ]),
    ]),
  );

  // ── Experience section ────────────────────────────────────────────────────

  Widget _buildExperienceSection() => _card(
    title: 'Experience',
    icon: Icons.work_history_rounded,
    subtitle: 'Chronological order excluding last position',
    child: Column(children: [
      ..._experienceRows.asMap().entries.map((e) => _buildExperienceRow(e.key, e.value)),
      const SizedBox(height: 8),
      _addRowButton('Add Experience', _addExperienceRow),
    ]),
  );

  Widget _buildExperienceRow(int i, Map<String, TextEditingController> row) =>
      Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Experience ${i + 1}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: _primary, fontSize: 13)),
        const Spacer(),
        if (i > 0)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.red, size: 20),
            onPressed: () => _removeExperienceRow(i),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ]),
      const SizedBox(height: 8),
      _field(row['organisation']!, 'Organisation', compact: true),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(row['from']!, 'Period From', compact: true, hint: 'MM/YYYY')),
        const SizedBox(width: 8),
        Expanded(child: _field(row['to']!,   'Period To',   compact: true, hint: 'MM/YYYY')),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(row['desig_joining']!,   'Designation at Joining',   compact: true)),
        const SizedBox(width: 8),
        Expanded(child: _field(row['desig_relieving']!, 'Designation at Relieving', compact: true)),
      ]),
      const SizedBox(height: 8),
      _field(row['job_resp']!, 'Job Responsibility', compact: true, maxLines: 2),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(row['superior']!, 'Designation of Immediate Superior', compact: true)),
        const SizedBox(width: 8),
        Expanded(
          child: _field(row['salary']!, 'Gross Salary Drawn', compact: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
        ),
      ]),
      const SizedBox(height: 8),
      _field(row['reason']!, 'Reason for Leaving', compact: true),
    ]),
  );

  // ── Last Position section ─────────────────────────────────────────────────

  Widget _buildLastPositionSection() => _card(
    title: 'Last Position Held',
    icon: Icons.business_center_rounded,
    child: Column(children: [
      _field(_lastReportingName,  'Last Reporting Person Name'),
      _field(_lastReportingDesig, 'Last Reporting Person Designation'),
      _field(_lastCompany,        'Last Company Name & Address', maxLines: 2),
      const SizedBox(height: 8),
      const _SectionLabel(label: 'References (from Last Company)'),
      const SizedBox(height: 8),
      _field(_ref1, 'Reference 1 — Name & Contact Number'),
      _field(_ref2, 'Reference 2 — Name & Contact Number'),
    ]),
  );

  // ── Additional Info section ───────────────────────────────────────────────

  Widget _buildAdditionalSection() => _card(
    title: 'Additional Information',
    icon: Icons.info_outline_rounded,
    child: Column(children: [
      Row(children: [
        Expanded(child: _field(_esiNumber, 'ESI Number')),
        const SizedBox(width: 12),
        Expanded(child: _field(_pfNumber,  'PF Number')),
      ]),
      _field(_languages,          'Languages Known'),
      _field(_hobbies,            'Your Hobbies'),
      _field(_interests,          'Interests (Sports / Music / Dance / Singing etc.)'),
      _field(_relatedToEmployee,  'Related to any employee? If yes, name'),
      _field(_professionalMember, 'Membership of any Professional Institution / Association'),
      _field(_specializedTraining,'Any Specialized Training Program attended'),
      _field(_otherInfo,          'Any Other Information / Suggestion', maxLines: 3),
    ]),
  );

  // ── Emergency section ─────────────────────────────────────────────────────

  Widget _buildEmergencySection() => _card(
    title: 'EMERGENCY DETAILS OF EMPLOYEE',
    icon: Icons.emergency_rounded,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: _dropdownField(
            value: _bloodGroupValue,
            label: 'Blood Group',
            items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
            onChanged: (v) => setState(() => _bloodGroupValue = v),
            bottomPad: 12,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _field(_allergicTo, 'Allergic To')),
      ]),
      _field(_majorIllness,    'Any Major Illness', maxLines: 2),
      _field(_emergencyName,   'Emergency Contact Person Name'),
      _field(_emergencyNumber, 'Emergency Contact Person Number',
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
      _field(_emergencyAddress,'Emergency Contact Person Address', maxLines: 2),
      // Aadhar Copy upload
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Aadhar Copy',
              style: TextStyle(fontSize: 12, color: Color(0xFF546E7A))),
          const SizedBox(height: 6),
          _fileUploadTile(
            label: 'Upload Aadhar Copy (PDF / image · max 1 MB)',
            file: _emergencyAadharFile,
            onPick: () async {
              final f = await _pickSingleFile();
              if (f != null) setState(() => _emergencyAadharFile = f);
            },
            onRemove: () => setState(() => _emergencyAadharFile = null),
            fullWidth: true,
          ),
        ]),
      ),
    ]),
  );

  // ── Attachments section ───────────────────────────────────────────────────

  Widget _buildAttachmentsSection() => _card(
    title: 'Attachments',
    icon: Icons.attach_file_rounded,
    subtitle: 'PDF / image · Images > 1 MB are auto-compressed · To be given as hard copy also',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...List.generate(_docLabels.length, (i) {
        final files = _attachments[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: files.isNotEmpty
                  ? const Color(0xFF0D47A1)
                  : const Color(0xFFE0E0E0),
              width: files.isNotEmpty ? 1.5 : 1,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Doc label row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_docLabels[i],
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF37474F),
                          fontWeight: FontWeight.w500)),
                ),
              ]),
            ),

            // Uploaded files list
            if (files.isNotEmpty) ...[
              const Divider(height: 1, color: Color(0xFFE8EAF6)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  children: files.asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(children: [
                      const Icon(Icons.insert_drive_file_rounded,
                          size: 16, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.value.name,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1B5E20),
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(
                            () => _attachments[i].removeAt(e.key)),
                        child: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 13, color: Colors.red),
                        ),
                      ),
                    ]),
                  )).toList(),
                ),
              ),
            ],

            // Upload button
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_rounded, size: 15),
                label: Text(
                    files.isEmpty ? 'Add File' : 'Add More',
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D47A1),
                  side: const BorderSide(color: Color(0xFF0D47A1)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                ),
                onPressed: () => _pickFiles(i),
              ),
            ),
          ]),
        );
      }),
    ]),
  );

  // ── Declaration section ───────────────────────────────────────────────────

  Widget _buildDeclarationSection() => _card(
    title: 'Declaration',
    icon: Icons.gavel_rounded,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDE7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDD835)),
        ),
        child: const Text(
          'I declare that the information given herein above is true & correct to the best of my knowledge & belief & nothing material has been concealed.\n\nI understand that if the above information is found false or incorrect, at any time during the course of my employment, my services will be terminated forthwith without any notice or compensation.',
          style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.6),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: _dateField(
            label: 'Date',
            value: _fmt(_declarationDateVal),
            onTap: () async {
              final d = await _pickDate(initial: _declarationDateVal);
              if (d != null) setState(() => _declarationDateVal = d);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _field(_declarationPlace, 'Place')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Checkbox(
          value: _declarationAgreed,
          onChanged: (v) => setState(() => _declarationAgreed = v ?? false),
          activeColor: _primary,
        ),
        const Expanded(
          child: Text('I agree to the above declaration',
              style: TextStyle(fontSize: 13, color: Color(0xFF37474F))),
        ),
      ]),
    ]),
  );

  Widget _buildSubmitButton() => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      icon: _saving
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.send_rounded, size: 18),
      label: Text(_saving ? 'Submitting...' : 'Submit Joining Form',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _saving ? null : _submit,
    ),
  );

  // ── Shared widget helpers ─────────────────────────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) =>
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE8EAF6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: _primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E))),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF78909C))),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            child,
          ]),
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
    bool compact = false,
    List<TextInputFormatter>? inputFormatters,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: compact ? 0 : 12),
        child: TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 10 : 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Colors.red)),
            labelStyle:
                const TextStyle(color: Color(0xFF546E7A), fontSize: 13),
          ),
        ),
      );

  // Calendar date picker field (read-only, opens date picker on tap)
  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool compact = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: compact ? 0 : 12),
        child: GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: TextFormField(
              readOnly: true,
              controller: TextEditingController(text: value),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: label,
                suffixIcon: const Icon(Icons.calendar_today_rounded,
                    size: 17, color: _primary),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: compact ? 10 : 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide:
                        const BorderSide(color: _primary, width: 1.5)),
                labelStyle:
                    const TextStyle(color: Color(0xFF546E7A), fontSize: 13),
              ),
            ),
          ),
        ),
      );

  // Dropdown field
  Widget _dropdownField({
    required String? value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double bottomPad = 0,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _primary, width: 1.5)),
            labelStyle:
                const TextStyle(color: Color(0xFF546E7A), fontSize: 13),
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)),
          items: items
              .map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      );

  // Compact file upload tile (shows filename when picked, upload button otherwise)
  Widget _fileUploadTile({
    required String label,
    required _AttachFile? file,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    bool fullWidth = false,
  }) {
    if (file != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF4CAF50)),
        ),
        child: Row(children: [
          const Icon(Icons.insert_drive_file_rounded,
              size: 15, color: Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(file.name,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 16, color: Colors.red),
          ),
        ]),
      );
    }
    return OutlinedButton.icon(
      icon: const Icon(Icons.upload_file_rounded, size: 14),
      label: Text(label,
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _primary),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize:
            fullWidth ? const Size(double.infinity, 42) : const Size(0, 38),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onPick,
    );
  }

  Widget _addRowButton(String label, VoidCallback onTap) =>
      OutlinedButton.icon(
        icon: const Icon(Icons.add_rounded, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _primary),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF546E7A)));
}
