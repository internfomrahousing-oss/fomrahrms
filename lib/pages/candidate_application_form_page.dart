import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

const _blue  = Color(0xFF0D47A1);

class CandidateApplicationFormPage extends StatefulWidget {
  const CandidateApplicationFormPage({super.key});
  @override
  State<CandidateApplicationFormPage> createState() =>
      _CandidateApplicationFormPageState();
}

class _CandidateApplicationFormPageState
    extends State<CandidateApplicationFormPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Personal
  final _name         = TextEditingController();
  final _mobile       = TextEditingController();
  final _place        = TextEditingController();
  final _nationality  = TextEditingController();
  final _email        = TextEditingController();
  final _age          = TextEditingController();

  // ── Experience
  final _totalExp     = TextEditingController();
  final _relevantExp  = TextEditingController();
  final _reasonChange = TextEditingController();
  final _currentCtc   = TextEditingController();
  final _expectedCtc  = TextEditingController();

  // ── Source / other
  final _jobPortal    = TextEditingController();
  final _referredBy   = TextEditingController();
  final _relatedEmp   = TextEditingController();
  final _appliedBefore= TextEditingController();

  // ── Education (fixed 5 rows)
  final _education = [
    _EduRow('X Standard'),
    _EduRow('XII Standard / Diploma'),
    _EduRow('UG Degree'),
    _EduRow('PG Degree'),
    _EduRow('Others'),
  ];
  String? _standingArrears; // 'Yes' | 'No'

  // ── Employment History (4 rows)
  final _empHistory = List.generate(4, (_) => _EmpRow());

  // ── Referrals (2 rows)
  final _referrals = List.generate(2, (_) => _RefRow());

  // ── Address / Declaration
  final _address         = TextEditingController();
  final _declarationName = TextEditingController();
  final _signatureDate   = TextEditingController();

  // ── Dates / choices
  DateTime? _interviewDate;
  DateTime? _dob;
  String? _gender;
  String? _maritalStatus;
  String? _postApplied;
  String? _noticePeriod;
  String? _source;

  // ── Resume
  String? _resumeFileName;
  String? _resumeUrl;
  bool _uploadingResume = false;

  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [
      _name, _mobile, _place, _nationality, _email, _age,
      _totalExp, _relevantExp, _reasonChange, _currentCtc, _expectedCtc,
      _jobPortal, _referredBy, _relatedEmp, _appliedBefore,
      _address, _declarationName, _signatureDate,
    ]) { c.dispose(); }
    for (final r in _education)  r.dispose();
    for (final r in _empHistory) r.dispose();
    for (final r in _referrals)  r.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  Future<void> _pickDate(bool isInterview) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _blue)),
        child: child!,
      ),
    );
    if (picked != null) setState(() {
      if (isInterview) _interviewDate = picked;
      else _dob = picked;
    });
  }

  Future<void> _pickResume() async {
    setState(() => _uploadingResume = true);
    try {
      final nameCompleter   = Completer<String?>();
      final bytesCompleter  = Completer<Uint8List?>();
      final mimeCompleter   = Completer<String?>();

      final input = html.FileUploadInputElement()
        ..accept = '.pdf,.doc,.docx'
        ..click();

      input.onChange.listen((_) {
        final file = input.files?.first;
        if (file == null) {
          nameCompleter.complete(null);
          bytesCompleter.complete(null);
          mimeCompleter.complete(null);
          return;
        }
        nameCompleter.complete(file.name);
        mimeCompleter.complete(file.type);
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoad.listen((_) {
          final result = reader.result;
          if (result is ByteBuffer) {
            bytesCompleter.complete(result.asUint8List());
          } else {
            bytesCompleter.complete(null);
          }
        });
        reader.onError.listen((_) => bytesCompleter.complete(null));
      });

      final name  = await nameCompleter.future;
      final bytes = await bytesCompleter.future;
      final mime  = await mimeCompleter.future;

      if (name != null && bytes != null) {
        final url = await SupabaseService.uploadResume(bytes, name, mime ?? '');
        setState(() {
          _resumeFileName = name;
          _resumeUrl      = url;
        });
      }
    } catch (_) {
    } finally {
      setState(() => _uploadingResume = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_interviewDate == null || _dob == null ||
        _gender == null || _maritalStatus == null ||
        _postApplied == null || _noticePeriod == null || _source == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all required fields.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    setState(() => _submitting = true);

    await SupabaseService.saveCandidateApplication({
      'name':                _name.text.trim(),
      'mobile':              _mobile.text.trim(),
      'place':               _place.text.trim(),
      'dob':                 _fmt(_dob),
      'nationality':         _nationality.text.trim(),
      'email':               _email.text.trim(),
      'gender':              _gender ?? '',
      'marital_status':      _maritalStatus ?? '',
      'age':                 _age.text.trim(),
      'interview_date':      _fmt(_interviewDate),
      'post_applied':        _postApplied ?? '',
      'total_experience':    _totalExp.text.trim(),
      'relevant_experience': _relevantExp.text.trim(),
      'reason_for_change':   _reasonChange.text.trim(),
      'current_ctc':         _currentCtc.text.trim(),
      'expected_ctc':        _expectedCtc.text.trim(),
      'notice_period':       _noticePeriod ?? '',
      'source':              _source ?? '',
      'job_portal':          _jobPortal.text.trim(),
      'referred_by':         _referredBy.text.trim(),
      'related_employee':    _relatedEmp.text.trim(),
      'applied_before':      _appliedBefore.text.trim(),
      'standing_arrears':    _standingArrears ?? '',
      'education_history':   _education.map((r) => r.toMap()).toList(),
      'employment_history':  _empHistory.map((r) => r.toMap()).toList(),
      'referrals':           _referrals.map((r) => r.toMap()).toList(),
      'address':             _address.text.trim(),
      'declaration_name':    _declarationName.text.trim(),
      'signature_date':      _signatureDate.text.trim(),
      'resume_url':          _resumeUrl ?? '',
    });

    if (!mounted) return;
    setState(() => _submitting = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
          SizedBox(width: 8),
          Text('Application Submitted',
              style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: const Text(
          'Your application has been submitted successfully. We will get back to you soon.',
          style: TextStyle(color: Color(0xFF37474F)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _resetForm(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue, foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit Another'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (final c in [
      _name, _mobile, _place, _nationality, _email, _age,
      _totalExp, _relevantExp, _reasonChange, _currentCtc, _expectedCtc,
      _jobPortal, _referredBy, _relatedEmp, _appliedBefore,
      _address, _declarationName, _signatureDate,
    ]) { c.clear(); }
    for (final r in _education)  r.clear();
    for (final r in _empHistory) r.clear();
    for (final r in _referrals)  r.clear();
    setState(() {
      _interviewDate = null; _dob = null;
      _gender = null; _maritalStatus = null;
      _postApplied = null; _noticePeriod = null; _source = null;
      _standingArrears = null;
      _resumeFileName = null; _resumeUrl = null;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: const Color(0xFFF5F7FA),
      child: Column(children: [
        // Header
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment_ind_rounded, color: _blue, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Candidate Application Form',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _blue)),
                Text('Fill in all details carefully',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
              ]),
            ),
            TextButton.icon(
              onPressed: _resetForm,
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF78909C)),
            ),
          ]),
        ),

        // Form
        Expanded(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Personal Information ─────────────────────────
                      _SectionHeader(icon: Icons.person_rounded, title: 'Personal Information'),
                      const SizedBox(height: 16),
                      _row(narrow, [
                        _Field(label: 'Name', controller: _name, required: true),
                        _Field(label: 'Mobile Number', controller: _mobile,
                            keyboard: TextInputType.phone, required: true),
                      ]),
                      const SizedBox(height: 14),
                      _row(narrow, [
                        _Field(label: 'Place', controller: _place, required: true),
                        _Field(label: 'Nationality', controller: _nationality, required: true),
                      ]),
                      const SizedBox(height: 14),
                      _row(narrow, [
                        _Field(label: 'Email ID', controller: _email,
                            keyboard: TextInputType.emailAddress, required: true),
                        _Field(label: 'Age', controller: _age,
                            keyboard: TextInputType.number, required: true),
                      ]),
                      const SizedBox(height: 14),
                      _DateField(label: 'Date of Birth', value: _fmt(_dob),
                          required: true, onTap: () => _pickDate(false)),
                      const SizedBox(height: 14),
                      _RadioGroup(label: 'Gender', required: true,
                          options: const ['Male', 'Female'],
                          value: _gender, onChanged: (v) => setState(() => _gender = v)),
                      const SizedBox(height: 14),
                      _RadioGroup(label: 'Marital Status', required: true,
                          options: const ['Single', 'Married', 'Separated'],
                          value: _maritalStatus, onChanged: (v) => setState(() => _maritalStatus = v)),

                      const SizedBox(height: 24),
                      // ── Interview Details ────────────────────────────
                      _SectionHeader(icon: Icons.event_note_rounded, title: 'Interview Details'),
                      const SizedBox(height: 16),
                      _DateField(label: 'Interview Attended Date', value: _fmt(_interviewDate),
                          required: true, onTap: () => _pickDate(true)),
                      const SizedBox(height: 14),
                      _RadioGroup(label: 'Post Applied', required: true, wrap: true,
                          options: const ['HR','ACCOUNTS','SALES','MARKETING',
                              'GMI','PROJECTS','LAND ACQUISITION','DIGITAL MARKETING'],
                          value: _postApplied, onChanged: (v) => setState(() => _postApplied = v)),

                      const SizedBox(height: 24),
                      // ── Experience & CTC ─────────────────────────────
                      _SectionHeader(icon: Icons.work_history_rounded, title: 'Experience & CTC'),
                      const SizedBox(height: 16),
                      _row(narrow, [
                        _Field(label: 'Total Experience', controller: _totalExp,
                            hint: 'e.g. 3 years 2 months', required: true),
                        _Field(label: 'Relevant Experience', controller: _relevantExp,
                            hint: 'e.g. 2 years', required: true),
                      ]),
                      const SizedBox(height: 14),
                      _Field(label: 'Reason for Change in Job', controller: _reasonChange,
                          maxLines: 2, required: true),
                      const SizedBox(height: 14),
                      _row(narrow, [
                        _Field(label: 'Current CTC per Month (INR)', controller: _currentCtc,
                            keyboard: TextInputType.number, required: true),
                        _Field(label: 'Expected CTC per Month (INR)', controller: _expectedCtc,
                            keyboard: TextInputType.number, required: true),
                      ]),
                      const SizedBox(height: 14),
                      _RadioGroup(label: 'Notice Period (to join if selected)', required: true,
                          options: const ['Immediate','15 Days','30 Days','60 Days or more'],
                          value: _noticePeriod, onChanged: (v) => setState(() => _noticePeriod = v)),

                      const SizedBox(height: 24),
                      // ── Educational Qualifications ───────────────────
                      _SectionHeader(icon: Icons.school_rounded,
                          title: 'Educational Qualifications'),
                      const SizedBox(height: 16),
                      _EducationTable(
                        rows: _education,
                        standingArrears: _standingArrears,
                        onArrearsChanged: (v) => setState(() => _standingArrears = v),
                      ),

                      const SizedBox(height: 24),
                      // ── Employment History ───────────────────────────
                      _SectionHeader(icon: Icons.business_center_rounded,
                          title: 'Employment History (Current & Previous, if any)'),
                      const SizedBox(height: 16),
                      _EmpHistoryTable(rows: _empHistory),

                      const SizedBox(height: 24),
                      // ── Source ───────────────────────────────────────
                      _SectionHeader(icon: Icons.campaign_rounded, title: 'Source'),
                      const SizedBox(height: 16),
                      _RadioGroup(label: 'Source', required: true,
                          options: const ['Walk In','Referred by Employee',
                              'Consultancy (Specify)','Job Portal / Other (Specify)','Other'],
                          value: _source, onChanged: (v) => setState(() => _source = v)),
                      const SizedBox(height: 14),
                      _Field(label: 'Mention Job Portal (if applicable)',
                          controller: _jobPortal, hint: 'e.g. Naukri, LinkedIn…'),
                      const SizedBox(height: 14),
                      _Field(label: 'If Referred by Employee — Name & Employee ID',
                          controller: _referredBy, hint: 'Name and EMP ID', maxLines: 2),
                      const SizedBox(height: 14),
                      _Field(label: 'If Related to Any Employee — Name, EMP ID & Relationship',
                          controller: _relatedEmp, hint: 'Name, EMP ID, Relationship', maxLines: 2),

                      const SizedBox(height: 24),
                      // ── Referrals ────────────────────────────────────
                      _SectionHeader(icon: Icons.group_add_rounded,
                          title: 'Refer Friends / Relatives Looking for a Job'),
                      const SizedBox(height: 16),
                      _ReferralTable(rows: _referrals),

                      const SizedBox(height: 24),
                      // ── Previous Application ─────────────────────────
                      _SectionHeader(icon: Icons.history_rounded, title: 'Previous Application'),
                      const SizedBox(height: 16),
                      _Field(label: 'Have you applied for a job with us earlier?',
                          controller: _appliedBefore,
                          hint: 'If yes, mention Job and Date', maxLines: 2),

                      const SizedBox(height: 24),
                      // ── Address ──────────────────────────────────────
                      _SectionHeader(icon: Icons.location_on_rounded,
                          title: 'Address for Communication'),
                      const SizedBox(height: 16),
                      _Field(label: 'Full Address', controller: _address, maxLines: 3),

                      const SizedBox(height: 24),
                      // ── Resume Upload ────────────────────────────────
                      _SectionHeader(icon: Icons.attach_file_rounded, title: 'Resume'),
                      const SizedBox(height: 16),
                      _ResumeUploader(
                        fileName: _resumeFileName,
                        uploading: _uploadingResume,
                        onPick: _pickResume,
                      ),

                      const SizedBox(height: 24),
                      // ── Declaration ──────────────────────────────────
                      _SectionHeader(icon: Icons.verified_rounded, title: 'Declaration'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(fontSize: 13, color: Color(0xFF37474F), height: 1.5),
                                children: [
                                  TextSpan(text: 'I, '),
                                  TextSpan(text: '___________________________',
                                      style: TextStyle(color: _blue)),
                                  TextSpan(
                                      text: ', hereby confirm that the details provided by me in the '
                                          'Applicant Information Sheet is true, complete and accurate.'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _row(narrow, [
                              _Field(label: 'Full Name (Declaration)', controller: _declarationName),
                              _Field(label: 'Signature with Date', controller: _signatureDate,
                                  hint: 'e.g. 23/06/2025'),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      // ── Submit ───────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded),
                          label: Text(_submitting ? 'Submitting…' : 'Submit Application',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _row(bool narrow, List<Widget> children) {
    if (narrow) {
      return Column(
        children: children
            .expand((w) => [w, const SizedBox(height: 14)])
            .toList()
          ..removeLast(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 14)])
          .toList()
        ..removeLast(),
    );
  }
}

// ── Education data holder ───────────────────────────────────────────────────────
class _EduRow {
  final String academics;
  final degree    = TextEditingController();
  final college   = TextEditingController();
  final passing   = TextEditingController();
  final marks     = TextEditingController();
  String? certificate; // 'Yes' | 'No'

  _EduRow(this.academics);

  Map<String, String> toMap() => {
    'academics':   academics,
    'degree':      degree.text.trim(),
    'college':     college.text.trim(),
    'passing':     passing.text.trim(),
    'marks':       marks.text.trim(),
    'certificate': certificate ?? '',
  };

  void clear() {
    degree.clear(); college.clear();
    passing.clear(); marks.clear();
    certificate = null;
  }

  void dispose() {
    degree.dispose(); college.dispose();
    passing.dispose(); marks.dispose();
  }
}

// ── Education Table ─────────────────────────────────────────────────────────────
class _EducationTable extends StatefulWidget {
  final List<_EduRow> rows;
  final String? standingArrears;
  final ValueChanged<String?> onArrearsChanged;
  const _EducationTable({
    required this.rows,
    required this.standingArrears,
    required this.onArrearsChanged,
  });

  @override
  State<_EducationTable> createState() => _EducationTableState();
}

class _EducationTableState extends State<_EducationTable> {
  @override
  Widget build(BuildContext context) {
    const colWidths = [160.0, 150.0, 190.0, 120.0, 90.0, 130.0];
    const headers   = [
      'Academics', 'Degree /\nSpecialization',
      'School / College / University',
      'Month/Year\nof Passing', '% Marks', 'Certificate\nAvailable',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sub-header: Standing Arrears
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          child: Row(children: [
            const Text('Standing Arrears in Degree, if any',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
                    color: Color(0xFF37474F))),
            const SizedBox(width: 16),
            _arrearOption('Yes'),
            const SizedBox(width: 12),
            _arrearOption('No'),
          ]),
        ),

        // Column headers
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(children: [
            Container(
              color: const Color(0xFFE3F2FD),
              child: Row(
                children: List.generate(headers.length, (i) => Container(
                  width: colWidths[i],
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      right: i < headers.length - 1
                          ? const BorderSide(color: Color(0xFFCCCCCC))
                          : BorderSide.none,
                    ),
                  ),
                  child: Text(headers[i],
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
                )),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            // Data rows
            ...widget.rows.asMap().entries.map((e) {
              final idx = e.key;
              final row = e.value;
              return Column(children: [
                Row(children: [
                  // Academics label (read-only)
                  Container(
                    width: colWidths[0],
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xFFEEEEEE))),
                    ),
                    child: Text(row.academics,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF37474F))),
                  ),
                  _eCell(row.degree,  colWidths[1]),
                  _eCell(row.college, colWidths[2]),
                  _eCell(row.passing, colWidths[3], hint: 'MM/YYYY'),
                  _eCell(row.marks,   colWidths[4],
                      keyboard: TextInputType.number),
                  // Certificate Yes/No
                  Container(
                    width: colWidths[5],
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(children: [
                      _certOption(row, 'Yes'),
                      const SizedBox(width: 6),
                      _certOption(row, 'No'),
                    ]),
                  ),
                ]),
                if (idx < widget.rows.length - 1)
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              ]);
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _arrearOption(String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Radio<String>(
        value: label,
        groupValue: widget.standingArrears,
        onChanged: widget.onArrearsChanged,
        activeColor: _blue,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF37474F))),
    ]);
  }

  Widget _certOption(_EduRow row, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Radio<String>(
        value: label,
        groupValue: row.certificate,
        onChanged: (v) => setState(() => row.certificate = v),
        activeColor: _blue,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF37474F))),
    ]);
  }

  Widget _eCell(TextEditingController ctrl, double width,
      {String? hint, TextInputType keyboard = TextInputType.text}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
        ),
      ),
    );
  }
}

