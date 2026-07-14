import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../models/candidate_store.dart';
import '../models/form_config.dart';
import '../models/user_session.dart';
import '../widgets/back_button.dart';
import '../widgets/filter_panel.dart';
import '../theme/app_theme.dart';

Color get _mgmtColor => AppTheme.sidebarSelectedBg;

const _avatarPalette = <Color>[
  Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF22C55E),
  Color(0xFFF59E0B), Color(0xFF06B6D4), Color(0xFF8B5CF6),
  Color(0xFFEF4444), Color(0xFF14B8A6),
];
Color _avatarColor(String name) =>
    _avatarPalette[name.isEmpty ? 0 : name.codeUnitAt(0) % _avatarPalette.length];

enum _MgmtReviewFilter { all, pending, accepted, rejected }

class ManagementInterviewReviewPage extends StatefulWidget {
  const ManagementInterviewReviewPage({super.key});

  @override
  State<ManagementInterviewReviewPage> createState() =>
      _ManagementInterviewReviewPageState();
}

class _ManagementInterviewReviewPageState
    extends State<ManagementInterviewReviewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Candidate Reviews ──────────────────────────────────────
  List<Map<String, dynamic>> _candidates = [];
  bool _candidatesLoading = false;
  String? _candidatesError;
  String _search = '';
  _MgmtReviewFilter _filter = _MgmtReviewFilter.all;

  String _mgmtStatusOf(Map<String, dynamic> row) =>
      (row['management_status'] as String?) ?? 'pending';

  int get _countPending  => _candidates.where((r) => _mgmtStatusOf(r) == 'pending').length;
  int get _countAccepted => _candidates.where((r) => _mgmtStatusOf(r) == 'accepted').length;
  int get _countRejected => _candidates.where((r) => _mgmtStatusOf(r) == 'rejected').length;

  List<Map<String, dynamic>> get _filteredCandidates {
    final q = _search.trim().toLowerCase();
    return _candidates.where((r) {
      final status = _mgmtStatusOf(r);
      final matchesFilter = switch (_filter) {
        _MgmtReviewFilter.all => true,
        _MgmtReviewFilter.pending => status == 'pending',
        _MgmtReviewFilter.accepted => status == 'accepted',
        _MgmtReviewFilter.rejected => status == 'rejected',
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return r.values.any((v) => v.toString().toLowerCase().contains(q));
    }).toList();
  }

  // ── Tab 2: Form Approvals ─────────────────────────────────────────
  List<Map<String, dynamic>> _formVersions = [];
  List<Map<String, dynamic>> _activeFormSections = [];
  bool _formLoading = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCandidates();
    _fetchFormVersions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Candidate Reviews ─────────────────────────────────────────────

  Future<void> _fetchCandidates() async {
    setState(() {
      _candidatesLoading = true;
      _candidatesError = null;
    });
    try {
      final all = await SupabaseService.fetchCandidateApplications();
      final filtered = all.where((r) {
        final managerStatus = (r['manager_status'] as String?) ?? 'pending';
        return managerStatus == 'accepted';
      }).toList();
      setState(() {
        _candidates = filtered;
        _candidatesLoading = false;
      });
    } catch (e) {
      setState(() {
        _candidatesError = e.toString();
        _candidatesLoading = false;
      });
    }
  }

  String _cell(Map<String, dynamic> row, String key) {
    final v = row[key];
    if (v == null) return '';
    if (key == 'submitted_at') {
      try {
        final dt = DateTime.parse(v.toString()).toLocal();
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {
        return v.toString();
      }
    }
    return v.toString();
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'accepted':
        return _badge('Approved', Icons.verified_rounded,
            const Color(0xFF22C55E), const Color(0xFFDCFCE7));
      case 'rejected':
        return _badge('Rejected', Icons.cancel_rounded,
            const Color(0xFFEF4444), const Color(0xFFFEE2E2));
      default:
        return _badge('Pending Review', Icons.hourglass_empty_rounded,
            const Color(0xFFF59E0B), const Color(0xFFFEF3C7));
    }
  }

  Widget _badge(String label, IconData icon, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _showApproveDialog(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Candidate',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _mgmtColor)),
        content: const Text(
            'This will mark the candidate as approved by Management.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateCandidateStatus(row, 'accepted', null);
    }
  }

  Future<void> _showRejectDialog(Map<String, dynamic> row) async {
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444))),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateCandidateStatus(
                  row, 'rejected', commentCtrl.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCommentDialog(Map<String, dynamic> row) async {
    final commentCtrl = TextEditingController(
        text: (row['management_comment'] as String?) ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Management Comment',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _mgmtColor)),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _mgmtColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final id = row['id']?.toString() ?? '';
              if (id.isEmpty) return;
              try {
                await SupabaseService.updateCandidateStatus(
                    id, {'management_comment': commentCtrl.text.trim()});
                await _fetchCandidates();
              } catch (_) {}
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(
      BuildContext ctx, Map<String, dynamic> row) async {
    final name = (row['name'] ?? '').toString().trim();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Text('Delete Application',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Permanently delete "$name"\'s application?\n\nThis cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await SupabaseService.deleteCandidateApplication(id);
      _fetchCandidates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _updateCandidateStatus(
      Map<String, dynamic> row, String status, String? comment) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      final fields = <String, dynamic>{'management_status': status};
      if (comment != null) fields['management_comment'] = comment;
      await SupabaseService.updateCandidateStatus(id, fields);
      NotificationService.interviewDecided(
        candidateName: (row['name'] ?? '').toString(),
        stage: 'Management',
        accepted: status == 'accepted',
      );
      await _fetchCandidates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── Form Approvals ────────────────────────────────────────────────

  Future<void> _fetchFormVersions() async {
    setState(() {
      _formLoading = true;
      _formError = null;
    });
    try {
      final versions = await SupabaseService.fetchFormVersions();
      // Extract active sections from the most recently approved version for diff
      final approved = versions
          .where((v) => (v['status'] as String?) == 'approved')
          .toList()
        ..sort((a, b) => ((b['version_number'] as int?) ?? 0)
            .compareTo((a['version_number'] as int?) ?? 0));
      List<Map<String, dynamic>> activeSects = [];
      if (approved.isNotEmpty) {
        final cfg = approved.first['form_config'] as Map?;
        if (cfg != null) {
          activeSects = FormConfig.getSections(Map<String, dynamic>.from(cfg));
        }
      }
      setState(() {
        _formVersions = versions;
        _activeFormSections = activeSects;
        _formLoading = false;
      });
    } catch (e) {
      setState(() {
        _formError = e.toString();
        _formLoading = false;
      });
    }
  }

  Future<void> _approveFormVersion(Map<String, dynamic> version) async {
    final vNum = (version['version_number'] as int?) ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Form v$vNum',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _mgmtColor)),
        content: const Text(
            'Approving this version will update the live Application Form immediately. '
            'A new versioned link will be generated.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve Form'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = version['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await SupabaseService.updateFormVersionStatus(
        id,
        'approved',
        decidedBy: UserSession.name.isNotEmpty ? UserSession.name : 'Management',
      );
      NotificationService.formEditDecided(formName: 'Interview Form', approved: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Form v$vNum approved! Link: ${FormConfig.versionedLink(vNum)}'),
          backgroundColor: const Color(0xFF22C55E),
          duration: const Duration(seconds: 4),
        ));
        await _fetchFormVersions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectFormVersion(Map<String, dynamic> version) async {
    final vNum = (version['version_number'] as int?) ?? 0;
    final noteCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Form v$vNum',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add a reason (optional):',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Reason for rejection…',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final id = version['id']?.toString() ?? '';
              if (id.isEmpty) return;
              try {
                await SupabaseService.updateFormVersionStatus(
                  id,
                  'rejected',
                  decidedBy: UserSession.name.isNotEmpty
                      ? UserSession.name
                      : 'Management',
                  note: noteCtrl.text.trim(),
                );
                NotificationService.formEditDecided(formName: 'Interview Form', approved: false);
                await _fetchFormVersions();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const NavBackButton(),
                const SizedBox(width: 8),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _mgmtColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.admin_panel_settings_rounded,
                      color: _mgmtColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Interview Review',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _mgmtColor)),
                      Text('Review candidates and form edit requests',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: (_candidatesLoading || _formLoading)
                      ? null
                      : () {
                          _fetchCandidates();
                          _fetchFormVersions();
                        },
                  icon: (_candidatesLoading || _formLoading)
                      ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _mgmtColor))
                      : Icon(Icons.refresh_rounded, color: _mgmtColor),
                ),
              ]),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: _mgmtColor,
                unselectedLabelColor: const Color(0xFF6B7280),
                indicatorColor: _mgmtColor,
                tabs: [
                  Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.people_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                          'Candidate Reviews (${_candidates.length})',
                          style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                  Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_document, size: 16),
                      const SizedBox(width: 6),
                      Builder(builder: (ctx) {
                        final pending = _formVersions
                            .where((v) =>
                                (v['status'] as String?) == 'pending')
                            .length;
                        return Text(
                          'Form Approvals${pending > 0 ? ' ($pending pending)' : ''}',
                          style: const TextStyle(fontSize: 13),
                        );
                      }),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Tab Body ─────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Candidate Reviews
              Column(children: [
                if (_candidates.isNotEmpty)
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
                    child: Column(children: [
                      _ReviewStatsRow(
                        total: _candidates.length,
                        pending: _countPending,
                        accepted: _countAccepted,
                        rejected: _countRejected,
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(builder: (context, constraints) {
                        final narrowRow = constraints.maxWidth < 560;
                        final search = TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: 'Search candidates…',
                            prefixIcon: Icon(Icons.search_rounded, color: _mgmtColor, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        );
                        final filterBtn = FilterTriggerButton(
                          hasActiveFilters: _filter != _MgmtReviewFilter.all,
                          onTap: () {
                            _MgmtReviewFilter draft = _filter;
                            showFilterPanel(
                              context,
                              title: 'Filters',
                              onReset: () => draft = _MgmtReviewFilter.all,
                              onApply: () => setState(() => _filter = draft),
                              builder: (context, setPanelState) => FilterChipGroup<_MgmtReviewFilter>(
                                label: 'Status',
                                value: draft == _MgmtReviewFilter.all ? null : draft,
                                options: const [_MgmtReviewFilter.pending, _MgmtReviewFilter.accepted,
                                    _MgmtReviewFilter.rejected],
                                labelOf: (f) => switch (f) {
                                  _MgmtReviewFilter.all => 'All (${_candidates.length})',
                                  _MgmtReviewFilter.pending => 'Pending ($_countPending)',
                                  _MgmtReviewFilter.accepted => 'Accepted ($_countAccepted)',
                                  _MgmtReviewFilter.rejected => 'Rejected ($_countRejected)',
                                },
                                onChanged: (v) => setPanelState(() => draft = v ?? _MgmtReviewFilter.all),
                              ),
                            );
                          },
                        );
                        return narrowRow
                            ? Column(children: [search, const SizedBox(height: 10), filterBtn])
                            : Row(children: [Expanded(child: search), const SizedBox(width: 10), filterBtn]);
                      }),
                    ]),
                  ),
                Expanded(
                  child: _candidatesLoading
                      ? Center(
                          child: CircularProgressIndicator(color: _mgmtColor))
                      : _candidatesError != null
                          ? _ErrorView(
                              error: _candidatesError!,
                              onRetry: _fetchCandidates)
                          : _candidates.isEmpty
                              ? const _EmptyCandidates()
                              : _filteredCandidates.isEmpty
                                  ? const _EmptyFilterState()
                                  : _CandidateList(
                                      items: _filteredCandidates,
                                      cellFn: _cell,
                                      statusBadgeFn: _statusBadge,
                                      onApprove: _showApproveDialog,
                                      onReject: _showRejectDialog,
                                      onComment: _showCommentDialog,
                                      onDelete: _deleteRecord,
                                      onView: (row) {
                                        CandidateStore.selected = row;
                                        context.push('/management/candidate-detail');
                                      },
                                    ),
                ),
              ]),

              // Tab 2: Form Approvals
              _formLoading
                  ? Center(
                      child: CircularProgressIndicator(color: _mgmtColor))
                  : _formError != null
                      ? _ErrorView(
                          error: _formError!, onRetry: _fetchFormVersions)
                      : _formVersions.isEmpty
                          ? const _EmptyFormVersions()
                          : _FormVersionList(
                              versions: _formVersions,
                              activeSections: _activeFormSections,
                              onApprove: _approveFormVersion,
                              onReject: _rejectFormVersion,
                            ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Candidate list ────────────────────────────────────────────────────────────

class _CandidateList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>, String) cellFn;
  final Widget Function(String) statusBadgeFn;
  final void Function(Map<String, dynamic>) onApprove;
  final void Function(Map<String, dynamic>) onReject;
  final void Function(Map<String, dynamic>) onComment;
  final void Function(BuildContext, Map<String, dynamic>) onDelete;
  final void Function(Map<String, dynamic>) onView;

  const _CandidateList({
    required this.items,
    required this.cellFn,
    required this.statusBadgeFn,
    required this.onApprove,
    required this.onReject,
    required this.onComment,
    required this.onDelete,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final row = items[idx];
        final mgmtStatus = (row['management_status'] as String?) ?? 'pending';
        final isPending = mgmtStatus == 'pending';
        final name = (row['name'] ?? '').toString().trim();
        final date = cellFn(row, 'submitted_at');
        final post = (row['post_applied'] ?? '').toString().trim();
        final manager = (row['assigned_manager'] ?? '').toString().trim();
        final hrComment = (row['hr_comment'] ?? '').toString().trim();
        final managerComment =
            (row['manager_comment'] ?? '').toString().trim();
        final mgmtComment =
            (row['management_comment'] ?? '').toString().trim();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: mgmtStatus == 'accepted'
                  ? const Color(0xFF86EFAC)
                  : mgmtStatus == 'rejected'
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFE5E7EB),
              width: mgmtStatus != 'pending' ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _avatarColor(name).withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: _avatarColor(name),
                            fontWeight: FontWeight.bold,
                            fontSize: 17),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.isEmpty ? 'Unknown' : name,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _mgmtColor)),
                            const SizedBox(height: 3),
                            Text('Submitted: $date',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280))),
                            if (post.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(post,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280))),
                            ],
                            if (manager.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.person_outline_rounded,
                                    size: 11, color: Color(0xFF6B7280)),
                                const SizedBox(width: 4),
                                Text('Reviewed by Manager: $manager',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280))),
                              ]),
                            ],
                          ]),
                    ),
                    const SizedBox(width: 8),
                    statusBadgeFn(mgmtStatus),
                  ],
                ),

                if (mgmtStatus == 'accepted') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
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
                ],

                if (hrComment.isNotEmpty ||
                    managerComment.isNotEmpty ||
                    mgmtComment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 6),
                  if (hrComment.isNotEmpty)
                    _CommentRow(label: 'HR', text: hrComment),
                  if (managerComment.isNotEmpty)
                    _CommentRow(label: 'Manager', text: managerComment),
                  if (mgmtComment.isNotEmpty)
                    _CommentRow(label: 'Management', text: mgmtComment),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (isPending) ...[
                    _ActionBtn(
                      label: 'Approve',
                      icon: Icons.verified_rounded,
                      color: const Color(0xFF22C55E),
                      onTap: () => onApprove(row),
                    ),
                    _ActionBtn(
                      label: 'Reject',
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFEF4444),
                      onTap: () => onReject(row),
                    ),
                  ],
                  _ActionBtn(
                    label: 'Comment',
                    icon: Icons.comment_outlined,
                    color: const Color(0xFF6B7280),
                    onTap: () => onComment(row),
                  ),
                  _ActionBtn(
                    label: 'View',
                    icon: Icons.open_in_new_rounded,
                    color: _mgmtColor,
                    onTap: () => onView(row),
                  ),
                  _ActionBtn(
                    label: 'Delete',
                    icon: Icons.delete_forever_rounded,
                    color: Colors.red.shade700,
                    onTap: () => onDelete(ctx, row),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Form diff helpers ─────────────────────────────────────────────────────────
enum _AFDiffStatus { added, removed, modified, disabled, unchanged }

class _AFSectionDiff {
  final Map<String, dynamic> section;
  final _AFDiffStatus status;
  final List<String> addedFields;
  final List<String> removedFields;
  final List<String> hiddenChanged;
  const _AFSectionDiff({
    required this.section,
    required this.status,
    this.addedFields  = const [],
    this.removedFields = const [],
    this.hiddenChanged = const [],
  });
}

List<_AFSectionDiff> _computeAFDiff(
    List<Map<String, dynamic>> pending,
    List<Map<String, dynamic>> active) {
  final result = <_AFSectionDiff>[];
  for (final s in pending) {
    final id      = (s['id'] as String?) ?? '';
    final enabled = (s['enabled'] as bool?) ?? true;
    final aIdx    = active.indexWhere((a) => a['id'] == id);
    if (aIdx == -1) {
      result.add(_AFSectionDiff(section: s, status: _AFDiffStatus.added));
      continue;
    }
    if (!enabled) {
      result.add(_AFSectionDiff(section: s, status: _AFDiffStatus.disabled));
      continue;
    }
    final a        = active[aIdx];
    final pCustom  = FormConfig.getCustomFields(s);
    final aCustom  = FormConfig.getCustomFields(a);
    final pHidden  = FormConfig.getHiddenFieldIds(s).toSet();
    final aHidden  = FormConfig.getHiddenFieldIds(a).toSet();
    final pIds     = pCustom.map((f) => f['id'] as String? ?? '').toSet();
    final aIds     = aCustom.map((f) => f['id'] as String? ?? '').toSet();
    final added    = pIds.difference(aIds).toList();
    final removed  = aIds.difference(pIds).toList();
    final hidChg   = [...pHidden.difference(aHidden), ...aHidden.difference(pHidden)];
    final titleChg = (s['title'] as String?) != (a['title'] as String?);
    final isModified = added.isNotEmpty || removed.isNotEmpty || hidChg.isNotEmpty || titleChg;
    result.add(_AFSectionDiff(
      section: s,
      status: isModified ? _AFDiffStatus.modified : _AFDiffStatus.unchanged,
      addedFields: added,
      removedFields: removed,
      hiddenChanged: hidChg,
    ));
  }
  for (final a in active) {
    final id = (a['id'] as String?) ?? '';
    if (!pending.any((p) => p['id'] == id)) {
      result.add(_AFSectionDiff(section: a, status: _AFDiffStatus.removed));
    }
  }
  return result;
}

// ── Form version list ─────────────────────────────────────────────────────────

class _FormVersionList extends StatelessWidget {
  final List<Map<String, dynamic>> versions;
  final List<Map<String, dynamic>> activeSections;
  final void Function(Map<String, dynamic>) onApprove;
  final void Function(Map<String, dynamic>) onReject;

  const _FormVersionList({
    required this.versions,
    required this.activeSections,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: versions.length,
      itemBuilder: (ctx, idx) {
        final v      = versions[idx];
        final status = (v['status'] as String?) ?? 'pending';
        if (status == 'pending') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AFPendingCard(
              version: v,
              activeSections: activeSections,
              onApprove: () => onApprove(v),
              onReject:  () => onReject(v),
            ),
          );
        }
        // Approved / Rejected — compact history card
        return _AFHistoryCard(version: v);
      },
    );
  }
}

