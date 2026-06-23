import 'package:flutter/material.dart';

const _blue = Color(0xFF0D47A1);
const _lightBlue = Color(0xFFE3F2FD);

class CandidateApplicationFormPage extends StatefulWidget {
  const CandidateApplicationFormPage({super.key});

  @override
  State<CandidateApplicationFormPage> createState() =>
      _CandidateApplicationFormPageState();
}

class _CandidateApplicationFormPageState
    extends State<CandidateApplicationFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final _name          = TextEditingController();
  final _mobile        = TextEditingController();
  final _place         = TextEditingController();
  final _nationality   = TextEditingController();
  final _email         = TextEditingController();
  final _totalExp      = TextEditingController();
  final _relevantExp   = TextEditingController();
  final _reasonChange  = TextEditingController();
  final _currentCtc    = TextEditingController();
  final _expectedCtc   = TextEditingController();
  final _age           = TextEditingController();
  final _jobPortal     = TextEditingController();
  final _referredBy    = TextEditingController();
  final _relatedEmp    = TextEditingController();
  final _appliedBefore = TextEditingController();

  // Date fields
  DateTime? _interviewDate;
  DateTime? _dob;

  // Radio / choice fields
  String? _gender;
  String? _maritalStatus;
  String? _postApplied;
  String? _noticePeriod;
  String? _source;

  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [
      _name, _mobile, _place, _nationality, _email,
      _totalExp, _relevantExp, _reasonChange, _currentCtc,
      _expectedCtc, _age, _jobPortal, _referredBy,
      _relatedEmp, _appliedBefore,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, bool isInterview) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _blue),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isInterview) _interviewDate = picked;
        else _dob = picked;
      });
    }
  }

  String _fmt(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_interviewDate == null || _dob == null ||
        _gender == null || _maritalStatus == null ||
        _postApplied == null || _noticePeriod == null || _source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _submitted = true);
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
          'The candidate application has been recorded successfully.',
          style: TextStyle(color: Color(0xFF37474F)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('New Application'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (final c in [
      _name, _mobile, _place, _nationality, _email,
      _totalExp, _relevantExp, _reasonChange, _currentCtc,
      _expectedCtc, _age, _jobPortal, _referredBy,
      _relatedEmp, _appliedBefore,
    ]) { c.clear(); }
    setState(() {
      _interviewDate = null;
      _dob           = null;
      _gender        = null;
      _maritalStatus = null;
      _postApplied   = null;
      _noticePeriod  = null;
      _source        = null;
      _submitted     = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
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
                  Text('Fill in the candidate details for interview',
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

          // ── Form ────────────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Personal Information ─────────────────────
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

                        // DOB
                        _DateField(
                          label: 'Date of Birth',
                          value: _fmt(_dob),
                          required: true,
                          onTap: () => _pickDate(context, false),
                        ),
                        const SizedBox(height: 14),

                        // Gender
                        _RadioGroup(
                          label: 'Gender',
                          required: true,
                          options: const ['Male', 'Female'],
                          value: _gender,
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                        const SizedBox(height: 14),

                        // Marital Status
                        _RadioGroup(
                          label: 'Marital Status',
                          required: true,
                          options: const ['Single', 'Married', 'Separated'],
                          value: _maritalStatus,
                          onChanged: (v) => setState(() => _maritalStatus = v),
                        ),

                        const SizedBox(height: 24),
                        // ── Interview Details ────────────────────────
                        _SectionHeader(icon: Icons.event_note_rounded, title: 'Interview Details'),
                        const SizedBox(height: 16),

                        _DateField(
                          label: 'Interview Attended Date',
                          value: _fmt(_interviewDate),
                          required: true,
                          onTap: () => _pickDate(context, true),
                        ),
                        const SizedBox(height: 14),

                        // Post Applied
                        _RadioGroup(
                          label: 'Post Applied',
                          required: true,
                          options: const [
                            'HR', 'ACCOUNTS', 'SALES', 'MARKETING',
                            'GMI', 'PROJECTS', 'LAND ACQUISITION', 'DIGITAL MARKETING',
                          ],
                          value: _postApplied,
                          onChanged: (v) => setState(() => _postApplied = v),
                          wrap: true,
                        ),

                        const SizedBox(height: 24),
                        // ── Experience & CTC ─────────────────────────
                        _SectionHeader(icon: Icons.work_history_rounded, title: 'Experience & CTC'),
                        const SizedBox(height: 16),

                        _row(narrow, [
                          _Field(label: 'Total Experience', controller: _totalExp,
                              hint: 'e.g. 3 years 2 months', required: true),
                          _Field(label: 'Relevant Experience', controller: _relevantExp,
                              hint: 'e.g. 2 years', required: true),
                        ]),
                        const SizedBox(height: 14),
                        _Field(
                          label: 'Reason for Change in Job',
                          controller: _reasonChange,
                          maxLines: 2,
                          required: true,
                        ),
                        const SizedBox(height: 14),
                        _row(narrow, [
                          _Field(label: 'Current CTC per Month (INR)',
                              controller: _currentCtc,
                              keyboard: TextInputType.number, required: true),
                          _Field(label: 'Expected CTC per Month (INR)',
                              controller: _expectedCtc,
                              keyboard: TextInputType.number, required: true),
                        ]),
                        const SizedBox(height: 14),

                        // Notice Period
                        _RadioGroup(
                          label: 'Notice Period (to join if selected)',
                          required: true,
                          options: const ['Immediate', '15 Days', '30 Days', '60 Days or more'],
                          value: _noticePeriod,
                          onChanged: (v) => setState(() => _noticePeriod = v),
                        ),

                        const SizedBox(height: 24),
                        // ── Source ───────────────────────────────────
                        _SectionHeader(icon: Icons.campaign_rounded, title: 'Source'),
                        const SizedBox(height: 16),

                        _RadioGroup(
                          label: 'Source',
                          required: true,
                          options: const [
                            'Walk In',
                            'Referred by Employee',
                            'Consultancy (Specify)',
                            'Job Portal / Other (Specify)',
                            'Other',
                          ],
                          value: _source,
                          onChanged: (v) => setState(() => _source = v),
                        ),
                        const SizedBox(height: 14),

                        _Field(
                          label: 'Mention Job Portal (if applicable)',
                          controller: _jobPortal,
                          hint: 'e.g. Naukri, LinkedIn...',
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          label: 'If Referred by Employee — Name & Employee ID (compulsory)',
                          controller: _referredBy,
                          hint: 'Name and EMP ID',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          label: 'If Related to Any Employee — Name, EMP ID & Relationship',
                          controller: _relatedEmp,
                          hint: 'Name, EMP ID, Relationship',
                          maxLines: 2,
                        ),

                        const SizedBox(height: 24),
                        // ── Previous Application ─────────────────────
                        _SectionHeader(icon: Icons.history_rounded, title: 'Previous Application'),
                        const SizedBox(height: 16),

                        _Field(
                          label: 'Have you applied for a job with us earlier?',
                          controller: _appliedBefore,
                          hint: 'If yes, mention Job and Date',
                          maxLines: 2,
                        ),

                        const SizedBox(height: 32),

                        // ── Submit ───────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Submit Application',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
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
        ],
      ),
    );
  }

  Widget _row(bool narrow, List<Widget> children) {
    if (narrow) {
      return Column(
        children: children.expand((w) => [w, const SizedBox(height: 14)]).toList()
          ..removeLast(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.expand((w) => [Expanded(child: w), const SizedBox(width: 14)]).toList()
        ..removeLast(),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

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
      Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
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
    required this.label,
    required this.controller,
    this.keyboard = TextInputType.text,
    this.hint,
    this.maxLines = 1,
    this.required = false,
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
        filled: true,
        fillColor: Colors.white,
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
  final String label;
  final String value;
  final bool required;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.required = false,
  });

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
            filled: true,
            fillColor: Colors.white,
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
  final bool required;
  final bool wrap;

  const _RadioGroup({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF37474F)),
          ),
          const SizedBox(height: 8),
          wrap
              ? Wrap(
                  spacing: 0,
                  runSpacing: 0,
                  children: options.map((opt) => SizedBox(
                    width: 200,
                    child: RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      activeColor: _blue,
                      title: Text(opt, style: const TextStyle(fontSize: 13)),
                      value: opt,
                      groupValue: value,
                      onChanged: onChanged,
                    ),
                  )).toList(),
                )
              : Column(
                  children: options.map((opt) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    activeColor: _blue,
                    title: Text(opt, style: const TextStyle(fontSize: 13)),
                    value: opt,
                    groupValue: value,
                    onChanged: onChanged,
                  )).toList(),
                ),
        ],
      ),
    );
  }
}
