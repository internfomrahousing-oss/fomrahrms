import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/org_lists.dart';
import '../models/app_user.dart';
import '../models/leave_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';
import '../widgets/filter_panel.dart';
import '../theme/app_theme.dart';

class HrLeaveRecordsPage extends StatefulWidget {
  const HrLeaveRecordsPage({super.key});

  @override
  State<HrLeaveRecordsPage> createState() => _HrLeaveRecordsPageState();
}

class _HrLeaveRecordsPageState extends State<HrLeaveRecordsPage>
    with SingleTickerProviderStateMixin {
  static Color get _color => AppTheme.primaryBlue;

  late final TabController _tabs;
  bool _loading = true;

  // Month shown in the All Applications tab — always starts on the current month.
  // Resets to current month each time the page is (re)opened.
  late DateTime _selectedMonth;

  List<AppUser> _employees = [];
  List<LeaveApplication> get _applications => LeaveStore.applications;

  // ── Employee Allocations tab: search / filter / pagination state ─────────
  final _searchController = TextEditingController();
  String _search = '';
  String _deptFilter = 'All';
  String _desigFilter = 'All';
  String _statusFilter = 'Active';
  int _page = 1;
  int _pageSize = 10;

  List<LeaveApplication> get _monthApps {
    return _applications.where((a) =>
        a.from.year == _selectedMonth.year &&
        a.from.month == _selectedMonth.month).toList();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  static const _monthNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        UserStore.load(),
        SupabaseService.fetchLeaveApplications().timeout(const Duration(seconds: 8)),
      ]);

      final users = results[0] as List<AppUser>;
      final leaves = results[1] as List<LeaveApplication>;

      if (leaves.isNotEmpty) {
        LeaveStore.applications..clear()..addAll(leaves);
        LeaveStore.syncCounter();
      }

      if (mounted) {
        setState(() {
          // Housekeeping/Support Staff are managed via Staff Portal Approvals
          // instead, so they're excluded from Employee Allocations.
          _employees = users
              .where((u) => (u.role == 'Employee' || u.role == 'Manager') &&
                  !kStaffPortalDepartments.contains(u.department))
              .toList();
          _loading = false;
          _page = 1;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Filter to current month only — leaves reset each month, no carry-over
  bool _isThisMonth(LeaveApplication a) {
    final now = DateTime.now();
    return a.from.year == now.year && a.from.month == now.month;
  }

  double _usedBucket(String name, String bucket, {bool monthOnly = true}) =>
      _applications.where((a) =>
          a.employeeName == name &&
          a.bucket == bucket &&
          a.managerStatus == LeaveApprovalStatus.approved &&
          (!monthOnly || _isThisMonth(a)))
      .fold(0.0, (s, a) => s + a.effectiveDays);

  double _elUsedSince(String name, String since) {
    final cutoff = since.isNotEmpty ? DateTime.tryParse(since) : null;
    return _applications.where((a) =>
        a.employeeName == name &&
        a.leaveType == 'Earned Leave' &&
        a.managerStatus == LeaveApprovalStatus.approved &&
        (cutoff == null || a.from.isAfter(cutoff)))
    .fold(0.0, (s, a) => s + a.effectiveDays);
  }

static String _fmtD(double d) =>
      d % 1 == 0 ? '${d.toInt()}d' : '${d.toStringAsFixed(1)}d';

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtJoined(String iso) {
    if (iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')} ${_monthNames[d.month - 1].substring(0, 3)} ${d.year}';
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = _selectedMonth.isAfter(now)
        ? DateTime(now.year, now.month, 1)
        : DateTime(_selectedMonth.year, _selectedMonth.month, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.day,
    );

    if (picked != null && mounted) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        child: Column(
        children: [
          // Header
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: EdgeInsets.fromLTRB(narrow ? 12 : 24, narrow ? 16 : 24, narrow ? 12 : 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const NavBackButton(),
                  SizedBox(width: narrow ? 4 : 8),
                  if (!narrow) ...[
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.folder_shared_rounded, color: _color, size: 26),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Leave Records',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium),
                      if (!narrow)
                        const Text('HR Management', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ]),
                  ),
                  SizedBox(width: narrow ? 4 : 8),
                  narrow
                      ? IconButton(
                          tooltip: 'Edit Forms',
                          onPressed: () {
                            final prefix = UserSession.role == UserRole.management
                                ? '/management'
                                : '';
                            context.push('$prefix/edit-leave-form');
                          },
                          icon: Icon(Icons.edit_note_rounded, color: _color),
                        )
                      : OutlinedButton.icon(
                          onPressed: () {
                            final prefix = UserSession.role == UserRole.management
                                ? '/management'
                                : '';
                            context.push('$prefix/edit-leave-form');
                          },
                          icon: const Icon(Icons.edit_note_rounded, size: 15),
                          label: const Text('Edit Forms', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _color,
                            side: BorderSide(color: _color),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                  SizedBox(width: narrow ? 4 : 8),
                  IconButton(
                    onPressed: _reload,
                    icon: Icon(Icons.refresh_rounded, color: _color),
                    tooltip: 'Refresh',
                  ),
                ]),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabs,
                  labelColor: _color,
                  unselectedLabelColor: const Color(0xFF6B7280),
                  indicatorColor: _color,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(icon: Icon(Icons.people_rounded,      size: 18), text: 'Employee Allocations'),
                    Tab(icon: Icon(Icons.event_note_rounded,  size: 18), text: 'Leave'),
                    Tab(icon: Icon(Icons.access_time_rounded, size: 18), text: 'Permission'),
                    Tab(icon: Icon(Icons.swap_horiz_rounded,  size: 18), text: 'Comp Off'),
                  ],
                ),
              ],
            ),
          ),

          // The whole page (header, tab bar, and this) scrolls as one via
          // the SingleChildScrollView above, so this just shows whichever
          // tab is selected rather than a bounded-height TabBarView.
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            switch (_tabs.index) {
              0 => _buildAllocationsTab(),
              1 => _buildApplicationsTab(typeFilter: 'leave'),
              2 => _buildApplicationsTab(typeFilter: 'Permission'),
              _ => _buildApplicationsTab(typeFilter: 'Comp Off'),
            },
        ],
        ),
      ),
    );
  }

  // ── Tab 1: Employee allocations ───────────────────────────────────────────

  List<AppUser> get _filteredEmployees {
    final q = _search.trim().toLowerCase();
    return _employees.where((e) {
      final matchesSearch = q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.email.toLowerCase().contains(q) ||
          e.role.toLowerCase().contains(q);
      final matchesDept = _deptFilter == 'All' || e.department == _deptFilter;
      final matchesDesig = _desigFilter == 'All' || e.designation == _desigFilter;
      final matchesStatus = _statusFilter == 'All' ||
          (_statusFilter == 'Active' ? e.active : !e.active);
      return matchesSearch && matchesDept && matchesDesig && matchesStatus;
    }).toList();
  }

  int _pageCountFor(int total) => total == 0 ? 1 : (total / _pageSize).ceil();

  double get _orgTotalAvailable {
    double sum = 0;
    for (final u in _employees) {
      sum += (u.monthlyMl - _usedBucket(u.name, 'ML')).clamp(0, u.monthlyMl.toDouble());
      sum += (u.monthlyCl - _usedBucket(u.name, 'CL')).clamp(0, u.monthlyCl.toDouble());
      final elQuota = (u.monthlyEl * 12).toDouble();
      sum += (elQuota - _elUsedSince(u.name, u.elLastAvailedAt)).clamp(0, elQuota);
    }
    return sum;
  }

  double get _orgTotalUsed {
    double sum = 0;
    for (final u in _employees) {
      sum += _usedBucket(u.name, 'ML');
      sum += _usedBucket(u.name, 'CL');
      sum += _elUsedSince(u.name, u.elLastAvailedAt);
    }
    return sum;
  }

  Widget _buildAllocationsTab() {
    if (_employees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.group_off_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No employees found', style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Add employees via Administration first.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ]),
        ),
      );
    }

    final filtered = _filteredEmployees;
    final pageCount = _pageCountFor(filtered.length);
    final page = _page.clamp(1, pageCount);
    final start = (page - 1) * _pageSize;
    final paged = filtered.isEmpty
        ? <AppUser>[]
        : filtered.sublist(start, (start + _pageSize).clamp(0, filtered.length));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildStatsRow(),
        const SizedBox(height: 16),
        _buildFilterBar(),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(children: [
                  Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('No employees match these filters',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                ]),
              ),
            ),
          )
        else ...[
          ...paged.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildEmployeeCard(u),
              )),
          const SizedBox(height: 8),
          _buildPaginationFooter(filtered.length, pageCount, page),
        ],
      ]),
    );
  }

  Widget _buildStatsRow() {
    final cards = [
      _StatCard(
        icon: Icons.groups_rounded,
        color: _color,
        label: 'Total Employees',
        value: '${_employees.where((e) => e.active).length}',
        caption: 'Active employees',
      ),
      _StatCard(
        icon: Icons.event_note_rounded,
        color: Colors.green.shade600,
        label: 'Total Leave Types',
        value: '3',
        caption: 'ML, CL, EL',
      ),
      _StatCard(
        icon: Icons.calendar_month_rounded,
        color: Colors.purple.shade600,
        label: 'Total Available',
        value: _fmtD(_orgTotalAvailable),
        caption: 'Across all leave types',
      ),
      _StatCard(
        icon: Icons.swap_horiz_rounded,
        color: Colors.orange.shade700,
        label: 'Total Used',
        value: _fmtD(_orgTotalUsed),
        caption: 'Across all leave types',
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 700) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
        );
      }
      final statsRow = Row(children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 12),
        ],
      ]);
      if (constraints.maxWidth < 950) return statsRow;
      return Row(children: [
        Expanded(child: statsRow),
        const SizedBox(width: 16),
        _buildIllustration(),
      ]);
    });
  }

  Widget _buildIllustration() {
    return Container(
      width: 150,
      height: 112,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withValues(alpha: 0.08), _color.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.all_inclusive_rounded, size: 42, color: _color.withValues(alpha: 0.18)),
        Icon(Icons.self_improvement_rounded, size: 46, color: _color.withValues(alpha: 0.55)),
      ]),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(builder: (context, constraints) {
          final search = TextField(
            controller: _searchController,
            onChanged: (v) => setState(() { _search = v; _page = 1; }),
            decoration: InputDecoration(
              hintText: 'Search employee by name, email or role...',
              prefixIcon: Icon(Icons.search_rounded, color: _color, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );
          final filterBtn = FilterTriggerButton(
            hasActiveFilters: _deptFilter != 'All' || _desigFilter != 'All' || _statusFilter != 'Active',
            onTap: () {
              String deptDraft = _deptFilter;
              String desigDraft = _desigFilter;
              String statusDraft = _statusFilter;
              showFilterPanel(
                context,
                title: 'Filters',
                onReset: () { deptDraft = 'All'; desigDraft = 'All'; statusDraft = 'Active'; },
                onApply: () => setState(() {
                  _deptFilter = deptDraft; _desigFilter = desigDraft; _statusFilter = statusDraft; _page = 1;
                }),
                builder: (context, setPanelState) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FilterDropdownField<String>(
                    label: 'Department',
                    value: deptDraft == 'All' ? null : deptDraft,
                    options: kDepartments,
                    labelOf: (d) => d,
                    allLabel: 'All Departments',
                    onChanged: (v) => setPanelState(() => deptDraft = v ?? 'All'),
                  ),
                  FilterDropdownField<String>(
                    label: 'Designation',
                    value: desigDraft == 'All' ? null : desigDraft,
                    options: kDesignations,
                    labelOf: (d) => d,
                    allLabel: 'All Designations',
                    onChanged: (v) => setPanelState(() => desigDraft = v ?? 'All'),
                  ),
                  FilterChipGroup<String>(
                    label: 'Status',
                    value: statusDraft == 'All' ? null : statusDraft,
                    options: const ['Active', 'Inactive'],
                    labelOf: (s) => s,
                    onChanged: (v) => setPanelState(() => statusDraft = v ?? 'All'),
                  ),
                ]),
              );
            },
          );

          if (constraints.maxWidth < 760) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              search,
              const SizedBox(height: 10),
              filterBtn,
            ]);
          }

          return Row(children: [
            Expanded(child: search),
            const SizedBox(width: 10),
            filterBtn,
          ]);
        }),
      ),
    );
  }

  Widget _buildEmployeeCard(AppUser user) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, constraints) {
          final info = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _color.withValues(alpha: 0.12),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(user.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: Color(0xFF111827))),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: user.active ? Colors.green.shade600 : Colors.grey.shade400,
                    ),
                  ),
                ]),
                Text(user.email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                Text(user.designation.isEmpty ? user.role : user.designation,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
                if (user.department.isNotEmpty)
                  Text(user.department, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (user.active ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(user.active ? 'Active' : 'Inactive',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: user.active ? Colors.green.shade700 : Colors.grey.shade600)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.employeeId.isEmpty ? '—' : user.employeeId} · Joined on ${_fmtJoined(user.dateOfJoining)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ]),
            ),
          ]);

          final balances = Row(children: [
            _LeaveTypeBlock('ML',
              icon: Icons.wb_twilight_rounded,
              used: _usedBucket(user.name, 'ML'),
              quota: user.monthlyMl,
              color: AppTheme.accentBlue),
            const SizedBox(width: 8),
            _LeaveTypeBlock('CL',
              icon: Icons.event_available_rounded,
              used: _usedBucket(user.name, 'CL'),
              quota: user.monthlyCl,
              color: Colors.teal.shade700),
            const SizedBox(width: 8),
            _LeaveTypeBlock('EL',
              icon: Icons.card_giftcard_rounded,
              used: _elUsedSince(user.name, user.elLastAvailedAt),
              quota: user.monthlyEl * 12,
              color: Colors.purple.shade700),
          ]);

          if (constraints.maxWidth < 640) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              info,
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              balances,
            ]);
          }

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 4, child: info),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: balances),
          ]);
        }),
      ),
    );
  }

  Widget _buildPaginationFooter(int totalCount, int pageCount, int page) {
    final rangeStart = totalCount == 0 ? 0 : (page - 1) * _pageSize + 1;
    final rangeEnd = (page * _pageSize).clamp(0, totalCount);

    final info = Text('Showing $rangeStart to $rangeEnd of $totalCount employees',
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)));

    final pageSizeDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderSubtle),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _pageSize,
          isDense: true,
          items: const [10, 20, 50]
              .map((n) => DropdownMenuItem(value: n, child: Text('$n per page', style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: (v) => setState(() { _pageSize = v!; _page = 1; }),
        ),
      ),
    );

    final pager = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        icon: const Icon(Icons.chevron_left_rounded),
        color: page > 1 ? _color : Colors.grey.shade400,
        onPressed: page > 1 ? () => setState(() => _page = page - 1) : null,
      ),
      for (final entry in _pageWindow(pageCount, page))
        entry == '...'
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: Color(0xFF6B7280))),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _page = entry as int),
                  child: Container(
                    width: 32, height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry == page ? _color : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$entry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: entry == page ? Colors.white : const Color(0xFF111827),
                        )),
                  ),
                ),
              ),
      IconButton(
        icon: const Icon(Icons.chevron_right_rounded),
        color: page < pageCount ? _color : Colors.grey.shade400,
        onPressed: page < pageCount ? () => setState(() => _page = page + 1) : null,
      ),
    ]);

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 640) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          info,
          const SizedBox(height: 8),
          Row(children: [pageSizeDropdown, const Spacer(), pager]),
        ]);
      }
      return Row(children: [
        info,
        const Spacer(),
        pageSizeDropdown,
        const SizedBox(width: 16),
        pager,
      ]);
    });
  }

  /// Builds the compact page-number window (e.g. 1 … 4 5 6 … 13), always
  /// including the first, last, and pages adjacent to the current one.
  List<Object> _pageWindow(int total, int current) {
    if (total <= 7) return List.generate(total, (i) => i + 1);
    final keep = <int>{1, total, current};
    if (current - 1 >= 1) keep.add(current - 1);
    if (current + 1 <= total) keep.add(current + 1);
    final sorted = keep.toList()..sort();
    final result = <Object>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) result.add('...');
      result.add(sorted[i]);
    }
    return result;
  }

  // ── Tabs 2-4: Applications filtered by type ──────────────────────────────

  Widget _buildApplicationsTab({required String typeFilter}) {
    final apps = _monthApps.where((a) {
      if (typeFilter == 'leave') {
        return a.leaveType != 'Permission' && a.leaveType != 'Comp Off';
      }
      return a.leaveType == typeFilter;
    }).toList();
    final pending  = apps.where((a) => a.managerStatus == LeaveApprovalStatus.pending).length;
    final approved = apps.where((a) => a.managerStatus == LeaveApprovalStatus.approved).length;
    final denied   = apps.where((a) => a.managerStatus == LeaveApprovalStatus.denied).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Month navigator
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(children: [
                  Tooltip(
                    message: 'Previous month',
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.month == 1 ? _selectedMonth.year - 1 : _selectedMonth.year,
                          _selectedMonth.month == 1 ? 12 : _selectedMonth.month - 1,
                        );
                      }),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.chevron_left_rounded, size: 28, color: _color),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _pickMonth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(children: [
                          Text(
                            '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: _color),
                          ),
                          Text(
                            _isCurrentMonth ? 'Current month' : 'Tap to pick month',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: _isCurrentMonth ? '' : 'Next month',
                    child: InkWell(
                      onTap: _isCurrentMonth ? null : () => setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.month == 12 ? _selectedMonth.year + 1 : _selectedMonth.year,
                          _selectedMonth.month == 12 ? 1 : _selectedMonth.month + 1,
                        );
                      }),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.chevron_right_rounded, size: 28,
                            color: _isCurrentMonth ? Colors.grey.shade400 : _color),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Summary badges
        Row(children: [
          _StatusBadge('Pending',  Icons.hourglass_empty_rounded, Colors.orange.shade700, pending),
          const SizedBox(width: 10),
          _StatusBadge('Approved', Icons.check_circle_rounded,    Colors.green.shade700,  approved),
          const SizedBox(width: 10),
          _StatusBadge('Denied',   Icons.cancel_rounded,          Colors.red.shade700,    denied),
        ]),
        const SizedBox(height: 16),

        if (apps.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(children: [
                  Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    _isCurrentMonth
                        ? 'No applications this month'
                        : 'No applications in ${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                ]),
              ),
            ),
          )
        else
          ...apps.map((app) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AppCard(app: app, fmt: _fmt),
              )),
      ]),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String caption;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(caption, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}

