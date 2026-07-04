import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/lead_service.dart';
import '../widgets/back_button.dart';

class LeadManagementHubPage extends StatefulWidget {
  final String basePath; // e.g. '/lead-management' or '/management/lead-management'
  const LeadManagementHubPage({super.key, required this.basePath});

  @override
  State<LeadManagementHubPage> createState() => _LeadManagementHubPageState();
}

class _LeadManagementHubPageState extends State<LeadManagementHubPage> {
  static const _blue   = Color(0xFF0D47A1);

  List<LeadSource> _sources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    LeadService.invalidateCache(); // always read fresh from SharedPreferences
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
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Step-by-step guide
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('How to add a new sheet:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A237E))),
                    const SizedBox(height: 8),
                    ...[
                      '1. Create a Google Sheet with column headers in row 1',
                      '2. Click Share → add info@fomrahousing.in as Editor',
                      '3. Copy the URL from the browser address bar',
                      '4. Paste it below and click Test Connection',
                    ].map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(step,
                              style: const TextStyle(
                                  fontSize: 11.5, color: Color(0xFF283593))),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDec('Source name', 'e.g. WhatsApp Leads'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                onChanged: (_) => setSt(() {}),
                decoration: _inputDec('Google Sheet URL',
                    'https://docs.google.com/spreadsheets/d/…/edit'),
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
                      await LeadService.addSource(
                          nameCtrl.text, urlCtrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      // _sources IS _cachedSources (same reference) — addSource
                      // already mutated it, so just trigger a rebuild
                      if (mounted) setState(() {});
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

  void _showSetupGuide() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D47A1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(children: [
                  const Icon(Icons.integration_instructions_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('How to Add a New Sheet',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
              ),
              // Steps
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Follow these steps for each new Google Sheet:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A237E)),
                      ),
                      const SizedBox(height: 14),
                      _guideStep('1', 'Create the Google Sheet',
                          'Open Google Sheets and create a new spreadsheet. Add your column headers in the first row (e.g. Name, Phone, Status).'),
                      _guideStep('2', 'Open Apps Script',
                          'In the sheet, click Extensions → Apps Script. Or go to script.google.com and click New project.'),
                      _guideStep('3', 'Paste the script code',
                          'Delete everything in the editor. Paste the code below, then click Save (Ctrl+S).'),
                      const _GasCodeBlock(),
                      _guideStep('4', 'Deploy as Web App',
                          'First time: Click Deploy → New deployment → Type: Web app → Execute as: Me → Who has access: Anyone → Deploy → Authorise when prompted.\n\nUpdating existing script: Click Deploy → Manage deployments → pencil icon → change Version to "New version" → Deploy.'),
                      _guideStep('5', 'Copy the /exec URL',
                          'After deploying, copy the URL ending in /exec. That is your Apps Script URL for this sheet.'),
                      _guideStep('6', 'Add it in the app',
                          'Tap Add New here, enter a name, paste the /exec URL, click Test Connection, then Add.'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guideStep(String num, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A237E))),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF546E7A), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
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
      backgroundColor: null,
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
                    const NavBackButton(),
                    const SizedBox(width: 8),
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
                    Expanded(
                      child: Column(
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
                    ),
                    TextButton.icon(
                      onPressed: _showSetupGuide,
                      icon: const Icon(Icons.help_outline_rounded, size: 16),
                      label: const Text('Setup Guide',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: _blue),
                    ),
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
  static const _fbBlue = Color(0xFF1877F2);
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

// ── GAS script code block with Copy button ────────────────────────────────────

class _GasCodeBlock extends StatefulWidget {
  const _GasCodeBlock();
  @override
  State<_GasCodeBlock> createState() => _GasCodeBlockState();
}

class _GasCodeBlockState extends State<_GasCodeBlock> {
  bool _copied = false;

  static const _code = r'''function getVisibleSheet(ss) {
  var sheets = ss.getSheets();
  for (var i = 0; i < sheets.length; i++) {
    if (!sheets[i].isSheetHidden()) return sheets[i];
  }
  return sheets[0];
}

function doGet(e) {
  try {
    var sheetId = e.parameter.spreadsheetId;
    var ss = sheetId
      ? SpreadsheetApp.openById(sheetId)
      : SpreadsheetApp.getActiveSpreadsheet();
    var sheet = getVisibleSheet(ss);
    var action = e.parameter.action;
    if (action === 'list')   return list(sheet);
    if (action === 'add')    return add(sheet, e.parameter);
    if (action === 'update') return update(sheet, e.parameter);
    if (action === 'delete') return deleteRow(sheet, e.parameter);
    return respond({ error: 'Unknown action: ' + action });
  } catch (err) {
    return respond({ error: err.toString() });
  }
}

// Finds the row with the most filled cells within the first 5 rows (the real header row)
function findHeaderRow(data) {
  var best = 0, bestCount = 0;
  for (var i = 0; i < Math.min(data.length, 5); i++) {
    var count = data[i].filter(function(c) { return c !== ''; }).length;
    if (count > bestCount) { bestCount = count; best = i; }
  }
  return best;
}

function list(sheet) {
  var data = sheet.getDataRange().getValues();
  var hi = findHeaderRow(data);
  if (data.length <= hi + 1) return respond([]);
  var headers = data[hi];
  var leads = data.slice(hi + 1)
    .filter(function(row) { return row.some(function(cell) { return cell !== ''; }); })
    .map(function(row) {
      var obj = {};
      headers.forEach(function(h, i) {
        obj[h] = row[i] != null ? String(row[i]) : '';
      });
      return obj;
    });
  return respond(leads);
}

function add(sheet, params) {
  var data = sheet.getRange(1, 1, Math.min(5, sheet.getLastRow()), sheet.getLastColumn()).getValues();
  var hi = findHeaderRow(data);
  var headers = data[hi];
  var newRow = headers.map(function(h) { return params[h] || ''; });
  sheet.appendRow(newRow);
  SpreadsheetApp.flush();
  return respond({ success: true, message: 'Row added' });
}

function update(sheet, params) {
  var data = sheet.getDataRange().getValues();
  var hi = findHeaderRow(data);
  var headers = data[hi];
  var keyValue = params[headers[0]];
  for (var i = hi + 1; i < data.length; i++) {
    if (String(data[i][0]) === String(keyValue)) {
      var updated = headers.map(function(h, j) {
        return params[h] !== undefined ? params[h] : String(data[i][j]);
      });
      sheet.getRange(i+1,1,1,headers.length).setValues([updated]);
      SpreadsheetApp.flush();
      return respond({ success: true, message: 'Row updated' });
    }
  }
  return respond({ error: 'Row not found' });
}

function deleteRow(sheet, params) {
  var data = sheet.getDataRange().getValues();
  var hi = findHeaderRow(data);
  var headers = data[hi];
  var keyValue = params[headers[0]];
  for (var i = hi + 1; i < data.length; i++) {
    if (String(data[i][0]) === String(keyValue)) {
      sheet.deleteRow(i + 1);
      SpreadsheetApp.flush();
      return respond({ success: true, message: 'Row deleted' });
    }
  }
  return respond({ error: 'Row not found' });
}

function respond(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}''';

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: _code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(children: [
              const Icon(Icons.code_rounded, size: 13, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Apps Script code',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
              ),
              GestureDetector(
                onTap: _copy,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _copied
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _copied
                          ? Icons.check_rounded
                          : Icons.copy_rounded,
                      size: 12,
                      color: _copied
                          ? Colors.white
                          : const Color(0xFFCCCCCC),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _copied ? 'Copied!' : 'Copy',
                      style: TextStyle(
                          fontSize: 11,
                          color: _copied
                              ? Colors.white
                              : const Color(0xFFCCCCCC)),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          // Code
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              _code,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  color: Color(0xFFCE9178),
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
