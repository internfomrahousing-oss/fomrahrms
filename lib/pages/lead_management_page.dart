import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/lead_model.dart';
import '../services/lead_service.dart';

const _blue = Color(0xFF0D47A1);


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

  // Position chip filter
  String _positionFilter = 'All';
  List<String> _positionOptions = ['All'];

  // Range filters — values and detected bounds
  double _expMin = 0, _expMax = 20;
  double _relExpMin = 0, _relExpMax = 20;
  double _ctcMin = 0, _ctcMax = 100000;
  double _ageMin = 18, _ageMax = 60;
  late RangeValues _expRange;
  late RangeValues _relExpRange;
  late RangeValues _ctcRange;
  late RangeValues _ageRange;

  // Detected column names from sheet headers
  String? _colPosition;
  String? _colTotalExp;
  String? _colRelExp;
  String? _colCtc;
  String? _colAge;

  final _searchCtrl = TextEditingController();

  // Column detection helper
  String? _findCol(List<String> keywords) {
    if (_all.isEmpty) return null;
    for (final key in _all.first.fields.keys) {
      final u = key.toUpperCase();
      if (keywords.any((kw) => u.contains(kw))) return key;
    }
    return null;
  }

  // Extract first numeric value from a string
  double? _parseNum(String s) {
    final m = RegExp(r'[\d]+(?:[.,]\d+)?').firstMatch(s.replaceAll(',', ''));
    if (m == null) return null;
    return double.tryParse(m.group(0)!.replaceAll(',', ''));
  }

  List<double> _numericVals(String? col) {
    if (col == null) return [];
    return _all
        .map((l) => _parseNum(l.fields[col] ?? ''))
        .whereType<double>()
        .toList();
  }

  void _computeRanges() {
    _colPosition = _findCol(['APPLIED POSITION', 'POSITION', 'APPLIED']);
    _colTotalExp = _findCol(['TOTAL EXP', 'TOTAL EXPERIENCE', 'EXPERIENCE']);
    _colRelExp   = _findCol(['RELEVANT EXP', 'RELEVANT EXPERIENCE', 'RELAVANT']);
    _colCtc      = _findCol(['EXPECTED CTC', 'EXPECTED SALARY', 'CTC']);
    _colAge      = _findCol(['AGE']);

    // Position options
    if (_colPosition != null) {
      final vals = _all.map((l) => l.fields[_colPosition!] ?? '').where((v) => v.isNotEmpty).toSet().toList()..sort();
      _positionOptions = ['All', ...vals];
    } else {
      _positionOptions = ['All'];
    }
    _positionFilter = 'All';

    _setRange(_numericVals(_colTotalExp), 0, 20, (mn, mx) { _expMin = mn; _expMax = mx; _expRange = RangeValues(mn, mx); });
    _setRange(_numericVals(_colRelExp),   0, 20, (mn, mx) { _relExpMin = mn; _relExpMax = mx; _relExpRange = RangeValues(mn, mx); });
    _setRange(_numericVals(_colCtc),      0, 100000, (mn, mx) { _ctcMin = mn; _ctcMax = mx; _ctcRange = RangeValues(mn, mx); });
    _setRange(_numericVals(_colAge),      18, 60, (mn, mx) { _ageMin = mn; _ageMax = mx; _ageRange = RangeValues(mn, mx); });
  }

  void _setRange(List<double> vals, double defMin, double defMax, void Function(double, double) apply) {
    if (vals.isEmpty) { apply(defMin, defMax); return; }
    final mn = vals.reduce((a, b) => a < b ? a : b);
    final mx = vals.reduce((a, b) => a > b ? a : b);
    apply(mn == mx ? defMin : mn, mn == mx ? defMax : mx);
  }

  bool get _hasActiveFilter {
    return _positionFilter != 'All' ||
        (_colTotalExp != null && (_expRange.start > _expMin || _expRange.end < _expMax)) ||
        (_colRelExp   != null && (_relExpRange.start > _relExpMin || _relExpRange.end < _relExpMax)) ||
        (_colCtc      != null && (_ctcRange.start > _ctcMin || _ctcRange.end < _ctcMax)) ||
        (_colAge      != null && (_ageRange.start > _ageMin || _ageRange.end < _ageMax));
  }

  void _clearFilters() {
    setState(() {
      _positionFilter = 'All';
      _expRange    = RangeValues(_expMin, _expMax);
      _relExpRange = RangeValues(_relExpMin, _relExpMax);
      _ctcRange    = RangeValues(_ctcMin, _ctcMax);
      _ageRange    = RangeValues(_ageMin, _ageMax);
    });
    _applyFilter();
  }

  String get _scriptUrl  => widget.url;
  String get _sourceName => widget.name;

  @override
  void initState() {
    super.initState();
    _expRange    = RangeValues(_expMin, _expMax);
    _relExpRange = RangeValues(_relExpMin, _relExpMax);
    _ctcRange    = RangeValues(_ctcMin, _ctcMax);
    _ageRange    = RangeValues(_ageMin, _ageMax);
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
      _filterValue = 'All';
    });
    try {
      final leads = await LeadService.fetchLeads(_scriptUrl);
      setState(() {
        _all = leads;
        _computeRanges();
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
      // Search
      if (q.isNotEmpty && !lead.fields.values.any((v) => v.toLowerCase().contains(q))) return false;
      // Position chip
      if (_positionFilter != 'All' && _colPosition != null &&
          (lead.fields[_colPosition!] ?? '') != _positionFilter) return false;
      // Range: total exp
      if (_colTotalExp != null) {
        final v = _parseNum(lead.fields[_colTotalExp!] ?? '');
        if (v != null && (v < _expRange.start || v > _expRange.end)) return false;
      }
      // Range: relevant exp
      if (_colRelExp != null) {
        final v = _parseNum(lead.fields[_colRelExp!] ?? '');
        if (v != null && (v < _relExpRange.start || v > _relExpRange.end)) return false;
      }
      // Range: expected CTC
      if (_colCtc != null) {
        final v = _parseNum(lead.fields[_colCtc!] ?? '');
        if (v != null && (v < _ctcRange.start || v > _ctcRange.end)) return false;
      }
      // Range: age
      if (_colAge != null) {
        final v = _parseNum(lead.fields[_colAge!] ?? '');
        if (v != null && (v < _ageRange.start || v > _ageRange.end)) return false;
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
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF0D47A1);
        break;
      case 'follow-up':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case 'interested':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'not interested':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      case 'converted':
        bg = const Color(0xFFF3E5F5);
        fg = const Color(0xFF6A1B9A);
        break;
      case 'lost':
        bg = const Color(0xFFEEEEEE);
        fg = const Color(0xFF616161);
        break;
      default:
        bg = const Color(0xFFF5F5F5);
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
        title: const Text('Edit Lead',
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
                      fillColor: isKey ? const Color(0xFFF0F0F0) : null,
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
        title: const Text('Add New Lead',
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
                fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
        content: Text(
          'Remove "${lead.name}" permanently from Google Sheets?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF546E7A)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
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
          backgroundColor: const Color(0xFFC62828),
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
          backgroundColor: Color(0xFF2E7D32),
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
      // Give GAS up to 4 s to write before re-fetching
      await Future.delayed(const Duration(seconds: 4));
      await _fetch();
      if (!mounted) return;
      if (_all.length > prevCount) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lead added to Google Sheets'),
          backgroundColor: Color(0xFF2E7D32),
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
              decoration: const BoxDecoration(
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
                                fontSize: 12, color: Color(0xFF78909C), fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(
                          e.value.isEmpty ? '—' : e.value,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1A237E), fontWeight: FontWeight.w500),
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
                    side: const BorderSide(color: _blue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () { Navigator.pop(ctx); _showEditDialog(lead); },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: const BorderSide(color: Color(0xFFC62828)),
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: _blue),
                    onPressed: () => context.pop(),
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
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
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _blue)),
                        Text(
                          '${_all.length} lead${_all.length == 1 ? '' : 's'} total',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF78909C)),
                        ),
                        if (_scriptUrl.isNotEmpty)
                          Text(
                            'Sheet: ${_shortUrl(_scriptUrl)}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF90A4AE)),
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
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _blue))
                        : const Icon(Icons.refresh_rounded, color: _blue),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, project…',
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
                            color: _showFilter ? _blue : const Color(0xFFF5F7FA),
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Header row with Clear All
                      Row(children: [
                        const Text('Filters',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
                        const Spacer(),
                        if (_hasActiveFilter)
                          GestureDetector(
                            onTap: _clearFilters,
                            child: const Text('Clear All',
                                style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
                          ),
                      ]),
                      const SizedBox(height: 12),

                      // Applied Position chips
                      if (_colPosition != null) ...[
                        const Text('Applied Position',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF546E7A))),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _positionOptions.map((v) {
                              final isSelected = _positionFilter == v;
                              final count = v == 'All'
                                  ? _all.length
                                  : _all.where((l) => (l.fields[_colPosition!] ?? '') == v).length;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () { setState(() => _positionFilter = v); _applyFilter(); },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelected ? _blue : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isSelected ? _blue : const Color(0xFFCCCCCC)),
                                    ),
                                    child: Text(
                                      count > 0 ? '$v ($count)' : v,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.white : const Color(0xFF546E7A)),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Range sliders
                      if (_colTotalExp != null) ...[
                        _RangeLabel('Total Experience',
                            '${_expRange.start.toStringAsFixed(1)} – ${_expRange.end.toStringAsFixed(1)} yrs'),
                        RangeSlider(
                          values: _expRange,
                          min: _expMin, max: _expMax,
                          activeColor: _blue,
                          inactiveColor: const Color(0xFFBBDEFB),
                          onChanged: (v) { setState(() => _expRange = v); _applyFilter(); },
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_colRelExp != null) ...[
                        _RangeLabel('Relevant Experience',
                            '${_relExpRange.start.toStringAsFixed(1)} – ${_relExpRange.end.toStringAsFixed(1)} yrs'),
                        RangeSlider(
                          values: _relExpRange,
                          min: _relExpMin, max: _relExpMax,
                          activeColor: _blue,
                          inactiveColor: const Color(0xFFBBDEFB),
                          onChanged: (v) { setState(() => _relExpRange = v); _applyFilter(); },
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_colCtc != null) ...[
                        _RangeLabel('Expected CTC',
                            '₹${_fmtCtc(_ctcRange.start)} – ₹${_fmtCtc(_ctcRange.end)}'),
                        RangeSlider(
                          values: _ctcRange,
                          min: _ctcMin, max: _ctcMax,
                          activeColor: _blue,
                          inactiveColor: const Color(0xFFBBDEFB),
                          onChanged: (v) { setState(() => _ctcRange = v); _applyFilter(); },
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_colAge != null) ...[
                        _RangeLabel('Age',
                            '${_ageRange.start.toInt()} – ${_ageRange.end.toInt()} yrs'),
                        RangeSlider(
                          values: _ageRange,
                          min: _ageMin, max: _ageMax,
                          divisions: (_ageMax - _ageMin).toInt().clamp(1, 100),
                          activeColor: _blue,
                          inactiveColor: const Color(0xFFBBDEFB),
                          onChanged: (v) { setState(() => _ageRange = v); _applyFilter(); },
                        ),
                      ],
                    ]),
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

class _RangeLabel extends StatelessWidget {
  final String label;
  final String value;
  const _RangeLabel(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF546E7A))),
    const Spacer(),
    Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
  ]);
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
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
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
                style: const TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 16),
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A237E)),
                    ),
                  ),
                  statusBadge,
                ]),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF78909C)),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A))),
                  ]),
                ],
                if (project.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.work_outline_rounded, size: 11, color: Color(0xFF78909C)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(project,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A)),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 4,
                    children: extras.map((e) => Text(
                      '${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF90A4AE)),
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
                    style: const TextStyle(fontSize: 10, color: _blue, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                _SmallIconBtn(icon: Icons.edit_rounded, color: _blue, onTap: onEdit),
                const SizedBox(width: 4),
                _SmallIconBtn(icon: Icons.delete_outline_rounded, color: const Color(0xFFC62828), onTap: onDelete),
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
          color: const Color(0xFFBBDEFB),
        ),
        const SizedBox(height: 12),
        Text(
          hasLeads ? 'No leads match your filter' : 'No leads yet',
          style: const TextStyle(
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
              const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
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
            size: 52, color: Color(0xFFBBDEFB)),
        const SizedBox(height: 12),
        const Text('Could not load leads',
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
                  fontSize: 12, color: Color(0xFF78909C))),
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