// ── Pending form version card (full diff) ─────────────────────────────────────
class _AFPendingCard extends StatefulWidget {
  final Map<String, dynamic> version;
  final List<Map<String, dynamic>> activeSections;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _AFPendingCard({
    required this.version,
    required this.activeSections,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_AFPendingCard> createState() => _AFPendingCardState();
}

class _AFPendingCardState extends State<_AFPendingCard> {
  bool _acting = false;
  final Set<String> _expandedSections = {};

  Future<void> _act(Future<void> Function() fn) async {
    setState(() => _acting = true);
    await fn();
    if (mounted) setState(() => _acting = false);
  }

  static const _sectionIcons = <String, IconData>{
    'personal_info':       Icons.person_rounded,
    'interview_details':   Icons.record_voice_over_rounded,
    'experience_ctc':      Icons.work_history_rounded,
    'education':           Icons.school_rounded,
    'employment_history':  Icons.business_center_rounded,
    'source':              Icons.ads_click_rounded,
    'referrals':           Icons.people_rounded,
    'previous_application': Icons.history_rounded,
    'address':             Icons.home_rounded,
    'resume':              Icons.description_rounded,
    'declaration':         Icons.verified_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final v         = widget.version;
    final vNum      = (v['version_number'] as int?) ?? 0;
    final createdBy = (v['created_by'] as String?) ?? 'HR';
    String dateStr  = '';
    try {
      final raw = v['created_at'];
      if (raw != null) {
        final dt = DateTime.parse(raw.toString()).toLocal();
        dateStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
      }
    } catch (_) {}

    final configRaw = v['form_config'];
    final pendingSections = configRaw is Map
        ? FormConfig.getSections(Map<String, dynamic>.from(configRaw))
        : <Map<String, dynamic>>[];
    final diffs = _computeAFDiff(pendingSections, widget.activeSections);

    final addedCount    = diffs.where((d) => d.status == _AFDiffStatus.added).length;
    final modifiedCount = diffs.where((d) => d.status == _AFDiffStatus.modified).length;
    final removedCount  = diffs.where((d) => d.status == _AFDiffStatus.removed || d.status == _AFDiffStatus.disabled).length;
    final hasChanges    = addedCount + modifiedCount + removedCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentBlue, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.lightBlue,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _mgmtColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Form v$vNum',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Submitted by $createdBy',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF9800)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.pending_actions_rounded, size: 12, color: Color(0xFFF59E0B)),
                SizedBox(width: 4),
                Text('Pending Review', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
              ]),
            ),
          ]),
        ),

        // Changes summary
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            const Text('Changes vs current live form:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            const SizedBox(width: 8),
            if (!hasChanges)
              _AFDiffPill('No Changes', const Color(0xFF6B7280), const Color(0xFFF8FAFC))
            else ...[
              if (addedCount    > 0) ...[_AFDiffPill('+$addedCount New',      const Color(0xFF22C55E), const Color(0xFFDCFCE7)), const SizedBox(width: 4)],
              if (modifiedCount > 0) ...[_AFDiffPill('~$modifiedCount Changed', const Color(0xFFF59E0B), const Color(0xFFFEF3C7)), const SizedBox(width: 4)],
              if (removedCount  > 0)   _AFDiffPill('-$removedCount Removed',  const Color(0xFFEF4444), const Color(0xFFFEE2E2)),
            ],
          ]),
        ),

        const Divider(height: 20, indent: 16, endIndent: 16),

        // Full form preview with diff
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Form Structure Preview',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            ...diffs.map((diff) {
              final id = (diff.section['id'] as String?) ?? '';
              return _AFSectionTile(
                diff: diff,
                icon: _sectionIcons[id] ?? Icons.segment_rounded,
                expanded: _expandedSections.contains(id),
                onToggle: () => setState(() {
                  if (_expandedSections.contains(id)) _expandedSections.remove(id);
                  else _expandedSections.add(id);
                }),
              );
            }),
          ]),
        ),

        // Actions
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _acting ? null : () => _act(() async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reject Form Version',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                      content: Text('Reject application form v$vNum submitted by $createdBy?\n\nThe current live form will remain unchanged.',
                          style: const TextStyle(fontSize: 13, height: 1.5)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) widget.onReject();
                }),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _acting ? null : () => _act(() async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Approve & Publish',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                      content: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Publish application form v$vNum?',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF22C55E)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'This will immediately become the live application form. A versioned link will be generated that candidates can use to apply.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF22C55E), height: 1.5),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Approve & Publish'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) widget.onApprove();
                }),
                icon: _acting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Approve & Publish', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── History card (approved / rejected) ────────────────────────────────────────
