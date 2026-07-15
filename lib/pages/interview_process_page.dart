import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/user_store.dart';
import '../services/email_service.dart';
import '../services/pre_offer_pdf_service.dart';
import '../models/candidate_store.dart';
import '../models/form_config.dart';
import '../constants/org_lists.dart';
import '../utils/token_util.dart';
import '../widgets/filter_panel.dart';
import '../widgets/responsive_header_row.dart';
import '../theme/app_theme.dart';

Color get _blue => AppTheme.primaryBlue;

class InterviewProcessPage extends StatefulWidget {
  const InterviewProcessPage({super.key});

  @override
  State<InterviewProcessPage> createState() => _InterviewProcessPageState();
}

enum _SortOrder { latest, oldest, nameAz, expHighLow }

class _InterviewProcessPageState extends State<InterviewProcessPage> {
  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  String? _error;
  // 'pending' | 'done' | 'all'
  String _filter = 'pending';
  final _searchCtrl = TextEditingController();
  String _activeFormLink = FormConfig.baseLink;

  String _deptFilter     = 'All';
  String _expFilter      = 'All';
  String _assignedFilter = 'All';
  _SortOrder _sort       = _SortOrder.latest;

  static const _expBuckets = ['All', '0–2 yrs', '3–5 yrs', '6+ yrs'];
  static const _unassignedLabel = 'Unassigned';

  List<String> get _departmentOptions {
    final s = _all
        .map((r) => (r['post_applied'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...s];
  }

  List<String> get _assignedOptions {
    final s = _all
        .map((r) => (r['assigned_manager'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...s, _unassignedLabel];
  }

  bool _matchesExpBucket(Map<String, dynamic> row, String bucket) {
    if (bucket == 'All') return true;
    final exp = double.tryParse(
            (row['total_experience'] ?? '').toString().replaceAll(RegExp('[^0-9.]'), '')) ??
        0;
    switch (bucket) {
      case '0–2 yrs': return exp <= 2;
      case '3–5 yrs': return exp > 2 && exp <= 5;
      case '6+ yrs':  return exp > 5;
      default: return true;
    }
  }

  RealtimeChannel? _candidateChannel;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _fetch();
    _loadActiveFormLink();
    _subscribeToCandidateChanges();
  }

  // Reflects offer-acceptance (and any other change) in the HR portal live,
  // without requiring a manual refresh — see /pre-offer/{token} accept page.
  void _subscribeToCandidateChanges() {
    _candidateChannel = Supabase.instance.client
        .channel('candidate_applications_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'candidate_applications',
          callback: (_) => _fetch(),
        )
        .subscribe();
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
    if (_candidateChannel != null) Supabase.instance.client.removeChannel(_candidateChannel!);
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
        base = _all.where((r) => !_isRejected(r) && _compositeStatus(r) != 'approved').toList();
        break;
      case 'done':
        // approved but NOT yet marked pre-offer sent
        base = _all.where((r) =>
            _compositeStatus(r) == 'approved' && r['pre_offer_sent'] != true).toList();
        break;
      case 'pre_offer':
        base = _all.where((r) => r['pre_offer_sent'] == true).toList();
        break;
      case 'rejected':
        base = _all.where(_isRejected).toList();
        break;
      default:
        base = _all;
    }

    if (_deptFilter != 'All') {
      base = base.where((r) => (r['post_applied'] ?? '').toString().trim() == _deptFilter).toList();
    }
    if (_expFilter != 'All') {
      base = base.where((r) => _matchesExpBucket(r, _expFilter)).toList();
    }
    if (_assignedFilter != 'All') {
      base = base.where((r) {
        final m = (r['assigned_manager'] ?? '').toString().trim();
        return _assignedFilter == _unassignedLabel ? m.isEmpty : m == _assignedFilter;
      }).toList();
    }
    if (q.isNotEmpty) {
      base = base.where((r) => r.values.any(
          (v) => v.toString().toLowerCase().contains(q))).toList();
    }

    base = List.of(base);
    switch (_sort) {
      case _SortOrder.latest:
        base.sort((a, b) => (b['submitted_at'] ?? '').toString().compareTo((a['submitted_at'] ?? '').toString()));
        break;
      case _SortOrder.oldest:
        base.sort((a, b) => (a['submitted_at'] ?? '').toString().compareTo((b['submitted_at'] ?? '').toString()));
        break;
      case _SortOrder.nameAz:
        base.sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));
        break;
      case _SortOrder.expHighLow:
        double exp(Map<String, dynamic> r) => double.tryParse(
                (r['total_experience'] ?? '').toString().replaceAll(RegExp('[^0-9.]'), '')) ??
            0;
        base.sort((a, b) => exp(b).compareTo(exp(a)));
        break;
    }

    setState(() => _filtered = base);
  }

