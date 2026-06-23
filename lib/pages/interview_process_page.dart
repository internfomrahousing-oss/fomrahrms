import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kDefaultScriptUrl = 'https://script.google.com/macros/s/AKfycbx_7ND_IorBm_YhP9hCa7VJewEJ0EpxQ5hb32DIHqs9MFBm2spzMUNuW7nCbz-68UeuMA/exec';
const _kUrlPrefKey = 'interview_script_url';

const _blue = Color(0xFF0D47A1);

class InterviewProcessPage extends StatefulWidget {
  const InterviewProcessPage({super.key});

  @override
  State<InterviewProcessPage> createState() => _InterviewProcessPageState();
}

class _InterviewProcessPageState extends State<InterviewProcessPage> {
  List<String> _headers = [];
  List<Map<String, String>> _rows = [];
  List<Map<String, String>> _filtered = [];
  bool _loading = false;
  String? _error;
  String _scriptUrl = _kDefaultScriptUrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _loadUrlThenFetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUrlThenFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kUrlPrefKey);
    if (saved != null && saved.isNotEmpty) {
      setState(() => _scriptUrl = saved);
    }
    if (_scriptUrl.isNotEmpty) _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uri = Uri.parse(_scriptUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('Server returned ${res.statusCode}');
      final raw = json.decode(res.body) as List;
      if (raw.isEmpty) { setState(() { _loading = false; }); return; }
      final headers = (raw[0] as List).map((e) => e.toString().trim()).toList();
      final rows = raw.skip(1).map((r) {
        final cells = (r as List);
        final map = <String, String>{};
        for (int i = 0; i < headers.length; i++) {
          map[headers[i]] = i < cells.length ? cells[i].toString() : '';
        }
        return map;
      }).toList();
      setState(() {
        _headers  = headers;
        _rows     = rows;
        _filtered = rows;
        _loading  = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _rows
          : _rows.where((r) => r.values.any((v) => v.toLowerCase().contains(q))).toList();
    });
  }

  void _showSettings() {
    final ctrl = TextEditingController(text: _scriptUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.settings_rounded, color: _blue, size: 20),
          SizedBox(width: 8),
          Text('Interview Form Settings',
              style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Google Apps Script URL',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'https://script.google.com/macros/s/...',
                  hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 12),
                  prefixIcon: const Icon(Icons.link_rounded, color: _blue, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _blue, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBCCF0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How to get the URL:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
                    SizedBox(height: 4),
                    Text('1. Open Google Sheet → Extensions → Apps Script',
                        style: TextStyle(fontSize: 11, color: Color(0xFF37474F))),
                    Text('2. Deploy → New deployment → Web app',
                        style: TextStyle(fontSize: 11, color: Color(0xFF37474F))),
                    Text('3. Set "Who has access" to Anyone → Deploy',
                        style: TextStyle(fontSize: 11, color: Color(0xFF37474F))),
                    Text('4. Copy and paste the Web App URL here',
                        style: TextStyle(fontSize: 11, color: Color(0xFF37474F))),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_kUrlPrefKey, _kDefaultScriptUrl);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              setState(() {
                _scriptUrl = _kDefaultScriptUrl;
                _headers = [];
                _rows = [];
                _filtered = [];
              });
              _fetch();
            },
            child: const Text('Reset to Default', style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isEmpty) return;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_kUrlPrefKey, url);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              setState(() {
                _scriptUrl = url;
                _headers = [];
                _rows = [];
                _filtered = [];
              });
              _fetch();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save & Reload'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad = narrow ? 16.0 : 24.0;

    return Material(
      color: const Color(0xFFF5F7FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!narrow) ...[
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.record_voice_over_rounded,
                          color: _blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Interview Process',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _blue)),
                      Text('${_rows.length} response${_rows.length == 1 ? '' : 's'} from Google Form',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF78909C))),
                    ]),
                    const Spacer(),
                    // Candidate Application Form button
                    ElevatedButton.icon(
                      onPressed: () => html.window.open(
                        '${html.window.location.href.split('#')[0]}#/candidate-application',
                        '_blank',
                      ),
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
                    const SizedBox(width: 4),
                    // Settings icon
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: _showSettings,
                      icon: const Icon(Icons.settings_rounded, color: _blue),
                    ),
                    // Refresh icon
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
                  const SizedBox(height: 16),
                ],

                // Search bar (only when data is loaded)
                if (_headers.isNotEmpty)
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search responses…',
                      prefixIcon: const Icon(Icons.search_rounded, color: _blue, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () { _searchCtrl.clear(); },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Expanded(
            child: _loading && _rows.isEmpty
                ? const Center(child: CircularProgressIndicator(color: _blue))
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _fetch)
                    : _headers.isEmpty
                        ? const Center(
                            child: Text('No data yet.',
                                style: TextStyle(color: Color(0xFF78909C))))
                        : _DataTable(headers: _headers, rows: _filtered),
          ),
        ],
      ),
    );
  }
}

// ── Data table ────────────────────────────────────────────────────────────────

class _DataTable extends StatelessWidget {
  final List<String> headers;
  final List<Map<String, String>> rows;
  const _DataTable({required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFBBDEFB)),
          SizedBox(height: 12),
          Text('No matching responses.', style: TextStyle(color: Color(0xFF78909C))),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFE3F2FD)),
            dataRowMinHeight: 44,
            dataRowMaxHeight: 60,
            columnSpacing: 24,
            headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _blue),
            columns: [
              const DataColumn(label: Text('#')),
              ...headers.map((h) => DataColumn(label: Text(h))),
            ],
            rows: rows.asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              return DataRow(
                color: WidgetStateProperty.resolveWith(
                  (s) => idx.isEven ? Colors.white : const Color(0xFFF8F9FA),
                ),
                cells: [
                  DataCell(Text('${idx + 1}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF78909C)))),
                  ...headers.map((h) {
                    final val = row[h] ?? '';
                    final isUrl = val.startsWith('http://') || val.startsWith('https://');
                    return DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: isUrl
                            ? MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => html.window.open(val, '_blank'),
                                  child: Text(
                                    val,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1565C0),
                                      decoration: TextDecoration.underline,
                                      decorationColor: Color(0xFF1565C0),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              )
                            : Text(
                                val,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 52, color: Color(0xFFBBDEFB)),
        const SizedBox(height: 12),
        const Text('Could not load responses',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _blue)),
        const SizedBox(height: 6),
        Text(error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF78909C))),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}
