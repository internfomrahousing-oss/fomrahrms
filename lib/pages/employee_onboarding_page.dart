import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeOnboardingPage extends StatefulWidget {
  const EmployeeOnboardingPage({super.key});

  @override
  State<EmployeeOnboardingPage> createState() => _EmployeeOnboardingPageState();
}

class _EmployeeOnboardingPageState extends State<EmployeeOnboardingPage> {
  static const _primary = Color(0xFF0D47A1);
  List<Map<String, dynamic>> _forms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('onboarding_forms')
          .select()
          .order('submitted_at', ascending: false);
      setState(() { _forms = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_primary, Color(0xFF1565C0)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Employee Onboarding',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_loading ? 'Loading...' : '${_forms.length} submission${_forms.length == 1 ? '' : 's'} received',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _load,
              ),
            ]),
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: _primary),
            ))
          else if (_forms.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No submissions yet', style: TextStyle(color: Colors.grey.shade500)),
                  ]),
                ),
              ),
            )
          else
            ..._forms.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SubmissionCard(data: f),
            )),
        ]),
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _SubmissionCard({required this.data});

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = (d['name'] as String? ?? '').isNotEmpty ? d['name'] : d['full_name'] ?? 'Unknown';
    final submittedAt = d['submitted_at'] != null
        ? DateTime.tryParse(d['submitted_at'] as String)
        : null;
    final dateStr = submittedAt != null
        ? '${submittedAt.day}/${submittedAt.month}/${submittedAt.year}'
        : '—';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE8EAF6))),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF0D47A1),
                child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A237E))),
                  const SizedBox(height: 2),
                  Text('${d['designation'] ?? ''} · Submitted $dateStr',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                ]),
              ),
              Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: const Color(0xFF78909C)),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _section('Basic Information', [
                _row('Name',            d['name']),
                _row('Phone Number',    d['phone_number']),
                _row('Father Name',     d['father_name']),
                _row('Designation',     d['designation']),
                _row('Date of Joining', d['date_of_joining']),
              ]),
              _section('Personal Data', [
                _row('Full Name',         d['full_name']),
                _row('Date of Birth',     d['date_of_birth']),
                _row('Postal Address',    d['postal_address']),
                _row('Permanent Address', d['permanent_address']),
              ]),
              _jsonSection('Family Details', d['family_details'],
                  ['name','age','gender','relation','occupation','aadhar']),
              _jsonSection('Education Qualification', d['education'],
                  ['qualification','university','year','marks','subject']),
              _jsonSection('Experience', d['experience'],
                  ['organisation','from','to','desig_joining','desig_relieving','job_resp','superior','salary','reason']),
              _section('Last Position Held', [
                _row('Last Reporting Person',        d['last_reporting_name']),
                _row('Last Reporting Designation',   d['last_reporting_designation']),
                _row('Last Company',                 d['last_company']),
                _row('Reference 1',                  d['reference1']),
                _row('Reference 2',                  d['reference2']),
              ]),
              _section('Additional Information', [
                _row('ESI Number',          d['esi_number']),
                _row('PF Number',           d['pf_number']),
                _row('Languages Known',     d['languages_known']),
                _row('Hobbies',             d['hobbies']),
                _row('Interests',           d['interests']),
                _row('Related to Employee', d['related_to_employee']),
                _row('Professional Membership', d['professional_membership']),
                _row('Specialized Training',    d['specialized_training']),
                _row('Other Information',       d['other_information']),
              ]),
              _section('Emergency Details', [
                _row('Blood Group',              d['blood_group']),
                _row('Allergic To',              d['allergic_to']),
                _row('Major Illness',            d['major_illness']),
                _row('Emergency Contact Name',   d['emergency_contact_name']),
                _row('Emergency Contact Number', d['emergency_contact_number']),
                _row('Emergency Contact Address',d['emergency_contact_address']),
                _row('Aadhar Number',            d['aadhar_number']),
              ]),
              _section('Declaration', [
                _row('Date',  d['declaration_date']),
                _row('Place', d['declaration_place']),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _section(String title, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
      const Divider(height: 12),
      ...rows,
      const SizedBox(height: 4),
    ],
  );

  Widget _row(String label, dynamic value) {
    final v = (value?.toString() ?? '').trim();
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 180, child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF546E7A)))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E)))),
      ]),
    );
  }

  Widget _jsonSection(String title, dynamic jsonData, List<String> keys) {
    List rows = [];
    if (jsonData is List) rows = jsonData;
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
        const Divider(height: 12),
        ...rows.asMap().entries.map((e) {
          final item = e.value as Map;
          final values = keys.map((k) => item[k]?.toString() ?? '').where((v) => v.isNotEmpty);
          if (values.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: keys.map((k) => _row(_keyLabel(k), item[k])).toList()),
          );
        }),
      ],
    );
  }

  String _keyLabel(String k) => k
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