// ── Employment History data holder ─────────────────────────────────────────────
class _EmpRow {
  final org      = TextEditingController();
  final position = TextEditingController();
  final from     = TextEditingController();
  final to       = TextEditingController();
  final ctc      = TextEditingController();
  final reason   = TextEditingController();

  Map<String, String> toMap() => {
    'organization':   org.text.trim(),
    'position_held':  position.text.trim(),
    'from':           from.text.trim(),
    'to':             to.text.trim(),
    'last_ctc':       ctc.text.trim(),
    'reason_leaving': reason.text.trim(),
  };

  void clear() {
    org.clear(); position.clear(); from.clear();
    to.clear(); ctc.clear(); reason.clear();
  }

  void dispose() {
    org.dispose(); position.dispose(); from.dispose();
    to.dispose(); ctc.dispose(); reason.dispose();
  }
}

// ── Referral data holder ────────────────────────────────────────────────────────
class _RefRow {
  final name         = TextEditingController();
  final organization = TextEditingController();
  final designation  = TextEditingController();
  final relationship = TextEditingController();
  final contact      = TextEditingController();

  Map<String, String> toMap() => {
    'name':         name.text.trim(),
    'organization': organization.text.trim(),
    'designation':  designation.text.trim(),
    'relationship': relationship.text.trim(),
    'contact':      contact.text.trim(),
  };

