import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/lead_model.dart';
import '../services/lead_service.dart';
import '../services/notification_service.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

Color get _blue => AppTheme.primaryBlue;


class LeadManagementPage extends StatefulWidget {
  final String url;
  final String name;
  const LeadManagementPage({
    super.key,
    required this.url,
    required this.name,
  });

  @override
  State<LeadManagementPage> createState() => _LeadManagementPageState();
}

class _LeadManagementPageState extends State<LeadManagementPage> {
  List<Lead> _all = [];
  List<Lead> _filtered = [];
  bool _loading = false;
  String? _error;

  bool _showFilter = false;

  // Generic filter state — auto-detected from sheet columns
  Map<String, List<String>> _catOptions  = {}; // col → unique values
  Map<String, String>       _catSelected = {}; // col → selected ('All' = no filter)
  Map<String, double>       _numMin      = {};
  Map<String, double>       _numMax      = {};
  Map<String, RangeValues>  _numRange    = {};

  final _searchCtrl = TextEditingController();

  // Extract first numeric value from a string
  double? _parseNum(String s) {
    final m = RegExp(r'\d+(?:[.]\d+)?').firstMatch(s.replaceAll(',', ''));
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }

  // Prettify a column header for display
  String _prettyCol(String col) => col
      .split(RegExp(r'[\s_]+'))
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  // Format a numeric value for a given column (adds units/currency where obvious)
  String _fmtNum(String col, double v) {
    final u = col.toUpperCase();
    if (u.contains('CTC') || u.contains('SALARY') || u.contains('WAGE') || u.contains('PAY')) {
      return '₹${_fmtCtc(v)}';
    }
    final suffix = (u.contains('EXP') || u.contains('AGE') || u.contains('YEAR')) ? ' yrs' : '';
    return '${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(1)}$suffix';
  }

  void _computeFilters() {
    _catOptions.clear();
    _catSelected.clear();
    _numMin.clear();
    _numMax.clear();
    _numRange.clear();
    if (_all.isEmpty) return;

    // Skip the first column (row key / serial number)
    final skipCol = _all.first.fields.keys.isNotEmpty ? _all.first.fields.keys.first : '';

    for (final col in _all.first.fields.keys) {
      if (col == skipCol) continue;
      final vals = _all
          .map((l) => (l.fields[col] ?? '').trim())
          .where((v) => v.isNotEmpty)
          .toList();
      if (vals.isEmpty) continue;

      // Numeric detection: >70% of non-empty values parse as numbers
      final nums = vals.map(_parseNum).whereType<double>().toList();
      if (nums.length >= vals.length * 0.7 && nums.length >= 3) {
        final mn = nums.reduce((a, b) => a < b ? a : b);
        final mx = nums.reduce((a, b) => a > b ? a : b);
        if (mx > mn) {
          _numMin[col] = mn;
          _numMax[col] = mx;
          _numRange[col] = RangeValues(mn, mx);
        }
      } else {
        // Categorical: 2–8 unique short-text values (exclude free-text/comment columns)
        final unique = vals.toSet().toList()..sort();
        final avgLen = vals.fold<double>(0, (s, v) => s + v.length) / vals.length;
        if (unique.length >= 2 && unique.length <= 8 && avgLen <= 22) {
          _catOptions[col] = unique;
          _catSelected[col] = 'All';
        }
      }
    }
  }

  bool get _hasActiveFilter =>
      _catSelected.values.any((v) => v != 'All') ||
      _numRange.entries.any((e) =>
          e.value.start > _numMin[e.key]! || e.value.end < _numMax[e.key]!);

  void _clearFilters() {
    setState(() {
      for (final col in _catSelected.keys) _catSelected[col] = 'All';
      for (final col in _numRange.keys) {
        _numRange[col] = RangeValues(_numMin[col]!, _numMax[col]!);
      }
    });
    _applyFilter();
  }

