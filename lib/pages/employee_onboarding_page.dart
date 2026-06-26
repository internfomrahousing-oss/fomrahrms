// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Status helpers
Color _statusColor(String s) {
  if (s == 'hr_approved') return const Color(0xFF2E7D32);
  if (s == 'hr_denied')   return const Color(0xFFC62828);
  if (s == 'access_granted') return const Color(0xFF6A1B9A);
  return const Color(0xFFE65100);
}
String _statusLabel(String s) {
  if (s == 'hr_approved')    return 'HR Approved';
  if (s == 'hr_denied')      return 'Denied';
  if (s == 'access_granted') return 'Access Granted';
  return 'Pending';
}

const _blue = Color(0xFF0D47A1);

class EmployeeOnboardingPage extends StatefulWidget {
  const EmployeeOnboardingPage({super.key});

  @override
  State<EmployeeOnboardingPage> createState() => _EmployeeOnboardingPageState();
}

class _EmployeeOnboardingPageState extends State<EmployeeOnboardingPage> {
  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('onboarding_forms')
          .select()
          .order('submitted_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(data);
      setState(() { _all = rows; _filtered = rows; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((r) => r.values.any(
              (v) => v.toString().toLowerCase().contains(q))).toList();
    });
  }

  void _openForm() {
    html.window.open(
      'https://fomrahrms-zeta.vercel.app/#/onboarding-form',
      '_blank',
    );
  }

  void _copyLink() {
    final link = 'https://fomrahrms-zeta.vercel.app/#/onboarding-form';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Link copied to clipboard'),
      duration: Duration(seconds: 2),
      backgroundColor: Color(0xFF2E7D32),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: const Color(0xFFF5F7FA),
      child: Column(children: [
        // ── Header ────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.how_to_reg_rounded, color: _blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Employee Onboarding',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _blue)),
                  Text('${_all.length} submission${_all.length == 1 ? '' : 's'} received',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF78909C))),
                ]),
              ),
              if (!narrow) ...[
                OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copy Link', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: const BorderSide(color: _blue),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: _openForm,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Joining Form', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _fetch,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
                    : const Icon(Icons.refresh_rounded, color: _blue),
              ),
            ]),

            if (_all.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search submissions…',
                  prefixIcon: const Icon(Icons.search_rounded, color: _blue, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: _searchCtrl.clear)
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ]),
        ),

        // ── Body ──────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : _filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _all.isEmpty ? 'No submissions yet' : 'No results found',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        ),
                        if (_all.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Click "Joining Form" to open the form and share it',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ]),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(pad),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _SubmissionCard(data: _filtered[i], onRefresh: _fetch),
                    ),
        ),
      ]),
    );
  }
}

// ── Submission card ────────────────────────────────────────────────────────────
class _SubmissionCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;
  const _SubmissionCard({required this.data, required this.onRefresh});

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _expanded = false;
  bool _acting = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _acting = true);
    try {
      await Supabase.instance.client
          .from('onboarding_forms')
          .update({'status': status})
          .eq('id', widget.data['id'].toString());
      widget.onRefresh();
    } catch (_) {
      setState(() => _acting = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Submission', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to permanently delete this submission?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _acting = true);
    try {
      await Supabase.instance.client
          .from('onboarding_forms')
          .delete()
          .eq('id', widget.data['id'].toString());
      widget.onRefresh();
    } catch (_) {
      setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = ((d['name'] as String?) ?? '').isNotEmpty
        ? d['name'] as String
        : (d['full_name'] as String?) ?? 'Unknown';
    final submittedAt = d['submitted_at'] != null
        ? DateTime.tryParse(d['submitted_at'] as String)?.toLocal()
        : null;
    final dateStr = submittedAt != null
        ? '${submittedAt.day.toString().padLeft(2,'0')}/${submittedAt.month.toString().padLeft(2,'0')}/${submittedAt.year}'
        : '—';
    final status = (d['status'] as String?) ?? 'pending';
    final isPending = status == 'pending';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE8EAF6))),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: _blue,
                child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A237E))),
                  const SizedBox(height: 2),
                  Text('${(d['designation'] as String?) ?? ''}  ·  $dateStr',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                ]),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              // Delete button
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                visualDensity: VisualDensity.compact,
                onPressed: _acting ? null : () => _delete(context),
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
                _row('Last Reporting Person',      d['last_reporting_name']),
                _row('Last Reporting Designation', d['last_reporting_designation']),
                _row('Last Company',               d['last_company']),
                _row('Reference 1',                d['reference1']),
                _row('Reference 2',                d['reference2']),
              ]),
              _section('Additional Information', [
                _row('ESI Number',              d['esi_number']),
                _row('PF Number',               d['pf_number']),
                _row('Languages Known',         d['languages_known']),
                _row('Hobbies',                 d['hobbies']),
                _row('Interests',               d['interests']),
                _row('Related to Employee',     d['related_to_employee']),
                _row('Professional Membership', d['professional_membership']),
                _row('Specialized Training',    d['specialized_training']),
                _row('Other Information',       d['other_information']),
              ]),
              _section('Emergency Details', [
                _row('Blood Group',               d['blood_group']),
                _row('Allergic To',               d['allergic_to']),
                _row('Major Illness',             d['major_illness']),
                _row('Emergency Contact Name',    d['emergency_contact_name']),
                _row('Emergency Contact Number',  d['emergency_contact_number']),
                _row('Emergency Contact Address', d['emergency_contact_address']),
                _row('Aadhar Number',             d['aadhar_number']),
              ]),
              _section('Declaration', [
                _row('Date',  d['declaration_date']),
                _row('Place', d['declaration_place']),
              ]),
              _attachmentsSection(d['attachments']),

              // Approve / Deny buttons (only if pending)
              if (isPending) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Deny'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _acting ? null : () => _updateStatus('hr_denied'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _acting ? null : () => _updateStatus('hr_approved'),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    final visible = rows.whereType<Padding>().toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
      const Divider(height: 10),
      ...rows,
    ]);
  }

  Widget _row(String label, dynamic value) {
    final v = (value?.toString() ?? '').trim();
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 190,
            child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF546E7A)))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E)))),
      ]),
    );
  }

  Widget _jsonSection(String title, dynamic jsonData, List<String> keys) {
    final rows = jsonData is List ? jsonData : [];
    final nonEmpty = rows.where((item) =>
        item is Map && keys.any((k) => (item[k]?.toString() ?? '').isNotEmpty)).toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
      const Divider(height: 10),
      ...nonEmpty.asMap().entries.map((e) {
        final item = e.value as Map;
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
    ]);
  }

  Widget _attachmentsSection(dynamic data) {
    final items = data is List ? data : [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      const Text('Attachments', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
      const Divider(height: 10),
      ...items.map((item) {
        final name = item['name']?.toString() ?? '';
        final type = item['doc_type']?.toString() ?? '';
        final url  = item['url']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            const Icon(Icons.insert_drive_file_rounded, size: 14, color: _blue),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type, style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A))),
              Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E))),
            ])),
            if (url.isNotEmpty)
              TextButton(
                onPressed: () => html.window.open(url, '_blank'),
                child: const Text('View', style: TextStyle(fontSize: 12)),
              ),
          ]),
        );
      }),
    ]);
  }

  String _keyLabel(String k) => k
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
