// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../services/user_store.dart';

Future<List<AppUser>> _loadAllUsers() async {
  try { return await UserStore.load(); } catch (_) { return []; }
}

String _autoEmail(String name) =>
    name.trim().toLowerCase().split(RegExp(r'\s+')).join('.');

String _nextEmpId(List<AppUser> users) {
  final nums = users
      .map((u) => u.employeeId)
      .where((id) => RegExp(r'^EMP\d+$').hasMatch(id))
      .map((id) => int.tryParse(id.substring(3)) ?? 0)
      .toList();
  final next = nums.isEmpty ? 1 : (nums.reduce((a, b) => a > b ? a : b) + 1);
  return 'EMP${next.toString().padLeft(3, '0')}';
}

// Status helpers
Color _statusColor(String s) {
  if (s == 'hr_approved')    return const Color(0xFF1565C0);
  if (s == 'hr_denied')      return const Color(0xFFC62828);
  if (s == 'mgmt_approved')  return const Color(0xFF2E7D32);
  if (s == 'mgmt_denied')    return const Color(0xFFB71C1C);
  if (s == 'access_granted') return const Color(0xFF6A1B9A);
  return const Color(0xFFE65100);
}
String _statusLabel(String s) {
  if (s == 'hr_approved')    return 'Awaiting Management';
  if (s == 'hr_denied')      return 'HR Denied';
  if (s == 'mgmt_approved')  return 'Mgmt Approved';
  if (s == 'mgmt_denied')    return 'Mgmt Denied';
  if (s == 'access_granted') return 'Active';
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
                OutlinedButton.icon(
                  onPressed: () => context.push('/edit-onboarding-form'),
                  icon: const Icon(Icons.edit_note_rounded, size: 15),
                  label: const Text('Edit Form', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6A1B9A),
                    side: const BorderSide(color: Color(0xFF6A1B9A)),
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
  Map<String, dynamic>? _linkedInterview;

  Future<void> _fetchLinkedInterview() async {
    if (_linkedInterview != null) return;
    final d    = widget.data;
    final name  = ((d['name'] as String?) ?? '').trim();
    final phone = ((d['phone_number'] as String?) ?? '').trim();
    if (name.isEmpty) return;
    try {
      final results = await Supabase.instance.client
          .from('candidate_applications')
          .select('name, post_applied, hr_status, manager_status, management_status')
          .or('name.ilike.%$name%${phone.isNotEmpty ? ",mobile.eq.$phone" : ""}')
          .limit(1);
      if (results.isNotEmpty && mounted) {
        setState(() => _linkedInterview = Map<String, dynamic>.from(results.first as Map));
      }
    } catch (_) {}
  }

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

  Future<void> _sendToManagement(BuildContext context) async {
    final allUsers = await _loadAllUsers();
    final managers = allUsers.where((u) => u.role == 'Manager').map((u) => u.name).toList();
    if (!context.mounted) return;

    final d = widget.data;
    final name = (d['name'] as String?) ?? '';
    final emailCtrl = TextEditingController(text: _autoEmail(name));
    final empIdCtrl  = TextEditingController(text: _nextEmpId(allUsers));
    String selectedManager = managers.isNotEmpty ? managers.first : '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Forward to Management', style: TextStyle(color: _blue, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: _blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'These details will be used to create the employee account once Management approves.',
                    style: const TextStyle(fontSize: 12, color: _blue),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.email_rounded, color: _blue, size: 20),
                  suffix: const Text('@fomrahousing.in',
                      style: TextStyle(color: _blue, fontWeight: FontWeight.w600, fontSize: 13)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: Colors.white,
                  labelStyle: const TextStyle(color: Color(0xFF78909C)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: empIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Employee ID',
                  prefixIcon: const Icon(Icons.badge_rounded, color: _blue, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: Colors.white,
                  labelStyle: const TextStyle(color: Color(0xFF78909C)),
                ),
              ),
              if (managers.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedManager.isNotEmpty ? selectedManager : null,
                  decoration: InputDecoration(
                    labelText: 'Reporting Manager',
                    prefixIcon: const Icon(Icons.manage_accounts_rounded, color: _blue, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true, fillColor: Colors.white,
                  ),
                  items: managers.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setS(() => selectedManager = v ?? ''),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text('No managers found. Add a Manager user first.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _acting = true);
                try {
                  await Supabase.instance.client
                      .from('onboarding_forms')
                      .update({
                        'status':           'hr_approved',
                        'assigned_email':   '${emailCtrl.text.trim()}@fomrahousing.in',
                        'assigned_emp_id':  empIdCtrl.text.trim(),
                        'assigned_manager': selectedManager,
                      })
                      .eq('id', widget.data['id'].toString());
                  widget.onRefresh();
                } catch (e) {
                  setState(() => _acting = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to forward: $e\n\nHave you run the SQL to add the status columns in Supabase?'),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 8),
                    ));
                  }
                }
              },
              child: const Text('Forward'),
            ),
          ],
        ),
      ),
    );
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
          onTap: () {
            setState(() => _expanded = !_expanded);
            if (_expanded) _fetchLinkedInterview();
          },
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
              // Linked interview record indicator
              if (_linkedInterview != null) ...[
                _LinkedInterviewBanner(data: _linkedInterview!),
                const SizedBox(height: 12),
              ],
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

              // HR: Approve/Deny on pending
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
                      label: const Text('Send to Management'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _acting ? null : () => _sendToManagement(context),
                    ),
                  ),
                ]),
              ],
              // Show assigned details once forwarded
              if (status == 'hr_approved') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Forwarded with details:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _blue)),
                    const SizedBox(height: 4),
                    Text('Email: ${d['assigned_email'] ?? '—'}', style: const TextStyle(fontSize: 11, color: _blue)),
                    Text('Emp ID: ${d['assigned_emp_id'] ?? '—'}', style: const TextStyle(fontSize: 11, color: _blue)),
                    Text('Manager: ${d['assigned_manager'] ?? '—'}', style: const TextStyle(fontSize: 11, color: _blue)),
                  ]),
                ),
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

