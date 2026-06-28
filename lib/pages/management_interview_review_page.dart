import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../models/candidate_store.dart';
import '../models/form_config.dart';
import '../models/user_session.dart';

const _mgmtColor = Color(0xFF4A148C);

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

  // ── Tab 2: Form Approvals ─────────────────────────────────────────
  List<Map<String, dynamic>> _formVersions = [];
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
            const Color(0xFF2E7D32), const Color(0xFFE8F5E9));
      case 'rejected':
        return _badge('Rejected', Icons.cancel_rounded,
            const Color(0xFFC62828), const Color(0xFFFFEBEE));
      default:
        return _badge('Pending Review', Icons.hourglass_empty_rounded,
            const Color(0xFFE65100), const Color(0xFFFFF3E0));
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
        title: const Text('Approve Candidate',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _mgmtColor)),
        content: const Text(
            'This will mark the candidate as approved by Management.',
            style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
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
                color: Color(0xFFC62828))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add a comment (optional):',
              style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
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
              backgroundColor: const Color(0xFFC62828),
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
        title: const Text('Management Comment',
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
          style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
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
      setState(() {
        _formVersions = versions;
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
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _mgmtColor)),
        content: const Text(
            'Approving this version will update the live Application Form immediately. '
            'A new versioned link will be generated.',
            style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Form v$vNum approved! Link: ${FormConfig.versionedLink(vNum)}'),
          backgroundColor: const Color(0xFF2E7D32),
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
                color: Color(0xFFC62828))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add a reason (optional):',
              style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
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
              backgroundColor: const Color(0xFFC62828),
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
      color: const Color(0xFFF5F7FA),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _mgmtColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: _mgmtColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
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
                              fontSize: 12, color: Color(0xFF78909C))),
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
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _mgmtColor))
                      : const Icon(Icons.refresh_rounded, color: _mgmtColor),
                ),
              ]),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: _mgmtColor,
                unselectedLabelColor: const Color(0xFF78909C),
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
              _candidatesLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _mgmtColor))
                  : _candidatesError != null
                      ? _ErrorView(
                          error: _candidatesError!,
                          onRetry: _fetchCandidates)
                      : _candidates.isEmpty
                          ? const _EmptyCandidates()
                          : _CandidateList(
                              items: _candidates,
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

              // Tab 2: Form Approvals
              _formLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _mgmtColor))
                  : _formError != null
                      ? _ErrorView(
                          error: _formError!, onRetry: _fetchFormVersions)
                      : _formVersions.isEmpty
                          ? const _EmptyFormVersions()
                          : _FormVersionList(
                              versions: _formVersions,
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
                  ? const Color(0xFFA5D6A7)
                  : mgmtStatus == 'rejected'
                      ? const Color(0xFFEF9A9A)
                      : const Color(0xFFE0E0E0),
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
                      backgroundColor:
                          const Color(0xFF4A148C).withValues(alpha: 0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: _mgmtColor,
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
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _mgmtColor)),
                            const SizedBox(height: 3),
                            Text('Submitted: $date',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF78909C))),
                            if (post.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(post,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF546E7A))),
                            ],
                            if (manager.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.person_outline_rounded,
                                    size: 11, color: Color(0xFF78909C)),
                                const SizedBox(width: 4),
                                Text('Reviewed by Manager: $manager',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF78909C))),
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
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.verified_rounded,
                          size: 15, color: Color(0xFF2E7D32)),
                      SizedBox(width: 6),
                      Text('Approved by Management and Manager',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],

                if (hrComment.isNotEmpty ||
                    managerComment.isNotEmpty ||
                    mgmtComment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 6),
                  if (hrComment.isNotEmpty)
                    _CommentRow(label: 'HR', text: hrComment),
                  if (managerComment.isNotEmpty)
                    _CommentRow(label: 'Manager', text: managerComment),
                  if (mgmtComment.isNotEmpty)
                    _CommentRow(label: 'Management', text: mgmtComment),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (isPending) ...[
                    _ActionBtn(
                      label: 'Approve',
                      icon: Icons.verified_rounded,
                      color: const Color(0xFF2E7D32),
                      onTap: () => onApprove(row),
                    ),
                    _ActionBtn(
                      label: 'Reject',
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFC62828),
                      onTap: () => onReject(row),
                    ),
                  ],
                  _ActionBtn(
                    label: 'Comment',
                    icon: Icons.comment_outlined,
                    color: const Color(0xFF546E7A),
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

// ── Form version list ─────────────────────────────────────────────────────────

class _FormVersionList extends StatelessWidget {
  final List<Map<String, dynamic>> versions;
  final void Function(Map<String, dynamic>) onApprove;
  final void Function(Map<String, dynamic>) onReject;

  const _FormVersionList({
    required this.versions,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: versions.length,
      itemBuilder: (ctx, idx) {
        final v = versions[idx];
        final vNum = (v['version_number'] as int?) ?? 0;
        final status = (v['status'] as String?) ?? 'pending';
        final createdBy = (v['created_by'] as String?) ?? '';
        final approvedBy = (v['approved_by'] as String?) ?? '';
        final rejectionNote = (v['rejection_note'] as String?) ?? '';
        final isPending = status == 'pending';

        String dateStr = '';
        try {
          final raw = v['created_at'];
          if (raw != null) {
            final dt = DateTime.parse(raw.toString()).toLocal();
            dateStr =
                '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }
        } catch (_) {}

        // Sections summary
        final configRaw = v['form_config'];
        List<Map<String, dynamic>> sections = [];
        if (configRaw is Map) {
          sections = FormConfig.getSections(
              Map<String, dynamic>.from(configRaw));
        }
        final enabledSections =
            sections.where((s) => (s['enabled'] as bool?) != false).toList();

        late Color statusBg;
        late Color statusFg;
        late IconData statusIcon;
        late String statusLabel;
        switch (status) {
          case 'approved':
            statusBg = const Color(0xFFE8F5E9);
            statusFg = const Color(0xFF2E7D32);
            statusIcon = Icons.check_circle_rounded;
            statusLabel = 'Approved';
            break;
          case 'rejected':
            statusBg = const Color(0xFFFFEBEE);
            statusFg = const Color(0xFFC62828);
            statusIcon = Icons.cancel_rounded;
            statusLabel = 'Rejected';
            break;
          default:
            statusBg = const Color(0xFFFFF3E0);
            statusFg = const Color(0xFFE65100);
            statusIcon = Icons.hourglass_empty_rounded;
            statusLabel = 'Pending Approval';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: status == 'approved'
                  ? const Color(0xFFA5D6A7)
                  : status == 'rejected'
                      ? const Color(0xFFEF9A9A)
                      : const Color(0xFFE0E0E0),
              width: status != 'pending' ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _mgmtColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Form v$vNum',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _mgmtColor)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (createdBy.isNotEmpty)
                          Text('Submitted by $createdBy',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF546E7A))),
                        if (dateStr.isNotEmpty)
                          Text(dateStr,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF78909C))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(statusIcon, size: 12, color: statusFg),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: statusFg,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),

                // Sections summary
                if (sections.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 8),
                  Text(
                      '${enabledSections.length} of ${sections.length} sections enabled',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF78909C))),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    ...sections.map((s) {
                      final sEnabled = (s['enabled'] as bool?) != false;
                      final sTitle =
                          (s['title'] as String?) ?? (s['id'] as String? ?? '');
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sEnabled
                              ? _mgmtColor.withValues(alpha: 0.08)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sEnabled
                                  ? _mgmtColor.withValues(alpha: 0.2)
                                  : const Color(0xFFE0E0E0)),
                        ),
                        child: Text(sTitle,
                            style: TextStyle(
                                fontSize: 10,
                                color: sEnabled
                                    ? _mgmtColor
                                    : const Color(0xFFBBBBBB),
                                decoration: sEnabled
                                    ? null
                                    : TextDecoration.lineThrough)),
                      );
                    }),
                  ]),
                ],

                if (approvedBy.isNotEmpty && status == 'approved') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.verified_rounded,
                          size: 14, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            'Approved by $approvedBy\n${FormConfig.versionedLink(vNum)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2E7D32))),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copied'),
                              backgroundColor: Color(0xFF2E7D32),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded,
                            size: 12, color: Color(0xFF2E7D32)),
                        label: const Text('Copy',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF2E7D32))),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                    ]),
                  ),
                ],

                if (rejectionNote.isNotEmpty && status == 'rejected') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.cancel_rounded,
                          size: 14, color: Color(0xFFC62828)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Reason: $rejectionNote',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFC62828))),
                      ),
                    ]),
                  ),
                ],

                // Preview Form button (all versions)
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () {
                    final cfg = configRaw is Map
                        ? Map<String, dynamic>.from(configRaw)
                        : <String, dynamic>{};
                    showDialog(
                      context: context,
                      builder: (_) => _FormPreviewDialog(
                          config: cfg, vNum: vNum),
                    );
                  },
                  icon: const Icon(Icons.preview_rounded, size: 15),
                  label: const Text('Preview Full Form',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: _mgmtColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6)),
                ),

                if (isPending) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _ActionBtn(
                      label: 'Approve Form',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF2E7D32),
                      onTap: () => onApprove(v),
                    ),
                    _ActionBtn(
                      label: 'Reject',
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFC62828),
                      onTap: () => onReject(v),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        );
      },
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
                  color: Color(0xFF546E7A))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A)),
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
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 52, color: Color(0xFFCE93D8)),
        SizedBox(height: 12),
        Text('No candidates pending approval',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _mgmtColor)),
        SizedBox(height: 6),
        Text('Candidates accepted by a Manager will appear here.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
      ]),
    );
  }
}

