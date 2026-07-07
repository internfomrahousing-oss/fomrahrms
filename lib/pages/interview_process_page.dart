// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../models/candidate_store.dart';
import '../models/form_config.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

Color get _blue => AppTheme.primaryBlue;

class InterviewProcessPage extends StatefulWidget {
  const InterviewProcessPage({super.key});

  @override
  State<InterviewProcessPage> createState() => _InterviewProcessPageState();
}

class _InterviewProcessPageState extends State<InterviewProcessPage> {
  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  String? _error;
  // 'pending' | 'done' | 'all'
  String _filter = 'pending';
  final _searchCtrl = TextEditingController();
  String _activeFormLink = FormConfig.baseLink;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _fetch();
    _loadActiveFormLink();
  }

  Future<void> _loadActiveFormLink() async {
    try {
      final active = await SupabaseService.fetchActiveFormVersion();
      if (active != null && mounted) {
        final vNum = (active['version_number'] as int?) ?? 1;
        setState(() => _activeFormLink = FormConfig.versionedLink(vNum));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await SupabaseService.fetchCandidateApplications();
      // HR only sees records they haven't soft-deleted
      final visible = rows.where((r) => r['hr_deleted'] != true).toList();
      setState(() {
        _all      = visible;
        _filtered = visible;
        _loading  = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<Map<String, dynamic>> base;
    switch (_filter) {
      case 'pending':
        base = _all.where((r) => _compositeStatus(r) != 'approved').toList();
        break;
      case 'done':
        // approved but NOT yet marked pre-offer sent
        base = _all.where((r) =>
            _compositeStatus(r) == 'approved' && r['pre_offer_sent'] != true).toList();
        break;
      case 'pre_offer':
        base = _all.where((r) => r['pre_offer_sent'] == true).toList();
        break;
      default:
        base = _all;
    }
    setState(() {
      _filtered = q.isEmpty
          ? base
          : base.where((r) => r.values.any(
              (v) => v.toString().toLowerCase().contains(q))).toList();
    });
  }

  int get _pendingCount   => _all.where((r) => _compositeStatus(r) != 'approved').length;
  int get _doneCount      => _all.where((r) => _compositeStatus(r) == 'approved' && r['pre_offer_sent'] != true).length;
  int get _preOfferCount  => _all.where((r) => r['pre_offer_sent'] == true).length;

  String _cell(Map<String, dynamic> row, String key) {
    final v = row[key];
    if (v == null) return '';
    if (key == 'submitted_at') {
      try {
        final dt = DateTime.parse(v.toString()).toLocal();
        return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } catch (_) { return v.toString(); }
    }
    return v.toString();
  }

  String _compositeStatus(Map<String, dynamic> row) {
    final mgmt    = (row['management_status'] as String?) ?? 'pending';
    final manager = (row['manager_status']    as String?) ?? 'pending';
    final hr      = (row['hr_status']         as String?) ?? 'pending';
    if (mgmt    == 'accepted') return 'approved';
    if (mgmt    == 'rejected') return 'rejected_mgmt';
    if (manager == 'rejected') return 'rejected_manager';
    if (hr      == 'rejected') return 'rejected_hr';
    if (manager == 'accepted') return 'with_management';
    if (hr      == 'accepted') return 'with_manager';
    return 'pending';
  }

  Widget _statusBadge(String status) {
    late Color bg;
    late Color fg;
    late String label;
    late IconData icon;
    switch (status) {
      case 'approved':
        bg = const Color(0xFFDCFCE7); fg = const Color(0xFF22C55E);
        label = 'Approved'; icon = Icons.check_circle_rounded; break;
      case 'rejected_mgmt':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFEF4444);
        label = 'Rejected by Management'; icon = Icons.cancel_rounded; break;
      case 'rejected_manager':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFEF4444);
        label = 'Rejected by Manager'; icon = Icons.cancel_rounded; break;
      case 'rejected_hr':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFEF4444);
        label = 'Rejected'; icon = Icons.cancel_rounded; break;
      case 'with_management':
        bg = const Color(0xFFEFF6FF); fg = const Color(0xFF2563EB);
        label = 'With Management'; icon = Icons.business_rounded; break;
      case 'with_manager':
        bg = const Color(0xFFEFF6FF); fg = _blue;
        label = 'With Manager'; icon = Icons.person_rounded; break;
      default:
        bg = const Color(0xFFFEF3C7); fg = const Color(0xFFF59E0B);
        label = 'Pending Review'; icon = Icons.hourglass_empty_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _showAcceptDialog(Map<String, dynamic> row) async {
    final managers = await _loadManagers();
    if (!mounted) return;
    String? selected = managers.isNotEmpty ? managers.first : null;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Assign to Manager',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose which manager should review this candidate:',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selected,
              decoration: InputDecoration(
                labelText: 'Manager',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: managers.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setS(() => selected = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: selected == null ? null : () async {
                Navigator.pop(ctx);
                await _doAccept(row, selected!);
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _loadManagers() async {
    final users = await UserStore.load();
    final names = users
        .where((u) => u.role == 'Manager' && u.active)
        .map((u) => u.name)
        .toList();
    if (!names.contains('Manager')) names.insert(0, 'Manager');
    return names;
  }

  Future<void> _doAccept(Map<String, dynamic> row, String managerName) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await SupabaseService.updateCandidateStatus(id, {
        'hr_status':        'accepted',
        'assigned_manager': managerName,
      });
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showRejectDialog(Map<String, dynamic> row) async {
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add a comment (optional):',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          TextField(
            controller: commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Reason for rejection…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _doReject(row, commentCtrl.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _doReject(Map<String, dynamic> row, String comment) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await SupabaseService.updateCandidateStatus(id, {
        'hr_status':  'rejected',
        'hr_comment': comment,
      });
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showCommentDialog(Map<String, dynamic> row) async {
    final commentCtrl = TextEditingController(
        text: (row['hr_comment'] as String?) ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('HR Comment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        content: TextField(
          controller: commentCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Add or update your comment…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final id = row['id']?.toString() ?? '';
              if (id.isEmpty) return;
              try {
                await SupabaseService.updateCandidateStatus(id,
                    {'hr_comment': commentCtrl.text.trim()});
                await _fetch();
              } catch (_) {}
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteForHr(BuildContext ctx, Map<String, dynamic> row) async {
    final name = (row['name'] ?? '').toString().trim();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Text('Remove from your view',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'This will hide "$name" from your Interview Process dashboard.\n\nManagement will still be able to see this application.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await SupabaseService.updateCandidateStatus(id, {'hr_deleted': true});
      _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSendEmailDialog(BuildContext context, Map<String, dynamic> row) {
    final name  = (row['name']  ?? '').toString().trim();
    final email = (row['email'] ?? '').toString().trim();

    const positions = [
      'HR', 'ADMIN', 'OPERATION', 'CRM', 'PROJECTS',
      'LAND ACQUISITION', 'ACCOUNTS', 'SALES', 'DIGITAL MARKETING',
    ];

    const formLink = 'https://fomrahrms-zeta.vercel.app/#/onboarding-form';

    String? selectedPosition = (row['post_applied'] ?? '').toString().trim();
    if (!positions.contains(selectedPosition)) selectedPosition = null;

    DateTime joiningDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay joiningTime = const TimeOfDay(hour: 9, minute: 30);

    final titleCtrl  = TextEditingController(text: 'Manager');
    final letterCtrl = TextEditingController();

    String _fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    String _fmtTime(TimeOfDay t) {
      final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      final m = t.minute.toString().padLeft(2, '0');
      final period = t.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $period';
    }

    void _refreshLetter(setDlgState) {
      final title = titleCtrl.text.trim();
      final pos   = selectedPosition ?? 'the applied role';
      final designation = title.isNotEmpty ? '$title- $pos' : pos;
      final body = '''Dear $name,
Congratulations!
We are pleased to offer you the position of $designation at Fomra Housing & Infrastructure Pvt Ltd, based on the terms and conditions mutually discussed and agreed upon. You are requested to join us on ${_fmtDate(joiningDate)} at ${_fmtTime(joiningTime)} at our corporate office.

Corporate Office Address:
Fomra Housing & Infrastructure Pvt Ltd,
Old No. F76, Chintamani, 1st Floor,
Agathiyar Nagar Extension, 2nd Street,
Anna Nagar East,
Chennai, Tamil Nadu – 600102

If you are unable to report on the specified date, kindly inform us in advance by email.
Please note that this pre-employment offer is subject to successful verification of the information and documents provided by you. You are required to submit Xerox copies of the following documents at the time of joining:

Required Documents
1. Proof of Academic Qualifications:
   o  10th & 12th Mark Sheets
   o  UG & PG Mark Sheets and Degree Certificates
2. Experience Certificates & Relieving Letters (if applicable)
3. Last 3 Months' Salary Slips from previous employment(s) (if applicable)
4. Bank Account Details
5. Proof of Identity (Aadhar Card, PAN Card)
6. Passport Size Photographs – 2 copies

Kindly complete your onboarding form at the link below before joining:
$formLink

This offer is valid for 3 days from the date of this email. Please confirm your acceptance within 2 days of receiving this communication. If we do not receive your confirmation within the stipulated time, the offer will be considered withdrawn and the position may be offered to another candidate.

This offer is subject to the standard terms and conditions of employment at Fomra Housing & Infrastructure Pvt Ltd. Your employment will be governed by the company's policies, rules, and guidelines.

We look forward to welcoming you to our team and hope for a long, productive, and mutually rewarding association.

Warm regards,
HR Team
Fomra Housing & Infrastructure Pvt Ltd''';
      setDlgState(() => letterCtrl.text = body);
    }

    // Init letter text once
    WidgetsBinding.instance.addPostFrameCallback((_) {});

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          // Initialise on first build
          if (letterCtrl.text.isEmpty) _refreshLetter(setDlgState);

          final subject   = Uri.encodeComponent('Offer Letter – Fomra Housing & Infrastructure Pvt Ltd');
          final mailtoUrl = 'mailto:$email?subject=$subject&body=${Uri.encodeComponent(letterCtrl.text)}';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.mail_outline_rounded, color: AppTheme.accentBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Send Offer Letter',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _blue)),
            ]),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _EmailField(label: 'To', value: email.isNotEmpty ? email : '(email not on file)'),
                  const SizedBox(height: 8),
                  _EmailField(label: 'Subject', value: 'Offer Letter – Fomra Housing & Infrastructure Pvt Ltd'),
                  const SizedBox(height: 14),

                  // ── Row 1: Title field + Position dropdown ──────────────
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Title / designation prefix
                    Expanded(
                      flex: 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Title / Designation',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                        const SizedBox(height: 4),
                        TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Manager, Executive',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (_) => _refreshLetter(setDlgState),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    // Position dropdown
                    Expanded(
                      flex: 3,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Position',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: selectedPosition,
                          hint: const Text('Select position', style: TextStyle(fontSize: 13)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          items: positions.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p, style: const TextStyle(fontSize: 13)),
                          )).toList(),
                          onChanged: (v) {
                            setDlgState(() => selectedPosition = v);
                            _refreshLetter(setDlgState);
                          },
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Row 2: Joining Date + Joining Time ─────────────────
                  Row(children: [
                    // Date picker
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Joining Date',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: joiningDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              joiningDate = picked;
                              _refreshLetter(setDlgState);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.accentBlue),
                              const SizedBox(width: 8),
                              Text(_fmtDate(joiningDate),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    // Time picker
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Joining Time',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: joiningTime,
                            );
                            if (picked != null) {
                              joiningTime = picked;
                              _refreshLetter(setDlgState);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              Icon(Icons.access_time_rounded, size: 14, color: AppTheme.accentBlue),
                              const SizedBox(width: 8),
                              Text(_fmtTime(joiningTime),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // ── Edit Letter ────────────────────────────────────────
                  Row(children: [
                    const Text('Edit Letter',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _refreshLetter(setDlgState),
                      icon: const Icon(Icons.refresh_rounded, size: 13),
                      label: const Text('Reset to template', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  TextField(
                    controller: letterCtrl,
                    maxLines: 18,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.6),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      fillColor: Theme.of(context).colorScheme.surface,
                      filled: true,
                    ),
                  ),

                  if (email.isEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                        SizedBox(width: 6),
                        Expanded(child: Text(
                            'No email address on file for this candidate.',
                            style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B)))),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  titleCtrl.dispose();
                  letterCtrl.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('Send Offer Letter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: email.isEmpty ? null : () async {
                  Navigator.pop(ctx);
                  html.window.open(mailtoUrl, '_self');
                  final id = (row['id'] ?? '').toString();
                  if (id.isNotEmpty) {
                    try {
                      await SupabaseService.updateCandidateStatus(id, {
                        'pre_offer_sent': true,
                        'pre_offer_sent_at': DateTime.now().toUtc().toIso8601String(),
                      });
                    } catch (_) {}
                    _fetch();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const NavBackButton(),
                  const SizedBox(width: 8),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.record_voice_over_rounded,
                        color: _blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Interview Process',
                            style: TextStyle(fontSize: 22,
                                fontWeight: FontWeight.bold, color: _blue)),
                        Text(
                          '${_all.length} application${_all.length == 1 ? '' : 's'} received',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      html.window.navigator.clipboard
                          ?.writeText(_activeFormLink);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Form link copied to clipboard'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFF22C55E),
                      ));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('Copy Link',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: BorderSide(color: _blue),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () =>
                        html.window.open(_activeFormLink, '_blank'),
                    icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                    label: const Text('Application Form',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      final base = GoRouterState.of(context).uri.path
                              .startsWith('/management/')
                          ? '/management'
                          : '';
                      context.push('$base/edit-form');
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Edit Form',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _fetch,
                    icon: _loading
                        ? SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _blue))
                        : Icon(Icons.refresh_rounded, color: _blue),
                  ),
                ]),

                if (_all.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Filter chips
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    FilterChip(
                      avatar: const Icon(Icons.hourglass_empty_rounded, size: 13, color: Color(0xFFF59E0B)),
                      label: Text('Interview Pending ($_pendingCount)'),
                      selected: _filter == 'pending',
                      onSelected: (_) => setState(() { _filter = 'pending'; _applyFilter(); }),
                      selectedColor: const Color(0xFFFEF3C7),
                      checkmarkColor: const Color(0xFFF59E0B),
                      labelStyle: TextStyle(
                          color: _filter == 'pending' ? const Color(0xFFF59E0B) : Colors.grey.shade600,
                          fontWeight: _filter == 'pending' ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12),
                      side: BorderSide(color: _filter == 'pending' ? const Color(0xFFF59E0B) : Colors.grey.shade300),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF22C55E)),
                      label: Text('Interview Done ($_doneCount)'),
                      selected: _filter == 'done',
                      onSelected: (_) => setState(() { _filter = 'done'; _applyFilter(); }),
                      selectedColor: const Color(0xFFDCFCE7),
                      checkmarkColor: const Color(0xFF22C55E),
                      labelStyle: TextStyle(
                          color: _filter == 'done' ? const Color(0xFF22C55E) : Colors.grey.shade600,
                          fontWeight: _filter == 'done' ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12),
                      side: BorderSide(color: _filter == 'done' ? const Color(0xFF22C55E) : Colors.grey.shade300),
                    ),
                    FilterChip(
                      avatar: Icon(Icons.mark_email_read_rounded, size: 13, color: AppTheme.primaryBlue),
                      label: Text('Pre Offer & Onboarding Sent ($_preOfferCount)'),
                      selected: _filter == 'pre_offer',
                      onSelected: (_) => setState(() { _filter = 'pre_offer'; _applyFilter(); }),
                      selectedColor: const Color(0xFFEDE7F6),
                      checkmarkColor: AppTheme.primaryBlue,
                      labelStyle: TextStyle(
                          color: _filter == 'pre_offer' ? AppTheme.primaryBlue : Colors.grey.shade600,
                          fontWeight: _filter == 'pre_offer' ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12),
                      side: BorderSide(color: _filter == 'pre_offer' ? AppTheme.primaryBlue : Colors.grey.shade300),
                    ),
                    FilterChip(
                      label: Text('All Applications (${_all.length})'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() { _filter = 'all'; _applyFilter(); }),
                      selectedColor: _blue.withValues(alpha: 0.12),
                      checkmarkColor: _blue,
                      labelStyle: TextStyle(
                          color: _filter == 'all' ? _blue : Colors.grey.shade600,
                          fontWeight: _filter == 'all' ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12),
                      side: BorderSide(color: _filter == 'all' ? _blue : Colors.grey.shade300),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search applications…',
                      prefixIcon: Icon(Icons.search_rounded,
                          color: _blue, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: _searchCtrl.clear,
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: _blue))
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _fetch)
                    : _filtered.isEmpty
                        ? const _EmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, idx) {
                              final row = _filtered[idx];
                              return _ApplicationCard(
                                row: row,
                                dateStr: _cell(row, 'submitted_at'),
                                status: _compositeStatus(row),
                                statusBadge: _statusBadge(_compositeStatus(row)),
                                onAccept: () => _showAcceptDialog(row),
                                onReject: () => _showRejectDialog(row),
                                onComment: () => _showCommentDialog(row),
                                onSendEmail: () => _showSendEmailDialog(context, row),
                                onDelete: () => _deleteForHr(context, row),
                                onView: () {
                                  CandidateStore.selected = row;
                                  context.push('/candidate-detail');
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Application Card ──────────────────────────────────────────────────────────

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final String dateStr;
  final String status;
  final Widget statusBadge;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComment;
  final VoidCallback onView;
  final VoidCallback? onSendEmail;
  final VoidCallback? onDelete;

  const _ApplicationCard({
    required this.row,
    required this.dateStr,
    required this.status,
    required this.statusBadge,
    required this.onAccept,
    required this.onReject,
    required this.onComment,
    required this.onView,
    this.onSendEmail,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name          = (row['name']          ?? '').toString().trim();
    final post          = (row['post_applied']   ?? '').toString().trim();
    final exp           = (row['total_experience']?? '').toString().trim();
    final manager       = (row['assigned_manager']?? '').toString().trim();
    final hrComment     = (row['hr_comment']      ?? '').toString().trim();
    final managerComment= (row['manager_comment'] ?? '').toString().trim();
    final mgmtComment   = (row['management_comment']?? '').toString().trim();
    final managerStatus = (row['manager_status']  ?? 'pending').toString();
    final mgmtStatus    = (row['management_status']?? 'pending').toString();

    final isPending      = status == 'pending';
    final isApproved     = status == 'approved';
    final preOfferSent   = row['pre_offer_sent'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isApproved
              ? const Color(0xFF86EFAC)
              : status.startsWith('rejected')
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE5E7EB),
          width: isApproved || status.startsWith('rejected') ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: avatar, name, status ─────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: _blue, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Unknown' : name,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: _blue)),
                  const SizedBox(height: 3),
                  Text('Submitted: $dateStr',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
                  if (post.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      post + (exp.isNotEmpty ? '  •  $exp yrs exp.' : ''),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ],
                ],
              )),
              const SizedBox(width: 8),
              statusBadge,
            ]),

            // ── Extra info: manager assignment / approval message ──────
            if (manager.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text('Assigned to: $manager',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(width: 16),
                if (managerStatus != 'pending') ...[
                  Icon(
                    managerStatus == 'accepted'
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                    size: 14,
                    color: managerStatus == 'accepted'
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Manager: ${managerStatus == 'accepted' ? 'Accepted' : 'Rejected'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: managerStatus == 'accepted'
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ]),
            ],

            if (isApproved) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.verified_rounded,
                      size: 15, color: Color(0xFF22C55E)),
                  SizedBox(width: 6),
                  Text('Approved by Management and Manager',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
              if (preOfferSent) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.mark_email_read_rounded,
                        size: 15, color: AppTheme.primaryBlue),
                    SizedBox(width: 6),
                    Text('Pre Offer & Onboarding Sent',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ],

            if (mgmtStatus == 'rejected') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.cancel_rounded, size: 15, color: Color(0xFFEF4444)),
                  SizedBox(width: 6),
                  Text('Rejected by Management',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],

            // ── Comments ───────────────────────────────────────────────
            if (hrComment.isNotEmpty || managerComment.isNotEmpty || mgmtComment.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 6),
              if (hrComment.isNotEmpty)
                _CommentChip(label: 'HR', comment: hrComment),
              if (managerComment.isNotEmpty)
                _CommentChip(label: 'Manager', comment: managerComment),
              if (mgmtComment.isNotEmpty)
                _CommentChip(label: 'Management', comment: mgmtComment),
            ],

            // ── Action buttons ─────────────────────────────────────────
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (isPending) ...[
                _ActionButton(
                  label: 'Accept',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF22C55E),
                  onTap: onAccept,
                ),
                _ActionButton(
                  label: 'Reject',
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFEF4444),
                  onTap: onReject,
                ),
              ],
              _ActionButton(
                label: 'Comment',
                icon: Icons.comment_outlined,
                color: const Color(0xFF6B7280),
                onTap: onComment,
              ),
              _ActionButton(
                label: 'View',
                icon: Icons.open_in_new_rounded,
                color: _blue,
                onTap: onView,
              ),
              if (isApproved && onSendEmail != null)
                _ActionButton(
                  label: 'Send Email',
                  icon: Icons.mail_outline_rounded,
                  color: AppTheme.accentBlue,
                  onTap: onSendEmail!,
                  highlight: true,
                ),
              if (onDelete != null)
                _ActionButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red.shade700,
                  onTap: onDelete!,
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _CommentChip extends StatelessWidget {
  final String label;
  final String comment;
  const _CommentChip({required this.label, required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(comment,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool highlight;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: highlight ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: highlight ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: highlight ? Colors.white : color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: highlight ? Colors.white : color,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Email field helper ────────────────────────────────────────────────────────
class _EmailField extends StatelessWidget {
  final String label;
  final String value;
  const _EmailField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 60,
        child: Text('$label:',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
      ),
      Expanded(
        child: Text(value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
      ),
    ]);
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 52, color: Color(0xFFDBEAFE)),
        SizedBox(height: 12),
        Text('No applications yet',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _blue)),
        SizedBox(height: 6),
        Text('Submitted forms will appear here instantly.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 52, color: Color(0xFFDBEAFE)),
        const SizedBox(height: 12),
        Text('Could not load applications',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _blue)),
        const SizedBox(height: 6),
        Text(error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue, foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}
