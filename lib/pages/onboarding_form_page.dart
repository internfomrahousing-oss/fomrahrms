// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AttachFile {
  final String name;
  final Uint8List bytes;
  final String mime;
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
  final _designation = TextEditingController();
  final _dateJoining = TextEditingController();

  // ── Section 2: Personal Data
  final _fullName        = TextEditingController();
  final _dob             = TextEditingController();
  final _postalAddress   = TextEditingController();
  final _permanentAddress= TextEditingController();

  // ── Section 3: Family Details (dynamic rows)
  List<Map<String, TextEditingController>> _familyRows = [];

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
  final _bloodGroup        = TextEditingController();
  final _allergicTo        = TextEditingController();
  final _majorIllness      = TextEditingController();
  final _emergencyName     = TextEditingController();
  final _emergencyNumber   = TextEditingController();
  final _emergencyAddress  = TextEditingController();
  final _aadharNumber      = TextEditingController();

  // ── Declaration
  final _declarationDate  = TextEditingController();
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

  void _addFamilyRow() {
    _familyRows.add({
      'name':       TextEditingController(),
      'age':        TextEditingController(),
      'gender':     TextEditingController(),
      'relation':   TextEditingController(),
      'occupation': TextEditingController(),
      'aadhar':     TextEditingController(),
    });
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

  Map<String, dynamic> _rowToMap(Map<String, TextEditingController> row) =>
      row.map((k, v) => MapEntry(k, v.text.trim()));

  void _pickFiles(int docIndex) {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*,.pdf,.doc,.docx,.xls,.xlsx'
      ..multiple = true;
    input.onChange.listen((_) async {
      for (final file in input.files ?? []) {
        if (file.size > 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('"${file.name}" exceeds 1 MB limit and was skipped.'),
              backgroundColor: Colors.red,
            ));
          }
          continue;
        }
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        final bytes = (reader.result as ByteBuffer).asUint8List();
        if (mounted) {
          setState(() => _attachments[docIndex].add(
            _AttachFile(name: file.name, bytes: bytes, mime: file.type),
          ));
        }
      }
    });
    input.click();
  }

  Future<List<Map<String, dynamic>>> _uploadAttachments() async {
    final result = <Map<String, dynamic>>[];
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    for (int i = 0; i < _attachments.length; i++) {
      for (final file in _attachments[i]) {
        try {
          final path = '$ts/doc${i + 1}_${file.name}';
          await Supabase.instance.client.storage
              .from('onboarding-attachments')
              .uploadBinary(path, file.bytes,
                  fileOptions: FileOptions(
                      contentType: file.mime.isEmpty ? 'application/octet-stream' : file.mime));
          final url = Supabase.instance.client.storage
              .from('onboarding-attachments')
              .getPublicUrl(path);
          result.add({'doc_type': _docLabels[i], 'name': file.name, 'url': url});
        } catch (_) {
          result.add({'doc_type': _docLabels[i], 'name': file.name, 'url': ''});
        }
      }
    }
    return result;
  }

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

    final uploadedFiles = await _uploadAttachments();

    final payload = {
      'name':                      _name.text.trim(),
      'phone_number':              _phone.text.trim(),
      'father_name':               _fatherName.text.trim(),
      'designation':               _designation.text.trim(),
      'date_of_joining':           _dateJoining.text.trim(),
      'full_name':                 _fullName.text.trim(),
      'date_of_birth':             _dob.text.trim(),
      'postal_address':            _postalAddress.text.trim(),
      'permanent_address':         _permanentAddress.text.trim(),
      'family_details':            _familyRows.map(_rowToMap).toList(),
      'education':                 _educationRows.map(_rowToMap).toList(),
      'experience':                _experienceRows.map(_rowToMap).toList(),
      'last_reporting_name':       _lastReportingName.text.trim(),
      'last_reporting_designation':_lastReportingDesig.text.trim(),
      'last_company':              _lastCompany.text.trim(),
      'reference1':                _ref1.text.trim(),
      'reference2':                _ref2.text.trim(),
      'esi_number':                _esiNumber.text.trim(),
      'pf_number':                 _pfNumber.text.trim(),
      'languages_known':           _languages.text.trim(),
      'hobbies':                   _hobbies.text.trim(),
      'interests':                 _interests.text.trim(),
      'related_to_employee':       _relatedToEmployee.text.trim(),
      'professional_membership':   _professionalMember.text.trim(),
      'specialized_training':      _specializedTraining.text.trim(),
      'other_information':         _otherInfo.text.trim(),
      'blood_group':               _bloodGroup.text.trim(),
      'allergic_to':               _allergicTo.text.trim(),
      'major_illness':             _majorIllness.text.trim(),
      'emergency_contact_name':    _emergencyName.text.trim(),
      'emergency_contact_number':  _emergencyNumber.text.trim(),
      'emergency_contact_address': _emergencyAddress.text.trim(),
      'aadhar_number':             _aadharNumber.text.trim(),
      'declaration_date':          _declarationDate.text.trim(),
      'declaration_place':         _declarationPlace.text.trim(),
      'attachments':               uploadedFiles,
    };

    try {
      await Supabase.instance.client.from('onboarding_forms').insert(payload);
      setState(() { _saving = false; _submitted = true; });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error submitting form: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _fatherName, _designation, _dateJoining,
      _fullName, _dob, _postalAddress, _permanentAddress,
      _lastReportingName, _lastReportingDesig, _lastCompany, _ref1, _ref2,
      _esiNumber, _pfNumber, _languages, _hobbies, _interests,
      _relatedToEmployee, _professionalMember, _specializedTraining, _otherInfo,
      _bloodGroup, _allergicTo, _majorIllness,
      _emergencyName, _emergencyNumber, _emergencyAddress, _aadharNumber,
      _declarationDate, _declarationPlace,
    ]) { c.dispose(); }
    for (final row in _familyRows)    { for (final c in row.values) c.dispose(); }
    for (final row in _educationRows) { for (final c in row.values) c.dispose(); }
    for (final row in _experienceRows){ for (final c in row.values) c.dispose(); }
    super.dispose();
  }

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
          child: Column(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 64),
            const SizedBox(height: 16),
            const Text('Form Submitted Successfully!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            const SizedBox(height: 8),
            const Text('Your joining form has been submitted.\nHR will review your details.',
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

  Widget _buildSection1() => _card(
    title: 'Basic Information',
    icon: Icons.person_rounded,
    child: Column(children: [
      _field(_name,        'Name *',             required: true),
      _field(_phone,       'Phone Number *',      required: true, keyboardType: TextInputType.phone),
      _field(_fatherName,  'Father Name'),
      _field(_designation, 'Designation'),
      _field(_dateJoining, 'Date of Joining',    hint: 'DD/MM/YYYY'),
    ]),
  );

  Widget _buildSection2() => _card(
    title: 'Personal Data Form',
    icon: Icons.assignment_ind_rounded,
    child: Column(children: [
      _field(_fullName,         'Full Name'),
      _field(_dob,              'Date of Birth', hint: 'DD/MM/YYYY'),
      _field(_postalAddress,    'Postal Address', maxLines: 3),
      _field(_permanentAddress, 'Permanent Address', maxLines: 3),
    ]),
  );

  Widget _buildFamilySection() => _card(
    title: 'Family Details',
    icon: Icons.family_restroom_rounded,
    child: Column(children: [
      ..._familyRows.asMap().entries.map((e) => _buildFamilyRow(e.key, e.value)),
      const SizedBox(height: 8),
      _addRowButton('Add Family Member', _addFamilyRow),
    ]),
  );

  Widget _buildFamilyRow(int i, Map<String, TextEditingController> row) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Member ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: _primary, fontSize: 13)),
        const Spacer(),
        if (i > 0) IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
          onPressed: () => _removeFamilyRow(i),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(row['name']!,       'Name', compact: true)),
        const SizedBox(width: 8),
        Expanded(child: _field(row['age']!,        'Age',  compact: true, keyboardType: TextInputType.number)),
        const SizedBox(width: 8),
        Expanded(child: _field(row['gender']!,     'Gender', compact: true)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(row['relation']!,   'Relation',   compact: true)),
        const SizedBox(width: 8),
        Expanded(child: _field(row['occupation']!, 'Occupation', compact: true)),
        const SizedBox(width: 8),
        Expanded(child: _field(row['aadhar']!,     'Aadhar No.', compact: true)),
      ]),
    ]),
  );

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

  Widget _buildEducationRow(int i, Map<String, TextEditingController> row) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Entry ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: _primary, fontSize: 13)),
        const Spacer(),
        if (i > 0) IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
          onPressed: () => _removeEducationRow(i),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(row['qualification']!, 'Qualification', compact: true)),
        const SizedBox(width: 8),
        Expanded(child: _field(row['university']!,    'University / Institute', compact: true)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(row['year']!,    'Year of Passing', compact: true)),
        const SizedBox(width: 8),
        Expanded(child: _field(row['marks']!,   '% Marks', compact: true)),
        const SizedBox(width: 8),
        Expanded(child: _field(row['subject']!, 'Major Subject', compact: true)),
      ]),
    ]),
  );

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

  Widget _buildExperienceRow(int i, Map<String, TextEditingController> row) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Experience ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: _primary, fontSize: 13)),
        const Spacer(),
        if (i > 0) IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
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
        Expanded(child: _field(row['salary']!,   'Gross Salary Drawn', compact: true)),
      ]),
      const SizedBox(height: 8),
      _field(row['reason']!, 'Reason for Leaving', compact: true),
    ]),
  );

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

  Widget _buildAdditionalSection() => _card(
    title: 'Additional Information',
    icon: Icons.info_outline_rounded,
    child: Column(children: [
      Row(children: [
        Expanded(child: _field(_esiNumber, 'ESI Number')),
        const SizedBox(width: 12),
        Expanded(child: _field(_pfNumber,  'PF Number')),
      ]),
      _field(_languages,         'Languages Known'),
      _field(_hobbies,           'Your Hobbies'),
      _field(_interests,         'Interests (Sports / Music / Dance / Singing etc.)'),
      _field(_relatedToEmployee, 'Related to any employee? If yes, name'),
      _field(_professionalMember,'Membership of any Professional Institution / Association'),
      _field(_specializedTraining,'Any Specialized Training Program attended'),
      _field(_otherInfo,         'Any Other Information / Suggestion', maxLines: 3),
    ]),
  );

  Widget _buildEmergencySection() => _card(
    title: 'Emergency Details',
    icon: Icons.emergency_rounded,
    child: Column(children: [
      Row(children: [
        Expanded(child: _field(_bloodGroup, 'Blood Group')),
        const SizedBox(width: 12),
        Expanded(child: _field(_allergicTo, 'Allergic To')),
      ]),
      _field(_majorIllness,      'Any Major Illness', maxLines: 2),
      _field(_emergencyName,     'Emergency Contact Person Name'),
      _field(_emergencyNumber,   'Emergency Contact Person Number', keyboardType: TextInputType.phone),
      _field(_emergencyAddress,  'Emergency Contact Person Address', maxLines: 2),
      _field(_aadharNumber,      'Aadhar Number'),
    ]),
  );

  Widget _buildAttachmentsSection() => _card(
    title: 'Attachments',
    icon: Icons.attach_file_rounded,
    subtitle: 'To be given as hard copy also · Max 1 MB per file',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...List.generate(_docLabels.length, (i) {
        final files = _attachments[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Row(children: [
                  Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0D47A1), fontSize: 13)),
                  Expanded(child: Text(_docLabels[i],
                      style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)))),
                ]),
              ),
            ]),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...files.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.insert_drive_file_rounded, size: 14, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(e.value.name,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E)),
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _attachments[i].removeAt(e.key)),
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                  ),
                ]),
              )),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Add', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
                side: const BorderSide(color: Color(0xFF0D47A1)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _pickFiles(i),
            ),
          ]),
        );
      }),
    ]),
  );

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
        Expanded(child: _field(_declarationDate,  'Date',  hint: 'DD/MM/YYYY')),
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
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card({required String title, required IconData icon, required Widget child, String? subtitle}) =>
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE8EAF6))),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
                  if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
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

  Widget _field(TextEditingController ctrl, String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
    bool compact = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: compact ? 0 : 12),
        child: TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 10 : 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _primary, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Colors.red)),
            labelStyle: const TextStyle(color: Color(0xFF546E7A), fontSize: 13),
          ),
        ),
      );

  Widget _addRowButton(String label, VoidCallback onTap) => OutlinedButton.icon(
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
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF546E7A)));
}