class _AFHistoryCard extends StatelessWidget {
  final Map<String, dynamic> version;
  const _AFHistoryCard({required this.version});

  @override
  Widget build(BuildContext context) {
    final v           = version;
    final vNum        = (v['version_number'] as int?) ?? 0;
    final status      = (v['status'] as String?) ?? '';
    final createdBy   = (v['created_by'] as String?) ?? '';
    final approvedBy  = (v['approved_by'] as String?) ?? '';
    final rejectionNote = (v['rejection_note'] as String?) ?? '';
    String dateStr = '';
    try {
      final raw = v['created_at'];
      if (raw != null) {
        final dt = DateTime.parse(raw.toString()).toLocal();
        dateStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
      }
    } catch (_) {}

    final isApproved = status == 'approved';
    final borderColor = isApproved ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final bgColor     = isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final fgColor     = isApproved ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final statusLabel = isApproved ? 'Approved' : 'Rejected';
    final statusIcon  = isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _mgmtColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('Form v$vNum', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _mgmtColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (createdBy.isNotEmpty)
                Text('By $createdBy', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              if (dateStr.isNotEmpty)
                Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 12, color: fgColor),
              const SizedBox(width: 4),
              Text(statusLabel, style: TextStyle(fontSize: 11, color: fgColor, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        if (isApproved && approvedBy.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF22C55E)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Approved by $approvedBy  •  ${FormConfig.versionedLink(vNum)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF22C55E))),
            ),
          ]),
        ],
        if (!isApproved && rejectionNote.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.cancel_rounded, size: 13, color: Color(0xFFEF4444)),
            const SizedBox(width: 6),
            Expanded(child: Text('Reason: $rejectionNote', style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)))),
          ]),
        ],
      ]),
    );
  }
}