class _EmptyFormVersions extends StatelessWidget {
  const _EmptyFormVersions();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.edit_document, size: 52, color: Color(0xFFCE93D8)),
        SizedBox(height: 12),
        Text('No form edit requests',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _mgmtColor)),
        SizedBox(height: 6),
        Text('Form versions submitted by HR will appear here for approval.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
      ]),
    );
  }
}

// ── Full Form Preview Dialog ──────────────────────────────────────────────────

class _FormPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> config;
  final int vNum;
  const _FormPreviewDialog({required this.config, required this.vNum});

  static const _sectionIcons = <String, IconData>{
    'personal_info':        Icons.person_rounded,
    'interview_details':    Icons.event_note_rounded,
    'experience_ctc':       Icons.work_history_rounded,
    'education':            Icons.school_rounded,
    'employment_history':   Icons.business_center_rounded,
    'source':               Icons.campaign_rounded,
    'referrals':            Icons.group_add_rounded,
    'previous_application': Icons.history_rounded,
    'address':              Icons.location_on_rounded,
    'resume':               Icons.attach_file_rounded,
    'declaration':          Icons.verified_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final sections = config.isEmpty
        ? FormConfig.getSections(FormConfig.defaults())
        : FormConfig.getSections(config);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: BoxDecoration(
                color: _mgmtColor.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: _mgmtColor.withValues(alpha: 0.1))),
              ),
              child: Row(children: [
                const Icon(Icons.preview_rounded, size: 20, color: _mgmtColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Form v$vNum — Full Preview',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _mgmtColor)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: Color(0xFF78909C)),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            // Body
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sections.length,
                itemBuilder: (ctx, i) {
                  final section = sections[i];
                  final id       = (section['id'] as String?) ?? '';
                  final title    = (section['title'] as String?) ?? id;
                  final enabled  = (section['enabled'] as bool?) ?? true;
                  final icon     = _sectionIcons[id] ?? Icons.segment_rounded;
                  final builtInDefs = FormConfig.builtInFieldDefs[id] ?? [];
                  final hiddenIds   = FormConfig.getHiddenFieldIds(section);
                  final customFields = FormConfig.getCustomFields(section);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: enabled ? Colors.white : const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: enabled
                            ? _mgmtColor.withValues(alpha: 0.2)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section header
                        Row(children: [
                          Icon(icon,
                              size: 16,
                              color: enabled
                                  ? _mgmtColor
                                  : const Color(0xFFBBBBBB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(title,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: enabled
                                        ? const Color(0xFF263238)
                                        : const Color(0xFFBBBBBB),
                                    decoration: enabled
                                        ? null
                                        : TextDecoration.lineThrough)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: enabled
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              enabled ? 'Enabled' : 'Disabled',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: enabled
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFBBBBBB)),
                            ),
                          ),
                        ]),

                        if (enabled && (builtInDefs.isNotEmpty || customFields.isNotEmpty)) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Color(0xFFF0F0F0)),
                          const SizedBox(height: 8),

                          // Built-in fields
                          if (builtInDefs.isNotEmpty) ...[
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              ...builtInDefs.map((f) {
                                final isHidden = hiddenIds.contains(f['id']);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isHidden
                                        ? const Color(0xFFF5F5F5)
                                        : _mgmtColor.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isHidden
                                          ? const Color(0xFFE0E0E0)
                                          : _mgmtColor.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                    Icon(
                                      isHidden
                                          ? Icons.visibility_off_rounded
                                          : Icons.check_rounded,
                                      size: 9,
                                      color: isHidden
                                          ? const Color(0xFFBBBBBB)
                                          : _mgmtColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(f['label']!,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: isHidden
                                                ? const Color(0xFFBBBBBB)
                                                : _mgmtColor,
                                            decoration: isHidden
                                                ? TextDecoration.lineThrough
                                                : null)),
                                  ]),
                                );
                              }),
                            ]),
                          ],

                          // Custom fields
                          if (customFields.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...customFields.map((cf) {
                              final label  = (cf['label'] as String?) ?? '';
                              final type   = (cf['type'] as String?) ?? 'short_answer';
                              final req    = (cf['required'] as bool?) ?? false;
                              final typeLabel = type == 'mcq'
                                  ? 'MCQ'
                                  : type == 'file_upload'
                                      ? 'File Upload'
                                      : type == 'number'
                                          ? 'Numbers Only'
                                          : type == 'date'
                                              ? 'Date / Calendar'
                                              : type == 'checkbox'
                                                  ? 'Checkbox'
                                                  : 'Short Answer';
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(children: [
                                  const Icon(Icons.add_circle_outline_rounded,
                                      size: 10, color: Color(0xFF78909C)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      '$label  [$typeLabel]${req ? ' *' : ''}',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF546E7A),
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ]),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
        const Icon(Icons.cloud_off_rounded,
            size: 52, color: Color(0xFFCE93D8)),
        const SizedBox(height: 12),
        const Text('Could not load data',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _mgmtColor)),
        const SizedBox(height: 6),
        Text(error,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF78909C))),
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
