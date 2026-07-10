import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/kra_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../utils/open_url.dart';
import '../widgets/app_file_picker.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class EmployeeKraPage extends StatefulWidget {
  final AppUser employee;
  const EmployeeKraPage({super.key, required this.employee});

  @override
  State<EmployeeKraPage> createState() => _EmployeeKraPageState();
}

class _EmployeeKraPageState extends State<EmployeeKraPage> {
  static Color get _color => AppTheme.primaryBlue;
  static const _mimeByExt = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  bool get _canManage =>
      UserSession.role == UserRole.hr || UserSession.role == UserRole.management;

  List<KraDocument> _docs = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await SupabaseService.fetchKraDocuments();
    if (!mounted) return;
    setState(() {
      _docs = all.where((d) => d.employeeEmail == widget.employee.email).toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      _loading = false;
    });
  }

  String _mimeFromName(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return _mimeByExt[ext] ?? 'application/octet-stream';
  }

  Future<void> _handleUpload(List<PlatformFile> files) async {
    final file = files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not read the selected file'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('File too large (max 5 MB)'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _uploading = true);
    try {
      final url = await SupabaseService.uploadKraFile(bytes, file.name, _mimeFromName(file.name));
      final doc = KraDocument(
        id: KraStore.generateId(),
        employeeEmail: widget.employee.email,
        employeeName: widget.employee.name,
        fileName: file.name,
        fileUrl: url,
        uploadedBy: UserSession.name,
      );
      await SupabaseService.saveKraDocument(doc);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Uploaded ${doc.fileName}'),
        backgroundColor: _color,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(KraDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove KRA document?'),
        content: Text('This removes "${doc.fileName}" for ${widget.employee.name}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseService.deleteKraDocument(doc.id);
    await _load();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final u = widget.employee;
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
              CircleAvatar(
                radius: 22,
                backgroundColor: _color.withValues(alpha: 0.12),
                child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                    style: TextStyle(color: _color, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text(
                      [u.designation, u.department].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ]),
              ),
              if (_canManage)
                AppFilePicker(
                  accept: '.pdf,.doc,.docx,image/*',
                  onFiles: _handleUpload,
                  builder: (trigger) => ElevatedButton.icon(
                    onPressed: _uploading ? null : trigger,
                    icon: _uploading
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_file_rounded, size: 16),
                    label: Text(_uploading ? 'Uploading…' : 'Upload KRA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 24),

            Text('KRA Documents',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
            const SizedBox(height: 12),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_docs.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.flag_outlined, size: 44, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No KRA documents yet',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13.5)),
                      if (_canManage) ...[
                        const SizedBox(height: 4),
                        Text('Tap "Upload KRA" to add one',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ]),
                  ),
                ),
              )
            else
              ..._docs.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DocCard(
                      doc: d,
                      canManage: _canManage,
                      dateLabel: _fmt(d.uploadedAt),
                      onView: () => viewAttachment(d.fileUrl),
                      onDownload: () => downloadUrl(d.fileUrl),
                      onDelete: () => _delete(d),
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
  final bool canManage;
  final String dateLabel;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  const _DocCard({
    required this.doc,
    required this.canManage,
    required this.dateLabel,
    required this.onView,
    required this.onDownload,
    required this.onDelete,
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
              Text('Uploaded by ${doc.uploadedBy.isEmpty ? '—' : doc.uploadedBy} · $dateLabel',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ]),
          ),
          IconButton(
            tooltip: 'View',
            icon: const Icon(Icons.visibility_outlined, size: 19),
            onPressed: onView,
          ),
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_rounded, size: 19),
            onPressed: onDownload,
          ),
          if (canManage)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.red),
              onPressed: onDelete,
            ),
        ]),
      ),
    );
  }
}