  bool _isRejected(Map<String, dynamic> r) => _compositeStatus(r).startsWith('rejected');

  int get _pendingCount   => _all.where((r) => !_isRejected(r) && _compositeStatus(r) != 'approved').length;
  int get _doneCount      => _all.where((r) => _compositeStatus(r) == 'approved' && r['pre_offer_sent'] != true).length;
  int get _preOfferCount  => _all.where((r) => r['pre_offer_sent'] == true).length;
  int get _rejectedCount  => _all.where(_isRejected).length;

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

  ({Color bg, Color fg, String label, IconData icon}) _statusMeta(String status, {bool preOfferSent = false}) {
    if (status == 'approved' && preOfferSent) {
      return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF22C55E),
          label: 'Pre Offer & Onboarding Sent', icon: Icons.mark_email_read_rounded);
    }
    switch (status) {
      case 'approved':
        return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF22C55E),
            label: 'Approved', icon: Icons.check_circle_rounded);
      case 'rejected_mgmt':
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFEF4444),
            label: 'Rejected by Management', icon: Icons.cancel_rounded);
      case 'rejected_manager':
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFEF4444),
            label: 'Rejected by Manager', icon: Icons.cancel_rounded);
      case 'rejected_hr':
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFEF4444),
            label: 'Rejected', icon: Icons.cancel_rounded);
      case 'with_management':
        return (bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB),
            label: 'With Management', icon: Icons.business_rounded);
      case 'with_manager':
        return (bg: const Color(0xFFEFF6FF), fg: _blue,
            label: 'With Manager', icon: Icons.person_rounded);
      default:
        return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFF59E0B),
            label: 'Pending Review', icon: Icons.hourglass_empty_rounded);
    }
  }

  Widget _statusBadge(String status, {bool preOfferSent = false}) {
    final m = _statusMeta(status, preOfferSent: preOfferSent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: m.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(m.icon, size: 12, color: m.fg),
        const SizedBox(width: 4),
        Text(m.label, style: TextStyle(fontSize: 11, color: m.fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  static const _monthAbbr = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  String _shortDate(dynamic v) {
    if (v == null) return '';
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')} ${_monthAbbr[dt.month - 1]}';
    } catch (_) { return ''; }
  }

  List<_StageInfo> _buildStages(Map<String, dynamic> row) {
    final hrStatus      = (row['hr_status'] ?? 'pending').toString();
    final managerStatus = (row['manager_status'] ?? 'pending').toString();
    final mgmtStatus    = (row['management_status'] ?? 'pending').toString();
    final preOfferSent  = row['pre_offer_sent'] == true;
    final preOfferAccepted = row['pre_offer_accepted'] == true;
    final onboardingLinkSent = row['onboarding_link_sent'] == true;

    _StageState of(String status, bool reached) {
      if (status == 'accepted') return _StageState.completed;
      if (status == 'rejected') return _StageState.rejected;
      return reached ? _StageState.current : _StageState.pending;
    }

    final hrState = of(hrStatus, true);
    final managerReached = hrStatus == 'accepted';
    final managerState = of(managerStatus, managerReached);
    final mgmtReached = managerStatus == 'accepted';
    final mgmtState = of(mgmtStatus, mgmtReached);
    final approved = mgmtStatus == 'accepted';
    final offerState = !approved
        ? _StageState.pending
        : (preOfferSent ? _StageState.completed : _StageState.current);
    final acceptState = !preOfferSent
        ? _StageState.pending
        : (preOfferAccepted ? _StageState.completed : _StageState.current);
    final onboardingState = !preOfferAccepted
        ? _StageState.pending
        : (onboardingLinkSent ? _StageState.completed : _StageState.current);
    final onboardingCompleted = row['onboarding_completed'] == true;
    final onboardingCompletedState = !onboardingLinkSent
        ? _StageState.pending
        : (onboardingCompleted ? _StageState.completed : _StageState.current);

    return [
      _StageInfo('Applied', _shortDate(row['submitted_at']), _StageState.completed),
      _StageInfo('HR Review', _shortDate(row['hr_status_at']), hrState),
      _StageInfo('Manager', _shortDate(row['manager_status_at']), managerState),
      _StageInfo('Management', _shortDate(row['management_status_at']), mgmtState),
      _StageInfo('Offer Sent', _shortDate(row['pre_offer_sent_at']), offerState),
      _StageInfo('Offer Accepted', _shortDate(row['pre_offer_accepted_at']), acceptState),
      _StageInfo('Onboarding Sent', _shortDate(row['onboarding_link_sent_at']), onboardingState),
      _StageInfo('Onboarding Done', _shortDate(row['onboarding_completed_at']), onboardingCompletedState),
    ];
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
        'hr_status_at':     DateTime.now().toUtc().toIso8601String(),
        'assigned_manager': managerName,
      });
      NotificationService.candidateAssignedToManager(
        candidateName: (row['name'] ?? '').toString(),
        managerName: managerName,
      );
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
        'hr_status':    'rejected',
        'hr_status_at': DateTime.now().toUtc().toIso8601String(),
        'hr_comment':   comment,
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

    const positions = kDepartments;

    const formLink = 'https://fomrahrms-zeta.vercel.app/#/onboarding-form';

    final appliedRaw = (row['post_applied'] ?? '').toString().trim();
    String? selectedPosition = positions.firstWhere(
      (d) => d.toLowerCase() == appliedRaw.toLowerCase(),
      orElse: () => '',
    );
    if (selectedPosition.isEmpty) selectedPosition = null;

    String? selectedDesignation = 'Manager';

    DateTime joiningDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay joiningTime = const TimeOfDay(hour: 9, minute: 30);

    final letterCtrl = TextEditingController();
    bool sending = false;

    String _fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    String _fmtTime(TimeOfDay t) {
      final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      final m = t.minute.toString().padLeft(2, '0');
      final period = t.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $period';
    }

    void _refreshLetter(setDlgState) {
      final title = selectedDesignation ?? '';
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

          const subject = 'Offer Letter – Fomra Housing & Infrastructure Pvt Ltd';

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
              Text('Send Pre-Offer Letter',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _blue)),
            ]),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _EmailField(label: 'To', value: email.isNotEmpty ? email : '(email not on file)'),
                  const SizedBox(height: 8),
                  _EmailField(label: 'Subject', value: subject),
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
                        DropdownButtonFormField<String>(
                          value: selectedDesignation,
                          hint: const Text('Select designation', style: TextStyle(fontSize: 13)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          items: kDesignations.map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d, style: const TextStyle(fontSize: 13)),
                          )).toList(),
                          onChanged: (v) {
                            setDlgState(() => selectedDesignation = v);
                            _refreshLetter(setDlgState);
                          },
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
                  letterCtrl.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                icon: sending
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 15),
                label: Text(sending ? 'Sending…' : 'Send Pre-Offer Letter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: email.isEmpty || sending ? null : () async {
                  setDlgState(() => sending = true);
                  final id = (row['id'] ?? '').toString();
                  if (id.isEmpty) {
                    setDlgState(() => sending = false);
                    return;
                  }
                  try {
                    final token = TokenUtil.generate();
                    final pdfBytes = await PreOfferPdfService.build(
                      candidateName: name,
                      letterBody: letterCtrl.text,
                    );
                    await SupabaseService.uploadPreOfferPdf(id, pdfBytes);
                    final acceptLink = 'https://fomrahrms-zeta.vercel.app/#/pre-offer/$token';
                    final error = await EmailService.sendEmail(
                      templateName: 'pre_offer',
                      recipient: email,
                      data: {
                        'name': name,
                        'designation': selectedDesignation ?? '',
                        'department': selectedPosition ?? '',
                        'acceptLink': acceptLink,
                      },
                      attachments: [
                        EmailAttachment(filename: 'Pre-Offer-Letter.pdf', bytes: pdfBytes),
                      ],
                      relatedCandidateId: id,
                    );
                    if (error != null) {
                      setDlgState(() => sending = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed to send: $error')),
                        );
                      }
                      return;
                    }
                    letterCtrl.dispose();
                    Navigator.pop(ctx);
                    await SupabaseService.updateCandidateStatus(id, {
                      'pre_offer_sent': true,
                      'pre_offer_sent_at': DateTime.now().toUtc().toIso8601String(),
                      'pre_offer_token': token,
                      'pre_offer_token_created_at': DateTime.now().toUtc().toIso8601String(),
                      'department': selectedPosition ?? '',
                      'designation': selectedDesignation ?? '',
                    });
                    NotificationService.preOfferSent(candidateName: name);
                    _fetch();
                  } catch (e) {
                    setDlgState(() => sending = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed to send: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendOnboardingForm(BuildContext context, Map<String, dynamic> row) async {
    final id = (row['id'] ?? '').toString();
    final name = (row['name'] ?? '').toString().trim();
    final email = (row['email'] ?? '').toString().trim();
    if (id.isEmpty || email.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Send Onboarding Form', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _blue)),
        content: Text(
          'This will email $name a secure link to fill in their onboarding / joining form.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = TokenUtil.generate();
    final formLink = 'https://fomrahrms-zeta.vercel.app/#/onboarding-form/$token';
    final error = await EmailService.sendEmail(
      templateName: 'onboarding_invite',
      recipient: email,
      data: {'name': name, 'formLink': formLink},
      relatedCandidateId: id,
    );
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $error'), backgroundColor: Colors.red));
      return;
    }
    await SupabaseService.updateCandidateStatus(id, {
      'onboarding_token': token,
      'onboarding_link_sent': true,
      'onboarding_link_sent_at': DateTime.now().toUtc().toIso8601String(),
    });
    NotificationService.onboardingLinkSent(candidateName: name);
    _fetch();
  }

  Widget _buildApplicationCard(Map<String, dynamic> row) {
    final status = _compositeStatus(row);
    final preOfferSent = row['pre_offer_sent'] == true;
    final meta = _statusMeta(status, preOfferSent: preOfferSent);
    return _ApplicationCard(
      row: row,
      dateStr: _cell(row, 'submitted_at'),
      status: status,
      statusBadge: _statusBadge(status, preOfferSent: preOfferSent),
      borderColor: meta.fg,
      statusLabel: meta.label,
      stages: _buildStages(row),
      onAccept: () => _showAcceptDialog(row),
      onReject: () => _showRejectDialog(row),
      onComment: () => _showCommentDialog(row),
      onSendEmail: () => _showSendEmailDialog(context, row),
      onSendOnboarding: () => _sendOnboardingForm(context, row),
      onDelete: () => _deleteForHr(context, row),
      onView: () {
        CandidateStore.selected = row;
        context.push('/candidate-detail');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
      child: SingleChildScrollView(child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveHeaderRow(
                  icon: Icons.record_voice_over_rounded,
                  color: _blue,
                  title: 'Interview Process',
                  subtitle: '${_all.length} application${_all.length == 1 ? '' : 's'} received',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () => context.push('/email-logs'),
                      icon: const Icon(Icons.mark_email_read_outlined, size: 15),
                      label: const Text('Email Logs', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side: BorderSide(color: _blue),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _activeFormLink));
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
                    ElevatedButton.icon(
                      onPressed: () =>
                          launchUrl(Uri.parse(_activeFormLink)),
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
                  ],
                ),

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
                      avatar: const Icon(Icons.cancel_rounded, size: 13, color: Color(0xFFEF4444)),
                      label: Text('Rejected ($_rejectedCount)'),
                      selected: _filter == 'rejected',
                      onSelected: (_) => setState(() { _filter = 'rejected'; _applyFilter(); }),
                      selectedColor: const Color(0xFFFEE2E2),
                      checkmarkColor: const Color(0xFFEF4444),
                      labelStyle: TextStyle(
                          color: _filter == 'rejected' ? const Color(0xFFEF4444) : Colors.grey.shade600,
                          fontWeight: _filter == 'rejected' ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12),
                      side: BorderSide(color: _filter == 'rejected' ? const Color(0xFFEF4444) : Colors.grey.shade300),
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
                  LayoutBuilder(builder: (context, constraints) {
                    final search = TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, role, experience…',
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
                    );
                    final filterBtn = FilterTriggerButton(
                      hasActiveFilters: _deptFilter != 'All' || _expFilter != 'All'
                          || _assignedFilter != 'All' || _sort != _SortOrder.latest,
                      onTap: () {
                        String deptDraft = _deptFilter;
                        String expDraft = _expFilter;
                        String assignedDraft = _assignedFilter;
                        _SortOrder sortDraft = _sort;
                        showFilterPanel(
                          context,
                          title: 'Filters',
                          onReset: () {
                            deptDraft = 'All'; expDraft = 'All'; assignedDraft = 'All'; sortDraft = _SortOrder.latest;
                          },
                          onApply: () => setState(() {
                            _deptFilter = deptDraft; _expFilter = expDraft; _assignedFilter = assignedDraft;
                            _sort = sortDraft;
                            _applyFilter();
                          }),
                          builder: (context, setPanelState) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            FilterDropdownField<String>(
                              label: 'Department',
                              value: deptDraft == 'All' ? null : deptDraft,
                              options: _departmentOptions.where((o) => o != 'All').toList(),
                              labelOf: (d) => d,
                              allLabel: 'All Departments',
                              onChanged: (v) => setPanelState(() => deptDraft = v ?? 'All'),
                            ),
                            FilterChipGroup<String>(
                              label: 'Experience',
                              value: expDraft == 'All' ? null : expDraft,
                              options: _expBuckets.where((o) => o != 'All').toList(),
                              labelOf: (d) => d,
                              onChanged: (v) => setPanelState(() => expDraft = v ?? 'All'),
                            ),
                            FilterDropdownField<String>(
                              label: 'Assigned',
                              value: assignedDraft == 'All' ? null : assignedDraft,
                              options: _assignedOptions.where((o) => o != 'All').toList(),
                              labelOf: (d) => d,
                              allLabel: 'All',
                              onChanged: (v) => setPanelState(() => assignedDraft = v ?? 'All'),
                            ),
                            FilterChipGroup<_SortOrder>(
                              label: 'Sort',
                              value: sortDraft == _SortOrder.latest ? null : sortDraft,
                              options: const [_SortOrder.oldest, _SortOrder.nameAz, _SortOrder.expHighLow],
                              labelOf: (s) => switch (s) {
                                _SortOrder.latest     => 'Latest',
                                _SortOrder.oldest     => 'Oldest',
                                _SortOrder.nameAz     => 'Name A–Z',
                                _SortOrder.expHighLow => 'Experience',
                              },
                              onChanged: (v) => setPanelState(() => sortDraft = v ?? _SortOrder.latest),
                            ),
                          ]),
                        );
                      },
                    );
                    if (constraints.maxWidth < 760) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        search,
                        const SizedBox(height: 8),
                        filterBtn,
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: search),
                      const SizedBox(width: 10),
                      filterBtn,
                    ]);
                  }),
                ],
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          _loading
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: _blue)),
                )
              : _error != null
                  ? _ErrorView(error: _error!, onRetry: _fetch)
                  : _filtered.isEmpty
                      ? const _EmptyState()
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _filtered.map((row) => _buildApplicationCard(row)).toList()),
                        ),
        ],
      )),
    );
  }
}

