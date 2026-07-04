import 'package:flutter/material.dart';
import '../models/maintenance_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/month_picker.dart';
import '../widgets/back_button.dart';

class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({super.key});

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

const _kIssueTypes = [
  'Attendance Issues',
  'Salary & Payroll Issues',
  'Leave Issues',
  'Manager-Related Issues',
  'Team Issues',
  'Workplace Behavior Issues',
  'IT Issues',
];

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  String? _selectedIssueType;
  DateTime? _selectedMonth;
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await SupabaseService.fetchMaintenanceTickets()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        MaintenanceStore.tickets..clear()..addAll(list);
        MaintenanceStore.syncCounter();
      });
    } catch (_) {}
  }

  Future<void> _submitTicket() async {
    final issueType = _selectedIssueType;
    final desc      = _descController.text.trim();
    if (issueType == null || desc.isEmpty) return;
    final role         = UserSession.role;
    final reporterName = UserSession.name.isNotEmpty
        ? UserSession.name
        : (role == UserRole.reportingManager ? 'Manager' : 'Employee');
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
      _selectedIssueType = null;
      _descController.clear();
    });
    final error = await SupabaseService.saveMaintenanceTicket(ticket);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $error'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 8),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Issue submitted successfully.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ));
    }
  }

  Future<void> _addressed(MaintenanceTicket t) async {
    setState(() => t.status = MaintenanceStatus.resolved);
    await SupabaseService.updateTicketStatus(t.id, MaintenanceStatus.resolved);
  }

  Future<void> _sendToManagement(MaintenanceTicket t) async {
    setState(() => t.sentToManagement = true);
    await SupabaseService.updateTicketSentToManagement(t.id, true);
  }

  bool _isResolved(MaintenanceTicket t) =>
      t.status == MaintenanceStatus.resolved ||
      t.status == MaintenanceStatus.closed;

  bool _matchesMonth(MaintenanceTicket t) =>
      _selectedMonth == null ||
      (t.createdAt.year == _selectedMonth!.year &&
          t.createdAt.month == _selectedMonth!.month);

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(context, _selectedMonth);
    if (picked != null && mounted) setState(() => _selectedMonth = picked);
  }

  Widget _buildMonthFilterRow() {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(children: [
      OutlinedButton.icon(
        onPressed: _pickMonth,
        icon: Icon(
          _selectedMonth != null
              ? Icons.calendar_today_rounded
              : Icons.calendar_month_rounded,
          size: 16,
        ),
        label: Text(
            _selectedMonth != null ? monthLabel(_selectedMonth!) : 'Filter by Month'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _selectedMonth != null ? primary : null,
          side: _selectedMonth != null ? BorderSide(color: primary) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      if (_selectedMonth != null) ...[
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: () => setState(() => _selectedMonth = null),
          tooltip: 'Clear',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    switch (UserSession.role) {
      case UserRole.hr:
        return _buildHrPage(context);
      case UserRole.management:
        return _buildManagementPage(context);
      default:
        return _buildReporterPage(context);
    }
  }

  // ── HR Page: 3 tabs ──────────────────────────────────────────────────────

  Widget _buildHrPage(BuildContext context) {
    final tickets  = MaintenanceStore.tickets.where(_matchesMonth).toList();
    final pending  = tickets.where((t) => !_isResolved(t) && !t.sentToManagement).toList();
    final resolved = tickets.where(_isResolved).toList();
    final sentMgmt = tickets.where((t) => t.sentToManagement && !_isResolved(t)).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: null,
        body: Column(children: [
          _Header(
            onRefresh: _reload,
            monthFilter: _buildMonthFilterRow(),
            bottom: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Pending (${pending.length})'),
                Tab(text: 'Resolved (${resolved.length})'),
                Tab(text: 'Sent to Management (${sentMgmt.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              // Pending tab
              _TicketList(
                tickets: pending,
                emptyMessage: 'No pending issues.',
                actionsBuilder: (t) => [
                  _ActionBtn(
                    label: 'Send to Management',
                    icon: Icons.upload_rounded,
                    color: const Color(0xFF6A1B9A),
                    onTap: () => _sendToManagement(t),
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    label: 'Addressed',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green.shade700,
                    onTap: () => _addressed(t),
                  ),
                ],
              ),
              // Resolved tab
              _TicketList(
                tickets: resolved,
                emptyMessage: 'No resolved issues yet.',
                actionsBuilder: (_) => [],
              ),
              // Sent to Management tab
              _TicketList(
                tickets: sentMgmt,
                emptyMessage: 'No issues sent to management.',
                actionsBuilder: (t) => [
                  _ActionBtn(
                    label: 'Addressed',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green.shade700,
                    onTap: () => _addressed(t),
                  ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Management Page: 2 tabs ──────────────────────────────────────────────

  Widget _buildManagementPage(BuildContext context) {
    final tickets = MaintenanceStore.tickets.where(_matchesMonth).toList();
    final hrSent  = tickets.where((t) => t.sentToManagement).toList();
    final all     = tickets.toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: null,
        body: Column(children: [
          _Header(
            onRefresh: _reload,
            monthFilter: _buildMonthFilterRow(),
            bottom: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Issues from HR (${hrSent.length})'),
                Tab(text: 'All Issues (${all.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _TicketList(
                tickets: hrSent,
                emptyMessage: 'No issues sent by HR yet.',
                actionsBuilder: (t) => _isResolved(t) ? [] : [
                  _ActionBtn(
                    label: 'Addressed',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green.shade700,
                    onTap: () => _addressed(t),
                  ),
                ],
              ),
              _TicketList(
                tickets: all,
                emptyMessage: 'No issues reported yet.',
                actionsBuilder: (t) => _isResolved(t) ? [] : [
                  _ActionBtn(
                    label: 'Addressed',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green.shade700,
                    onTap: () => _addressed(t),
                  ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Reporter Page (Employee / Manager) ───────────────────────────────────

  Widget _buildReporterPage(BuildContext context) {
    final myRole    = UserSession.role;
    final myTickets = MaintenanceStore.tickets
        .where((t) => t.reportedByRole == myRole && _matchesMonth(t))
        .toList();

    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeaderRow(context),
          const SizedBox(height: 12),
          _buildMonthFilterRow(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionLabel(context: context,
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Report an Issue'),
                const SizedBox(height: 16),
                Text('Issue Type',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedIssueType,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.build_circle_rounded,
                        color: AppTheme.primaryBlue, size: 20),
                    hintText: 'Select issue type',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  items: _kIssueTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedIssueType = v),
                ),
                const SizedBox(height: 16),
                Text('Description',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600)),
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
              ]),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(context: context,
              icon: Icons.receipt_long_rounded,
              label: 'My Reported Issues'),
          const SizedBox(height: 12),
          if (myTickets.isEmpty)
            const _EmptyState(message: 'You have not reported any issues yet.')
          else
            ...myTickets.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TicketCard(ticket: t, actions: const []),
                )),
        ]),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(children: [
      const NavBackButton(),
      const SizedBox(width: 8),
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.build_rounded,
            color: Theme.of(context).colorScheme.primary, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Text('Maintenance Management',
          style: Theme.of(context).textTheme.headlineMedium)),
      IconButton(
        icon: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.primary),
        tooltip: 'Refresh',
        onPressed: _reload,
      ),
    ]);
  }
}

// ── Header widget used by HR and Management pages ─────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  final PreferredSizeWidget bottom;
  final Widget? monthFilter;
  const _Header({required this.onRefresh, required this.bottom, this.monthFilter});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const NavBackButton(),
          const SizedBox(width: 8),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.build_rounded,
                color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text('Maintenance Management',
              style: Theme.of(context).textTheme.headlineMedium)),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.primary),
            tooltip: 'Refresh',
            onPressed: onRefresh,
          ),
        ]),
        if (monthFilter != null) ...[
          const SizedBox(height: 8),
          monthFilter!,
        ],
        const SizedBox(height: 12),
        bottom,
      ]),
    );
  }
}

