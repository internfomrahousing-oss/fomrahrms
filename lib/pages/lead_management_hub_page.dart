import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/lead_service.dart';

class LeadManagementHubPage extends StatefulWidget {
  final String basePath; // e.g. '/lead-management' or '/management/lead-management'
  const LeadManagementHubPage({super.key, required this.basePath});

  @override
  State<LeadManagementHubPage> createState() => _LeadManagementHubPageState();
}

class _LeadManagementHubPageState extends State<LeadManagementHubPage> {
  static const _blue   = Color(0xFF0D47A1);
  static const _fbBlue = Color(0xFF1877F2);

  List<LeadSource> _sources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sources = await LeadService.getSources();
    if (mounted) setState(() { _sources = sources; _loading = false; });
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final urlCtrl  = TextEditingController();
    bool testing   = false;
    String? testMsg;
    bool testOk    = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add new source',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDec('Source name', 'e.g. WhatsApp Leads'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                onChanged: (_) => setSt(() {}),
                decoration: _inputDec('Google Script URL',
                    'https://script.google.com/macros/s/…/exec'),
              ),
              const SizedBox(height: 12),
              if (testMsg != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: testOk
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(testMsg!,
                      style: TextStyle(
                          fontSize: 12,
                          color: testOk ? Colors.green.shade800 : Colors.red.shade800)),
                ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: testing || urlCtrl.text.trim().isEmpty
                      ? null
                      : () async {
                          setSt(() { testing = true; testMsg = null; });
                          try {
                            final r = await LeadService.testUrl(urlCtrl.text.trim());
                            setSt(() {
                              testing = false;
                              testOk  = true;
                              testMsg = '✓ Connected — ${r.count} rows, '
                                  '${r.columns.length} columns: '
                                  '${r.columns.take(5).join(', ')}'
                                  '${r.columns.length > 5 ? '…' : ''}';
                            });
                          } catch (e) {
                            setSt(() {
                              testing = false;
                              testOk  = false;
                              testMsg = 'Error: $e';
                            });
                          }
                        },
                  icon: testing
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_rounded, size: 16),
                  label: const Text('Test connection'),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: urlCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        nameCtrl.text = 'New Source';
                      }
                      final src = await LeadService.addSource(
                          nameCtrl.text, urlCtrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) setState(() => _sources.add(src));
                    },
              child: const Text('Add'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showRenameDialog(LeadSource source) async {
    final ctrl = TextEditingController(text: source.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename source',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDec('Source name', 'e.g. Meta Leads'),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await LeadService.renameSource(source.id, result);
      if (mounted) setState(() => source.name = result.trim());
    }
  }

  Future<void> _confirmDelete(LeadSource source) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete source?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Remove "${source.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await LeadService.deleteSource(source.id);
      if (mounted) setState(() => _sources.removeWhere((s) => s.id == source.id));
    }
  }

  InputDecoration _inputDec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: _blue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add New',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.leaderboard_rounded,
                          color: _blue, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lead Management',
                              style: Theme.of(context).textTheme.headlineMedium),
                          Text(
                            '${_sources.length} source${_sources.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF78909C)),
                          ),
                        ]),
                  ]),
                  const SizedBox(height: 28),

                  if (_sources.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(children: [
                          Icon(Icons.inbox_rounded,
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No sources yet',
                              style: TextStyle(color: Colors.grey.shade500)),
                          const SizedBox(height: 6),
                          const Text('Tap "Add New" to connect a Google Sheet',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF78909C))),
                        ]),
                      ),
                    )
                  else
                    LayoutBuilder(builder: (context, constraints) {
                      final cols = constraints.maxWidth > 700
                          ? 3
                          : constraints.maxWidth > 480
                              ? 2
                              : 1;
                      return _Grid(
                        sources: _sources,
                        cols: cols,
                        basePath: widget.basePath,
                        onRename: _showRenameDialog,
                        onDelete: _confirmDelete,
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

// ── Grid layout ───────────────────────────────────────────────────────────────

class _Grid extends StatelessWidget {
  final List<LeadSource> sources;
  final int cols;
  final String basePath;
  final Future<void> Function(LeadSource) onRename;
  final Future<void> Function(LeadSource) onDelete;

  const _Grid({
    required this.sources,
    required this.cols,
    required this.basePath,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < sources.length; i += cols) {
      final end      = (i + cols) > sources.length ? sources.length : i + cols;
      final rowItems = sources.sublist(i, end);
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rowItems.map((s) {
            final isLast = rowItems.last == s;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 16, bottom: 16),
                child: _SourceCard(
                  source: s,
                  basePath: basePath,
                  onRename: () => onRename(s),
                  onDelete: () => onDelete(s),
                ),
              ),
            );
          }),
          ...List.generate(
              cols - rowItems.length, (_) => const Expanded(child: SizedBox())),
        ],
      ));
    }
    return Column(children: rows);
  }
}

// ── Source card ───────────────────────────────────────────────────────────────

class _SourceCard extends StatelessWidget {
  final LeadSource source;
  final String basePath;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SourceCard({
    required this.source,
    required this.basePath,
    required this.onRename,
    required this.onDelete,
  });

  static const _fbBlue = Color(0xFF1877F2);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          '$basePath/leads',
          extra: {'id': source.id, 'name': source.name, 'url': source.url},
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
          child: Row(children: [
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _fbBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.campaign_rounded, color: _fbBlue, size: 28),
            ),
            const SizedBox(width: 14),

            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E))),
                  const SizedBox(height: 3),
                  const Text('Tap to view leads',
                      style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                ],
              ),
            ),

            // Options menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: Color(0xFF78909C)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'rename') onRename();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
