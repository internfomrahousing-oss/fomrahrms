import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── PASTE YOUR APPS SCRIPT URL HERE after deploying ──────────────────────────
// Extensions → Apps Script → Deploy → New deployment → Web app → Anyone
const _kScriptUrl = 'https://script.google.com/macros/s/AKfycbx_7ND_IorBm_YhP9hCa7VJewEJ0EpxQ5hb32DIHqs9MFBm2spzMUNuW7nCbz-68UeuMA/exec';
// ─────────────────────────────────────────────────────────────────────────────

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
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    if (_kScriptUrl.isNotEmpty) _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uri = Uri.parse(_kScriptUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('Server returned ${res.statusCode}');
      // Response is a 2D array: first row = headers, rest = data rows
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
                    if (_kScriptUrl.isNotEmpty)
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
                if (_kScriptUrl.isNotEmpty && _headers.isNotEmpty)
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
            child: _kScriptUrl.isEmpty
                ? _SetupInstructions()
                : _loading && _rows.isEmpty
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
                    return DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
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

// ── Setup instructions ────────────────────────────────────────────────────────

class _SetupInstructions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.integration_instructions_rounded,
                          color: _blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Connect Google Form Responses',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _blue)),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _Step(n: 1, text: 'Open your Google Sheet'),
                  _Step(n: 2, text: 'Click Extensions → Apps Script'),
                  _Step(n: 3, text: 'Paste the script from your developer and click Save'),
                  _Step(n: 4, text: 'Click Deploy → New deployment → Web app'),
                  _Step(n: 5, text: 'Set "Who has access" to Anyone → Deploy'),
                  _Step(n: 6, text: 'Copy the Web App URL'),
                  _Step(n: 7, text: 'Give the URL to your developer — they will paste it into the app'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFF57F17)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Once set up, new Google Form submissions will appear here automatically.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
              color: _blue, shape: BoxShape.circle),
          child: Center(
            child: Text('$n',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF37474F))),
          ),
        ),
      ]),
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