  String get _scriptUrl  => widget.url;
  String get _sourceName => widget.name;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _fetch();
  }

  String _shortUrl(String url) {
    final re = RegExp(r'/s/([^/]+)/exec');
    final m = re.firstMatch(url);
    if (m != null) {
      final id = m.group(1)!;
      return 'script…/${id.length > 14 ? id.substring(0, 14) : id}…';
    }
    return url.length > 40 ? '${url.substring(0, 40)}…' : url;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading     = true;
      _error       = null;
      _all         = [];
      _filtered    = [];
    });
    try {
      final leads = await LeadService.fetchLeads(_scriptUrl);
      setState(() {
        _all = leads;
        _computeFilters();
        _filtered = _computeFilter(leads);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Lead> _computeFilter(List<Lead> source) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return source.where((lead) {
      if (q.isNotEmpty &&
          !lead.fields.values.any((v) => v.toLowerCase().contains(q))) return false;
      for (final col in _catSelected.keys) {
        final sel = _catSelected[col]!;
        if (sel != 'All' && (lead.fields[col] ?? '') != sel) return false;
      }
      for (final col in _numRange.keys) {
        final r = _numRange[col]!;
        final v = _parseNum(lead.fields[col] ?? '');
        if (v != null && (v < r.start || v > r.end)) return false;
      }
      return true;
    }).toList();
  }

  void _applyFilter() {
    setState(() => _filtered = _computeFilter(_all));
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'new':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      case 'follow-up':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFF59E0B);
        break;
      case 'interested':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF22C55E);
        break;
      case 'not interested':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFEF4444);
        break;
      case 'converted':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      case 'lost':
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF616161);
        break;
      default:
        bg = const Color(0xFFF8FAFC);
        fg = const Color(0xFF757575);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.isEmpty ? 'Unknown' : status,
        style: TextStyle(
            fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _showEditDialog(Lead lead) async {
    final columns = lead.fields.keys.toList();
    final ctrls   = {
      for (final col in columns)
        col: TextEditingController(text: lead.fields[col] ?? ''),
    };
    final firstCol = columns.isNotEmpty ? columns.first : '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Lead',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: columns.asMap().entries.map((e) {
                final isKey = e.value == firstCol;
                return Padding(
                  padding: EdgeInsets.only(top: e.key == 0 ? 0 : 12),
                  child: TextField(
                    controller: ctrls[e.value],
                    enabled: !isKey, // first column is the row key — read-only
                    decoration: InputDecoration(
                      labelText: e.value,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: isKey,
                      fillColor: isKey ? const Color(0xFFE5E7EB) : null,
                      helperText: isKey ? 'Row identifier — cannot be edited' : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final updatedFields = {
                for (final col in columns) col: ctrls[col]!.text.trim(),
              };
              await _doUpdate(Lead(fields: updatedFields));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in ctrls.values) c.dispose();
  }

  Future<void> _showAddDialog() async {
    final schema = LeadService.schemaFor(_scriptUrl);
    if (schema.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No columns detected yet. Refresh first.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // Auto-compute next value for the first column if it's numeric
    String firstColDefault = '';
    if (_all.isNotEmpty) {
      final nums = _all.map((l) => int.tryParse(l.rowKeyValue) ?? 0).toList();
      final max  = nums.reduce((a, b) => a > b ? a : b);
      firstColDefault = (max + 1).toString();
    } else {
      firstColDefault = '1';
    }

    final ctrls = {
      for (final col in schema)
        col: TextEditingController(
          text: col == schema.first ? firstColDefault : '',
        ),
    };

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add New Lead',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: schema.asMap().entries.map((e) => Padding(
                padding: EdgeInsets.only(top: e.key == 0 ? 0 : 12),
                child: _inputField(
                  e.value,
                  ctrls[e.value]!,
                  keyboard: e.key == 0 ? TextInputType.number : TextInputType.text,
                ),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final fields = {
                for (final col in schema) col: ctrls[col]!.text.trim(),
              };
              await _doAdd(Lead(fields: fields));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    for (final c in ctrls.values) c.dispose();
  }


  Future<void> _showDeleteDialog(Lead lead) async {
    if (!lead.canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot delete: this row has no identifier in the first column'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
        content: Text(
          'Remove "${lead.name}" permanently from Google Sheets?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _doDelete(lead);
  }

  Future<void> _doDelete(Lead lead) async {
    try {
      await LeadService.deleteLead(_scriptUrl, lead);
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${lead.name}" deleted from Google Sheets'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _doUpdate(Lead lead) async {
    try {
      await LeadService.updateLead(_scriptUrl, lead);
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lead updated in Google Sheets'),
          backgroundColor: Color(0xFF22C55E),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _doAdd(Lead lead) async {
    try {
      final prevCount = _all.length;
      await LeadService.addLead(_scriptUrl, lead);
      NotificationService.leadAdded(leadName: lead.name.isNotEmpty ? lead.name : 'New lead');
      // Give GAS up to 4 s to write before re-fetching
      await Future.delayed(const Duration(seconds: 4));
      await _fetch();
      if (!mounted) return;
      if (_all.length > prevCount) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lead added to Google Sheets'),
          backgroundColor: Color(0xFF22C55E),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Lead may not have been saved — try refreshing in a few seconds'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6)));
      }
    }
  }

  void _showDetailDialog(Lead lead) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Text('${lead.rowKeyColumn}: ${lead.rowKeyValue}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                if (lead.status.isNotEmpty)
                  Text(lead.status,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
              ]),
            ),
            // Fields
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: lead.fields.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 180,
                        child: Text(e.key,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(
                          e.value.isEmpty ? '—' : e.value,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  )).toList(),
                ),
              ),
            ),
            // Actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: BorderSide(color: _blue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () { Navigator.pop(ctx); _showEditDialog(lead); },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () { Navigator.pop(ctx); _showDeleteDialog(lead); },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
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
                  const NavBackButton(),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign_rounded,
                        color: Color(0xFF1877F2), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_sourceName,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _blue)),
                        RichText(text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          children: [
                            if (_hasActiveFilter) ...[
                              TextSpan(
                                text: '${_filtered.length}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: _blue),
                              ),
                              TextSpan(text: ' of ${_all.length} leads'),
                            ] else
                              TextSpan(text: '${_all.length} lead${_all.length == 1 ? '' : 's'} total'),
                          ],
                        )),
                        if (_scriptUrl.isNotEmpty)
                          Text(
                            'Sheet: ${_shortUrl(_scriptUrl)}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF6B7280)),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(narrow ? 'Add' : 'Add Lead',
                        style: const TextStyle(fontSize: 13)),
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
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _blue))
                        : Icon(Icons.refresh_rounded, color: _blue),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, project…',
                        prefixIcon: Icon(Icons.search_rounded, color: _blue, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: _searchCtrl.clear,
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filter toggle button
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _showFilter = !_showFilter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _showFilter ? _blue : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _showFilter ? _blue : const Color(0xFFDDDDDD)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.tune_rounded, size: 16,
                                color: _showFilter ? Colors.white : _blue),
                            const SizedBox(width: 5),
                            Text('Filter',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _showFilter ? Colors.white : _blue)),
                          ]),
                        ),
                      ),
                      // Active filter dot
                      if (_hasActiveFilter)
                        Positioned(
                          top: -3, right: -3,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.orange, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ]),

                // Filter panel
                if (_showFilter && _all.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8EDF5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // ── Panel header ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        child: Row(children: [
                          Icon(Icons.tune_rounded, size: 15, color: _blue),
                          const SizedBox(width: 6),
                          Text('Filters',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: _filtered.length < _all.length
                                  ? Colors.orange.withValues(alpha: 0.12)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_filtered.length} / ${_all.length}',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: _filtered.length < _all.length
                                      ? Colors.orange.shade800 : _blue),
                            ),
                          ),
                          const Spacer(),
                          if (_hasActiveFilter)
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.restart_alt_rounded, size: 14),
                              label: const Text('Reset', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orange.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ]),
                      ),
                      const Divider(height: 1),

                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                          // ── Categorical chip filters (one group per column)
                          ..._catOptions.entries.map((entry) {
                            final col = entry.key;
                            final vals = entry.value;
                            final sel = _catSelected[col]!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_prettyCol(col).toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                        color: Color(0xFF6B7280), letterSpacing: 0.8)),
                                const SizedBox(height: 8),
                                Wrap(spacing: 6, runSpacing: 6,
                                  children: ['All', ...vals].map((v) {
                                    final isAll = v == 'All';
                                    final active = sel == v;
                                    final count = isAll
                                        ? _all.length
                                        : _all.where((l) => (l.fields[col] ?? '') == v).length;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() => _catSelected[col] = v);
                                        _applyFilter();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 120),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: active ? _blue : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                              color: active ? _blue : const Color(0xFFDDE3ED)),
                                        ),
                                        child: Text('$v  $count',
                                            style: TextStyle(
                                                fontSize: 12, fontWeight: FontWeight.w600,
                                                color: active ? Colors.white : const Color(0xFF6B7280))),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (entry.key != _catOptions.keys.last || _numRange.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                ],
                              ]),
                            );
                          }),

                          // ── Numeric range sliders (one per column) ─────────
                          ..._numRange.keys.map((col) {
                            final r = _numRange[col]!;
                            final mn = _numMin[col]!;
                            final mx = _numMax[col]!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _RangeRow(
                                label: _prettyCol(col),
                                value: '${_fmtNum(col, r.start)} – ${_fmtNum(col, r.end)}',
                                slider: RangeSlider(
                                  values: r, min: mn, max: mx,
                                  activeColor: _blue,
                                  inactiveColor: const Color(0xFFDBEAFE),
                                  onChanged: (v) {
                                    setState(() => _numRange[col] = v);
                                    _applyFilter();
                                  },
                                ),
                              ),
                            );
                          }),

                          // ── No filterable columns ─────────────────────────
                          if (_catOptions.isEmpty && _numRange.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('No filterable columns detected in this sheet.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              ),
                            ),
                        ]),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: _blue))
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _fetch)
                    : _filtered.isEmpty
                        ? _EmptyState(hasLeads: _all.isNotEmpty)
                        : ListView.builder(
                            padding: EdgeInsets.all(pad),
                            itemCount: _filtered.length,
                            itemBuilder: (context, idx) {
                              final lead = _filtered[idx];
                              return _LeadCard(
                                lead: lead,
                                statusBadge: _statusBadge(lead.status),
                                onTap: () => _showDetailDialog(lead),
                                onEdit: () => _showEditDialog(lead),
                                onDelete: () => _showDeleteDialog(lead),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

String _fmtCtc(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000)   return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toInt().toString();
}

class _RangeRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget slider;
  const _RangeRow({required this.label, required this.value, required this.slider});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
        ),
      ]),
      slider,
    ],
  );
}

