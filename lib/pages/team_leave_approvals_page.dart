import 'dart:async';
import 'package:flutter/material.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';

class TeamLeaveApprovalsPage extends StatefulWidget {
  /// isManagement: controls header label and icon (management vs manager)
  /// showAll: when true, shows every employee's leaves; when false, team only
  final bool isManagement;
  final bool showAll;
  const TeamLeaveApprovalsPage({
    super.key,
    this.isManagement = false,
    this.showAll = false,
  });

  @override
  State<TeamLeaveApprovalsPage> createState() => _TeamLeaveApprovalsPageState();
}

class _TeamLeaveApprovalsPageState extends State<TeamLeaveApprovalsPage> {
  static const _color = Color(0xFF283593);
  bool get _isMgmt   => widget.isManagement;
  bool get _showAll  => widget.showAll;

  Set<String> _teamNames = {};
  bool _teamLoaded = false;
  String _search = '';
  LeaveApprovalStatus? _filterStatus;
  bool _loading = false;

  List<LeaveApplication> get _requests {
    if (_showAll) return LeaveStore.applications;
    if (!_teamLoaded) return LeaveStore.applications;
    if (!_isMgmt) {
      // Manager: team's Permission/CompOff + regular leaves ≤ 2 days
      return LeaveStore.applications
          .where((a) => _teamNames.contains(a.employeeName) &&
              (a.leaveType == 'Permission' ||
               a.leaveType == 'Comp Off' ||
               a.effectiveDays <= 2))
          .toList();
    }
    // Management: all employees
    return LeaveStore.applications;
  }

  bool _matchesFilter(LeaveApplication r) {
    final matchSearch = _search.isEmpty ||
        r.employeeName.toLowerCase().contains(_search.toLowerCase()) ||
        r.leaveType.toLowerCase().contains(_search.toLowerCase());
    final matchStatus =
        _filterStatus == null || r.managerStatus == _filterStatus;
    return matchSearch && matchStatus;
  }

  List<LeaveApplication> get _filtered =>
      _requests.where(_matchesFilter).toList();

  bool _isPermCompOff(LeaveApplication a) =>
      a.leaveType == 'Permission' || a.leaveType == 'Comp Off';

  List<LeaveApplication> get _leaveSection {
    var src = _filtered.where((a) => !_isPermCompOff(a));
    // Manager only handles ≤ 2-day regular leaves; holidays go to Management
    if (!_isMgmt && !_showAll) src = src.where((a) => a.effectiveDays <= 2);
    return src.toList();
  }

  List<LeaveApplication> get _permSection =>
      _filtered.where((a) => a.leaveType == 'Permission').toList();

  List<LeaveApplication> get _compOffSection =>
      _filtered.where((a) => a.leaveType == 'Comp Off').toList();

