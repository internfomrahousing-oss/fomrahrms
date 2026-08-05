import 'package:flutter/material.dart';
import '../widgets/employee_list_dialog.dart';
import '../constants/org_lists.dart';
import '../models/app_user.dart';
import '../models/attendance_store.dart';
import '../models/leave_store.dart';
import '../models/office_timing.dart';
import '../models/payslip_store.dart';
import '../models/user_session.dart';
import '../services/report_pdf_service.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../theme/app_theme.dart';
import '../utils/checkin_status.dart';
import '../widgets/reports/attendance_trend_chart.dart';
import '../widgets/reports/department_attendance_chart.dart';
import '../widgets/reports/leave_distribution_chart.dart';
import '../widgets/reports/live_tracking_map.dart';
import '../widgets/reports/payroll_summary_card.dart';
import '../widgets/reports/report_card_shell.dart';
import '../widgets/reports/report_tables.dart';
import '../widgets/reports/reports_header.dart';
import '../widgets/reports/working_hours_chart.dart';
import '../widgets/stat_strip.dart';

String _dateStr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class ReportsAnalyticsPage extends StatefulWidget {
  const ReportsAnalyticsPage({super.key});

  @override
  State<ReportsAnalyticsPage> createState() => _ReportsAnalyticsPageState();
}

class _ReportsAnalyticsPageState extends State<ReportsAnalyticsPage> {
  bool _loading = true;
  bool _refreshing = false;
  bool _exporting = false;

  List<AppUser> _users = [];
  List<AttendanceRecord> _todayAttendance = [];
  List<AttendanceRecord> _rangeAttendance = [];
  List<LeaveApplication> _leaveApps = [];
  List<Payslip> _payslips = [];
  List<AttendanceRecord> _checkedInNow = [];

  final List<({String filename, DateTime generatedAt})> _recentReports = [];

  QuickRange _quickRange = QuickRange.thisWeek;
  DateTimeRange _range = rangeFor(QuickRange.thisWeek);
  String? _department;
  String? _location;
  String? _role;

  bool get _canSeePayroll =>
      UserSession.role == UserRole.hr || UserSession.role == UserRole.management;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // HR/Management see the whole org (minus Staff Portal, managed separately
  // — see Staff Portal Approvals); a Reporting Manager reaching this page
  // sees only their own reportees, same scoping as Employee Management.
  List<AppUser> _baseRoster(List<AppUser> users) {
    final withoutStaffPortal =
        users.where((u) => !kStaffPortalDepartments.contains(u.department)).toList();
    if (_canSeePayroll) return withoutStaffPortal;
    if (!UserSession.isReportingManager) return const [];
    final me = UserSession.name.trim().toLowerCase();
    if (me.isEmpty) return const [];
    return withoutStaffPortal
        .where((u) => u.reportingManager.trim().toLowerCase() == me)
        .toList();
  }

  List<String> _datesInRange() {
    final days = _range.end.difference(_range.start).inDays;
    return [for (var i = 0; i <= days; i++) _dateStr(_range.start.add(Duration(days: i)))];
  }