class _LeaveTypeBlock extends StatelessWidget {
  final String type;
  final IconData icon;
  final double used;
  final int quota;
  final Color color;
  const _LeaveTypeBlock(this.type, {
    required this.icon,
    required this.used,
    required this.quota,
    required this.color,
  });

  static String _fmt(double d) =>
      d % 1 == 0 ? '${d.toInt()}d' : '${d.toStringAsFixed(1)}d';

  @override
  Widget build(BuildContext context) {
    final available = (quota - used).clamp(0.0, quota.toDouble());
    final ratio = quota == 0 ? 0.0 : (used / quota).clamp(0.0, 1.0);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(type,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            const Spacer(),
            Text(_fmt(quota.toDouble()),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.event_available_rounded, size: 11, color: Colors.green.shade700),
            const SizedBox(width: 3),
            Flexible(
              child: Text('${_fmt(available)} available',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.green.shade700)),
            ),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 11, color: Colors.orange.shade700),
            const SizedBox(width: 3),
            Flexible(
              child: Text('${_fmt(used)} used',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.orange.shade700)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  const _StatusBadge(this.label, this.icon, this.color, this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text('$count $label',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _AppCard extends StatelessWidget {
  final LeaveApplication app;
  final String Function(DateTime) fmt;
  const _AppCard({required this.app, required this.fmt});

  Color _statusColor(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => Colors.green.shade700,
        LeaveApprovalStatus.denied   => Colors.red.shade700,
        LeaveApprovalStatus.pending  => Colors.orange.shade700,
      };
  IconData _statusIcon(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => Icons.check_circle_rounded,
        LeaveApprovalStatus.denied   => Icons.cancel_rounded,
        LeaveApprovalStatus.pending  => Icons.hourglass_empty_rounded,
      };
  String _statusLabel(LeaveApprovalStatus s) => switch (s) {
        LeaveApprovalStatus.approved => 'Approved',
        LeaveApprovalStatus.denied   => 'Denied',
        LeaveApprovalStatus.pending  => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    final ms = app.managerStatus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.person_rounded, color: AppTheme.primaryBlue, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(app.employeeName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: Color(0xFF111827))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(ms).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(ms), size: 12, color: _statusColor(ms)),
                const SizedBox(width: 4),
                Text(_statusLabel(ms),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: _statusColor(ms))),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 4, children: [
            if (app.leaveType.isNotEmpty)
              _Chip(Icons.label_rounded, app.leaveType),
            _Chip(Icons.calendar_today_rounded, '${fmt(app.from)} → ${fmt(app.to)}'),
            _Chip(Icons.numbers_rounded, '${app.days} day${app.days == 1 ? '' : 's'}'),
            if (app.reason.isNotEmpty)
              _Chip(Icons.notes_rounded, app.reason),
          ]),
          if (ms != LeaveApprovalStatus.pending) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.manage_accounts_rounded,
                  size: 12, color: _statusColor(ms).withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                '${_statusLabel(ms)} by ${app.decidedBy.isEmpty ? 'Manager' : app.decidedBy}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(ms)),
              ),
              if (ms == LeaveApprovalStatus.denied &&
                  app.rejectionComment.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '· "${app.rejectionComment}"',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: const Color(0xFF6B7280)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
    ]);
  }
}