  int get _pendingCount =>
      _filtered.where((r) => r.managerStatus == LeaveApprovalStatus.pending).length;
  int get _approvedCount =>
      _filtered.where((r) => r.managerStatus == LeaveApprovalStatus.approved).length;
  int get _deniedCount =>
      _filtered.where((r) => r.managerStatus == LeaveApprovalStatus.denied).length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchLeaveApplications()
            .timeout(const Duration(seconds: 8)),
        UserStore.load(),
      ]);
      final leaves = results[0] as List<LeaveApplication>;
      final users  = results[1] as List;

      if (leaves.isNotEmpty) {
        LeaveStore.applications..clear()..addAll(leaves);
        LeaveStore.syncCounter();
      }

      final myTeam = users
          .cast<dynamic>()
          .where((u) => u.reportingManager == UserSession.name)
          .map<String>((u) => u.name as String)
          .toSet();

      if (mounted) {
        setState(() {
          _teamNames  = myTeam;
          _teamLoaded = true;
          _loading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(LeaveApplication app) async {
    final by = UserSession.name;
    setState(() {
      app.managerStatus    = LeaveApprovalStatus.approved;
      app.decidedBy        = by;
      app.rejectionComment = '';
      app.decidedAt        = DateTime.now();
      if (_isMgmt) app.managementDecided = true;
    });
    if (_isMgmt) {
      await SupabaseService.updateLeaveManagementStatus(
          app.id, LeaveApprovalStatus.approved, decidedBy: by);
    } else {
      await SupabaseService.updateLeaveManagerStatus(
          app.id, LeaveApprovalStatus.approved, decidedBy: by);
    }
  }

  Future<void> _deny(LeaveApplication app) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deny Leave',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Reason for denial (optional):',
              style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
          const SizedBox(height: 10),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Insufficient notice / Busy period',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white),
            child: const Text('Deny'),
          ),
        ],
      ),
    );
    if (ok != true) { reasonCtrl.dispose(); return; }
    final comment = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    final by = UserSession.name;
    setState(() {
      app.managerStatus    = LeaveApprovalStatus.denied;
      app.decidedBy        = by;
      app.rejectionComment = comment;
      app.decidedAt        = DateTime.now();
      if (_isMgmt) app.managementDecided = true;
    });
    if (_isMgmt) {
      await SupabaseService.updateLeaveManagementStatus(
          app.id, LeaveApprovalStatus.denied,
          decidedBy: by, rejectionComment: comment);
    } else {
      await SupabaseService.updateLeaveManagerStatus(
          app.id, LeaveApprovalStatus.denied,
          decidedBy: by, rejectionComment: comment);
    }
  }

  Future<void> _reset(LeaveApplication app) async {
    setState(() {
      app.managerStatus    = LeaveApprovalStatus.pending;
      app.decidedBy        = '';
      app.rejectionComment = '';
      app.decidedAt        = null;
      if (_isMgmt) app.managementDecided = false;
    });
    if (_isMgmt) {
      await SupabaseService.updateLeaveManagementStatus(
          app.id, LeaveApprovalStatus.pending);
    } else {
      await SupabaseService.updateLeaveManagerStatus(
          app.id, LeaveApprovalStatus.pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isMgmt && _showAll) return _buildWithTabs(context);
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isMgmt
                    ? Icons.admin_panel_settings_rounded
                    : Icons.group_rounded,
                color: _color, size: 26),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _showAll ? 'All Leave Approvals' : 'Team Leave Approvals',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                _showAll
                    ? 'View and edit all employee leave decisions'
                    : 'Employees reporting directly to you',
                style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
              ),
            ]),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, color: _color),
              onPressed: _loadData,
            ),
          ]),
          const SizedBox(height: 24),

          // Summary chips
          Row(children: [
            _SummaryChip(
              label: 'Pending',
              count: _pendingCount,
              icon: Icons.hourglass_empty_rounded,
              color: Colors.orange.shade700,
              active: _filterStatus == LeaveApprovalStatus.pending,
              onTap: () => setState(() => _filterStatus =
                  _filterStatus == LeaveApprovalStatus.pending
                      ? null : LeaveApprovalStatus.pending),
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Approved',
              count: _approvedCount,
              icon: Icons.check_circle_rounded,
              color: Colors.green.shade700,
              active: _filterStatus == LeaveApprovalStatus.approved,
              onTap: () => setState(() => _filterStatus =
                  _filterStatus == LeaveApprovalStatus.approved
                      ? null : LeaveApprovalStatus.approved),
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Denied',
              count: _deniedCount,
              icon: Icons.cancel_rounded,
              color: Colors.red.shade700,
              active: _filterStatus == LeaveApprovalStatus.denied,
              onTap: () => setState(() => _filterStatus =
                  _filterStatus == LeaveApprovalStatus.denied
                      ? null : LeaveApprovalStatus.denied),
            ),
          ]),
          const SizedBox(height: 16),

          // Search bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search employee or leave type...',
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: _color, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _search = ''))
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _color, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_filterStatus != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Text(
                  'Showing: ${_filterStatus!.name[0].toUpperCase()}${_filterStatus!.name.substring(1)} only',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _filterStatus = null),
                  child: const Text('Clear',
                      style: TextStyle(
                          fontSize: 12,
                          color: _color,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),

          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator())),

          if (!_loading && !_isMgmt && _teamLoaded && _teamNames.isEmpty)
            _emptyCard(
              icon: Icons.group_off_rounded,
              title: 'No employees assigned to you',
              subtitle:
                  'Ask Management to assign employees via Administration → Edit User → Reporting Manager.',
            )
          else if (!_loading && _requests.isEmpty)
            _emptyCard(
              icon: Icons.inbox_rounded,
              title: _isMgmt
                  ? 'No leave requests yet'
                  : 'No leave requests from your team',
              subtitle: 'Leave requests will appear here for approval.',
            )
          else if (!_loading && _filtered.isEmpty)
            _emptyCard(
              icon: Icons.search_off_rounded,
              title: 'No results match your search',
              subtitle: '',
            )
          else if (!_loading) ...[
            // ── Leave Applications ──────────────────────────────────────────
            _SectionHeader(
              label: 'Leave Applications',
              count: _leaveSection.length,
              color: const Color(0xFF283593),
              icon: Icons.event_note_rounded,
            ),
            const SizedBox(height: 8),
            if (!_isMgmt)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _holidayPolicyNotice(context),
              ),
            if (_leaveSection.isEmpty)
              _emptyCard(
                icon: Icons.event_available_rounded,
                title: 'No leave requests',
                subtitle: '',
              )
            else
              ..._leaveSection.map((app) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RequestCard(
                      request:      app,
                      isManagement: _isMgmt,
                      onApprove:    () => _approve(app),
                      onDeny:       () => _deny(app),
                      onReset:      () => _reset(app),
                    ),
                  )),
            const SizedBox(height: 20),

            // ── Permission Applications ─────────────────────────────────────
            _SectionHeader(
              label: 'Permission Applications',
              count: _permSection.length,
              color: const Color(0xFF00838F),
              icon: Icons.access_time_rounded,
            ),
            const SizedBox(height: 8),
            _permLimitBanner(context),
            const SizedBox(height: 8),
            if (_permSection.isEmpty)
              _emptyCard(
                icon: Icons.schedule_rounded,
                title: 'No permission requests',
                subtitle: '',
              )
            else
              ..._permSection.map((app) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RequestCard(
                      request:      app,
                      isManagement: _isMgmt,
                      onApprove:    () => _approve(app),
                      onDeny:       () => _deny(app),
                      onReset:      () => _reset(app),
                    ),
                  )),
            const SizedBox(height: 20),

            // ── Comp Off Applications ───────────────────────────────────────
            _SectionHeader(
              label: 'Comp Off Applications',
              count: _compOffSection.length,
              color: const Color(0xFF2E7D32),
              icon: Icons.swap_horiz_rounded,
            ),
            const SizedBox(height: 8),
            if (_compOffSection.isEmpty)
              _emptyCard(
                icon: Icons.swap_horiz_rounded,
                title: 'No comp off requests',
                subtitle: '',
              )
            else
              ..._compOffSection.map((app) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RequestCard(
                      request:      app,
                      isManagement: _isMgmt,
                      onApprove:    () => _approve(app),
                      onDeny:       () => _deny(app),
                      onReset:      () => _reset(app),
                    ),
                  )),
          ],
        ]),
      ),
    );
  }

  // ── Management "All Leave Approvals" tabbed view ─────────────────────────────

  Widget _buildWithTabs(BuildContext context) {
    final leaveApps   = _filtered.where((a) => !_isPermCompOff(a)).toList();
    final permApps    = _permSection;
    final compOffApps = _compOffSection;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: null,
        body: Column(children: [
          // Fixed header
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header row
              Row(children: [
                const NavBackButton(),
                const SizedBox(width: 8),
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: _color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('All Leave Approvals', style: Theme.of(context).textTheme.headlineMedium),
                    const Text('View and edit all employee leave decisions',
                        style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
                  ]),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, color: _color),
                  onPressed: _loadData,
                ),
              ]),
              const SizedBox(height: 16),

              // Summary chips
              Row(children: [
                _SummaryChip(
                  label: 'Pending',
                  count: _pendingCount,
                  icon: Icons.hourglass_empty_rounded,
                  color: Colors.orange.shade700,
                  active: _filterStatus == LeaveApprovalStatus.pending,
                  onTap: () => setState(() => _filterStatus =
                      _filterStatus == LeaveApprovalStatus.pending ? null : LeaveApprovalStatus.pending),
                ),
                const SizedBox(width: 10),
                _SummaryChip(
                  label: 'Approved',
                  count: _approvedCount,
                  icon: Icons.check_circle_rounded,
                  color: Colors.green.shade700,
                  active: _filterStatus == LeaveApprovalStatus.approved,
                  onTap: () => setState(() => _filterStatus =
                      _filterStatus == LeaveApprovalStatus.approved ? null : LeaveApprovalStatus.approved),
                ),
                const SizedBox(width: 10),
                _SummaryChip(
                  label: 'Denied',
                  count: _deniedCount,
                  icon: Icons.cancel_rounded,
                  color: Colors.red.shade700,
                  active: _filterStatus == LeaveApprovalStatus.denied,
                  onTap: () => setState(() => _filterStatus =
                      _filterStatus == LeaveApprovalStatus.denied ? null : LeaveApprovalStatus.denied),
                ),
              ]),
              const SizedBox(height: 12),

              // Search bar
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search employee or leave type...',
                      prefixIcon: const Icon(Icons.search_rounded, color: _color, size: 20),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _search = ''))
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _color, width: 2),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tabs
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: 'Leaves (${leaveApps.length})'),
                  Tab(text: 'Permission (${permApps.length})'),
                  Tab(text: 'Comp Off (${compOffApps.length})'),
                ],
              ),
            ]),
          ),

          // Tab content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _tabList(context, leaveApps,   'No leave applications yet.'),
                    _tabList(context, permApps,    'No permission requests.'),
                    _tabList(context, compOffApps, 'No comp off requests.'),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _tabList(BuildContext context, List<LeaveApplication> apps, String emptyMsg) {
    if (apps.isEmpty) {
      final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_rounded, size: 52, color: muted),
          const SizedBox(height: 12),
          Text(emptyMsg,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 14)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: apps.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _RequestCard(
          request:      apps[i],
          isManagement: true,
          onApprove:    () => _approve(apps[i]),
          onDeny:       () => _deny(apps[i]),
          onReset:      () => _reset(apps[i]),
        ),
      ),
    );
  }

  Widget _holidayPolicyNotice(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.withValues(alpha: 0.12)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Colors.amber.withValues(alpha: isDark ? 0.4 : 0.6)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded,
            size: 15,
            color: isDark
                ? Colors.amber.shade300
                : const Color(0xFFF57F17)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Leaves > 2 days go directly to Management for approval.',
            style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? Colors.amber.shade300
                    : const Color(0xFFF57F17),
                fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }

  Widget _permLimitBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF00838F).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF00838F).withValues(alpha: 0.25)),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline_rounded,
            size: 15, color: Color(0xFF00838F)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Each employee is entitled to 2 hours of permission per month.',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFF00838F),
                fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }

  Widget _emptyCard(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Builder(builder: (context) {
            final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
            return Column(children: [
              Icon(icon, size: 52, color: muted),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: muted, fontSize: 14)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 12)),
              ],
            ]);
          }),
        ),
      ),
    );
  }
}

