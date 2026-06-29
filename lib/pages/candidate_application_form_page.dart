import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../models/form_config.dart';
import '../widgets/web_file_picker.dart';

const _blue  = Color(0xFF0D47A1);

class CandidateApplicationFormPage extends StatefulWidget {
  final String? version;
  const CandidateApplicationFormPage({super.key, this.version});
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

  // ── Dates / choices
  DateTime? _interviewDate;
  DateTime? _dob;
  DateTime? _declarationDate;
  String? _gender;
  String? _maritalStatus;
  String? _postApplied;
  String? _noticePeriod;
  String? _source;
  bool _declarationAgreed = false;

  // ── Resume
  String? _resumeFileName;
  String? _resumeUrl;
  bool _uploadingResume = false;

  bool _submitting = false;

  // ── Form config
  Map<String, dynamic> _config = {};
  bool _configLoading = true;

  // ── Custom fields state (keyed by field id from config)
  final Map<String, TextEditingController> _customTextControllers = {};
  final Map<String, String?> _customMcqValues = {};
  final Map<String, String?> _customFileNames = {};
  final Map<String, String?> _customFileUrls = {};
  final Map<String, bool> _customFileUploading = {};
  final Map<String, DateTime?> _customDateValues = {};
  final Map<String, bool> _customCheckboxValues = {};

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      Map<String, dynamic>? versionData;
      final v = widget.version;
      if (v != null && v.isNotEmpty) {
        final vNum = int.tryParse(v);
        if (vNum != null) {
          versionData = await SupabaseService.fetchFormVersionByNumber(vNum);
        }
      } else {
        versionData = await SupabaseService.fetchActiveFormVersion();
      }
      if (versionData != null && mounted) {
        final cfg = Map<String, dynamic>.from(
            versionData['form_config'] as Map);
        // Pre-create controllers for custom short-answer fields
        for (final section in FormConfig.getSections(cfg)) {
          for (final field in FormConfig.getCustomFields(section)) {
            final id = (field['id'] as String?) ?? '';
            if (id.isEmpty) continue;
            if ((field['type'] as String?) == 'short_answer') {
              _customTextControllers.putIfAbsent(
                  id, () => TextEditingController());
            }
          }
        }
        setState(() {
          _config = cfg;
          _configLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _configLoading = false);
  }

  List<Map<String, dynamic>> _sectionCustomFields(String id) {
    if (_config.isEmpty) return [];
    try {
      final s = FormConfig.getSections(_config)
          .firstWhere((s) => s['id'] == id);
      return FormConfig.getCustomFields(s);
    } catch (_) {
      return [];
    }
  }

  Future<void> _handleCustomFile(String fieldId, html.File rawFile) async {
    setState(() => _customFileUploading[fieldId] = true);
    try {
      final reader = html.FileReader();
      reader.readAsDataUrl(rawFile);
      await Future.any([
        reader.onLoad.first,
        reader.onError.first.then((_) => throw Exception('Could not read file')),
      ]);
      final dataUrl = reader.result as String;
      final comma = dataUrl.indexOf(',');
      if (comma < 0) throw 'Malformed data URL';
      var bytes = base64Decode(dataUrl.substring(comma + 1));
      var mime  = rawFile.type.isEmpty ? 'application/octet-stream' : rawFile.type;
      // Images → compress to ≤200 KB
      if (mime.startsWith('image/')) {
        final compressed = await _compressImage(bytes, mime);
        if (compressed != null) { bytes = compressed; mime = 'image/jpeg'; }
      }
      final url = await SupabaseService.uploadFile(bytes, rawFile.name, mime);
      if (mounted) {
        setState(() {
          _customFileNames[fieldId] = rawFile.name;
          _customFileUrls[fieldId]  = url;
        });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text('File added: ${rawFile.name}'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
          ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red,
            duration: const Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => _customFileUploading[fieldId] = false);
    }
  }

  List<Widget> _renderCustomFields(
      List<Map<String, dynamic>> fields, bool narrow) {
    if (fields.isEmpty) return [];
    final widgets = <Widget>[];
    for (final field in fields) {
      final id = (field['id'] as String?) ?? '';
      if (id.isEmpty) continue;
      final type = (field['type'] as String?) ?? 'short_answer';
      final label = (field['label'] as String?) ?? '';
      final isRequired = (field['required'] as bool?) ?? false;

      widgets.add(const SizedBox(height: 14));

      if (type == 'short_answer') {
        final ctrl = _customTextControllers.putIfAbsent(
            id, () => TextEditingController());
        widgets.add(_Field(
          label: label,
          controller: ctrl,
          required: isRequired,
        ));
      } else if (type == 'mcq') {
        final rawOpts = field['options'];
        final opts = rawOpts is List
            ? List<String>.from(rawOpts.cast<String>())
            : <String>[];
        widgets.add(_RadioGroup(
          label: label,
          options: opts,
          value: _customMcqValues[id],
          onChanged: (v) => setState(() => _customMcqValues[id] = v),
          required: isRequired,
          wrap: opts.length > 3,
        ));
      } else if (type == 'photo_upload' || type == 'file_upload') {
        widgets.add(_CustomFileUploader(
          label: label,
          isRequired: isRequired,
          fileName: _customFileNames[id],
          uploading: _customFileUploading[id] ?? false,
          onRawFile: (f) => _handleCustomFile(id, f),
          accept: type == 'photo_upload'
              ? 'image/*'
              : '.pdf,.doc,.docx,.xls,.xlsx',
          isPhoto: type == 'photo_upload',
        ));
      } else if (type == 'number') {
        final ctrl = _customTextControllers.putIfAbsent(
            id, () => TextEditingController());
        widgets.add(_Field(
          label: label,
          controller: ctrl,
          required: isRequired,
          keyboard: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ));
      } else if (type == 'date') {
        final picked = _customDateValues[id];
        widgets.add(_CustomDateField(
          label: label,
          isRequired: isRequired,
          value: picked,
          onPick: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: picked ?? now,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => _customDateValues[id] = d);
          },
        ));
      } else if (type == 'checkbox') {
        final checked = _customCheckboxValues[id] ?? false;
        widgets.add(GestureDetector(
          onTap: () => setState(() => _customCheckboxValues[id] = !checked),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: checked ? _blue : const Color(0xFFE0E0E0),
              ),
            ),
            child: Row(children: [
              Icon(
                checked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: checked ? _blue : const Color(0xFFBBBBBB),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isRequired ? '$label *' : label,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF37474F)),
                ),
              ),
            ]),
          ),
        ));
      }
    }
    return widgets;
  }

  bool _secEnabled(String id) =>
      _config.isEmpty || FormConfig.isSectionEnabled(_config, id);

  String _secTitle(String id, String fallback) =>
      _config.isEmpty ? fallback : FormConfig.getSectionTitle(_config, id, fallback);

  List<String> _secOptions(String id, String key, List<String> fallback) =>
      _config.isEmpty
          ? fallback
          : FormConfig.getSectionOptions(_config, id, key, fallback);

  bool _fHide(String sId, String fId) {
    if (_config.isEmpty) return false;
    final s = FormConfig.getSection(_config, sId);
    if (s == null) return false;
    return FormConfig.isFieldHidden(s, fId);
  }

  @override
  void dispose() {
    for (final c in [
      _name, _mobile, _place, _nationality, _email, _age,
      _totalExp, _relevantExp, _reasonChange, _currentCtc, _expectedCtc,
      _jobPortal, _referredBy, _relatedEmp, _appliedBefore,
      _address, _declarationName,
    ]) { c.dispose(); }
    for (final r in _education)  r.dispose();
    for (final r in _empHistory) r.dispose();
    for (final r in _referrals)  r.dispose();
    for (final c in _customTextControllers.values) c.dispose();
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

  Future<void> _pickDeclarationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _blue)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _declarationDate = picked);
  }

  Future<void> _handleResume(html.File rawFile) async {
    setState(() => _uploadingResume = true);
    try {
      final reader = html.FileReader();
      reader.readAsDataUrl(rawFile);
      await Future.any([
        reader.onLoad.first,
        reader.onError.first.then((_) => throw Exception('Could not read file')),
      ]);
      final dataUrl = reader.result as String;
      final comma = dataUrl.indexOf(',');
      if (comma < 0) throw 'Malformed data URL';
      var bytes = base64Decode(dataUrl.substring(comma + 1));
      var mime  = rawFile.type.isEmpty ? 'application/octet-stream' : rawFile.type;
      var name  = rawFile.name;
      // Images → compress to ≤200 KB
      if (mime.startsWith('image/')) {
        final compressed = await _compressImage(bytes, mime);
        if (compressed != null) {
          bytes = compressed;
          mime  = 'image/jpeg';
          name  = '${name.replaceAll(RegExp(r'\.[^.]+$'), '')}.jpg';
        }
      }
      final url = await SupabaseService.uploadResume(bytes, name, mime);
      if (mounted) {
        setState(() { _resumeFileName = name; _resumeUrl = url; });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text('Resume uploaded: $name'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resume upload failed: $e'), backgroundColor: Colors.red,
            duration: const Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => _uploadingResume = false);
    }
  }

  // Compress image via Canvas API to ≤200 KB.
  Future<Uint8List?> _compressImage(Uint8List bytes, String mime) async {
    try {
      final blob = html.Blob([bytes], mime);
      final url  = html.Url.createObjectUrlFromBlob(blob);
      final img  = html.ImageElement(src: url);
      await Future.any([
        img.onLoad.first,
        img.onError.first.then((_) => throw Exception('Image load failed')),
      ]);
      html.Url.revokeObjectUrl(url);
      int w = img.naturalWidth, h = img.naturalHeight;
      const maxDim = 1200;
      if (w > maxDim || h > maxDim) {
        if (w > h) { h = (h * maxDim / w).round(); w = maxDim; }
        else       { w = (w * maxDim / h).round(); h = maxDim; }
      }
      const target = 200 * 1024; // 200 KB
      for (final q in [0.8, 0.6, 0.4, 0.2, 0.1, 0.05]) {
        final c = html.CanvasElement(width: w, height: h);
        c.context2D.drawImageScaled(img, 0, 0, w.toDouble(), h.toDouble());
        final out = Uint8List.fromList(base64Decode(c.toDataUrl('image/jpeg', q).split(',').last));
        if (out.length <= target) return out;
      }
      // Last resort: halve dimensions
      w = (w * 0.6).round(); h = (h * 0.6).round();
      final c = html.CanvasElement(width: w, height: h);
      c.context2D.drawImageScaled(img, 0, 0, w.toDouble(), h.toDouble());
      return Uint8List.fromList(base64Decode(c.toDataUrl('image/jpeg', 0.05).split(',').last));
    } catch (_) { return null; }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if ((!_fHide('interview_details', 'interview_date') && _interviewDate == null) ||
        (!_fHide('personal_info', 'dob') && _dob == null) ||
        (!_fHide('personal_info', 'gender') && _gender == null) ||
        (!_fHide('personal_info', 'marital_status') && _maritalStatus == null) ||
        (!_fHide('interview_details', 'post_applied') && _postApplied == null) ||
        (!_fHide('experience_ctc', 'notice_period') && _noticePeriod == null) ||
        (!_fHide('source', 'source') && _source == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all required fields.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    // Validate required custom fields
    for (final section in FormConfig.getSections(_config)) {
      final sId = (section['id'] as String?) ?? '';
      if (!_secEnabled(sId)) continue;
      for (final field in FormConfig.getCustomFields(section)) {
        final fId = (field['id'] as String?) ?? '';
        final isReq = (field['required'] as bool?) ?? false;
        if (!isReq || fId.isEmpty) continue;
        final fType = (field['type'] as String?) ?? 'short_answer';
        final fLabel = (field['label'] as String?) ?? 'field';
        bool missing = false;
        if (fType == 'short_answer' || fType == 'number') {
          missing = (_customTextControllers[fId]?.text.trim() ?? '').isEmpty;
        } else if (fType == 'mcq') {
          missing = _customMcqValues[fId] == null;
        } else if (fType == 'file_upload' || fType == 'photo_upload') {
          missing = _customFileUrls[fId] == null;
        } else if (fType == 'date') {
          missing = _customDateValues[fId] == null;
        } else if (fType == 'checkbox') {
          missing = !(_customCheckboxValues[fId] ?? false);
        }
        if (missing) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Required: "$fLabel"'),
            backgroundColor: Colors.redAccent,
          ));
          return;
        }
      }
    }

    if (_secEnabled('declaration')) {
      if (!_fHide('declaration', 'declaration_date') && _declarationDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a date in the Declaration section.'),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
      if (!_fHide('declaration', 'declaration_agree') && !_declarationAgreed) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must agree to the declaration before submitting.'),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
    }

    setState(() => _submitting = true);

    try {
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
      'signature_date':      _fmt(_declarationDate),
      'declaration_agreed':  true,
      'resume_url':          _resumeUrl ?? '',
      'custom_field_values': {
        for (final e in _customTextControllers.entries)
          e.key: e.value.text.trim(),
        for (final e in _customMcqValues.entries) e.key: e.value ?? '',
        for (final e in _customFileUrls.entries) e.key: e.value ?? '',
        for (final e in _customDateValues.entries)
          if (e.value != null)
            e.key: '${e.value!.day.toString().padLeft(2, '0')}/${e.value!.month.toString().padLeft(2, '0')}/${e.value!.year}',
        for (final e in _customCheckboxValues.entries) e.key: e.value,
      },
    });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Submission Failed',
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          content: Text(
            'Error: ${e.toString()}\n\nPlease make sure the database table is set up correctly.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

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
      _address, _declarationName,
    ]) { c.clear(); }
    for (final r in _education)  r.clear();
    for (final r in _empHistory) r.clear();
    for (final r in _referrals)  r.clear();
    for (final c in _customTextControllers.values) c.clear();
    setState(() {
      _interviewDate = null; _dob = null;
      _gender = null; _maritalStatus = null;
      _postApplied = null; _noticePeriod = null; _source = null;
      _standingArrears = null;
      _declarationDate = null; _declarationAgreed = false;
      _resumeFileName = null; _resumeUrl = null;
      _customMcqValues.clear();
      _customFileNames.clear();
      _customFileUrls.clear();
      _customDateValues.clear();
      _customCheckboxValues.clear();
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    if (_configLoading) {
      return const Material(
        color: Color(0xFFF5F7FA),
        child: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }

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
                      if (_secEnabled('personal_info')) ...[
                      _SectionHeader(icon: Icons.person_rounded, title: _secTitle('personal_info', 'Personal Information')),
                      const SizedBox(height: 16),
                      _row(narrow, [
                        if (!_fHide('personal_info', 'name'))
                          _Field(label: 'Name', controller: _name, required: true),
                        if (!_fHide('personal_info', 'mobile'))
                          _Field(label: 'Mobile Number', controller: _mobile,
                              keyboard: TextInputType.phone, required: true,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))]),
                      ]),
                      _row(narrow, [
                        if (!_fHide('personal_info', 'place'))
                          _Field(label: 'Place', controller: _place, required: true),
                        if (!_fHide('personal_info', 'nationality'))
                          _Field(label: 'Nationality', controller: _nationality, required: true),
                      ]),
                      _row(narrow, [
                        if (!_fHide('personal_info', 'email'))
                          _Field(label: 'Email ID', controller: _email,
                              keyboard: TextInputType.emailAddress, required: true),
                        if (!_fHide('personal_info', 'age'))
                          _Field(label: 'Age', controller: _age,
                              keyboard: TextInputType.number, required: true,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                      ]),
                      if (!_fHide('personal_info', 'dob')) ...[
                        const SizedBox(height: 14),
                        _DateField(label: 'Date of Birth', value: _fmt(_dob),
                            required: true, onTap: () => _pickDate(false)),
                      ],
                      if (!_fHide('personal_info', 'gender')) ...[
                        const SizedBox(height: 14),
                        _RadioGroup(label: 'Gender', required: true,
                            options: const ['Male', 'Female'],
                            value: _gender, onChanged: (v) => setState(() => _gender = v)),
                      ],
                      if (!_fHide('personal_info', 'marital_status')) ...[
                        const SizedBox(height: 14),
                        _RadioGroup(label: 'Marital Status', required: true,
                            options: const ['Single', 'Married', 'Separated'],
                            value: _maritalStatus, onChanged: (v) => setState(() => _maritalStatus = v)),
                      ],
                      ..._renderCustomFields(_sectionCustomFields('personal_info'), narrow),
                      ], // end personal_info

                      // ── Interview Details ────────────────────────────
                      if (_secEnabled('interview_details')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.event_note_rounded,
                          title: _secTitle('interview_details', 'Interview Details')),
                      const SizedBox(height: 16),
                      if (!_fHide('interview_details', 'interview_date'))
                        _DateField(label: 'Interview Attended Date', value: _fmt(_interviewDate),
                            required: true, onTap: () => _pickDate(true)),
                      if (!_fHide('interview_details', 'post_applied')) ...[
                        const SizedBox(height: 14),
                        _RadioGroup(label: 'Post Applied', required: true, wrap: true,
                            options: _secOptions('interview_details', 'post_applied_options',
                                const ['HR','ADMIN','OPERATION','CRM',
                                    'PROJECTS','LAND ACQUISITION','ACCOUNTS',
                                    'SALES','DIGITAL MARKETING']),
                            value: _postApplied, onChanged: (v) => setState(() => _postApplied = v)),
                      ],
                      ..._renderCustomFields(_sectionCustomFields('interview_details'), narrow),
                      ], // end interview_details

                      // ── Experience & CTC ─────────────────────────────
                      if (_secEnabled('experience_ctc')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.work_history_rounded,
                          title: _secTitle('experience_ctc', 'Experience & CTC')),
                      const SizedBox(height: 16),
                      _row(narrow, [
                        if (!_fHide('experience_ctc', 'total_exp'))
                          _Field(label: 'Total Experience', controller: _totalExp,
                              hint: 'e.g. 3 years 2 months', required: true),
                        if (!_fHide('experience_ctc', 'relevant_exp'))
                          _Field(label: 'Relevant Experience', controller: _relevantExp,
                              hint: 'e.g. 2 years', required: true),
                      ]),
                      if (!_fHide('experience_ctc', 'reason_change')) ...[
                        const SizedBox(height: 14),
                        _Field(label: 'Reason for Change in Job', controller: _reasonChange,
                            maxLines: 2, required: true),
                      ],
                      _row(narrow, [
                        if (!_fHide('experience_ctc', 'current_ctc'))
                          _Field(label: 'Current CTC per Month (INR)', controller: _currentCtc,
                              keyboard: TextInputType.number, required: true,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
                        if (!_fHide('experience_ctc', 'expected_ctc'))
                          _Field(label: 'Expected CTC per Month (INR)', controller: _expectedCtc,
                              keyboard: TextInputType.number, required: true,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
                      ]),
                      if (!_fHide('experience_ctc', 'notice_period')) ...[
                        const SizedBox(height: 14),
                        _RadioGroup(label: 'Notice Period (to join if selected)', required: true,
                            options: _secOptions('experience_ctc', 'notice_period_options',
                                const ['Immediate','15 Days','30 Days','60 Days or more']),
                            value: _noticePeriod, onChanged: (v) => setState(() => _noticePeriod = v)),
                      ],
                      ..._renderCustomFields(_sectionCustomFields('experience_ctc'), narrow),
                      ], // end experience_ctc

                      // ── Educational Qualifications ───────────────────
                      if (_secEnabled('education')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.school_rounded,
                          title: _secTitle('education', 'Educational Qualifications')),
                      const SizedBox(height: 16),
                      if (!_fHide('education', 'education_table'))
                        _EducationTable(
                          rows: _education,
                          standingArrears: _fHide('education', 'standing_arrears')
                              ? null : _standingArrears,
                          onArrearsChanged: _fHide('education', 'standing_arrears')
                              ? (_) {} : (v) => setState(() => _standingArrears = v),
                        ),
                      ..._renderCustomFields(_sectionCustomFields('education'), narrow),
                      ], // end education

                      // ── Employment History ───────────────────────────
                      if (_secEnabled('employment_history')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.business_center_rounded,
                          title: _secTitle('employment_history',
                              'Employment History (Current & Previous, if any)')),
                      const SizedBox(height: 16),
                      if (!_fHide('employment_history', 'employment_table'))
                        _EmpHistoryTable(rows: _empHistory),
                      ..._renderCustomFields(_sectionCustomFields('employment_history'), narrow),
                      ], // end employment_history

                      // ── Source ───────────────────────────────────────
                      if (_secEnabled('source')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.campaign_rounded,
                          title: _secTitle('source', 'Source')),
                      const SizedBox(height: 16),
                      if (!_fHide('source', 'source'))
                        _RadioGroup(label: 'Source', required: true,
                            options: _secOptions('source', 'source_options',
                                const ['Walk In','Referred by Employee',
                                    'Consultancy (Specify)','Job Portal / Other (Specify)','Other']),
                            value: _source, onChanged: (v) => setState(() => _source = v)),
                      if (!_fHide('source', 'job_portal')) ...[
                        const SizedBox(height: 14),
                        _Field(label: 'Mention Job Portal (if applicable)',
                            controller: _jobPortal, hint: 'e.g. Naukri, LinkedIn…'),
                      ],
                      if (!_fHide('source', 'referred_by')) ...[
                        const SizedBox(height: 14),
                        _Field(label: 'If Referred by Employee — Name & Employee ID',
                            controller: _referredBy, hint: 'Name and EMP ID', maxLines: 2),
                      ],
                      if (!_fHide('source', 'related_emp')) ...[
                        const SizedBox(height: 14),
                        _Field(label: 'If Related to Any Employee — Name, EMP ID & Relationship',
                            controller: _relatedEmp, hint: 'Name, EMP ID, Relationship', maxLines: 2),
                      ],
                      ..._renderCustomFields(_sectionCustomFields('source'), narrow),
                      ], // end source

                      // ── Referrals ────────────────────────────────────
                      if (_secEnabled('referrals')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.group_add_rounded,
                          title: _secTitle('referrals',
                              'Refer Friends / Relatives Looking for a Job')),
                      const SizedBox(height: 16),
                      if (!_fHide('referrals', 'referrals_table'))
                        _ReferralTable(rows: _referrals),
                      ..._renderCustomFields(_sectionCustomFields('referrals'), narrow),
                      ], // end referrals

                      // ── Previous Application ─────────────────────────
                      if (_secEnabled('previous_application')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.history_rounded,
                          title: _secTitle('previous_application', 'Previous Application')),
                      const SizedBox(height: 16),
                      if (!_fHide('previous_application', 'applied_before'))
                        _Field(label: 'Have you applied for a job with us earlier?',
                            controller: _appliedBefore,
                            hint: 'If yes, mention Job and Date', maxLines: 2),
                      ..._renderCustomFields(_sectionCustomFields('previous_application'), narrow),
                      ], // end previous_application

                      // ── Address ──────────────────────────────────────
                      if (_secEnabled('address')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.location_on_rounded,
                          title: _secTitle('address', 'Address for Communication')),
                      const SizedBox(height: 16),
                      if (!_fHide('address', 'address'))
                        _Field(label: 'Full Address', controller: _address, maxLines: 3),
                      ..._renderCustomFields(_sectionCustomFields('address'), narrow),
                      ], // end address

                      // ── Resume Upload ────────────────────────────────
                      if (_secEnabled('resume')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.attach_file_rounded,
                          title: _secTitle('resume', 'Resume')),
                      const SizedBox(height: 16),
                      if (!_fHide('resume', 'resume'))
                        _ResumeUploader(
                          fileName: _resumeFileName,
                          uploading: _uploadingResume,
                          onRawFile: _handleResume,
                        ),
                      ..._renderCustomFields(_sectionCustomFields('resume'), narrow),
                      ], // end resume

                      // ── Declaration ──────────────────────────────────
                      if (_secEnabled('declaration')) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(icon: Icons.verified_rounded,
                          title: _secTitle('declaration', 'Declaration')),
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
                            // Declaration text
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(fontSize: 13, color: Color(0xFF37474F), height: 1.6),
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
                            const SizedBox(height: 16),
                            // Full Name (required) + Date (required)
                            _row(narrow, [
                              if (!_fHide('declaration', 'declaration_name'))
                                _Field(label: 'Full Name', controller: _declarationName, required: true),
                              if (!_fHide('declaration', 'declaration_date'))
                                _DateField(
                                  label: 'Date',
                                  value: _fmt(_declarationDate),
                                  required: true,
                                  onTap: _pickDeclarationDate,
                                ),
                            ]),
                            const SizedBox(height: 16),
                            // I AGREE checkbox (compulsory)
                            if (!_fHide('declaration', 'declaration_agree'))
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _declarationAgreed
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _declarationAgreed
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFFFCC02),
                                  width: 1.5,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: _declarationAgreed,
                                onChanged: (v) => setState(
                                    () => _declarationAgreed = v ?? false),
                                activeColor: _blue,
                                checkColor: Colors.white,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 2),
                                title: const Text(
                                  'I AGREE TO THE ABOVE DECLARATION  *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF37474F),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._renderCustomFields(_sectionCustomFields('declaration'), narrow),
                      ], // end declaration

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
    if (children.isEmpty) return const SizedBox.shrink();
    if (narrow || children.length == 1) {
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
                  _eCell(row.marks, colWidths[4],
                      keyboard: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
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
      {String? hint, TextInputType keyboard = TextInputType.text,
      List<TextInputFormatter>? inputFormatters}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
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
                  _tableCell(e.value.ctc, widths[4], last: false,
                      keyboard: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
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
      {required bool last, String? hint,
      TextInputType keyboard = TextInputType.text,
      List<TextInputFormatter>? inputFormatters}) {
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
        inputFormatters: inputFormatters,
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
  final void Function(html.File) onRawFile;
  const _ResumeUploader(
      {required this.fileName, required this.uploading, required this.onRawFile});

  @override
  Widget build(BuildContext context) {
    Widget uploadBtn(VoidCallback? onPressed) => ElevatedButton.icon(
      onPressed: onPressed,
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
    );

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
                  : 'PDF, DOC, DOCX accepted — images auto-compressed to ≤200 KB',
              style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        uploading
            ? uploadBtn(null)
            : WebFilePicker(
                accept: '.pdf,.doc,.docx,.jpg,.jpeg,.png,image/*',
                onRawFiles: (files) => onRawFile(files.first),
                builder: (trigger) => uploadBtn(trigger),
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
  final List<TextInputFormatter>? inputFormatters;
  const _Field({
    required this.label, required this.controller,
    this.keyboard = TextInputType.text, this.hint,
    this.maxLines = 1, this.required = false,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
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

class _CustomFileUploader extends StatelessWidget {
  final String label;
  final bool isRequired;
  final String? fileName;
  final bool uploading;
  final void Function(html.File) onRawFile;
  final String accept;
  final bool isPhoto;
  const _CustomFileUploader({
    required this.label,
    required this.isRequired,
    required this.fileName,
    required this.uploading,
    required this.onRawFile,
    this.accept = '.pdf,.doc,.docx,.xls,.xlsx',
    this.isPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget uploadBtn(VoidCallback? onPressed) => ElevatedButton.icon(
      onPressed: onPressed,
      icon: uploading
          ? const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(
              fileName != null
                  ? Icons.swap_horiz_rounded
                  : Icons.attach_file_rounded,
              size: 16),
      label: Text(
          uploading
              ? 'Uploading…'
              : fileName != null ? 'Change' : 'Choose File',
          style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: fileName != null ? _blue : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRequired ? '$label *' : label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37474F)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                fileName != null
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: _blue, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName ?? 'No file selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: fileName != null
                            ? _blue
                            : const Color(0xFF78909C),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPhoto
                          ? 'JPG / PNG — auto-compressed to ≤200 KB'
                          : 'PDF, DOC, DOCX, XLS, XLSX accepted',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFBBBBBB))),
                  ]),
            ),
            const SizedBox(width: 12),
            uploading
                ? uploadBtn(null)
                : WebFilePicker(
                    accept: accept,
                    onRawFiles: (files) => onRawFile(files.first),
                    builder: (trigger) => uploadBtn(trigger),
                  ),
          ]),
        ],
      ),
    );
  }
}

class _CustomDateField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final DateTime? value;
  final VoidCallback onPick;
  const _CustomDateField({
    required this.label,
    required this.isRequired,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = value != null
        ? '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}'
        : null;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value != null ? _blue : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              formatted ?? (isRequired ? '$label *' : label),
              style: TextStyle(
                fontSize: 13,
                color: formatted != null
                    ? const Color(0xFF37474F)
                    : const Color(0xFF78909C),
              ),
            ),
          ),
          Icon(Icons.calendar_today_rounded,
              size: 18,
              color: value != null ? _blue : const Color(0xFFBBBBBB)),
        ]),
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
