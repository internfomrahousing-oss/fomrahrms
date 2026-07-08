import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/maintenance_form_config.dart';
import '../models/maintenance_store.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../theme/app_theme.dart';
import '../utils/month_picker.dart';
import '../widgets/back_button.dart';

class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({super.key});

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  String? _selectedIssueFor;
  String? _selectedIssueType;
  DateTime? _selectedMonth;
  String? _filterIssueFor;
  final _descController = TextEditingController();

  List<String> _issueForOptions = List<String>.from(MaintenanceFormConfig.defaultIssueForOptions);
  List<String> _issueTypes      = List<String>.from(MaintenanceFormConfig.defaultIssueTypes);

  @override
  void initState() {
    super.initState();
    _reload();
    _loadFormConfig();
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

  Future<void> _loadFormConfig() async {
    try {
      var cfg = MaintenanceFormConfig.cached;
      if (cfg == null) {
        final active = await SupabaseService.fetchActiveMaintenanceFormConfig()
            .timeout(const Duration(seconds: 8));
        cfg = active != null
            ? Map<String, dynamic>.from(active['form_config'] as Map)
            : MaintenanceFormConfig.defaults();
        MaintenanceFormConfig.setCache(cfg);
      }
      if (!mounted) return;
      setState(() {
        _issueForOptions = MaintenanceFormConfig.getIssueForOptions(cfg!);
        _issueTypes      = MaintenanceFormConfig.getIssueTypes(cfg);
      });
    } catch (_) {}
  }

  Future<void> _submitTicket() async {
    final issueFor  = _selectedIssueFor;
    final issueType = _selectedIssueType;
    final desc      = _descController.text.trim();
    if (issueFor == null || issueType == null || desc.isEmpty) return;
    final role         = UserSession.role;
    final reporterName = UserSession.name.isNotEmpty
        ? UserSession.name
        : switch (role) {
            UserRole.reportingManager => 'Manager',
            UserRole.hr => 'HR',
            _ => 'Employee',
          };
    final ticket = MaintenanceTicket(
      id:             MaintenanceStore.generateId(),
      reportedByRole: role,
      reportedBy:     reporterName,
      issueFor:       issueFor,
      issueType:      issueType,
      description:    desc,
      createdAt:      DateTime.now(),
    );
    setState(() {
      MaintenanceStore.tickets.insert(0, ticket);
      _selectedIssueFor = null;
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
      // Fire-and-forget: let HR (and Management, if applicable) know.
      NotificationService.maintenanceSubmitted(
        issueType: ticket.issueType,
        reportedBy: ticket.reportedBy,
        sentToManagement: ticket.sentToManagement,
      );
    }
  }

  Future<void> _resolveTicket(MaintenanceTicket t) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _ResolutionDialog(),
    );
    if (result == null || !mounted) return;
    final note = result['note'] as String;
    final when = result['when'] as DateTime;
    setState(() {
      t.status = MaintenanceStatus.resolved;
      t.resolutionNote = note;
      t.resolvedAt = when;
    });
    await SupabaseService.updateTicketResolution(t.id, note, when);
    _notifyReporterStatusChanged(t);
  }

  static const _routePrefixByRole = {
    UserRole.hr:               '',
    UserRole.employee:         '/employee',
    UserRole.reportingManager: '/manager',
    UserRole.management:       '/management',
  };

  // Fire-and-forget: resolves the reporter's email from their name and lets
  // them know their ticket's status changed.
  Future<void> _notifyReporterStatusChanged(MaintenanceTicket t) async {
    final users = await UserStore.load();
    AppUser? reporter;
    for (final u in users) {
      if (u.name.trim() == t.reportedBy.trim()) {
        reporter = u;
        break;
      }
    }
    if (reporter == null) return;
    NotificationService.maintenanceStatusChanged(
      reporterEmail: reporter.email,
      issueType: t.issueType,
      status: t.status.label,
      reporterRoutePrefix: _routePrefixByRole[t.reportedByRole] ?? '',
    );
  }

  Future<void> _managementResolve(MaintenanceTicket t) async {
    setState(() => t.managementReviewed = true);
    await SupabaseService.updateTicketManagementReviewed(t.id, true);
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

  bool _matchesIssueFor(MaintenanceTicket t) =>
      _filterIssueFor == null || t.issueFor == _filterIssueFor;

  bool _matchesFilters(MaintenanceTicket t) =>
      _matchesMonth(t) && _matchesIssueFor(t);

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(context, _selectedMonth);
    if (picked != null && mounted) setState(() => _selectedMonth = picked);
  }

  Widget _buildMonthFilterRow() {
    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
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
      if (_selectedMonth != null)
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: () => setState(() => _selectedMonth = null),
          tooltip: 'Clear',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      PopupMenuButton<String?>(
        tooltip: 'Filter by department',
        onSelected: (v) => setState(() => _filterIssueFor = v),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        itemBuilder: (_) => [
          const PopupMenuItem<String?>(value: null, child: Text('All Departments')),
          ..._issueForOptions.map((o) => PopupMenuItem<String?>(value: o, child: Text(o))),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
                color: _filterIssueFor != null
                    ? primary
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_list_rounded, size: 16,
                color: _filterIssueFor != null ? primary : null),
            const SizedBox(width: 6),
            Text(_filterIssueFor ?? 'Filter by Department',
                style: TextStyle(color: _filterIssueFor != null ? primary : null)),
          ]),
        ),
      ),
      if (_filterIssueFor != null)
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: () => setState(() => _filterIssueFor = null),
          tooltip: 'Clear',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
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
    final tickets  = MaintenanceStore.tickets.where(_matchesFilters).toList();
    final pending  = tickets.where((t) => !_isResolved(t) && !t.sentToManagement).toList();
    final resolved = tickets.where(_isResolved).toList();
    final sentMgmt = tickets.where((t) => t.sentToManagement && !_isResolved(t)).toList();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: null,
        body: Column(children: [
          _Header(
            onRefresh: _reload,
            monthFilter: _buildMonthFilterRow(),
            bottom: TabBar(
              isScrollable: true,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Pending (${pending.length})'),
                Tab(text: 'Resolved (${resolved.length})'),
                Tab(text: 'Sent to Management (${sentMgmt.length})'),
                const Tab(text: 'Report an Issue'),
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
                    color: AppTheme.primaryBlue,
                    onTap: () => _sendToManagement(t),
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    label: 'Addressed',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green.shade700,
                    onTap: () => _resolveTicket(t),
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
                actionsBuilder: (t) => t.managementReviewed
                    ? [
                        _ActionBtn(
                          label: 'Close Ticket',
                          icon: Icons.check_circle_rounded,
                          color: Colors.green.shade700,
                          onTap: () => _resolveTicket(t),
                        ),
                      ]
                    : [],
              ),
              // Report an Issue tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildReportFormCard(context),
                  const SizedBox(height: 24),
                  _SectionLabel(context: context,
                      icon: Icons.receipt_long_rounded,
                      label: 'My Reported Issues'),
                  const SizedBox(height: 12),
                  _buildMyReportedIssuesList(context),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Management Page: 2 tabs ──────────────────────────────────────────────

  Widget _buildManagementPage(BuildContext context) {
    final tickets = MaintenanceStore.tickets.where(_matchesFilters).toList();
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
                actionsBuilder: (t) => (_isResolved(t) || t.managementReviewed) ? [] : [
                  _ActionBtn(
                    label: 'Resolved',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green.shade700,
                    onTap: () => _managementResolve(t),
                  ),
                ],
              ),
              _TicketList(
                tickets: all,
                emptyMessage: 'No issues reported yet.',
                actionsBuilder: (t) => (_isResolved(t) || t.managementReviewed || !t.sentToManagement) ? [] : [
                  _ActionBtn(
                    label: 'Resolved',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green.shade700,
                    onTap: () => _managementResolve(t),
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
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeaderRow(context),
          const SizedBox(height: 12),
          _buildMonthFilterRow(),
          const SizedBox(height: 12),
          _buildReportFormCard(context),
          const SizedBox(height: 24),
          _SectionLabel(context: context,
              icon: Icons.receipt_long_rounded,
              label: 'My Reported Issues'),
          const SizedBox(height: 12),
          _buildMyReportedIssuesList(context),
        ]),
      ),
    );
  }

  // ── Shared "Report an Issue" form + "My Reported Issues" list ─────────────
  // Used by both the reporter page (Employee/Manager) and HR's own
  // "Report an Issue" tab, so the submission flow and approval process are
  // identical regardless of who is reporting.

  Widget _buildReportFormCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: _SectionLabel(context: context,
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Report an Issue'),
            ),
            if (UserSession.role == UserRole.hr)
              TextButton.icon(
                onPressed: () => context.push('/edit-maintenance-form'),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Edit Form', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ]),
          const SizedBox(height: 16),
          Text('Issue For',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedIssueFor,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.groups_rounded,
                  color: AppTheme.primaryBlue, size: 20),
              hintText: 'Select department',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
            items: _issueForOptions
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _selectedIssueFor = v),
          ),
          const SizedBox(height: 16),
          Text('Issue Type',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedIssueType,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.build_circle_rounded,
                  color: AppTheme.primaryBlue, size: 20),
              hintText: 'Select issue type',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
            items: _issueTypes
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
    );
  }

  Widget _buildMyReportedIssuesList(BuildContext context) {
    final myRole    = UserSession.role;
    final myTickets = MaintenanceStore.tickets
        .where((t) => t.reportedByRole == myRole && _matchesFilters(t))
        .toList();
    if (myTickets.isEmpty) {
      return const _EmptyState(message: 'You have not reported any issues yet.');
    }
    return Column(children: myTickets
        .map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TicketCard(ticket: t, actions: const []),
            ))
        .toList());
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
        MaintenanceStatus.open       => const Color(0xFFF59E0B),
        MaintenanceStatus.assigned   => const Color(0xFF2563EB),
        MaintenanceStatus.inProgress => const Color(0xFF2563EB),
        MaintenanceStatus.resolved   => const Color(0xFF22C55E),
        MaintenanceStatus.closed     => const Color(0xFF6B7280),
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
                color: cs.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(ticket.issueFor,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.7))),
            ),
            const SizedBox(width: 6),
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
            if (ticket.sentToManagement && !ticket.managementReviewed)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Sent to Mgmt',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue)),
              ),
            if (ticket.managementReviewed && ticket.status != MaintenanceStatus.resolved && ticket.status != MaintenanceStatus.closed)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Awaiting HR Closure',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309))),
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

          if (ticket.resolutionNote != null && ticket.resolutionNote!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Resolution', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 4),
                Text(ticket.resolutionNote!,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85))),
                if (ticket.resolvedAt != null) ...[
                  const SizedBox(height: 4),
                  Text('Resolved on ${_fmtDateTime(ticket.resolvedAt!)}',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
                ],
              ]),
            ),
            const SizedBox(height: 8),
          ],

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

  static String _fmtDateTime(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${_fmt(d)} ${hour12.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }
}

// ── Resolution dialog: captures how & when an issue was closed ────────────────

class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog();

  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<_ResolutionDialog> {
  final _noteController = TextEditingController();
  DateTime _when = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null || !mounted) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      setState(() => _error = 'Please describe how it was resolved.');
      return;
    }
    Navigator.pop(context, {'note': note, 'when': _when});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Close Ticket'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How was it resolved?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Describe how the issue was resolved…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          Text('When was it resolved?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickWhen,
            icon: const Icon(Icons.event_rounded, size: 16),
            label: Text(_TicketCard._fmtDateTime(_when)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Mark Done')),
      ],
    );
  }
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
