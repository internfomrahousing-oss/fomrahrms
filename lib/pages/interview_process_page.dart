import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

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
    if (kCandidateScriptUrl.isNotEmpty) _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http
          .get(Uri.parse(kCandidateScriptUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('Server returned ${res.statusCode}');
      final raw = json.decode(res.body) as List;
      if (raw.isEmpty) { setState(() { _loading = false; }); return; }
      final headers = (raw[0] as List).map((e) => e.toString().trim()).toList();
      final rows = raw.skip(1).map((r) {
        final cells = r as List;
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
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Interview Process',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold, color: _blue)),
                      Text('${_rows.length} application${_rows.length == 1 ? '' : 's'} received',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF78909C))),
                    ]),
                  ),
                  // Application Form button
                  ElevatedButton.icon(
                    onPressed: () => html.window.open(
                      '${html.window.location.href.split('#')[0]}#/candidate-application',
                      '_blank',
                    ),
                    icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                    label: const Text('Application Form', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Refresh
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: kCandidateScriptUrl.isEmpty || _loading ? null : _fetch,
                    icon: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
                        : const Icon(Icons.refresh_rounded, color: _blue),
                  ),
                ]),

                // Search bar
                if (_headers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search applications…',
                      prefixIcon: const Icon(Icons.search_rounded, color: _blue, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: _searchCtrl.clear,
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
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: kCandidateScriptUrl.isEmpty
                ? _SetupPrompt()
                : _loading && _rows.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: _blue))
                    : _error != null
                        ? _ErrorView(error: _error!, onRetry: _fetch)
                        : _headers.isEmpty
                            ? _EmptyState()
                            : _DataTable(headers: _headers, rows: _filtered),
          ),
        ],
      ),
    );
  }
}

// ── Empty / setup states ──────────────────────────────────────────────────────

class _SetupPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.link_off_rounded, size: 48, color: Color(0xFFBBDEFB)),
              const SizedBox(height: 16),
              const Text('Google Sheet not connected',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
              const SizedBox(height: 8),
              const Text(
                'Deploy a Google Apps Script and paste the URL in app_config.dart to see submissions here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF78909C)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 52, color: Color(0xFFBBDEFB)),
        SizedBox(height: 12),
        Text('No applications yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _blue)),
        SizedBox(height: 6),
        Text('Submitted forms will appear here.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
      ]),
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
          Text('No matching applications.',
              style: TextStyle(color: Color(0xFF78909C))),
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
                fontSize: 12, fontWeight: FontWeight.w700, color: _blue),
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
                      style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)))),
                  ...headers.map((h) {
                    final val = row[h] ?? '';
                    return DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(val,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2),
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
        const Text('Could not load applications',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _blue)),
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
            backgroundColor: _blue, foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}
