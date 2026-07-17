import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../models/candidate_store.dart';
import '../models/user_session.dart';
import '../widgets/back_button.dart';
import '../widgets/filter_panel.dart';

const _blue = Color(0xFF111827);

const _avatarPalette = <Color>[
  Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF22C55E),
  Color(0xFFF59E0B), Color(0xFF06B6D4), Color(0xFF8B5CF6),
  Color(0xFFEF4444), Color(0xFF14B8A6),
];
Color _avatarColor(String name) =>
    _avatarPalette[name.isEmpty ? 0 : name.codeUnitAt(0) % _avatarPalette.length];

enum _ReviewFilter { all, pending, accepted, rejected }

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
  String _search = '';
  _ReviewFilter _filter = _ReviewFilter.all;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String _statusOf(Map<String, dynamic> row) =>
      (row['manager_status'] as String?) ?? 'pending';

  int get _countPending  => _items.where((r) => _statusOf(r) == 'pending').length;
  int get _countAccepted => _items.where((r) => _statusOf(r) == 'accepted').length;
  int get _countRejected => _items.where((r) => _statusOf(r) == 'rejected').length;

  List<Map<String, dynamic>> get _filteredItems {
    final q = _search.trim().toLowerCase();
    return _items.where((r) {
      final status = _statusOf(r);
      final matchesFilter = switch (_filter) {
        _ReviewFilter.all => true,
        _ReviewFilter.pending => status == 'pending',
        _ReviewFilter.accepted => status == 'accepted',
        _ReviewFilter.rejected => status == 'rejected',
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return r.values.any((v) => v.toString().toLowerCase().contains(q));
    }).toList();
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
              backgroundColor: const Color(0xFFEF4444),
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
      final fields = <String, dynamic>{
        'manager_status':    status,
        'manager_status_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (comment != null) fields['manager_comment'] = comment;
      await SupabaseService.updateCandidateStatus(id, fields);
      final candidateName = (row['name'] ?? '').toString();
      if (status == 'accepted') {
        NotificationService.candidateReadyForManagement(candidateName: candidateName);
      }
      NotificationService.interviewDecided(
        candidateName: candidateName, stage: 'Manager', accepted: status == 'accepted',
      );
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
      color: null,
      child: SingleChildScrollView(child: Column(children: [
        // ── Header ────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
          child: Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _blue)),
                  Text(
                    '${_items.length} candidate${_items.length == 1 ? '' : 's'} assigned to you',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
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

        if (_items.isNotEmpty)
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
            child: Column(children: [
              _ReviewStatsRow(
                total: _items.length,
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
                    prefixIcon: const Icon(Icons.search_rounded, color: _blue, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                );
                final filterBtn = FilterTriggerButton(
                  hasActiveFilters: _filter != _ReviewFilter.all,
                  onTap: () {
                    _ReviewFilter draft = _filter;
                    showFilterPanel(
                      context,
                      title: 'Filters',
                      onReset: () => draft = _ReviewFilter.all,
                      onApply: () => setState(() => _filter = draft),
                      builder: (context, setPanelState) => FilterChipGroup<_ReviewFilter>(
                        label: 'Status',
                        value: draft == _ReviewFilter.all ? null : draft,
                        options: const [_ReviewFilter.pending, _ReviewFilter.accepted, _ReviewFilter.rejected],
                        labelOf: (f) => switch (f) {
                          _ReviewFilter.all => 'All (${_items.length})',
                          _ReviewFilter.pending => 'Pending ($_countPending)',
                          _ReviewFilter.accepted => 'Accepted ($_countAccepted)',
                          _ReviewFilter.rejected => 'Rejected ($_countRejected)',
                        },
                        onChanged: (v) => setPanelState(() => draft = v ?? _ReviewFilter.all),
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

        // ── Body ──────────────────────────────────────────────────────
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: _blue)),
              )
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _fetch)
                : _items.isEmpty
                    ? const _EmptyState()
                    : _filteredItems.isEmpty
                        ? const _EmptyFilterState()
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: _filteredItems.map(_buildCandidateCard).toList()),
                          ),
      ])),
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> row) {
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
                                      ? const Color(0xFF86EFAC)
                                      : mStatus == 'rejected'
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFE5E7EB),
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
                                          backgroundColor: _avatarColor(name)
                                              .withValues(alpha: 0.15),
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                                color: _avatarColor(name),
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
                                          color: Color(0xFFE5E7EB)),
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
                                        color: Color(0xFFE5E7EB)),
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
                                                  const Color(0xFF22C55E),
                                              onTap: () =>
                                                  _showAcceptDialog(row),
                                            ),
                                            _ActionBtn(
                                              label: 'Reject',
                                              icon: Icons.cancel_outlined,
                                              color:
                                                  const Color(0xFFEF4444),
                                              onTap: () =>
                                                  _showRejectDialog(row),
                                            ),
                                          ],
                                          _ActionBtn(
                                            label: 'Comment',
                                            icon: Icons.comment_outlined,
                                            color:
                                                const Color(0xFF6B7280),
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
                  color: Color(0xFF6B7280))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280)),
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
        Icon(Icons.inbox_rounded, size: 52, color: Color(0xFFDBEAFE)),
        SizedBox(height: 12),
        Text('No candidates assigned to you',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _blue)),
        SizedBox(height: 6),
        Text('HR will assign candidates here for your review.',
            style:
                TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
      ('Total Assigned', '$total', Icons.people_alt_rounded, _blue),
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

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded,
            size: 52, color: Color(0xFFDBEAFE)),
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
                const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
