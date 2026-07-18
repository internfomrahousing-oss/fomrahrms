import 'package:file_picker/file_picker.dart';
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
import '../utils/image_compress.dart';
import '../utils/month_picker.dart';
import '../utils/open_url.dart';
import '../utils/pdf_compress.dart';
import '../widgets/back_button.dart';
import '../widgets/filter_panel.dart';

const int _kMaxAttachmentBytes = 500 * 1024;

const _mimeByExt = {
  'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
  'gif': 'image/gif', 'webp': 'image/webp', 'heic': 'image/heic',
  'pdf': 'application/pdf',
};

String _mimeFromFileName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return _mimeByExt[ext] ?? 'application/octet-stream';
}

class MaintenanceManagementPage extends StatefulWidget {
  // When true (HR's "My Space" entry), always show the personal
  // report-an-issue view instead of the admin dashboard.
  final bool personalView;
  const MaintenanceManagementPage({super.key, this.personalView = false});

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  String? _selectedIssueFor;
  String? _selectedIssueType;
  String _selectedPriority = 'Medium';
  DateTime? _selectedMonth;
  String? _filterIssueFor;
  String? _filterPriority;
  int _hrTabIndex = 0;
  int _mgmtTabIndex = 0;
  final _descController = TextEditingController();

  // Attachment (optional) — uploaded immediately on selection, capped at
  // 500 KB. Images over the cap are auto-compressed; other files (PDFs) are
  // best-effort compressed and rejected if still too large.
  String? _attachmentUrl;
  String? _attachmentName;
  bool _uploadingAttachment = false;

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

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    final rawBytes = file.bytes;
    if (rawBytes == null) {
      _showAttachmentError('Could not read file.');
      return;
    }

