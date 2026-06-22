import 'package:flutter/material.dart';
import '../models/maintenance_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({super.key});

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState
    extends State<MaintenanceManagementPage> {
  final _issueTypeController = TextEditingController();
  final _descController      = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await SupabaseService.fetchMaintenanceTickets()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        MaintenanceStore.tickets
          ..clear()
          ..addAll(list);
        MaintenanceStore.syncCounter();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _issueTypeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submitTicket() {
    final issueType = _issueTypeController.text.trim();
    final desc      = _descController.text.trim();
    if (issueType.isEmpty || desc.isEmpty) return;

    final role = UserSession.role;
    final reporterName =
        role == UserRole.reportingManager ? 'Manager' : 'Employee';
    final ticket = MaintenanceTicket(
      id:             MaintenanceStore.generateId(),
      reportedByRole: role,
      reportedBy:     reporterName,
      issueType:      issueType,
      description:    desc,
      createdAt:      DateTime.now(),
    );
    setState(() {
      MaintenanceStore.tickets.insert(0, ticket);
      _issueTypeController.clear();
      _descController.clear();
    });
    SupabaseService.saveMaintenanceTicket(ticket);
  }

  @override
  Widget build(BuildContext context) {
    final isHr = UserSession.role == UserRole.hr;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            if (isHr) ..._buildHrContent(context) else ..._buildReporterContent(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.lightBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.build_rounded,
            color: AppTheme.primaryBlue, size: 22),
      ),
      const SizedBox(width: 14),
      Text('Maintenance Management',
          style: Theme.of(context).textTheme.headlineMedium),
    ]);
  }

  // ── HR view ────────────────────────────────────────────────────────────────

  List<Widget> _buildHrContent(BuildContext context) {
    final tickets = MaintenanceStore.tickets;
    final open =
        tickets.where((t) => t.status == MaintenanceStatus.open).length;
    final inProgress = tickets
        .where((t) => t.status == MaintenanceStatus.inProgress)
        .length;
    final resolved = tickets
        .where((t) =>
            t.status == MaintenanceStatus.resolved ||
            t.status == MaintenanceStatus.closed)
        .length;

    return [
      Row(children: [
        Expanded(
          child: _StatCard(
              label: 'Total', value: tickets.length, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
              label: 'Open', value: open, color: const Color(0xFFE65100)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
              label: 'In Progress',
              value: inProgress,
              color: const Color(0xFF6A1B9A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
              label: 'Resolved',
              value: resolved,
              color: const Color(0xFF2E7D32)),
        ),
      ]),
      const SizedBox(height: 24),
      _SectionLabel(
        context: context,
        icon: Icons.list_alt_rounded,
        label: 'All Reported Issues',
      ),
      const SizedBox(height: 12),
      if (tickets.isEmpty)
        _buildEmptyState(context, 'No issues have been reported yet.')
      else
        ...tickets.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HrTicketCard(
              ticket: t,
              onStatusChanged: (status) {
                setState(() => t.status = status);
                SupabaseService.updateTicketStatus(t.id, status);
              },
            ),
          ),
        ),
    ];
  }

  // ── Reporter (Employee / Manager) view ────────────────────────────────────

  List<Widget> _buildReporterContent(BuildContext context) {
    final myRole = UserSession.role;
    final myTickets = MaintenanceStore.tickets
        .where((t) => t.reportedByRole == myRole)
        .toList();

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(
                context: context,
                icon: Icons.add_circle_outline_rounded,
                label: 'Report an Issue',
              ),
              const SizedBox(height: 16),

              Text('Issue Type',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF37474F))),
              const SizedBox(height: 8),
              TextField(
                controller: _issueTypeController,
                decoration: InputDecoration(
                  hintText: 'e.g. Laptop not turning on, Network issue…',
                  prefixIcon: const Icon(Icons.build_circle_rounded,
                      color: AppTheme.primaryBlue, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              Text('Description',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF37474F))),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe the problem in detail…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitTicket,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit Issue'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      _SectionLabel(
        context: context,
        icon: Icons.receipt_long_rounded,
        label: 'My Reported Issues',
      ),
      const SizedBox(height: 12),
      if (myTickets.isEmpty)
        _buildEmptyState(context, 'You have not reported any issues yet.')
      else
        ...myTickets.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReporterTicketCard(ticket: t),
          ),
        ),
    ];
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF90A4AE), size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: const Color(0xFF90A4AE))),
          ]),
        ),
      ),
    );
  }
}

// ── Shared section label ───────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  const _SectionLabel(
      {required this.context, required this.icon, required this.label});

  @override
  Widget build(BuildContext _) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.lightBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF1A237E), fontWeight: FontWeight.w700)),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
    ]);
  }
}

// ── Stat card (HR view) ────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(children: [
          Text(
            value.toString(),
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF546E7A))),
        ]),
      ),
    );
  }
}

// ── HR ticket card (with status dropdown) ─────────────────────────────────

class _HrTicketCard extends StatelessWidget {
  final MaintenanceTicket ticket;
  final ValueChanged<MaintenanceStatus> onStatusChanged;
  const _HrTicketCard(
      {required this.ticket, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(ticket.issueType,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue)),
              ),
              const Spacer(),
              Text(ticket.id,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF90A4AE),
                      fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 10),
            Text(ticket.description,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF37474F))),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.access_time_rounded,
                  size: 14, color: Color(0xFF90A4AE)),
              const SizedBox(width: 4),
              Text(_formatDate(ticket.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF90A4AE))),
              const Spacer(),
              DropdownButton<MaintenanceStatus>(
                value: ticket.status,
                underline: const SizedBox(),
                isDense: true,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(ticket.status)),
                items: MaintenanceStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(s))),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onStatusChanged(v);
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Color _statusColor(MaintenanceStatus s) {
    switch (s) {
      case MaintenanceStatus.open:       return const Color(0xFFE65100);
      case MaintenanceStatus.assigned:   return const Color(0xFF0D47A1);
      case MaintenanceStatus.inProgress: return const Color(0xFF6A1B9A);
      case MaintenanceStatus.resolved:   return const Color(0xFF2E7D32);
      case MaintenanceStatus.closed:     return const Color(0xFF546E7A);
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── Reporter ticket card (read-only status badge) ─────────────────────────

class _ReporterTicketCard extends StatelessWidget {
  final MaintenanceTicket ticket;
  const _ReporterTicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(ticket.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(ticket.issueType,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue)),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(ticket.status.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(ticket.description,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF37474F))),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.access_time_rounded,
                  size: 14, color: Color(0xFF90A4AE)),
              const SizedBox(width: 4),
              Text(_formatDate(ticket.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF90A4AE))),
              const Spacer(),
              Text(ticket.id,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF90A4AE),
                      fontWeight: FontWeight.w500)),
            ]),
          ],
        ),
      ),
    );
  }

  Color _statusColor(MaintenanceStatus s) {
    switch (s) {
      case MaintenanceStatus.open:       return const Color(0xFFE65100);
      case MaintenanceStatus.assigned:   return const Color(0xFF0D47A1);
      case MaintenanceStatus.inProgress: return const Color(0xFF6A1B9A);
      case MaintenanceStatus.resolved:   return const Color(0xFF2E7D32);
      case MaintenanceStatus.closed:     return const Color(0xFF546E7A);
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