// ── Diff pill + section tile ───────────────────────────────────────────────────
class _AFDiffPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _AFDiffPill(this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

class _AFSectionTile extends StatelessWidget {
  final _AFSectionDiff diff;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  const _AFSectionTile({required this.diff, required this.icon, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final s     = diff.section;
    final id    = (s['id'] as String?) ?? '';
    final title = (s['title'] as String?) ?? id;

    Color borderColor, bgColor, textColor;
    String? badge;
    Color badgeColor, badgeBg;
    bool strikethrough = false;

    switch (diff.status) {
      case _AFDiffStatus.added:
        borderColor = const Color(0xFF66BB6A); bgColor = const Color(0xFFDCFCE7); textColor = const Color(0xFF15803D);
        badge = 'NEW'; badgeColor = const Color(0xFF15803D); badgeBg = const Color(0xFF86EFAC);
      case _AFDiffStatus.removed:
        borderColor = const Color(0xFFFCA5A5); bgColor = const Color(0xFFFEE2E2); textColor = const Color(0xFFB91C1C);
        badge = 'REMOVED'; badgeColor = const Color(0xFFB91C1C); badgeBg = const Color(0xFFFFCDD2); strikethrough = true;
      case _AFDiffStatus.disabled:
        borderColor = const Color(0xFFE5E7EB); bgColor = const Color(0xFFF8FAFC); textColor = const Color(0xFF9E9E9E);
        badge = 'DISABLED'; badgeColor = const Color(0xFF757575); badgeBg = const Color(0xFFE5E7EB); strikethrough = true;
      case _AFDiffStatus.modified:
        borderColor = const Color(0xFFFFB74D); bgColor = const Color(0xFFFEF3C7); textColor = const Color(0xFFF59E0B);
        badge = 'CHANGED'; badgeColor = const Color(0xFFF59E0B); badgeBg = const Color(0xFFFFE0B2);
      case _AFDiffStatus.unchanged:
        borderColor = const Color(0xFF3B82F6); bgColor = const Color(0xFFEFF6FF); textColor = _mgmtColor;
        badge = null; badgeColor = _mgmtColor; badgeBg = const Color(0xFF3B82F6);
    }

    final builtInDefs = FormConfig.builtInFieldDefs[id] ?? [];
    final customFields = FormConfig.getCustomFields(s);
    final hiddenIds    = FormConfig.getHiddenFieldIds(s);
    final totalFields  = builtInDefs.length + customFields.length;
    final visibleCount = builtInDefs.where((f) => !hiddenIds.contains(f['id'])).length + customFields.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor,
                    decoration: strikethrough ? TextDecoration.lineThrough : null)),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor, letterSpacing: 0.4)),
                ),
                const SizedBox(width: 4),
              ],
              if (diff.status != _AFDiffStatus.removed)
                Text('$visibleCount/$totalFields fields',
                    style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7))),
              const SizedBox(width: 4),
              Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: textColor),
            ]),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (builtInDefs.isNotEmpty) ...[
                Text('Built-in Fields:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 3,
                    children: builtInDefs.map((f) {
                      final fId      = f['id'] ?? '';
                      final fLabel   = f['label'] ?? fId;
                      final isHidden = hiddenIds.contains(fId);
                      final hidChg   = diff.hiddenChanged.contains(fId);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hidChg ? const Color(0xFFFFF9C4) : (isHidden ? const Color(0xFFE5E7EB) : bgColor),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: hidChg ? const Color(0xFFFFEB3B) : borderColor),
                        ),
                        child: Text(isHidden ? '$fLabel (hidden)' : fLabel,
                            style: TextStyle(fontSize: 10, color: isHidden ? Colors.grey : textColor,
                                decoration: isHidden ? TextDecoration.lineThrough : null)),
                      );
                    }).toList()),
                const SizedBox(height: 6),
              ],
              if (customFields.isNotEmpty || diff.addedFields.isNotEmpty || diff.removedFields.isNotEmpty) ...[
                Text('Custom Fields:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 3, children: [
                  ...customFields.map((f) {
                    final fId   = f['id'] as String? ?? '';
                    final lbl   = (f['label'] as String?) ?? fId;
                    final isNew = diff.addedFields.contains(fId);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNew ? const Color(0xFFDCFCE7) : bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isNew ? const Color(0xFF66BB6A) : borderColor),
                      ),
                      child: Text(isNew ? '$lbl ✦' : lbl,
                          style: TextStyle(fontSize: 10, color: isNew ? const Color(0xFF15803D) : textColor,
                              fontWeight: isNew ? FontWeight.w700 : FontWeight.normal)),
                    );
                  }),
                  ...diff.removedFields.map((fId) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5))),
                    child: Text('$fId (removed)',
                        style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C), decoration: TextDecoration.lineThrough)),
                  )),
                ]),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _CommentRow extends StatelessWidget {
  final String label;
  final String text;
  const _CommentRow({required this.label, required this.text});

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
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

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
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _EmptyCandidates extends StatelessWidget {
  const _EmptyCandidates();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 52, color: AppTheme.accentBlue),
        SizedBox(height: 12),
        Text('No candidates pending approval',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _mgmtColor)),
        SizedBox(height: 6),
        Text('Candidates accepted by a Manager will appear here.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      ]),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text('No candidates match this filter',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ]),
    );
  }
}