// ── Stage timeline ─────────────────────────────────────────────────────────────

enum _StageState { completed, current, rejected, pending }

class _StageInfo {
  final String label;
  final String date;
  final _StageState state;
  const _StageInfo(this.label, this.date, this.state);
}

class _StageTimeline extends StatelessWidget {
  final List<_StageInfo> stages;
  const _StageTimeline({required this.stages});

  Color _nodeColor(_StageState s) => switch (s) {
    _StageState.completed => const Color(0xFF22C55E),
    _StageState.current   => AppTheme.primaryBlue,
    _StageState.rejected  => const Color(0xFFEF4444),
    _StageState.pending   => const Color(0xFFD1D5DB),
  };

  IconData _nodeIcon(_StageState s) => switch (s) {
    _StageState.completed => Icons.check_circle_rounded,
    _StageState.current   => Icons.radio_button_checked_rounded,
    _StageState.rejected  => Icons.cancel_rounded,
    _StageState.pending   => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stages.map((s) => Expanded(
          child: Column(children: [
            Text(s.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(s.date.isEmpty ? '—' : s.date,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          ]),
        )).toList(),
      ),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < stages.length; i++) ...[
          Icon(_nodeIcon(stages[i].state), size: 16, color: _nodeColor(stages[i].state)),
          if (i != stages.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: stages[i].state == _StageState.completed
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFE5E7EB),
              ),
            ),
        ],
      ]),
    ]);
  }
}