// ── Scrollable list of tickets ────────────────────────────────────────────────

class _TicketList extends StatelessWidget {
  final List<MaintenanceTicket> tickets;
  final String emptyMessage;
  final List<Widget> Function(MaintenanceTicket) actionsBuilder;
  const _TicketList({
    required this.tickets,
    required this.emptyMessage,
    required this.actionsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) return _EmptyState(message: emptyMessage);
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: tickets.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _TicketCard(
          ticket: tickets[i],
          actions: actionsBuilder(tickets[i]),
        ),
      ),
    );
  }
}

// ── Single ticket card ────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final MaintenanceTicket ticket;
  final List<Widget> actions;
  const _TicketCard({required this.ticket, required this.actions});

  static Color _statusColor(MaintenanceStatus s) => switch (s) {
        MaintenanceStatus.open       => const Color(0xFFE65100),
        MaintenanceStatus.assigned   => const Color(0xFF0D47A1),
        MaintenanceStatus.inProgress => const Color(0xFF6A1B9A),
        MaintenanceStatus.resolved   => const Color(0xFF2E7D32),
        MaintenanceStatus.closed     => const Color(0xFF546E7A),
      };

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(ticket.status);
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: issue type chip + optional sent-to-mgmt badge + status
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(ticket.issueType,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.primary)),
            ),
            const Spacer(),
            if (ticket.sentToManagement)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Sent to Mgmt',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6A1B9A))),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(ticket.status.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sc)),
            ),
          ]),
          const SizedBox(height: 10),

          // Description
          Text(ticket.description,
              style: TextStyle(fontSize: 13, color: cs.onSurface)),
          const SizedBox(height: 8),

          // Footer: reporter · date · ticket ID
          Row(children: [
            Icon(Icons.person_rounded, size: 13, color: cs.onSurface.withValues(alpha: 0.55)),
            const SizedBox(width: 4),
            Text(ticket.reportedBy,
                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
            const SizedBox(width: 12),
            Icon(Icons.access_time_rounded,
                size: 13, color: cs.onSurface.withValues(alpha: 0.55)),
            const SizedBox(width: 4),
            Text(_fmt(ticket.createdAt),
                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
            const Spacer(),
            Text(ticket.id,
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500)),
          ]),

          // Actions row
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: actions),
          ],
        ]),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 52),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
      ]),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  const _SectionLabel(
      {required this.context, required this.icon, required this.label});

  @override
  Widget build(BuildContext _) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: cs.primary, size: 18),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700)),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: cs.outlineVariant)),
    ]);
  }
}