// ── Summary stats row ────────────────────────────────────────────────────────
class _ReviewStatsRow extends StatelessWidget {
  final int total;
  final int pending;
  final int accepted;
  final int rejected;
  const _ReviewStatsRow({
    required this.total,
    required this.pending,
    required this.accepted,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Total', '$total', Icons.people_alt_rounded, _mgmtColor),
      ('Pending Review', '$pending', Icons.hourglass_empty_rounded, const Color(0xFFF59E0B)),
      ('Accepted', '$accepted', Icons.check_circle_rounded, const Color(0xFF22C55E)),
      ('Rejected', '$rejected', Icons.cancel_rounded, const Color(0xFFEF4444)),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 720 ? 4 : constraints.maxWidth > 400 ? 2 : 1;
      final tileWidth = (constraints.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(
          width: tileWidth,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.$4.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.$4.withValues(alpha: 0.18)),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: c.$4, shape: BoxShape.circle),
                child: Icon(c.$3, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  Text(c.$2, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.$4)),
                ]),
              ),
            ]),
          ),
        )).toList(),
      );
    });
  }
}

class _EmptyFormVersions extends StatelessWidget {
  const _EmptyFormVersions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.edit_document, size: 52, color: AppTheme.accentBlue),
        SizedBox(height: 12),
        Text('No form edit requests',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _mgmtColor)),
        SizedBox(height: 6),
        Text('Form versions submitted by HR will appear here for approval.',
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
        Icon(Icons.cloud_off_rounded,
            size: 52, color: AppTheme.accentBlue),
        const SizedBox(height: 12),
        Text('Could not load data',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _mgmtColor)),
        const SizedBox(height: 6),
        Text(error,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _mgmtColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}