// ── Application Card ──────────────────────────────────────────────────────────

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final String dateStr;
  final String status;
  final Widget statusBadge;
  final Color borderColor;
  final String statusLabel;
  final List<_StageInfo> stages;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComment;
  final VoidCallback onView;
  final VoidCallback? onSendEmail;
  final VoidCallback? onSendOnboarding;
  final VoidCallback? onDelete;

  const _ApplicationCard({
    required this.row,
    required this.dateStr,
    required this.status,
    required this.statusBadge,
    required this.borderColor,
    required this.statusLabel,
    required this.stages,
    required this.onAccept,
    required this.onReject,
    required this.onComment,
    required this.onView,
    this.onSendEmail,
    this.onSendOnboarding,
    this.onDelete,
  });

  static const _avatarPalette = [
    Color(0xFF2563EB), Color(0xFFEF4444), Color(0xFF8B5CF6),
    Color(0xFFF97316), Color(0xFF22C55E), Color(0xFF0EA5E9),
  ];

  Color _avatarColor(String name) =>
      _avatarPalette[name.isEmpty ? 0 : name.codeUnitAt(0) % _avatarPalette.length];

  void _quickEmail(String email) {
    if (email.isEmpty) return;
    launchUrl(Uri.parse('mailto:$email'));
  }

  @override
  Widget build(BuildContext context) {
    final name           = (row['name']            ?? '').toString().trim();
    final email          = (row['email']            ?? '').toString().trim();
    final mobile         = (row['mobile']           ?? '').toString().trim();
    final post           = (row['post_applied']     ?? '').toString().trim();
    final exp            = (row['total_experience'] ?? '').toString().trim();
    final manager        = (row['assigned_manager'] ?? '').toString().trim();
    final hrComment      = (row['hr_comment']        ?? '').toString().trim();
    final managerComment = (row['manager_comment']   ?? '').toString().trim();
    final mgmtComment    = (row['management_comment']?? '').toString().trim();

    final isPending  = status == 'pending';
    final isApproved = status == 'approved';
    final avatarColor = _avatarColor(name);

    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: avatarColor.withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 17),
      ),
    );

    final infoBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name.isEmpty ? 'Unknown' : name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
      if (post.isNotEmpty || exp.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(
          [if (post.isNotEmpty) post.toUpperCase(), if (exp.isNotEmpty) '$exp yrs exp.'].join('  •  '),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
      ],
      if (email.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.email_rounded, size: 11, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(email, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
      ],
      if (mobile.isNotEmpty) ...[
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.phone_rounded, size: 11, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(mobile, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
      ],
      const SizedBox(height: 4),
      Text('Submitted: $dateStr', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
    ]);

    final assignedBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Assigned to', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      if (manager.isEmpty)
        Text('Unassigned', style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic))
      else
        Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: _blue.withValues(alpha: 0.12),
            child: Text(manager[0].toUpperCase(),
                style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(manager,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)))),
        ]),
    ]);

    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      _ActionButton(
        label: 'View',
        icon: Icons.visibility_outlined,
        color: _blue,
        onTap: onView,
      ),
      const SizedBox(width: 6),
      _ActionButton(
        label: 'Email',
        icon: Icons.mail_outline_rounded,
        color: AppTheme.accentBlue,
        onTap: isApproved && onSendEmail != null ? onSendEmail! : () => _quickEmail(email),
      ),
      const SizedBox(width: 6),
      if (isApproved) ...[
        _ActionButton(
          label: (row['onboarding_link_sent'] == true) ? 'Onboarding Sent' : 'Onboarding',
          icon: Icons.assignment_turned_in_outlined,
          color: row['pre_offer_accepted'] == true ? const Color(0xFF22C55E) : Colors.grey.shade400,
          onTap: row['pre_offer_accepted'] == true
              ? (onSendOnboarding ?? () {})
              : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Waiting for the candidate to accept the pre-offer first.'),
                  )),
        ),
        const SizedBox(width: 6),
      ],
      _ActionButton(
        label: 'Comment',
        icon: Icons.comment_outlined,
        color: const Color(0xFF6B7280),
        onTap: onComment,
      ),
      const SizedBox(width: 6),
      PopupMenuButton<String>(
        tooltip: 'More',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (v) {
          switch (v) {
            case 'accept': onAccept(); break;
            case 'reject': onReject(); break;
            case 'delete': onDelete?.call(); break;
          }
        },
        itemBuilder: (context) => [
          if (isPending) ...const [
            PopupMenuItem(value: 'accept', child: Row(children: [
              Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF22C55E)),
              SizedBox(width: 10), Text('Accept', style: TextStyle(fontSize: 13)),
            ])),
            PopupMenuItem(value: 'reject', child: Row(children: [
              Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
              SizedBox(width: 10), Text('Reject', style: TextStyle(fontSize: 13)),
            ])),
          ],
          if (onDelete != null)
            const PopupMenuItem(value: 'delete', child: Row(children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
              SizedBox(width: 10), Text('Delete', style: TextStyle(fontSize: 13)),
            ])),
        ],
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF6B7280)),
        ),
      ),
    ]);

    final comments = (hrComment.isNotEmpty || managerComment.isNotEmpty || mgmtComment.isNotEmpty)
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 6),
            if (hrComment.isNotEmpty) _CommentChip(label: 'HR', comment: hrComment),
            if (managerComment.isNotEmpty) _CommentChip(label: 'Manager', comment: managerComment),
            if (mgmtComment.isNotEmpty) _CommentChip(label: 'Management', comment: mgmtComment),
          ])
        : const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: borderColor, width: 4))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(child: infoBlock),
                  const SizedBox(width: 8),
                  statusBadge,
                ]),
                const SizedBox(height: 12),
                _StageTimeline(stages: stages),
                const SizedBox(height: 6),
                Text(statusLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: borderColor)),
                const SizedBox(height: 10),
                assignedBlock,
                comments,
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 8),
                actions,
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                avatar,
                const SizedBox(width: 12),
                SizedBox(width: 190, child: infoBlock),
                const SizedBox(width: 20),
                Expanded(child: Column(children: [
                  _StageTimeline(stages: stages),
                  const SizedBox(height: 6),
                  Text(statusLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: borderColor)),
                ])),
                const SizedBox(width: 20),
                SizedBox(width: 120, child: assignedBlock),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  statusBadge,
                  const SizedBox(height: 10),
                  actions,
                ]),
              ]),
              comments,
            ]);
          }),
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
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
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
