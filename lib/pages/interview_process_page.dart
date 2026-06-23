// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

const _blue = Color(0xFF0D47A1);

// Column display config: [supabase_key, Display Label]
const _columns = [
  ['submitted_at',       'Submitted On'],
  ['name',               'Name'],
  ['mobile',             'Mobile'],
  ['email',              'Email'],
  ['interview_date',     'Interview Date'],
  ['post_applied',       'Post Applied'],
  ['place',              'Place'],
  ['dob',                'DOB'],
  ['nationality',        'Nationality'],
  ['gender',             'Gender'],
  ['marital_status',     'Marital Status'],
  ['age',                'Age'],
  ['total_experience',   'Total Exp.'],
  ['relevant_experience','Relevant Exp.'],
  ['reason_for_change',  'Reason for Change'],
  ['current_ctc',        'Current CTC'],
  ['expected_ctc',       'Expected CTC'],
  ['notice_period',      'Notice Period'],
  ['source',             'Source'],
  ['job_portal',         'Job Portal'],
  ['referred_by',        'Referred By'],
  ['related_employee',   'Related Employee'],
  ['applied_before',     'Applied Before'],
];

class InterviewProcessPage extends StatefulWidget {
  const InterviewProcessPage({super.key});

  @override
  State<InterviewProcessPage> createState() => _InterviewProcessPageState();
}

class _InterviewProcessPageState extends State<InterviewProcessPage> {
  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await SupabaseService.fetchCandidateApplications();
      setState(() {
        _all      = rows;
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
          ? _all
          : _all.where((r) => r.values.any(
              (v) => v.toString().toLowerCase().contains(q))).toList();
    });
  }

  String _cell(Map<String, dynamic> row, String key) {
    final v = row[key];
    if (v == null) return '';
    if (key == 'submitted_at') {
      try {
        final dt = DateTime.parse(v.toString()).toLocal();
        return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } catch (_) { return v.toString(); }
    }
    return v.toString();
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Interview Process',
                            style: TextStyle(fontSize: 22,
                                fontWeight: FontWeight.bold, color: _blue)),
                        Text(
                          '${_all.length} application${_all.length == 1 ? '' : 's'} received',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF78909C)),
                        ),
                      ],
                    ),
                  ),
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
                  const SizedBox(width: 8),
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

                if (_all.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search applications…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _blue, size: 20),
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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _blue))
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _fetch)
                    : _filtered.isEmpty
                        ? const _EmptyState()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFFE3F2FD)),
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 60,
                                  columnSpacing: 20,
                                  headingTextStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _blue),
                                  columns: [
                                    const DataColumn(label: Text('#')),
                                    ..._columns.map((c) =>
                                        DataColumn(label: Text(c[1]))),
                                  ],
                                  rows: _filtered.asMap().entries.map((e) {
                                    final idx = e.key;
                                    final row = e.value;
                                    return DataRow(
                                      color: WidgetStateProperty.resolveWith(
                                        (s) => idx.isEven
                                            ? Colors.white
                                            : const Color(0xFFF8F9FA),
                                      ),
                                      cells: [
                                        DataCell(Text('${idx + 1}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF78909C)))),
                                        ..._columns.map((c) => DataCell(
                                          ConstrainedBox(
                                            constraints:
                                                const BoxConstraints(maxWidth: 180),
                                            child: Text(
                                              _cell(row, c[0]),
                                              style: const TextStyle(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                        )),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
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
        Text('No applications yet',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _blue)),
        SizedBox(height: 6),
        Text('Submitted forms will appear here instantly.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
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
        const Icon(Icons.cloud_off_rounded, size: 52, color: Color(0xFFBBDEFB)),
        const SizedBox(height: 12),
        const Text('Could not load applications',
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
            backgroundColor: _blue, foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}
