import 'package:flutter/material.dart';
import '../models/lead_model.dart';
import '../services/lead_service.dart';

const _blue = Color(0xFF0D47A1);


class LeadManagementPage extends StatefulWidget {
  const LeadManagementPage({super.key});

  @override
  State<LeadManagementPage> createState() => _LeadManagementPageState();
}

class _LeadManagementPageState extends State<LeadManagementPage> {
  List<Lead> _all = [];
  List<Lead> _filtered = [];
  List<String> _statusOptions = ['All'];
  bool _loading = false;
  String? _error;
  String _selectedStatus = 'All';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final leads = await LeadService.fetchLeads();
      final statuses = leads
          .map((l) => l.status)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _all = leads;
        _filtered = _computeFilter(leads);
        _statusOptions = ['All', ...statuses];
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
      final matchesStatus =
          _selectedStatus == 'All' || lead.status == _selectedStatus;
      final matchesSearch = q.isEmpty ||
          lead.name.toLowerCase().contains(q) ||
          lead.phone.toLowerCase().contains(q) ||
          lead.project.toLowerCase().contains(q) ||
          lead.source.toLowerCase().contains(q) ||
          lead.status.toLowerCase().contains(q);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  void _applyFilter() {
    setState(() {
      _filtered = _computeFilter(_all);
    });
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
    final nameCtrl = TextEditingController(text: lead.name);
    final phoneCtrl = TextEditingController(text: lead.phone);
    final projectCtrl = TextEditingController(text: lead.project);
    final sourceCtrl = TextEditingController(text: lead.source);
    final statusCtrl = TextEditingController(text: lead.status);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Lead',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _blue)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _inputField('Name', nameCtrl),
              const SizedBox(height: 12),
              _inputField('Phone', phoneCtrl,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _inputField('Project', projectCtrl),
              const SizedBox(height: 12),
              _inputField('Source', sourceCtrl),
              const SizedBox(height: 12),
              _inputField('Status', statusCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = lead.copyWith(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                project: projectCtrl.text.trim(),
                source: sourceCtrl.text.trim(),
                status: statusCtrl.text.trim(),
              );
              await _doUpdate(updated);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final nextId = _all.isEmpty
        ? 1
        : _all.map((l) => l.leadId).reduce((a, b) => a > b ? a : b) + 1;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final projectCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    final statusCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Lead',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _blue)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _inputField('Name', nameCtrl),
              const SizedBox(height: 12),
              _inputField('Phone', phoneCtrl,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _inputField('Project', projectCtrl),
              const SizedBox(height: 12),
              _inputField('Source', sourceCtrl),
              const SizedBox(height: 12),
              _inputField('Status', statusCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final newLead = Lead(
                leadId: nextId,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                project: projectCtrl.text.trim(),
                source: sourceCtrl.text.trim(),
                status: statusCtrl.text.trim(),
              );
              await _doAdd(newLead);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsDialog() async {
    final urlCtrl = TextEditingController(text: await LeadService.getUrl());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.settings_rounded, color: _blue, size: 20),
          SizedBox(width: 8),
          Text('Google Sheets Setup',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── URL field ──────────────────────────────────────────
              const Text('Apps Script URL',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _blue)),
              const SizedBox(height: 6),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  hintText: 'https://script.google.com/macros/s/…/exec',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),
              // ── How to set up ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline_rounded,
                          size: 15, color: _blue),
                      SizedBox(width: 6),
                      Text('How to connect a Google Sheet',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _blue)),
                    ]),
                    SizedBox(height: 8),
                    _SetupStep(n: '1', text: 'Open your Google Sheet → Extensions → Apps Script'),
                    _SetupStep(n: '2', text: 'Paste the script code provided by your admin, then press Ctrl+S'),
                    _SetupStep(n: '3', text: 'Click Deploy → New deployment → choose Web app'),
                    _SetupStep(n: '4', text: 'Set "Execute as: Me" and "Who has access: Anyone" → click Deploy'),
                    _SetupStep(n: '5', text: 'Copy the URL shown, paste it in the field above, and tap Save'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await LeadService.saveUrl(urlCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              await _fetch();
            },
            child: const Text('Save & Reload'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(Lead lead) async {
    if (lead.leadId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot delete: this lead has no valid ID in the sheet'),
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
      await LeadService.deleteLead(lead.leadId);
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
      await LeadService.updateLead(lead);
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
      await LeadService.addLead(lead);
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lead added to Google Sheets'),
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

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad = narrow ? 16.0 : 24.0;

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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.leaderboard_rounded,
                        color: _blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lead Management',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _blue)),
                        Text(
                          '${_all.length} lead${_all.length == 1 ? '' : 's'} total',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF78909C)),
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
                  IconButton(
                    tooltip: 'Google Sheets Settings',
                    onPressed: _showSettingsDialog,
                    icon: const Icon(Icons.settings_rounded, color: _blue),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, project…',
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
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Status filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusOptions.map((s) {
                      final isSelected = _selectedStatus == s;
                      final count = s == 'All'
                          ? _all.length
                          : _all.where((l) => l.status == s).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedStatus = s);
                            _applyFilter();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? _blue
                                    : const Color(0xFFDDDDDD),
                              ),
                            ),
                            child: Text(
                              count > 0 ? '$s ($count)' : s,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF546E7A),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
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

// ── Lead Card ────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final Lead lead;
  final Widget statusBadge;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LeadCard({
    required this.lead,
    required this.statusBadge,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    const Color(0xFF0D47A1).withValues(alpha: 0.1),
                child: Text(
                  lead.name.isNotEmpty
                      ? lead.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 17),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name.isEmpty ? 'Unknown' : lead.name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _blue),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.phone_rounded,
                          size: 12, color: Color(0xFF78909C)),
                      const SizedBox(width: 4),
                      Text(lead.phone.isEmpty ? '—' : lead.phone,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF546E7A))),
                      if (lead.source.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.campaign_rounded,
                            size: 12, color: Color(0xFF78909C)),
                        const SizedBox(width: 4),
                        Text(lead.source,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF546E7A))),
                      ],
                    ]),
                    if (lead.project.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.apartment_rounded,
                            size: 12, color: Color(0xFF78909C)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            lead.project,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF546E7A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  statusBadge,
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${lead.leadId}',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF78909C)),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionButton(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  color: _blue,
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFC62828),
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
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

class _SetupStep extends StatelessWidget {
  final String n;
  final String text;
  const _SetupStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 1, right: 8),
          decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
          child: Center(
            child: Text(n,
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF37474F))),
        ),
      ]),
    );
  }
}