    setState(() => _uploadingAttachment = true);
    try {
      var bytes = rawBytes;
      var mime = _mimeFromFileName(file.name);
      if (bytes.length > _kMaxAttachmentBytes) {
        if (mime.startsWith('image/')) {
          final compressed = await compressImage(bytes, mime);
          if (compressed != null) { bytes = compressed; mime = 'image/jpeg'; }
        } else if (mime == 'application/pdf') {
          final compressed = await compressPdf(bytes);
          if (compressed != null && compressed.length < bytes.length) bytes = compressed;
        }
        if (bytes.length > _kMaxAttachmentBytes) {
          throw 'File is still ${(bytes.length / 1024).round()} KB after compression — '
              'please attach a file under 500 KB.';
        }
      }
      final safeName = file.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final url = await SupabaseService.uploadFile(bytes, safeName, mime);
      if (!mounted) return;
      setState(() {
        _attachmentUrl = url;
        _attachmentName = file.name;
      });
    } catch (e) {
      if (mounted) _showAttachmentError('$e');
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  void _showAttachmentError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 6),
    ));
  }

  void _removeAttachment() {
    setState(() {
      _attachmentUrl = null;
      _attachmentName = null;
    });
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
      priority:       _selectedPriority,
      createdAt:      DateTime.now(),
      attachmentUrl:  _attachmentUrl,
      attachmentName: _attachmentName,
    );
    setState(() {
      MaintenanceStore.tickets.insert(0, ticket);
      _selectedIssueFor = null;
      _selectedIssueType = null;
      _selectedPriority = 'Medium';
      _descController.clear();
      _attachmentUrl = null;
      _attachmentName = null;
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
        reportedByHr: ticket.reportedByRole == UserRole.hr,
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
      reporterRoutePrefix: NotificationService.routePrefixForRole(t.reportedByRole),
    );
  }

  Future<void> _managementResolve(MaintenanceTicket t) async {
    setState(() => t.managementReviewed = true);
    await SupabaseService.updateTicketManagementReviewed(t.id, true);
    NotificationService.maintenanceAddressedByManagement(
      issueType: t.issueType, reportedBy: t.reportedBy,
    );
  }

  Future<void> _sendToManagement(MaintenanceTicket t) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _SendToManagementDialog(),
    );
    if (note == null || !mounted) return;
    setState(() {
      t.sentToManagement = true;
      t.managementReviewed = false;
      t.sendToManagementNote = note;
    });
    await SupabaseService.updateTicketSentToManagement(t.id, true, note: note);
    NotificationService.maintenanceEscalated(
      issueType: t.issueType, reportedBy: t.reportedBy, note: note,
    );
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

  bool _matchesPriority(MaintenanceTicket t) =>
      _filterPriority == null || t.priority == _filterPriority;

  bool _matchesFilters(MaintenanceTicket t) =>
      _matchesMonth(t) && _matchesIssueFor(t) && _matchesPriority(t);

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(context, _selectedMonth);
    if (picked != null && mounted) setState(() => _selectedMonth = picked);
  }

  Widget _buildMonthFilterRow() {
    return _PillDropdown(
      icon: Icons.calendar_month_rounded,
      label: _selectedMonth != null ? monthLabel(_selectedMonth!) : 'All Months',
      active: _selectedMonth != null,
      onTap: _pickMonth,
      onClear: _selectedMonth != null ? () => setState(() => _selectedMonth = null) : null,
    );
  }

  Widget _buildPriorityFilterButton() {
    return FilterTriggerButton(
      hasActiveFilters: _filterIssueFor != null || _filterPriority != null,
      onTap: () {
        String? issueForDraft = _filterIssueFor;
        String? priorityDraft = _filterPriority;
        showFilterPanel(
          context,
          title: 'Filters',
          onReset: () { issueForDraft = null; priorityDraft = null; },
          onApply: () => setState(() { _filterIssueFor = issueForDraft; _filterPriority = priorityDraft; }),
          builder: (context, setPanelState) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FilterDropdownField<String>(
              label: 'Department',
              value: issueForDraft,
              options: _issueForOptions,
              labelOf: (o) => o,
              allLabel: 'All Departments',
              onChanged: (v) => setPanelState(() => issueForDraft = v),
            ),
            FilterChipGroup<String>(
              label: 'Priority',
              value: priorityDraft,
              options: kMaintenancePriorities,
              labelOf: (o) => o,
              onChanged: (v) => setPanelState(() => priorityDraft = v),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.personalView) return _buildReporterPage(context);
    switch (UserSession.role) {
      case UserRole.hr:
        return _buildHrPage(context);
      case UserRole.management:
        return _buildManagementPage(context);
      default:
        return _buildReporterPage(context);
    }
  }

  // ── HR Page: 4 tabs ──────────────────────────────────────────────────────

  Widget _buildHrPage(BuildContext context) {
    final tickets  = MaintenanceStore.tickets.where(_matchesFilters).toList();
    // Awaiting Management's first look — once they've reviewed it (sent it
    // back), it drops out of here and rejoins Pending for HR to close.
    final sentMgmt = tickets.where((t) => t.sentToManagement && !t.managementReviewed && !_isResolved(t)).toList();
    final pending  = tickets.where((t) => !_isResolved(t) && !sentMgmt.contains(t)).toList();
    final resolved = tickets.where(_isResolved).toList();

    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(child: Column(children: [
        _Header(
          onRefresh: _reload,
          onReportIssue: () => setState(() => _hrTabIndex = 3),
          statCards: _MaintStatCardsRow(
            total: tickets.length,
            pending: pending.length,
            resolved: resolved.length,
            sentMgmt: sentMgmt.length,
          ),
          priorityFilter: _buildPriorityFilterButton(),
          monthFilter: _buildMonthFilterRow(),
          tabs: _PillTabs(
            index: _hrTabIndex,
            onChanged: (i) => setState(() => _hrTabIndex = i),
            labels: [
              'Pending (${pending.length})',
              'Resolved (${resolved.length})',
              'Sent to Management (${sentMgmt.length})',
              'Report an Issue',
            ],
          ),
        ),
        IndexedStack(index: _hrTabIndex, children: [
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
            // Sent to Management tab — awaiting their first look; once
            // reviewed a ticket drops out of this list and rejoins Pending.
            _TicketList(
              tickets: sentMgmt,
              emptyMessage: 'No issues sent to management.',
              actionsBuilder: (_) => [],
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
      ])),
    );
  }

  // ── Management Page: 2 tabs ──────────────────────────────────────────────

  Widget _buildManagementPage(BuildContext context) {
    final tickets = MaintenanceStore.tickets.where(_matchesFilters).toList();
    final hrSent  = tickets.where((t) => t.sentToManagement).toList();
    final all     = tickets.toList();
    final resolved = tickets.where(_isResolved).toList();
    final pending  = tickets.where((t) => !_isResolved(t) && !t.sentToManagement).toList();

    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(child: Column(children: [
        _Header(
          onRefresh: _reload,
          statCards: _MaintStatCardsRow(
            total: tickets.length,
            pending: pending.length,
            resolved: resolved.length,
            sentMgmt: hrSent.length,
          ),
          priorityFilter: _buildPriorityFilterButton(),
          monthFilter: _buildMonthFilterRow(),
          tabs: _PillTabs(
            index: _mgmtTabIndex,
            onChanged: (i) => setState(() => _mgmtTabIndex = i),
            labels: [
              'Issues from HR (${hrSent.length})',
              'All Issues (${all.length})',
            ],
          ),
        ),
        IndexedStack(index: _mgmtTabIndex, children: [
            _TicketList(
              tickets: hrSent,
              emptyMessage: 'No issues sent by HR yet.',
              actionsBuilder: (t) => (_isResolved(t) || t.managementReviewed) ? [] : [
                _ActionBtn(
                  label: 'Send Back to HR',
                  icon: Icons.reply_rounded,
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
                  label: 'Send Back to HR',
                  icon: Icons.reply_rounded,
                  color: Colors.green.shade700,
                  onTap: () => _managementResolve(t),
                ),
              ],
            ),
        ]),
      ])),
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
          Text('Priority',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedPriority,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.flag_rounded,
                  color: AppTheme.primaryBlue, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
            items: kMaintenancePriorities
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() => _selectedPriority = v ?? 'Medium'),
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
          _buildAttachmentPicker(context),
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

  Widget _buildAttachmentPicker(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Attachment (optional, max 500 KB)',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.attach_file_rounded, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _uploadingAttachment
                  ? 'Uploading…'
                  : (_attachmentName ?? 'No file selected (image or PDF)'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _attachmentName != null
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF)),
            ),
          ),
          const SizedBox(width: 8),
          if (_attachmentName != null && !_uploadingAttachment)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Remove',
              onPressed: _removeAttachment,
            ),
          OutlinedButton(
            onPressed: _uploadingAttachment ? null : _pickAttachment,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _uploadingAttachment
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_attachmentName != null ? 'Replace' : 'Upload'),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildMyReportedIssuesList(BuildContext context) {
    final myTickets = MaintenanceStore.tickets
        .where((t) => t.reportedBy == UserSession.name && _matchesFilters(t))
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
    final narrow = MediaQuery.of(context).size.width < 600;
    return Row(children: [
      const NavBackButton(),
      SizedBox(width: narrow ? 4 : 8),
      if (!narrow) ...[
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.build_rounded,
              color: Theme.of(context).colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
      ],
      Expanded(child: Text('Maintenance Management',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
  final Widget tabs;
  final Widget? monthFilter;
  final Widget? statCards;
  final Widget? priorityFilter;
  final VoidCallback? onReportIssue;
  const _Header({
    required this.onRefresh,
    required this.tabs,
    this.monthFilter,
    this.statCards,
    this.priorityFilter,
    this.onReportIssue,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final narrow = MediaQuery.of(context).size.width < 600;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 24, narrow ? 16 : 24, narrow ? 12 : 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const NavBackButton(),
          SizedBox(width: narrow ? 4 : 8),
          if (!narrow) ...[
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.build_rounded, color: primary, size: 22),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(child: Text('Maintenance Management',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium)),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: primary),
            tooltip: 'Refresh',
            onPressed: onRefresh,
          ),
          if (onReportIssue != null) ...[
            SizedBox(width: narrow ? 2 : 4),
            narrow
                ? IconButton(
                    tooltip: 'Report an Issue',
                    onPressed: onReportIssue,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: onReportIssue,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Report an Issue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
          ],
        ]),
        if (statCards != null) ...[
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: statCards!),
            if (priorityFilter != null) ...[
              const SizedBox(width: 12),
              priorityFilter!,
            ],
          ]),
        ],
        if (monthFilter != null) ...[
          const SizedBox(height: 14),
          monthFilter!,
        ],
        const SizedBox(height: 14),
        tabs,
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── Stat cards row ─────────────────────────────────────────────────────────────

class _MaintStatCardsRow extends StatelessWidget {
  final int total;
  final int pending;
  final int resolved;
  final int sentMgmt;
  const _MaintStatCardsRow({
    required this.total,
    required this.pending,
    required this.resolved,
    required this.sentMgmt,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatCard(icon: Icons.assignment_rounded, color: AppTheme.primaryBlue,
          value: '$total', label: 'Total Issues'),
      _StatCard(icon: Icons.access_time_filled_rounded, color: Colors.orange.shade700,
          value: '$pending', label: 'Pending'),
      _StatCard(icon: Icons.check_circle_rounded, color: const Color(0xFF22C55E),
          value: '$resolved', label: 'Resolved'),
      _StatCard(icon: Icons.send_rounded, color: Colors.purple.shade600,
          value: '$sentMgmt', label: 'Sent to Mgmt'),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 640) {
        return Row(children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: tiles[i]),
          ],
        ]);
      }
      return Wrap(spacing: 12, runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: 150, child: t)]);
    });
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatCard({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Pill-style tab row (replaces TabBar for a matching visual) ────────────────

class _PillTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<String> labels;
  const _PillTabs({required this.index, required this.onChanged, required this.labels});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: i == index ? primary : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: i == index ? primary : const Color(0xFFE5E7EB)),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: i == index ? Colors.white : const Color(0xFF374151))),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Pill dropdown (custom onTap, e.g. month picker) ───────────────────────────