  void clear() {
    name.clear(); organization.clear(); designation.clear();
    relationship.clear(); contact.clear();
  }

  void dispose() {
    name.dispose(); organization.dispose(); designation.dispose();
    relationship.dispose(); contact.dispose();
  }
}

// ── Employment History Table ────────────────────────────────────────────────────
class _EmpHistoryTable extends StatelessWidget {
  final List<_EmpRow> rows;
  const _EmpHistoryTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    const headers = [
      'Organization Name', 'Position Held',
      'From\n[MM-YYYY]', 'To\n[MM-YYYY]',
      'Last Drawn\nMonthly CTC', 'Reason for Leaving',
    ];
    const widths = [160.0, 150.0, 110.0, 110.0, 140.0, 170.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            // Header row
            Container(
              color: const Color(0xFFE3F2FD),
              child: Row(
                children: List.generate(headers.length, (i) => Container(
                  width: widths[i],
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      right: i < headers.length - 1
                          ? const BorderSide(color: Color(0xFFCCCCCC))
                          : BorderSide.none,
                    ),
                  ),
                  child: Text(headers[i],
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
                )),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            // Data rows
            ...rows.asMap().entries.map((e) => Column(children: [
              Row(
                children: [
                  _tableCell(e.value.org,      widths[0], last: false),
                  _tableCell(e.value.position, widths[1], last: false),
                  _tableCell(e.value.from,     widths[2], last: false, hint: 'MM-YYYY'),
                  _tableCell(e.value.to,       widths[3], last: false, hint: 'MM-YYYY'),
                  _tableCell(e.value.ctc,      widths[4], last: false),
                  _tableCell(e.value.reason,   widths[5], last: true),
                ],
              ),
              if (e.key < rows.length - 1)
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _tableCell(TextEditingController ctrl, double width,
      {required bool last, String? hint}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          right: last
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
        ),
      ),
    );
  }
}

// ── Referral Table ──────────────────────────────────────────────────────────────
class _ReferralTable extends StatelessWidget {
  final List<_RefRow> rows;
  const _ReferralTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    const headers = ['Name', 'Organization', 'Designation', 'Relationship', 'Contact Number'];
    const widths  = [140.0, 160.0, 150.0, 140.0, 150.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(children: [
          Container(
            color: const Color(0xFFE3F2FD),
            child: Row(
              children: List.generate(headers.length, (i) => Container(
                width: widths[i],
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: i < headers.length - 1
                        ? const BorderSide(color: Color(0xFFCCCCCC))
                        : BorderSide.none,
                  ),
                ),
                child: Text(headers[i],
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
              )),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          ...rows.asMap().entries.map((e) => Column(children: [
            Row(children: [
              _rCell(e.value.name,         widths[0], last: false),
              _rCell(e.value.organization, widths[1], last: false),
              _rCell(e.value.designation,  widths[2], last: false),
              _rCell(e.value.relationship, widths[3], last: false),
              _rCell(e.value.contact,      widths[4], last: true,
                  keyboard: TextInputType.phone),
            ]),
            if (e.key < rows.length - 1)
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
          ])),
        ]),
      ),
    );
  }

  Widget _rCell(TextEditingController ctrl, double width,
      {required bool last, TextInputType keyboard = TextInputType.text}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          right: last
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
        ),
      ),
    );
  }
}