// ── Lead Card (compact — tap to view full details) ───────────────────────────

class _LeadCard extends StatelessWidget {
  final Lead lead;
  final Widget statusBadge;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LeadCard({
    required this.lead,
    required this.statusBadge,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name    = lead.name;
    final phone   = lead.phone;
    final project = lead.project;
    final source  = lead.source;
    // Show a few extra columns that aren't already covered above
    final extras = lead.fields.entries
        .where((e) {
          final v = e.value.trim();
          if (v.isEmpty) return false;
          if (v == name || v == phone || v == project || v == source) return false;
          if (v == lead.rowKeyValue) return false;
          return true;
        })
        .take(3)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: _blue.withValues(alpha: 0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      name.isNotEmpty ? name : '(No name)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                  ),
                  statusBadge,
                ]),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ]),
                ],
                if (project.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.work_outline_rounded, size: 11, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(project,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 4,
                    children: extras.map((e) => Text(
                      '${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    )).toList(),
                  ),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            // Row id + actions
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(lead.rowKeyValue,
                    style: TextStyle(fontSize: 10, color: _blue, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                _SmallIconBtn(icon: Icons.edit_rounded, color: _blue, onTap: onEdit),
                const SizedBox(width: 4),
                _SmallIconBtn(icon: Icons.delete_outline_rounded, color: const Color(0xFFEF4444), onTap: onDelete),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallIconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

// ── Empty / Error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasLeads;
  const _EmptyState({required this.hasLeads});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          hasLeads
              ? Icons.search_off_rounded
              : Icons.people_outline_rounded,
          size: 52,
          color: const Color(0xFFDBEAFE),
        ),
        const SizedBox(height: 12),
        Text(
          hasLeads ? 'No leads match your filter' : 'No leads yet',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _blue),
        ),
        const SizedBox(height: 6),
        Text(
          hasLeads
              ? 'Try a different search or status filter.'
              : 'Add your first lead or connect your Google Sheet.',
          textAlign: TextAlign.center,
          style:
              const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
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
        const Icon(Icons.cloud_off_rounded,
            size: 52, color: Color(0xFFDBEAFE)),
        const SizedBox(height: 12),
        Text('Could not load leads',
            style: TextStyle(

                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _blue)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280))),
        ),
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