// ── Request card ───────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _RequestCard extends StatefulWidget {
  final LeaveApplication request;
  final bool isManagement;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback onReset;

  const _RequestCard({
    required this.request,
    required this.isManagement,
    required this.onApprove,
    required this.onDeny,
    required this.onReset,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  static const _undoWindow = Duration(minutes: 10);
  Timer? _timer;

  bool get _canUndo {
    final da = widget.request.decidedAt;
    if (da == null || widget.request.managerStatus == LeaveApprovalStatus.pending) return false;
    return DateTime.now().difference(da) < _undoWindow;
  }

  String get _countdown {
    final da = widget.request.decidedAt;
    if (da == null) return '';
    final remaining = _undoWindow - DateTime.now().difference(da);
    if (remaining.isNegative) return '';
    final m = remaining.inMinutes;
    final s = remaining.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _maybeStartTimer();
  }

  @override
  void didUpdateWidget(covariant _RequestCard old) {
    super.didUpdateWidget(old);
    _timer?.cancel();
    _maybeStartTimer();
  }

  void _maybeStartTimer() {
    if (!_canUndo) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_canUndo) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static Color _sc(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => Colors.green.shade700,
        LeaveApprovalStatus.denied   => Colors.red.shade700,
        LeaveApprovalStatus.pending  => Colors.orange.shade700,
      };
  static IconData _si(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => Icons.check_circle_rounded,
        LeaveApprovalStatus.denied   => Icons.cancel_rounded,
        LeaveApprovalStatus.pending  => Icons.hourglass_empty_rounded,
      };
  static String _sl(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => 'Approved',
        LeaveApprovalStatus.denied   => 'Denied',
        LeaveApprovalStatus.pending  => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    final status = widget.request.managerStatus;
    final sc     = _sc(status);
    final si     = _si(status);
    final sl     = _sl(status);

    final req = widget.request;
    return Card(
      child: Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final onSurface = cs.onSurface;
        final primary = cs.primary;

        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Employee header
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primary.withValues(alpha: isDark ? 0.2 : 0.1),
                child: Text(
                  req.employeeName.isNotEmpty
                      ? req.employeeName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.employeeName,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: onSurface)),
                      if (req.department.isNotEmpty)
                        Text(req.department,
                            style: TextStyle(
                                fontSize: 12,
                                color: onSurface.withValues(alpha: 0.5))),
                    ]),
              ),
              _StatusPill(sl, sc, si),
            ]),
            const SizedBox(height: 14),

            // Holiday badge
            if (req.effectiveDays > 2) ...[
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isDark ? Colors.red.shade700 : Colors.red.shade200),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.beach_access_rounded,
                        size: 13,
                        color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                    const SizedBox(width: 5),
                    Text('Holiday',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.red.shade300 : Colors.red.shade700)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
            ],

            // Leave details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.08 : 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: primary.withValues(alpha: isDark ? 0.18 : 0.08)),
              ),
              child: Column(children: [
                _DetailRow(Icons.label_rounded,      'Leave Type', req.leaveType),
                const SizedBox(height: 8),
                _DetailRow(Icons.date_range_rounded, 'Duration',
                    '${_fmtDate(req.from)}  →  ${_fmtDate(req.to)}'),
                const SizedBox(height: 8),
                _DetailRow(Icons.numbers_rounded,    'Days',
                    req.isHalfDay
                        ? '½ day'
                        : '${req.days} day${req.days == 1 ? '' : 's'}'),
                if (req.reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _DetailRow(Icons.notes_rounded, 'Reason', req.reason),
                ],
                if (req.leaveType == 'Permission') ...[
                  const SizedBox(height: 8),
                  Builder(builder: (ctx) {
                    final mu        = Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5);
                    final used      = LeaveStore.permUsedThisMonth(req.employeeName);
                    final remaining = (120 - used).clamp(0, 120);
                    final badgeColor = remaining == 0
                        ? Colors.red.shade700
                        : remaining <= 30
                            ? Colors.orange.shade700
                            : const Color(0xFF00838F);
                    return Row(children: [
                      Icon(Icons.schedule_rounded, size: 14, color: mu),
                      const SizedBox(width: 8),
                      Text('Monthly: ',
                          style: TextStyle(
                              fontSize: 12,
                              color: mu,
                              fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: badgeColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          remaining == 0
                              ? 'Limit reached'
                              : '$remaining min left this month',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeColor),
                        ),
                      ),
                    ]);
                  }),
                ],
              ]),
            ),
            const SizedBox(height: 14),

            // Action row — locked for managers when management has already decided
            if (!widget.isManagement && req.managementDecided)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: onSurface.withValues(alpha: isDark ? 0.15 : 0.12)),
                ),
                child: Row(children: [
                  Icon(Icons.lock_rounded,
                      size: 15, color: onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Decision locked by Management: $sl'
                      '${req.decidedBy.isNotEmpty ? ' (${req.decidedBy})' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          color: onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              )
            else if (status == LeaveApprovalStatus.pending)
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDeny,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Deny'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onApprove,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ])
            else
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(si, size: 16, color: sc),
                    const SizedBox(width: 6),
                    Text(
                      '$sl by ${req.decidedBy.isEmpty ? 'Manager' : req.decidedBy}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sc),
                    ),
                  ]),
                ),
                const Spacer(),
                if (_canUndo)
                  TextButton.icon(
                    onPressed: widget.onReset,
                    icon: const Icon(Icons.undo_rounded, size: 15),
                    label: Text('Undo ($_countdown)',
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: onSurface.withValues(alpha: 0.5)),
                  ),
              ]),

            // Denial reason
            if (status == LeaveApprovalStatus.denied &&
                req.rejectionComment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.07),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: isDark ? 0.4 : 0.25)),
                ),
                child: Text(req.rejectionComment,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.red.shade300 : Colors.red.shade800)),
              ),
            ],
          ]),
        );
      }),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: muted),
      const SizedBox(width: 8),
      Text('$label: ',
          style: TextStyle(
              fontSize: 12,
              color: muted,
              fontWeight: FontWeight.w500)),
      Expanded(
        child: Text(value,
            style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusPill(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ]),
      ),
      Expanded(
          child: Divider(color: color.withValues(alpha: 0.2), indent: 10)),
    ]);
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? Colors.white : color),
          const SizedBox(width: 6),
          Text('$count $label',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : color)),
        ]),
      ),
    );
  }
}