// ── Resume Uploader ─────────────────────────────────────────────────────────────
class _ResumeUploader extends StatelessWidget {
  final String? fileName;
  final bool uploading;
  final VoidCallback onPick;
  const _ResumeUploader(
      {required this.fileName, required this.uploading, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: fileName != null ? _blue : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            fileName != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
            color: _blue, size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              fileName ?? 'Upload Resume',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fileName != null ? _blue : const Color(0xFF37474F),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              fileName != null
                  ? 'Resume uploaded successfully'
                  : 'PDF, DOC or DOCX — max 10 MB',
              style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: uploading ? null : onPick,
          icon: uploading
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(fileName != null ? Icons.swap_horiz_rounded : Icons.attach_file_rounded,
                  size: 16),
          label: Text(uploading ? 'Uploading…' : fileName != null ? 'Change' : 'Choose File',
              style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue, foregroundColor: Colors.white,
            elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}

// ── Shared form widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _blue, size: 17),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
    ]);
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboard;
  final String? hint;
  final int maxLines;
  final bool required;
  const _Field({
    required this.label, required this.controller,
    this.keyboard = TextInputType.text, this.hint,
    this.maxLines = 1, this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label, value;
  final bool required;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value,
      required this.onTap, this.required = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          style: const TextStyle(fontSize: 13),
          controller: TextEditingController(text: value),
          validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: _blue),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _blue, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioGroup extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required, wrap;
  const _RadioGroup({required this.label, required this.options,
      required this.value, required this.onChanged,
      this.required = false, this.wrap = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(required ? '$label *' : label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
        const SizedBox(height: 8),
        wrap
            ? Wrap(children: options.map((opt) => SizedBox(
                width: 210,
                child: RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  activeColor: _blue,
                  title: Text(opt, style: const TextStyle(fontSize: 13)),
                  value: opt, groupValue: value, onChanged: onChanged,
                ),
              )).toList())
            : Column(children: options.map((opt) => RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                activeColor: _blue,
                title: Text(opt, style: const TextStyle(fontSize: 13)),
                value: opt, groupValue: value, onChanged: onChanged,
              )).toList()),
      ]),
    );
  }
}
