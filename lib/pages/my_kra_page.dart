import 'package:flutter/material.dart';
import '../models/kra_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../utils/open_url.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

/// Self-service view of the KRA documents HR has uploaded for the signed-in
/// user — view/download only, no upload (that's HR's job, see
/// kra_management_page.dart).
class MyKraPage extends StatefulWidget {
  const MyKraPage({super.key});

  @override
  State<MyKraPage> createState() => _MyKraPageState();
}

class _MyKraPageState extends State<MyKraPage> {
  static Color get _color => AppTheme.primaryBlue;
  List<KraDocument> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await SupabaseService.fetchKraDocuments();
    if (!mounted) return;
    final me = UserSession.email.trim().toLowerCase();
    setState(() {
      // Only approved documents are visible here — anything HR uploaded is
      // held pending until Management approves it.
      _docs = all.where((d) => d.employeeEmail.trim().toLowerCase() == me && d.isApproved).toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      _loading = false;
    });
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
                child: Icon(Icons.flag_rounded, color: _color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('My KRA', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text('Key Result Area documents uploaded by HR',
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
            else if (_docs.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.flag_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No KRA documents uploaded yet',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13.5)),
                    ]),
                  ),
                ),
              )
            else
              ..._docs.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DocCard(
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
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final KraDocument doc;
  final String dateLabel;
  final VoidCallback onView;
  final VoidCallback onDownload;
  const _DocCard({
    required this.doc,
    required this.dateLabel,
    required this.onView,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_rounded, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 3),
              Text('Uploaded by ${doc.uploadedBy.isEmpty ? 'HR' : doc.uploadedBy} · $dateLabel',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ]),
          ),
          OutlinedButton.icon(
            onPressed: onView,
            icon: const Icon(Icons.visibility_outlined, size: 15),
            label: const Text('View'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 15),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
    );
  }
}