  Future<void> _load({bool isRefresh = false}) async {
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
    });
    final today = DateTime.now();
    final todayStr = _dateStr(today);
    final monthYear = '${today.year}-${today.month.toString().padLeft(2, '0')}';

    final results = await Future.wait([
      UserStore.load(),
      SupabaseService.fetchAttendanceForDate(todayStr),
      SupabaseService.fetchAttendanceForDates(_datesInRange()),
      SupabaseService.fetchLeaveApplications(),
      SupabaseService.fetchCheckedInAttendance(todayStr),
      _canSeePayroll ? SupabaseService.fetchPayslipsForMonth(monthYear) : Future.value(<Payslip>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _users = _baseRoster(results[0] as List<AppUser>);
      _todayAttendance = results[1] as List<AttendanceRecord>;
      _rangeAttendance = results[2] as List<AttendanceRecord>;
      _leaveApps = results[3] as List<LeaveApplication>;
      _checkedInNow = results[4] as List<AttendanceRecord>;
      _payslips = results[5] as List<Payslip>;
      _loading = false;
      _refreshing = false;
    });
  }

  // ── Filters ────────────────────────────────────────────────────────────

  List<String> get _departmentOptions =>
      (_users.map((u) => u.department).where((d) => d.isNotEmpty).toSet().toList()..sort());
  List<String> get _locationOptions =>
      (_users.map((u) => u.workLocation).where((d) => d.isNotEmpty).toSet().toList()..sort());
  List<String> get _roleOptions =>
      (_users.map((u) => u.role).where((d) => d.isNotEmpty).toSet().toList()..sort());

  List<AppUser> get _filteredUsers => _users.where((u) {
        if (_department != null && u.department != _department) return false;
        if (_location != null && u.workLocation != _location) return false;
        if (_role != null && u.role != _role) return false;
        return true;
      }).toList();

  Set<String> get _filteredNames =>
      _filteredUsers.map((u) => u.name.toLowerCase()).toSet();

  int get _activeCount => _filteredUsers.where((u) => u.active).length;

  // ── Today KPIs ─────────────────────────────────────────────────────────

  List<AttendanceRecord> get _todayFiltered => _todayAttendance
      .where((r) => _filteredNames.contains(r.employeeName.toLowerCase()))
      .toList();

  int get _presentToday => _todayFiltered.where((r) => r.checkInTime.isNotEmpty).length;

  List<LeaveApplication> get _onLeaveTodayApps {
    final d = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _leaveApps.where((a) =>
        a.managerStatus == LeaveApprovalStatus.approved &&
        _filteredNames.contains(a.employeeName.toLowerCase()) &&
        !d.isBefore(DateTime(a.from.year, a.from.month, a.from.day)) &&
        !d.isAfter(DateTime(a.to.year, a.to.month, a.to.day))).toList();
  }

  int get _onLeaveToday =>
      _onLeaveTodayApps.map((a) => a.employeeName.toLowerCase()).toSet().length;

  int get _absentToday =>
      (_activeCount - _presentToday - _onLeaveToday).clamp(0, _activeCount);

  int get _liveCheckIns => _checkedInNow
      .where((r) => _filteredNames.contains(r.employeeName.toLowerCase()))
      .length;

  // ── Range-based data ──────────────────────────────────────────────────

  List<AttendanceRecord> get _rangeFiltered => _rangeAttendance
      .where((r) => _filteredNames.contains(r.employeeName.toLowerCase()))
      .toList();

  /// Resolves [employeeName]'s designation-based schedule from [_users];
  /// falls back to the default timing if the employee isn't found.
  OfficeTiming _scheduleForEmployee(String employeeName) {
    final n = employeeName.trim().toLowerCase();
    final user = _users.where((u) => u.name.trim().toLowerCase() == n).firstOrNull;
    return user != null ? OfficeTimingStore.scheduleForUser(user) : OfficeTimingStore.fallback;
  }

  bool _isLate(AttendanceRecord r) {
    if (r.checkInTime.isEmpty) return false;
    final date = parseSlashDate(r.date);
    if (date == null) return false;
    return checkInStatusFor(r.checkInTime, date, r.employeeName, _leaveApps,
                _scheduleForEmployee(r.employeeName)).status ==
        CheckInStatus.late;
  }

  int get _lateArrivalsInRange => _rangeFiltered.where(_isLate).length;

  double? _workedHours(AttendanceRecord r) {
    if (r.checkInTime.isEmpty || r.checkOutTime.isEmpty) return null;
    int? toMin(String t) {
      final p = t.split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return h * 60 + m;
    }
    final inM = toMin(r.checkInTime), outM = toMin(r.checkOutTime);
    if (inM == null || outM == null || outM < inM) return null;
    return (outM - inM) / 60.0;
  }

  double get _overtimeHoursInRange => _rangeFiltered.fold(0.0, (sum, r) {
        final hrs = _workedHours(r);
        if (hrs == null) return sum;
        final targetHours = _scheduleForEmployee(r.employeeName).workingHours;
        if (hrs <= targetHours) return sum;
        return sum + (hrs - targetHours);
      });

  static DateTime? _parseJoin(AppUser u) {
    final p = u.dateOfJoining.split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), mo = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (d == null || mo == null || y == null) return null;
    return DateTime(y, mo, d);
  }

  int get _newEmployeesInRange => _filteredUsers.where((u) {
        final joined = _parseJoin(u);
        if (joined == null) return false;
        return !joined.isBefore(_range.start) && !joined.isAfter(_range.end);
      }).length;

  // ── Charts ─────────────────────────────────────────────────────────────

  List<AttendanceTrendPoint> get _trendPoints {
    final total = _activeCount == 0 ? 1 : _activeCount;
    final byDate = <String, int>{};
    for (final r in _rangeFiltered) {
      if (r.checkInTime.isEmpty) continue;
      byDate[r.date] = (byDate[r.date] ?? 0) + 1;
    }
    return [
      for (final ds in _datesInRange())
        AttendanceTrendPoint(
          date: parseSlashDate(ds) ?? DateTime.now(),
          percent: (byDate[ds] ?? 0) / total,
        ),
    ];
  }

  List<DepartmentAttendanceBar> get _departmentBars {
    final days = _datesInRange().length.clamp(1, 1 << 30);
    final depts = _filteredUsers.map((u) => u.department).where((d) => d.isNotEmpty).toSet().toList()..sort();
    return [
      for (final dept in depts)
        () {
          final deptUsers = _filteredUsers.where((u) => u.department == dept && u.active).toSet();
          final deptNames = deptUsers.map((u) => u.name.toLowerCase()).toSet();
          final possible = deptUsers.length * days;
          final presentRecords = _rangeFiltered.where((r) =>
              deptNames.contains(r.employeeName.toLowerCase()) && r.checkInTime.isNotEmpty);
          final present = presentRecords.length;
          // Distinct people, not record count — the bar counts records over the
          // range, but a person is what someone wants to see when they tap it.
          final presentNames = presentRecords
              .map((r) => r.employeeName)
              .toSet()
              .toList()
            ..sort();
          final allNames = _users
              .where((u) => u.department == dept)
              .map((u) => u.name)
              .toList()
            ..sort();
          return DepartmentAttendanceBar(
              department: dept,
              percent: possible == 0 ? 0 : (present / possible).clamp(0.0, 1.0),
              presentNames: presentNames,
              allNames: allNames);
        }(),
    ];
  }

  List<WorkingHoursDay> get _workingHoursDays {
    final avgSum = List.filled(7, 0.0), avgCount = List.filled(7, 0);
    final otSum = List.filled(7, 0.0);
    for (final r in _rangeFiltered) {
      final hrs = _workedHours(r);
      if (hrs == null) continue;
      final date = parseSlashDate(r.date);
      if (date == null) continue;
      final idx = date.weekday - 1; // Mon=0..Sun=6
      avgSum[idx] += hrs;
      avgCount[idx]++;
      if (hrs > 8) otSum[idx] += hrs - 8;
    }
    return [
      for (var i = 0; i < 7; i++)
        WorkingHoursDay(
          label: _weekdayLabels[i],
          avgHours: avgCount[i] == 0 ? 0 : avgSum[i] / avgCount[i],
          overtimeHours: otSum[i],
        ),
    ];
  }

  static const _mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _dayLabel(DateTime d) => '${d.day} ${_mon[d.month - 1]}';

  /// Who is behind a department bar. Present people first, then the rest of
  /// the department marked absent, so the percentage is explained both ways.
  void _showDepartmentPeople(DepartmentAttendanceBar bar) {
    final present = bar.presentNames.toSet();
    final items = <EmployeeListItem>[
      for (final n in bar.presentNames)
        EmployeeListItem(name: n, subtitle: 'Present'),
      for (final n in bar.allNames.where((n) => !present.contains(n)))
        EmployeeListItem(name: n, subtitle: 'No attendance in this range'),
    ];
    showEmployeeListDialog(
      context,
      title: '${bar.department} — ${(bar.percent * 100).toStringAsFixed(0)}% attendance',
      icon: Icons.groups_rounded,
      color: AppTheme.accentBlue,
      items: items,
      emptyLabel: 'Nobody in this department',
    );
  }

  /// Who took a given leave type in the range.
  void _showLeavePeople(LeaveDistributionSlice slice) {
    final items = [
      for (final e in slice.entries)
        EmployeeListItem(
          name: e.split('|').first,
          subtitle: e.contains('|') ? e.split('|').last : '',
        ),
    ];
    showEmployeeListDialog(
      context,
      title: '${slice.label} — ${slice.count}',
      icon: Icons.event_busy_rounded,
      color: AppTheme.accentBlue,
      items: items,
      emptyLabel: 'No ${slice.label.toLowerCase()} in this range',
    );
  }

  List<LeaveDistributionSlice> get _leaveSlices {
    final approved = _leaveApps.where((a) =>
        a.managerStatus == LeaveApprovalStatus.approved &&
        _filteredNames.contains(a.employeeName.toLowerCase()) &&
        !a.to.isBefore(_range.start) && !a.from.isAfter(_range.end));
    final counts = <String, int>{'CL': 0, 'ML': 0, 'EL': 0, 'LOP': 0};
    // Who is behind each count, so a tap can list them instead of leaving the
    // number unexplainable.
    final who = <String, List<String>>{'CL': [], 'ML': [], 'EL': [], 'LOP': []};
    for (final a in approved) {
      final bucket = a.leaveBucket.isNotEmpty ? a.leaveBucket : LeaveStore.effectiveBucket(a.leaveType);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
      who[bucket]?.add('${a.employeeName}|${_dayLabel(a.from)}'
          '${a.days > 1 ? ' – ${_dayLabel(a.to)}' : ''} · ${a.days} day${a.days == 1 ? '' : 's'}');
    }
    List<String> e(String b) => (who[b] ?? [])..sort();
    return [
      LeaveDistributionSlice(bucket: 'CL', label: 'Casual Leave', count: counts['CL'] ?? 0, entries: e('CL')),
      LeaveDistributionSlice(bucket: 'ML', label: 'Sick / Medical Leave', count: counts['ML'] ?? 0, entries: e('ML')),
      LeaveDistributionSlice(bucket: 'EL', label: 'Earned Leave', count: counts['EL'] ?? 0, entries: e('EL')),
      LeaveDistributionSlice(bucket: 'LOP', label: 'Loss of Pay', count: counts['LOP'] ?? 0, entries: e('LOP')),
    ];
  }

  // ── Tables ─────────────────────────────────────────────────────────────

  List<TopAttendanceRow> get _topAttendanceRows {
    final days = _datesInRange().length.clamp(1, 1 << 30);
    final rows = _filteredUsers.where((u) => u.active).map((u) {
      final present = _rangeFiltered
          .where((r) => r.employeeName.toLowerCase() == u.name.toLowerCase() && r.checkInTime.isNotEmpty)
          .length;
      return TopAttendanceRow(
        name: u.name,
        department: u.department,
        attendancePercent: (present / days).clamp(0.0, 1.0),
        daysPresent: present,
        totalDays: days,
      );
    }).toList()
      ..sort((a, b) => b.attendancePercent.compareTo(a.attendancePercent));
    return rows.take(5).toList();
  }

  List<AttendanceOverviewRow> get _overviewRows {
    final total = _activeCount == 0 ? 1 : _activeCount;
    return [
      for (final ds in _datesInRange())
        () {
          final date = parseSlashDate(ds) ?? DateTime.now();
          final dayRecords = _rangeFiltered.where((r) => r.date == ds).toList();
          final present = dayRecords.where((r) => r.checkInTime.isNotEmpty).length;
          final late = dayRecords.where(_isLate).length;
          final dayLeaves = _leaveApps.where((a) =>
              a.managerStatus == LeaveApprovalStatus.approved &&
              _filteredNames.contains(a.employeeName.toLowerCase()) &&
              !date.isBefore(DateTime(a.from.year, a.from.month, a.from.day)) &&
              !date.isAfter(DateTime(a.to.year, a.to.month, a.to.day)));
          final halfDay = dayLeaves.where((a) => a.isHalfDay).length;
          final onLeave = dayLeaves.where((a) => !a.isHalfDay).length;
          final absent = (_activeCount - present - onLeave - halfDay).clamp(0, _activeCount);
          return AttendanceOverviewRow(
            date: date,
            present: present,
            absent: absent,
            late: late,
            halfDay: halfDay,
            onLeave: onLeave,
            attendancePercent: (present / total).clamp(0.0, 1.0),
          );
        }(),
    ];
  }

  // ── Live map ───────────────────────────────────────────────────────────

  List<LiveEmployeeMarker> get _liveMarkers {
    final markers = <LiveEmployeeMarker>[];
    for (final r in _checkedInNow) {
      if (!_filteredNames.contains(r.employeeName.toLowerCase())) continue;
      double? lat, lng;
      if (r.gpsPoints.isNotEmpty) {
        lat = r.gpsPoints.last[0];
        lng = r.gpsPoints.last[1];
      } else if (r.location.contains(',')) {
        final parts = r.location.split(',');
        lat = double.tryParse(parts[0].trim());
        lng = double.tryParse(parts.length > 1 ? parts[1].trim() : '');
      }
      if (lat == null || lng == null) continue;
      markers.add(LiveEmployeeMarker(
        employeeName: r.employeeName,
        employeeId: r.employeeId,
        lat: lat,
        lng: lng,
        status: r.gpsPoints.length > 1 ? MovementStatus.moving : MovementStatus.stationary,
      ));
    }
    return markers;
  }

  // ── Payroll ────────────────────────────────────────────────────────────

  double get _grossPay => _payslips.fold(0.0, (s, p) => s + p.actualGrossPay);
  double get _deductions => _payslips.fold(0.0, (s, p) => s + p.totalDeductions);
  double get _netPay => _payslips.fold(0.0, (s, p) => s + p.netPay);

  // ── Actions ────────────────────────────────────────────────────────────

  void _setQuickRange(QuickRange q) {
    setState(() {
      _quickRange = q;
      _range = rangeFor(q);
    });
    _load(isRefresh: true);
  }

  void _setCustomRange(DateTimeRange r) {
    setState(() {
      _quickRange = QuickRange.custom;
      _range = r;
    });
    _load(isRefresh: true);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final filename = await ReportPdfService.download(
        rangeStart: _range.start,
        rangeEnd: _range.end,
        kpis: {
          'Total Employees': '$_activeCount',
          'Present Today': '$_presentToday',
          'Absent Today': '$_absentToday',
          'On Leave': '$_onLeaveToday',
          'Late Arrivals': '$_lateArrivalsInRange',
          'Live Check-ins': '$_liveCheckIns',
          'Overtime Hours': '${_overtimeHoursInRange.toStringAsFixed(1)}h',
          'New Employees': '$_newEmployeesInRange',
        },
        overview: _overviewRows,
      );
      if (!mounted) return;
      setState(() => _recentReports.insert(0, (filename: filename, generatedAt: DateTime.now())));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final narrow = MediaQuery.of(context).size.width < 700;
    return Material(
      color: AppTheme.pageBackground,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(narrow ? 16 : 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ReportsHeader(
            range: _range,
            quickRange: _quickRange,
            onQuickRange: _setQuickRange,
            onCustomRange: _setCustomRange,
            department: _department,
            departmentOptions: _departmentOptions,
            onDepartmentChanged: (v) { setState(() => _department = v); },
            location: _location,
            locationOptions: _locationOptions,
            onLocationChanged: (v) { setState(() => _location = v); },
            role: _role,
            roleOptions: _roleOptions,
            onRoleChanged: (v) { setState(() => _role = v); },
            onRefresh: () => _load(isRefresh: true),
            refreshing: _refreshing,
            onExport: _export,
            exporting: _exporting,
          ),
          const SizedBox(height: 24),
          AppStatStrip(cards: [
            AppStatCard(
              title: 'Total Employees', value: '$_activeCount',
              icon: Icons.people_alt_rounded, color: AppTheme.primaryBlue,
            ),
            AppStatCard(
              title: 'Present Today', value: '$_presentToday',
              icon: Icons.check_circle_rounded, color: AppTheme.success,
              gaugePercent: _activeCount == 0 ? 0 : _presentToday / _activeCount,
            ),
            AppStatCard(
              title: 'Absent Today', value: '$_absentToday',
              icon: Icons.person_off_rounded, color: AppTheme.error,
              gaugePercent: _activeCount == 0 ? 0 : _absentToday / _activeCount,
            ),
            AppStatCard(
              title: 'On Leave', value: '$_onLeaveToday',
              icon: Icons.event_busy_rounded, color: AppTheme.warning,
              gaugePercent: _activeCount == 0 ? 0 : _onLeaveToday / _activeCount,
            ),
          ]),
          const SizedBox(height: 12),
          AppStatStrip(cards: [
            AppStatCard(
              title: 'Late Arrivals', value: '$_lateArrivalsInRange',
              icon: Icons.watch_later_rounded, color: AppTheme.warning,
            ),
            AppStatCard(
              title: 'Live Check-ins', value: '$_liveCheckIns',
              icon: Icons.location_on_rounded, color: AppTheme.accentBlue,
            ),
            AppStatCard(
              title: 'Overtime Hours', value: _overtimeHoursInRange.toStringAsFixed(1),
              icon: Icons.timelapse_rounded, color: AppTheme.purple,
            ),
            AppStatCard(
              title: 'New Employees', value: '$_newEmployeesInRange',
              icon: Icons.person_add_alt_1_rounded, color: AppTheme.pink,
            ),
          ]),
          const SizedBox(height: 24),
          _twoUp(
            narrow,
            AttendanceTrendChart(points: _trendPoints),
            LeaveDistributionChart(slices: _leaveSlices, onSliceTap: _showLeavePeople),
          ),
          const SizedBox(height: 20),
          _twoUp(
            narrow,
            DepartmentAttendanceChart(bars: _departmentBars, onBarTap: _showDepartmentPeople),
            WorkingHoursChart(days: _workingHoursDays),
          ),
          const SizedBox(height: 20),
          if (_canSeePayroll) ...[
            _twoUp(
              narrow,
              PayrollSummaryCard(
                grossPay: _grossPay,
                deductions: _deductions,
                netPay: _netPay,
                employeesProcessed: _payslips.length,
                totalEmployees: _activeCount,
              ),
              ReportCardShell(
                title: 'Live Employee Tracking',
                child: LiveTrackingMap(markers: _liveMarkers),
              ),
            ),
          ] else
            ReportCardShell(
              title: 'Live Employee Tracking',
              child: LiveTrackingMap(markers: _liveMarkers),
            ),
          const SizedBox(height: 20),
          TopAttendanceTable(rows: _topAttendanceRows),
          const SizedBox(height: 20),
          _recentReportsCard(),
          const SizedBox(height: 20),
          AttendanceOverviewTable(rows: _overviewRows),
        ]),
      ),
    );
  }

  Widget _twoUp(bool narrow, Widget a, Widget b) {
    if (narrow) return Column(children: [a, const SizedBox(height: 20), b]);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: a),
        const SizedBox(width: 20),
        Expanded(child: b),
      ]),
    );
  }

  Widget _recentReportsCard() {
    return ReportCardShell(
      title: 'Recent Reports',
      child: _recentReports.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Reports you export this session will show up here.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            )
          : Column(children: [
              for (final r in _recentReports)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.picture_as_pdf_rounded, size: 16, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.filename,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text('Generated on ${r.generatedAt.hour.toString().padLeft(2, '0')}:${r.generatedAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }
}
