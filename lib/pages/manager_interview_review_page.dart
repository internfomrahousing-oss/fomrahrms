import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../models/candidate_store.dart';
import '../models/user_session.dart';

const _blue = Color(0xFF1A237E);

class ManagerInterviewReviewPage extends StatefulWidget {
  const ManagerInterviewReviewPage({super.key});

  @override
  State<ManagerInterviewReviewPage> createState() =>
      _ManagerInterviewReviewPageState();
}

class _ManagerInterviewReviewPageState
    extends State<ManagerInterviewReviewPage> {
  List<Map<String, dynamic>> _items   = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all     = await SupabaseService.fetchCandidateApplications();
      final myName  = UserSession.name.trim();
      final filtered = all.where((r) {
        final hrStatus = ((r['hr_status'] as String?) ?? '').trim().toLowerCase();
        if (hrStatus != 'accepted') return false;
        // If no profile name is set yet, show all accepted candidates.
        if (myName.isEmpty) return true;
        final assigned = ((r['assigned_manager'] as String?) ?? '').trim().toLowerCase();
        return assigned == myName.toLowerCase();
      }).toList();
      setState(() { _items = filtered; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _cell(Map<String, dynamic> row, String key) {
    final v = row[key];
    if (v == null) return '';
    if (key == 'submitted_at') {
      try {
        final dt = DateTime.parse(v.toString()).toLocal();
        return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
      } catch (_) { return v.toString(); }
    }
    return v.toString();
  }

  Widget _managerStatusBadge(String status) {
    switch (status) {
      case 'accepted':
        return _badge('Accepted', Icons.check_circle_rounded,
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
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _showAcceptDialog(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept & Forward to Management',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        content: const Text(
            'This will forward the candidate to Management for final approval.',
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
            child: const Text('Accept & Forward'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateStatus(row, 'accepted', null);
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
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
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
              await _updateStatus(row, 'rejected', commentCtrl.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCommentDialog(Map<String, dynamic> row) async {
    final commentCtrl = TextEditingController(
        text: (row['manager_comment'] as String?) ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manager Comment',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        content: TextField(
          controller: commentCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Add or update your comment…',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
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
                    id, {'manager_comment': commentCtrl.text.trim()});
                await _fetch();
              } catch (_) {}
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
      Map<String, dynamic> row, String status, String? comment) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      final fields = <String, dynamic>{'manager_status': status};
      if (comment != null) fields['manager_comment'] = comment;
      await SupabaseService.updateCandidateStatus(id, fields);
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red));
      }
    }
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
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.rate_review_rounded,
                  color: _blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Interview Review',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _blue)),
                  Text(
                    '${_items.length} candidate${_items.length == 1 ? '' : 's'} assigned to you',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF78909C)),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _fetch,
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _blue))
                  : const Icon(Icons.refresh_rounded, color: _blue),
            ),
          ]),
        ),

        // ── Body ──────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _blue))
              : _error != null
                  ? _ErrorView(error: _error!, onRetry: _fetch)
                  : _items.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (context, idx) {
                            final row = _items[idx];
                            final mStatus =
                                (row['manager_status'] as String?) ??
                                    'pending';
                            final isPending = mStatus == 'pending';
                            final name =
                                (row['name'] ?? '').toString().trim();
                            final date = _cell(row, 'submitted_at');
                            final post =
                                (row['post_applied'] ?? '').toString().trim();
                            final hrComment =
                                (row['hr_comment'] ?? '').toString().trim();
                            final managerComment =
                                (row['manager_comment'] ?? '').toString().trim();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: mStatus == 'accepted'
                                      ? const Color(0xFFA5D6A7)
                                      : mStatus == 'rejected'
                                          ? const Color(0xFFEF9A9A)
                                          : const Color(0xFFE0E0E0),
                                  width: mStatus != 'pending' ? 1.5 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // ── Top row ──────────────────────
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: _blue
                                              .withValues(alpha: 0.1),
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: _blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  name.isEmpty
                                                      ? 'Unknown'
                                                      : name,
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _blue)),
                                              const SizedBox(height: 3),
                                              Text('Submitted: $date',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(
                                                          0xFF78909C))),
                                              if (post.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(post,
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                            0xFF546E7A))),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _managerStatusBadge(mStatus),
                                      ],
                                    ),

                                    // ── HR comment ───────────────────
                                    if (hrComment.isNotEmpty ||
                                        managerComment.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      const Divider(
                                          height: 1,
                                          color: Color(0xFFEEEEEE)),
                                      const SizedBox(height: 6),
                                      if (hrComment.isNotEmpty)
                                        _CommentRow(
                                            label: 'HR',
                                            text: hrComment),
                                      if (managerComment.isNotEmpty)
                                        _CommentRow(
                                            label: 'My Comment',
                                            text: managerComment),
                                    ],

                                    // ── Action buttons ───────────────
                                    const SizedBox(height: 10),
                                    const Divider(
                                        height: 1,
                                        color: Color(0xFFEEEEEE)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          if (isPending) ...[
                                            _ActionBtn(
                                              label: 'Accept',
                                              icon: Icons
                                                  .check_circle_outline_rounded,
                                              color:
                                                  const Color(0xFF2E7D32),
                                              onTap: () =>
                                                  _showAcceptDialog(row),
                                            ),
                                            _ActionBtn(
                                              label: 'Reject',
                                              icon: Icons.cancel_outlined,
                                              color:
                                                  const Color(0xFFC62828),
                                              onTap: () =>
                                                  _showRejectDialog(row),
                                            ),
                                          ],
                                          _ActionBtn(
                                            label: 'Comment',
                                            icon: Icons.comment_outlined,
                                            color:
                                                const Color(0xFF546E7A),
                                            onTap: () =>
                                                _showCommentDialog(row),
                                          ),
                                          _ActionBtn(
                                            label: 'View',
                                            icon: Icons
                                                .open_in_new_rounded,
                                            color: _blue,
                                            onTap: () {
                                              CandidateStore.selected = row;
                                              context.push(
                                                  '/manager/candidate-detail');
                                            },
                                          ),
                                        ]),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}

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
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF546E7A)),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 52, color: Color(0xFFBBDEFB)),
        SizedBox(height: 12),
        Text('No candidates assigned to you',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _blue)),
        SizedBox(height: 6),
        Text('HR will assign candidates here for your review.',
            style:
                TextStyle(fontSize: 12, color: Color(0xFF78909C))),
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
        const Icon(Icons.cloud_off_rounded,
            size: 52, color: Color(0xFFBBDEFB)),
        const SizedBox(height: 12),
        const Text('Could not load applications',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _blue)),
        const SizedBox(height: 6),
        Text(error,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 12, color: Color(0xFF78909C))),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
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