class _PillDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _PillDropdown({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? primary : const Color(0xFFE5E7EB)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? primary : const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? primary : const Color(0xFF111827))),
          if (onClear != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded, size: 15, color: Colors.grey.shade500),
            ),
          ] else ...[
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF6B7280)),
          ],
        ]),
      ),
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final t in tickets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TicketCard(
              ticket: t,
              actions: actionsBuilder(t),
            ),
          ),
      ]),
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

  static const _categoryPalette = [
    Color(0xFF2563EB), Color(0xFF8B5CF6), Color(0xFF0EA5E9),
    Color(0xFFF97316), Color(0xFF22C55E), Color(0xFFEC4899),
  ];

  Color _categoryColor(String issueFor) =>
      _categoryPalette[issueFor.isEmpty ? 0 : issueFor.codeUnitAt(0) % _categoryPalette.length];

  IconData _categoryIcon(String issueFor) {
    final v = issueFor.toLowerCase();
    if (v.contains('it')) return Icons.computer_rounded;
    if (v.contains('team') || v.contains('hr')) return Icons.groups_rounded;
    if (v.contains('admin') || v.contains('facility') || v.contains('office')) return Icons.apartment_rounded;
    return Icons.build_rounded;
  }

  static Color _priorityColor(String p) => switch (p) {
        'High' => const Color(0xFFEF4444),
        'Low'  => const Color(0xFF22C55E),
        _      => const Color(0xFFF59E0B),
      };

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(ticket.status);
    final cs = Theme.of(context).colorScheme;
    final catColor = _categoryColor(ticket.issueFor);
    final prColor = _priorityColor(ticket.priority);

    final leadingIcon = Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_categoryIcon(ticket.issueFor), color: catColor, size: 20),
    );

    final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(ticket.description,
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _chip(ticket.issueFor, catColor),
        _chip(ticket.issueType, catColor),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 4, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_rounded, size: 13, color: cs.onSurface.withValues(alpha: 0.55)),
          const SizedBox(width: 4),
          Text(ticket.reportedBy, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_rounded, size: 12, color: cs.onSurface.withValues(alpha: 0.55)),
          const SizedBox(width: 4),
          Text(_fmt(ticket.createdAt), style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
        ]),
        Text('#${ticket.id}',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55), fontWeight: FontWeight.w500)),
        if (ticket.attachmentUrl != null && ticket.attachmentUrl!.isNotEmpty)
          InkWell(
            onTap: () async {
              final url = await SupabaseService.resolveAttachmentUrl(
                  ticket.attachmentUrl!, bucket: 'RESUME');
              if (url != null) viewAttachment(url);
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.attach_file_rounded, size: 13, color: AppTheme.primaryBlue),
              const SizedBox(width: 2),
              Text('View Attachment',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
            ]),
          ),
      ]),
    ]);

    final statusChips = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _chip(ticket.status.label, sc),
      if (ticket.sentToManagement && !ticket.managementReviewed) ...[
        const SizedBox(height: 6),
        _chip('Sent to Management', AppTheme.primaryBlue),
      ],
      if (ticket.managementReviewed && ticket.status != MaintenanceStatus.resolved && ticket.status != MaintenanceStatus.closed) ...[
        const SizedBox(height: 6),
        _chip('Sent Back by Management', const Color(0xFFB45309)),
      ],
    ]);

    final priorityBlock = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('Priority', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: prColor),
        const SizedBox(width: 5),
        Text(ticket.priority, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: prColor)),
      ]),
    ]);

    final escalationBox = (ticket.sendToManagementNote != null && ticket.sendToManagementNote!.isNotEmpty)
        ? Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Note to Management', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 4),
              Text(ticket.sendToManagementNote!,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85))),
            ]),
          )
        : const SizedBox.shrink();

    final resolutionBox = (ticket.resolutionNote != null && ticket.resolutionNote!.isNotEmpty)
        ? Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
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
          )
        : const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: catColor, width: 4))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 640;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  leadingIcon,
                  const SizedBox(width: 12),
                  Expanded(child: titleBlock),
                  const SizedBox(width: 16),
                  priorityBlock,
                  const SizedBox(width: 16),
                  statusChips,
                ])
              else ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  leadingIcon,
                  const SizedBox(width: 12),
                  Expanded(child: titleBlock),
                ]),
                const SizedBox(height: 10),
                Row(children: [priorityBlock, const Spacer(), statusChips]),
              ],
              escalationBox,
              resolutionBox,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: actions),
              ],
            ]);
          }),
        ),
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

// ── Send-to-Management dialog: captures why it's being escalated ──────────────

class _SendToManagementDialog extends StatefulWidget {
  const _SendToManagementDialog();

  @override
  State<_SendToManagementDialog> createState() => _SendToManagementDialogState();
}

class _SendToManagementDialogState extends State<_SendToManagementDialog> {
  final _noteController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      setState(() => _error = 'Please add a note for Management.');
      return;
    }
    Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Send to Management'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Why is this being sent to Management?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Describe what needs their attention…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
              errorText: _error,
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Send')),
      ],
    );
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