// ── Linked interview banner ────────────────────────────────────────────────────
class _LinkedInterviewBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LinkedInterviewBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final post   = (data['post_applied'] ?? '').toString();
    final hrS    = (data['hr_status'] ?? 'pending').toString();
    final mgrS   = (data['manager_status'] ?? 'pending').toString();
    final mgmtS  = (data['management_status'] ?? 'pending').toString();

    bool _ok(String s) => s == 'accepted' || s == 'approved';
    final allDone = _ok(hrS) && _ok(mgrS) && _ok(mgmtS);

    Widget _chip(String label, String s) {
      final ok  = _ok(s);
      final rej = s == 'rejected';
      final c   = ok ? const Color(0xFF2E7D32) : rej ? const Color(0xFFC62828) : const Color(0xFFE65100);
      final bg  = ok ? const Color(0xFFE8F5E9) : rej ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text('$label: ${ok ? "✓" : rej ? "✗" : "…"}',
            style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: allDone ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: allDone ? const Color(0xFF2E7D32) : _blue,
          width: 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            allDone ? Icons.verified_rounded : Icons.assignment_rounded,
            size: 14,
            color: allDone ? const Color(0xFF2E7D32) : _blue,
          ),
          const SizedBox(width: 6),
          Text(
            allDone ? 'Interview Done — All Approvals Received' : 'Matched Interview Application',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: allDone ? const Color(0xFF2E7D32) : _blue,
            ),
          ),
        ]),
        if (post.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Applied for: $post',
              style: TextStyle(fontSize: 11, color: allDone ? const Color(0xFF388E3C) : const Color(0xFF546E7A))),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _chip('HR', hrS),
          _chip('Manager', mgrS),
          _chip('Management', mgmtS),
        ]),
      ]),
    );
  }
}
