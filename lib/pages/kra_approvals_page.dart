import 'package:flutter/material.dart';
import '../models/kra_store.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../utils/open_url.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

/// Management's queue of HR-uploaded KRA documents awaiting approval, plus
/// recently decided ones for reference. Management's own uploads never land
/// here — they're saved pre-approved (see employee_kra_page.dart).
class KraApprovalsPage extends StatefulWidget {
  const KraApprovalsPage({super.key});

  @override
  State<KraApprovalsPage> createState() => _KraApprovalsPageState();
}

class _KraApprovalsPageState extends State<KraApprovalsPage> {
  static Color get _color => AppTheme.primaryBlue;
  List<KraDocument> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await SupabaseService.fetchKraDocuments();
    if (!mounted) return;
    setState(() {
      _all = docs;
      _loading = false;
    });
  }

  List<KraDocument> get _pending => _all.where((d) => d.isPending).toList();
  List<KraDocument> get _decided =>
      _all.where((d) => !d.isPending).toList()
        ..sort((a, b) => (DateTime.tryParse(b.decidedAt) ?? DateTime(0))
            .compareTo(DateTime.tryParse(a.decidedAt) ?? DateTime(0)));

  Future<String?> _promptReviewNote(String title) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Reason (optional):', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final result = (ok == true) ? ctrl.text.trim() : null;
    ctrl.dispose();
    return result;
  }

  Future<void> _decide(KraDocument doc, bool approve) async {
    String reviewNote = '';
    if (!approve) {
      final note = await _promptReviewNote('Reject "${doc.fileName}"?');
      if (note == null) return; // cancelled
      reviewNote = note;
    }
    try {
      await SupabaseService.updateKraStatus(
        doc.id,
        approve ? 'approved' : 'rejected',
        decidedBy: UserSession.name,
        reviewNote: reviewNote,
      );
      await NotificationService.kraDecided(employeeName: doc.employeeName, approved: approve);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Approved' : 'Rejected'),
        backgroundColor: approve ? Colors.green.shade700 : Colors.red.shade700,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save decision: $e'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.fact_check_rounded, color: _color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('KRA Approvals',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text('HR-uploaded KRA documents awaiting your review',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ]),
              ),
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))),
                child: IconButton(
                  tooltip: 'Refresh',
                  icon: Icon(Icons.refresh_rounded, color: _color, size: 20),
                  onPressed: _load,
                ),
              ),
            ]),
            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text('Pending (${_pending.length})',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              if (_pending.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.check_circle_outline_rounded, size: 44, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text("You're all caught up", style: TextStyle(color: Colors.grey.shade400, fontSize: 13.5)),
                      ]),
                    ),
                  ),
                )
              else
                ..._pending.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PendingCard(
                        doc: d,
                        dateLabel: _fmt(d.uploadedAt),
                        onView: () async {
                          final url = await SupabaseService.resolveAttachmentUrl(d.fileUrl, bucket: 'RESUME');
                          if (url != null) viewAttachment(url);
                        },
                        onDownload: () async {
                          final url = await SupabaseService.resolveAttachmentUrl(d.fileUrl, bucket: 'RESUME');
                          if (url != null) downloadUrl(url);
                        },
                        onApprove: () => _decide(d, true),
                        onReject: () => _decide(d, false),
                      ),
                    )),

              if (_decided.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Recently Decided',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                ..._decided.take(20).map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DecidedCard(doc: d),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final KraDocument doc;
  final String dateLabel;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _PendingCard({
    required this.doc,
    required this.dateLabel,
    required this.onView,
    required this.onDownload,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              child: Text(doc.employeeName.isNotEmpty ? doc.employeeName[0].toUpperCase() : '?',
                  style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(doc.employeeName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                Text(doc.fileName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Uploaded by ${doc.uploadedBy.isEmpty ? 'HR' : doc.uploadedBy} · $dateLabel',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: onView,
              icon: const Icon(Icons.visibility_outlined, size: 15),
              label: const Text('View'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 15),
              label: const Text('Download'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded, size: 15),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_rounded, size: 15),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _DecidedCard extends StatelessWidget {
  final KraDocument doc;
  const _DecidedCard({required this.doc});

  String _fmtIso(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final approved = doc.isApproved;
    final color = approved ? Colors.green.shade700 : Colors.red.shade700;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(approved ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${doc.employeeName} · ${doc.fileName}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              Text('${approved ? 'Approved' : 'Rejected'} by ${doc.decidedBy.isEmpty ? '—' : doc.decidedBy} · ${_fmtIso(doc.decidedAt)}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              if (!approved && doc.reviewNote.isNotEmpty)
                Text('Reason: ${doc.reviewNote}',
                    style: TextStyle(fontSize: 11.5, color: Colors.red.shade700, fontStyle: FontStyle.italic)),
            ]),
          ),
        ]),
      ),
    );
  }
}
