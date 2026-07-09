import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/org_lists.dart';
import '../models/app_user.dart';
import '../models/onboarding_form_config.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../utils/form_version_label.dart';
import '../utils/open_url.dart';
import '../widgets/responsive_header_row.dart';
import '../theme/app_theme.dart';

Future<List<AppUser>> _loadAllUsers() async {
  try { return await UserStore.load(); } catch (_) { return []; }
}

String _autoEmail(String name) =>
    name.trim().toLowerCase().split(RegExp(r'\s+')).join('.');

String _nextEmpId(List<AppUser> users) {
  final nums = users
      .map((u) => u.employeeId)
      .where((id) => RegExp(r'^EMP\d+$').hasMatch(id))
      .map((id) => int.tryParse(id.substring(3)) ?? 0)
      .toList();
  final next = nums.isEmpty ? 1 : (nums.reduce((a, b) => a > b ? a : b) + 1);
  return 'EMP${next.toString().padLeft(3, '0')}';
}

// Status helpers
Color _statusColor(String s) {
  if (s == 'hr_approved')    return const Color(0xFF3B82F6);
  if (s == 'hr_denied')      return const Color(0xFFEF4444);
  if (s == 'mgmt_approved')  return const Color(0xFF22C55E);
  if (s == 'mgmt_denied')    return const Color(0xFFB91C1C);
  if (s == 'access_granted') return const Color(0xFF2563EB);
  return const Color(0xFFF59E0B);
}
String _statusLabel(String s) {
  if (s == 'hr_approved')    return 'Awaiting Management';
  if (s == 'hr_denied')      return 'HR Denied';
  if (s == 'mgmt_approved')  return 'Mgmt Approved';
  if (s == 'mgmt_denied')    return 'Mgmt Denied';
  if (s == 'access_granted') return 'Active';
  return 'Pending';
}

Color get _blue => AppTheme.primaryBlue;

enum _SubFilter { all, received, sentToManagement, approvedActive }
enum _OnboardSort { latest, oldest, nameAz }

// Deterministic pastel avatar color from a name, so rows read as distinct
// people at a glance rather than one flat color per row.
const _avatarPalette = <Color>[
  Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF22C55E),
  Color(0xFFF59E0B), Color(0xFF06B6D4), Color(0xFF8B5CF6),
  Color(0xFFEF4444), Color(0xFF14B8A6),
];
Color _avatarColor(String name) =>
    _avatarPalette[name.isEmpty ? 0 : name.codeUnitAt(0) % _avatarPalette.length];

bool _matchesSubFilter(Map<String, dynamic> row, _SubFilter f) {
  final status = (row['status'] as String?) ?? 'pending';
  switch (f) {
    case _SubFilter.all:
      return true;
    case _SubFilter.received:
      return status == 'pending';
    case _SubFilter.sentToManagement:
      return status == 'hr_approved';
    case _SubFilter.approvedActive:
      return status == 'mgmt_approved' || status == 'access_granted';
  }
}

class EmployeeOnboardingPage extends StatefulWidget {
  const EmployeeOnboardingPage({super.key});

  @override
  State<EmployeeOnboardingPage> createState() => _EmployeeOnboardingPageState();
}

class _EmployeeOnboardingPageState extends State<EmployeeOnboardingPage> {
  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _pendingVersions = [];
  List<Map<String, dynamic>> _activeSections  = [];
  Map<int, String> _versionLabels = {};
  int _tab = 0;
  bool _loading = false;
  _SubFilter _statusFilter = _SubFilter.all;
  String _deptFilter = 'All';
  String _managerFilter = 'All';
  _OnboardSort _sort = _OnboardSort.latest;
  final _searchCtrl = TextEditingController();

  String _statusOf(Map<String, dynamic> r) => (r['status'] as String?) ?? 'pending';

  List<String> get _departmentOptions {
    final s = _all
        .map((r) => (r['designation'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...s];
  }

  List<String> get _managerOptions {
    final s = _all
        .map((r) => (r['assigned_manager'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...s];
  }

  int get _countActiveOnboarding => _all.where((r) {
        final s = _statusOf(r);
        return s == 'pending' || s == 'hr_approved' || s == 'mgmt_approved';
      }).length;
  int get _countMgmtApproved => _all.where((r) => _statusOf(r) == 'mgmt_approved').length;
  int get _countJoined => _all.where((r) => _statusOf(r) == 'access_granted').length;
  int get _countPendingActions {
    final isManagement = UserSession.role == UserRole.management;
    return _all.where((r) {
      final s = _statusOf(r);
      return isManagement ? s == 'hr_approved' : s == 'pending';
    }).length;
  }

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
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('onboarding_forms')
            .select()
            .order('submitted_at', ascending: false),
        SupabaseService.fetchOnboardingFormVersions(),
      ]);
      // Flatten form_data JSONB into the row so display code can read
      // d['name'], d['attachments'] etc. without caring where they live.
      final rows = (results[0] as List).map((r) {
        final row = Map<String, dynamic>.from(r as Map);
        final fd  = row['form_data'];
        if (fd is Map) row.addAll(Map<String, dynamic>.from(fd));
        return row;
      }).toList();
      final allVersions = List<Map<String, dynamic>>.from(results[1]);
      final pending = allVersions
          .where((v) => (v['status'] as String?) == 'pending')
          .toList();
      final versionLabels = computeFormVersionLabels(allVersions);

      // Extract active (approved) sections for diff comparison
      final approved = allVersions
          .where((v) => (v['status'] as String?) == 'approved')
          .toList()
        ..sort((a, b) => ((b['version_number'] as int?) ?? 0)
            .compareTo((a['version_number'] as int?) ?? 0));
      List<Map<String, dynamic>> activeSects = [];
      if (approved.isNotEmpty) {
        final cfg = approved.first['form_config'] as Map?;
        if (cfg != null) {
          activeSects = OnboardingFormConfig.getSections(Map<String, dynamic>.from(cfg));
        }
      }

      setState(() {
        _all = rows;
        _pendingVersions = pending;
        _activeSections  = activeSects;
        _versionLabels   = versionLabels;
        _loading = false;
        // Auto-switch to Form Approvals tab when there are pending versions
        if (pending.isNotEmpty && _tab == 0) _tab = 1;
      });
      _applyFilter();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _approveVersion(Map<String, dynamic> version) async {
    final id = version['id'].toString();
    try {
      await SupabaseService.updateOnboardingFormVersionStatus(
        id, 'approved',
        decidedBy: UserSession.name.isNotEmpty ? UserSession.name : 'Management',
      );
      NotificationService.formEditDecided(formName: 'Onboarding Form', approved: true);
      final label = _versionLabels[(version['version_number'] as num?)?.toInt()] ??
          'v${version['version_number']}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Onboarding form $label approved and published!'),
        backgroundColor: const Color(0xFF22C55E),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
    _fetch();
  }

  Future<void> _rejectVersion(Map<String, dynamic> version) async {
    final id = version['id'].toString();
    try {
      await SupabaseService.updateOnboardingFormVersionStatus(id, 'rejected');
      NotificationService.formEditDecided(formName: 'Onboarding Form', approved: false);
      final label = _versionLabels[(version['version_number'] as num?)?.toInt()] ??
          'v${version['version_number']}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Onboarding form $label rejected.'),
        backgroundColor: Colors.orange,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
    _fetch();
  }

  Widget _buildSubmissionsTab(double pad) {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _all.isEmpty ? 'No submissions yet' : 'No results found',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
          if (_all.isEmpty) ...[
            const SizedBox(height: 8),
            Text('Click "Joining Form" to open the form and share it',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ]),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(pad),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _SubmissionCard(data: _filtered[i], onRefresh: _fetch),
    );
  }

  Widget _buildFormApprovalsTab(double pad) {
    return CustomScrollView(slivers: [
      SliverPadding(
        padding: EdgeInsets.all(pad),
        sliver: SliverList(delegate: SliverChildListDelegate([
          // Active form info banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF81C784)),
            ),
            child: Row(children: [
              const Icon(Icons.link_rounded, color: Color(0xFF22C55E), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Onboarding form link is always live',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                  const SizedBox(height: 2),
                  Text(
                    _activeSections.isEmpty
                        ? 'No approved version yet — form will use defaults.'
                        : 'Currently serving ${_activeSections.where((s) => (s["enabled"] as bool?) ?? true).length} active sections. Approving a new version instantly updates the form.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF388E3C)),
                  ),
                ]),
              ),
            ]),
          ),

          if (_pendingVersions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: Column(children: [
                Icon(Icons.check_circle_outline_rounded, size: 52, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No pending form versions', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                const SizedBox(height: 4),
                Text('When HR submits an edited form, it will appear here for approval.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ]),
            )
          else
            ..._pendingVersions.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PendingVersionCard(
                    version: v,
                    activeSections: _activeSections,
                    label: _versionLabels[(v['version_number'] as num?)?.toInt()],
                    onApprove: () => _approveVersion(v),
                    onReject: () => _rejectVersion(v),
                  ),
                )),
        ])),
      ),
    ]);
  }

  int get _countReceived => _all.where((r) => _matchesSubFilter(r, _SubFilter.received)).length;
  int get _countSent     => _all.where((r) => _matchesSubFilter(r, _SubFilter.sentToManagement)).length;
  int get _countApproved => _all.where((r) => _matchesSubFilter(r, _SubFilter.approvedActive)).length;

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    var rows = _all
        .where((r) => _matchesSubFilter(r, _statusFilter))
        .where((r) => q.isEmpty ||
            r.values.any((v) => v.toString().toLowerCase().contains(q)))
        .toList();
    if (_deptFilter != 'All') {
      rows = rows.where((r) => (r['designation'] ?? '').toString().trim() == _deptFilter).toList();
    }
    if (_managerFilter != 'All') {
      rows = rows.where((r) => (r['assigned_manager'] ?? '').toString().trim() == _managerFilter).toList();
    }
    rows = List.of(rows);
    switch (_sort) {
      case _OnboardSort.latest:
        rows.sort((a, b) => ((b['submitted_at'] ?? '').toString())
            .compareTo((a['submitted_at'] ?? '').toString()));
        break;
      case _OnboardSort.oldest:
        rows.sort((a, b) => ((a['submitted_at'] ?? '').toString())
            .compareTo((b['submitted_at'] ?? '').toString()));
        break;
      case _OnboardSort.nameAz:
        rows.sort((a, b) => ((a['name'] ?? '').toString().toLowerCase())
            .compareTo((b['name'] ?? '').toString().toLowerCase()));
        break;
    }
    setState(() => _filtered = rows);
  }

  void _openForm() {
    openUrl('https://fomrahrms-zeta.vercel.app/#/onboarding-form');
  }

  void _copyLink() {
    final link = 'https://fomrahrms-zeta.vercel.app/#/onboarding-form';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Link copied to clipboard'),
      duration: Duration(seconds: 2),
      backgroundColor: Color(0xFF22C55E),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
      child: Column(children: [
        // ── Header ────────────────────────────────────────────────────
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ResponsiveHeaderRow(
              icon: Icons.how_to_reg_rounded,
              color: _blue,
              title: 'Employee Onboarding',
              subtitle: '${_all.length} submission${_all.length == 1 ? '' : 's'} received',
              actions: [
                OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copy Link', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: BorderSide(color: _blue),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final base = GoRouterState.of(context).uri.path
                            .startsWith('/management/')
                        ? '/management'
                        : '';
                    context.push('$base/edit-onboarding-form');
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 15),
                  label: const Text('Edit Form', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: BorderSide(color: AppTheme.primaryBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openForm,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Joining Form', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _fetch,
                  icon: _loading
                      ? SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
                      : Icon(Icons.refresh_rounded, color: _blue),
                ),
              ],
            ),

            if (_all.isNotEmpty) ...[
              const SizedBox(height: 16),
              _OnboardStatsRow(
                total: _all.length,
                activeOnboarding: _countActiveOnboarding,
                mgmtApproved: _countMgmtApproved,
                joined: _countJoined,
                pendingActions: _countPendingActions,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;
                final search = TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, ID or department…',
                    prefixIcon: Icon(Icons.search_rounded, color: _blue, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: _searchCtrl.clear)
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                );
                final dropdowns = Row(mainAxisSize: MainAxisSize.min, children: [
                  _OnboardDropdown(
                    label: 'Department',
                    value: _deptFilter,
                    options: _departmentOptions,
                    onChanged: (v) => setState(() { _deptFilter = v; _applyFilter(); }),
                  ),
                  const SizedBox(width: 8),
                  _OnboardDropdown(
                    label: 'Manager',
                    value: _managerFilter,
                    options: _managerOptions,
                    onChanged: (v) => setState(() { _managerFilter = v; _applyFilter(); }),
                  ),
                  const SizedBox(width: 8),
                  _OnboardDropdown(
                    label: 'Sort',
                    value: switch (_sort) {
                      _OnboardSort.latest => 'Latest',
                      _OnboardSort.oldest => 'Oldest',
                      _OnboardSort.nameAz => 'Name A–Z',
                    },
                    options: const ['Latest', 'Oldest', 'Name A–Z'],
                    onChanged: (v) => setState(() {
                      _sort = switch (v) {
                        'Oldest' => _OnboardSort.oldest,
                        'Name A–Z' => _OnboardSort.nameAz,
                        _ => _OnboardSort.latest,
                      };
                      _applyFilter();
                    }),
                  ),
                ]);
                return narrow
                    ? Column(children: [
                        search,
                        const SizedBox(height: 10),
                        SingleChildScrollView(scrollDirection: Axis.horizontal, child: dropdowns),
                      ])
                    : Row(children: [
                        Expanded(child: search),
                        const SizedBox(width: 10),
                        dropdowns,
                      ]);
              }),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _OnboardFilterChip(
                    label: 'Received ($_countReceived)',
                    icon: Icons.inbox_rounded,
                    color: const Color(0xFFF59E0B),
                    selected: _statusFilter == _SubFilter.received,
                    onTap: () => setState(() { _statusFilter = _SubFilter.received; _applyFilter(); }),
                  ),
                  const SizedBox(width: 8),
                  _OnboardFilterChip(
                    label: 'Sent to Management ($_countSent)',
                    icon: Icons.forward_to_inbox_rounded,
                    color: const Color(0xFF3B82F6),
                    selected: _statusFilter == _SubFilter.sentToManagement,
                    onTap: () => setState(() { _statusFilter = _SubFilter.sentToManagement; _applyFilter(); }),
                  ),
                  const SizedBox(width: 8),
                  _OnboardFilterChip(
                    label: 'Approved & Active ($_countApproved)',
                    icon: Icons.verified_rounded,
                    color: const Color(0xFF22C55E),
                    selected: _statusFilter == _SubFilter.approvedActive,
                    onTap: () => setState(() { _statusFilter = _SubFilter.approvedActive; _applyFilter(); }),
                  ),
                  const SizedBox(width: 8),
                  _OnboardFilterChip(
                    label: 'All (${_all.length})',
                    icon: Icons.list_alt_rounded,
                    color: const Color(0xFF111827),
                    selected: _statusFilter == _SubFilter.all,
                    onTap: () => setState(() { _statusFilter = _SubFilter.all; _applyFilter(); }),
                  ),
                ]),
              ),
            ],
          ]),
        ),

        // ── Tab bar ───────────────────────────────────────────────────
        if (UserSession.role == UserRole.management)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
            child: Row(children: [
              _TabBtn(
                label: 'Submissions',
                count: _all.length,
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              _TabBtn(
                label: 'Form Approvals',
                count: _pendingVersions.length,
                selected: _tab == 1,
                badge: _pendingVersions.isNotEmpty,
                onTap: () => setState(() => _tab = 1),
              ),
            ]),
          ),

        // ── Body ──────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: _blue))
              : (_tab == 1 && UserSession.role == UserRole.management)
                  ? _buildFormApprovalsTab(pad)
                  : _buildSubmissionsTab(pad),
        ),
      ]),
    );
  }
}

// ── Summary stats row ────────────────────────────────────────────────────────────
class _OnboardStatsRow extends StatelessWidget {
  final int total;
  final int activeOnboarding;
  final int mgmtApproved;
  final int joined;
  final int pendingActions;
  const _OnboardStatsRow({
    required this.total,
    required this.activeOnboarding,
    required this.mgmtApproved,
    required this.joined,
    required this.pendingActions,
  });

  @override
  Widget build(BuildContext context) {
    String pct(int n) => total == 0 ? '0.0' : (n / total * 100).toStringAsFixed(1);
    final cards = [
      _StatCardData('Total Submissions', '$total', 'All time',
          Icons.inbox_rounded, _blue),
      _StatCardData('Active Onboarding', '$activeOnboarding', '${pct(activeOnboarding)}% of total',
          Icons.people_alt_rounded, const Color(0xFF22C55E)),
      _StatCardData('Mgmt Approved', '$mgmtApproved', '${pct(mgmtApproved)}% of total',
          Icons.verified_rounded, const Color(0xFF8B5CF6)),
      _StatCardData('Joined', '$joined', '${pct(joined)}% of total',
          Icons.badge_rounded, const Color(0xFFF97316)),
      _StatCardData('Pending Actions', '$pendingActions', 'Requires attention',
          Icons.pending_actions_rounded, const Color(0xFFEF4444)),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 900 ? 5 : constraints.maxWidth > 560 ? 3 : constraints.maxWidth > 340 ? 2 : 1;
      final tileWidth = (constraints.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(width: tileWidth, child: _StatCard(data: c))).toList(),
      );
    });
  }
}

class _StatCardData {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  const _StatCardData(this.label, this.value, this.sub, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.color.withValues(alpha: 0.18)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: data.color, shape: BoxShape.circle),
          child: Icon(data.icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            const SizedBox(height: 3),
            Text(data.value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: data.color)),
            const SizedBox(height: 1),
            Text(data.sub, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
          ]),
        ),
      ]),
    );
  }
}

// ── Filter dropdown (Department/Manager/Sort) ────────────────────────────────────
class _OnboardDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _OnboardDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _blue),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text('$label: $o')))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ── Status filter chip ──────────────────────────────────────────────────────────
class _OnboardFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _OnboardFilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: selected ? Colors.white : const Color(0xFF6B7280)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;
  const _TabBtn({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _blue : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _blue : const Color(0xFFD0D7F0),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _blue,
              )),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: badge
                  ? Colors.red
                  : (selected ? Colors.white24 : const Color(0xFFD0D7F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: badge ? Colors.white : (selected ? Colors.white : _blue),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Submission card ────────────────────────────────────────────────────────────
class _SubmissionCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;
  const _SubmissionCard({required this.data, required this.onRefresh});

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _expanded = false;
  bool _acting = false;
  Map<String, dynamic>? _linkedInterview;

  Future<void> _fetchLinkedInterview() async {
    if (_linkedInterview != null) return;
    final d    = widget.data;
    final name  = ((d['name'] as String?) ?? '').trim();
    final phone = ((d['phone_number'] as String?) ?? '').trim();
    if (name.isEmpty) return;
    try {
      final results = await Supabase.instance.client
          .from('candidate_applications')
          .select('name, post_applied, hr_status, manager_status, management_status, department, designation')
          .or('name.ilike.%$name%${phone.isNotEmpty ? ",mobile.eq.$phone" : ""}')
          .limit(1);
      if (results.isNotEmpty && mounted) {
        setState(() => _linkedInterview = Map<String, dynamic>.from(results.first as Map));
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _acting = true);
    try {
      await Supabase.instance.client
          .from('onboarding_forms')
          .update({'status': status})
          .eq('id', widget.data['id'].toString());
      widget.onRefresh();
    } catch (_) {
      setState(() => _acting = false);
    }
  }

  Future<void> _sendToManagement(BuildContext context) async {
    final allUsers = await _loadAllUsers();
    final managers = allUsers.where((u) => u.isReportingManager).map((u) => u.name).toList();
    await _fetchLinkedInterview();
    if (!context.mounted) return;

    final d = widget.data;
    final name = (d['name'] as String?) ?? '';
    final emailCtrl = TextEditingController(text: _autoEmail(name));
    final empIdCtrl  = TextEditingController(text: _nextEmpId(allUsers));
    String selectedManager = managers.isNotEmpty ? managers.first : '';

    // Department/designation chosen by HR on the pre-offer letter carry over here,
    // still editable in case the role changed before joining.
    final linkedDept  = (_linkedInterview?['department']  as String?)?.trim() ?? '';
    final linkedDesig = (_linkedInterview?['designation'] as String?)?.trim() ?? '';
    String? selectedDepartment   = kDepartments.contains(linkedDept)  ? linkedDept  : null;
    String? selectedDesignation  = kDesignations.contains(linkedDesig) ? linkedDesig : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Forward to Management', style: TextStyle(color: _blue, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: _blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'These details will be used to create the employee account once Management approves.',
                    style: TextStyle(fontSize: 12, color: _blue),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.email_rounded, color: _blue, size: 20),
                  suffix: Text('@fomrahousing.in',
                      style: TextStyle(color: _blue, fontWeight: FontWeight.w600, fontSize: 13)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: Colors.white,
                  labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: empIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Employee ID',
                  prefixIcon: Icon(Icons.badge_rounded, color: _blue, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: Colors.white,
                  labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDepartment,
                hint: const Text('Select department'),
                decoration: InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.account_tree_rounded, color: _blue, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: Colors.white,
                ),
                items: kDepartments.map((dep) => DropdownMenuItem(value: dep, child: Text(dep))).toList(),
                onChanged: (v) => setS(() => selectedDepartment = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDesignation,
                hint: const Text('Select designation'),
                decoration: InputDecoration(
                  labelText: 'Designation',
                  prefixIcon: Icon(Icons.work_rounded, color: _blue, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: Colors.white,
                ),
                items: kDesignations.map((des) => DropdownMenuItem(value: des, child: Text(des))).toList(),
                onChanged: (v) => setS(() => selectedDesignation = v),
              ),
              if (managers.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedManager.isNotEmpty ? selectedManager : null,
                  decoration: InputDecoration(
                    labelText: 'Reporting Manager',
                    prefixIcon: Icon(Icons.manage_accounts_rounded, color: _blue, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true, fillColor: Colors.white,
                  ),
                  items: managers.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setS(() => selectedManager = v ?? ''),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text('No managers found. Add a Manager user first.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _acting = true);
                try {
                  await Supabase.instance.client
                      .from('onboarding_forms')
                      .update({
                        'status':                'hr_approved',
                        'assigned_email':        '${emailCtrl.text.trim()}@fomrahousing.in',
                        'assigned_emp_id':       empIdCtrl.text.trim(),
                        'assigned_manager':      selectedManager,
                        'assigned_department':   selectedDepartment ?? '',
                        'assigned_designation':  selectedDesignation ?? '',
                      })
                      .eq('id', widget.data['id'].toString());
                  widget.onRefresh();
                } catch (e) {
                  setState(() => _acting = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to forward: $e\n\nHave you run the SQL to add the status columns in Supabase?'),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 8),
                    ));
                  }
                }
              },
              child: const Text('Forward'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Submission', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to permanently delete this submission?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _acting = true);
    try {
      await Supabase.instance.client
          .from('onboarding_forms')
          .delete()
          .eq('id', widget.data['id'].toString());
      widget.onRefresh();
    } catch (_) {
      setState(() => _acting = false);
    }
  }

  Future<void> _approveManagement(BuildContext context) async {
    final d = widget.data;
    final email       = (d['assigned_email']       as String?) ?? '';
    final empId       = (d['assigned_emp_id']      as String?) ?? '';
    final manager     = (d['assigned_manager']     as String?) ?? '';
    final department  = (d['assigned_department']  as String?) ?? '';
    final designation = (d['assigned_designation'] as String?) ?? (d['designation'] as String?) ?? '';

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No email assigned. Ask HR to re-forward this submission.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _acting = true);
    try {
      final user = AppUser(
        name:             (d['name']            as String?) ?? '',
        email:            email,
        employeeId:       empId,
        designation:      designation,
        department:       department,
        role:             'Employee',
        active:           true,
        reportingManager: manager,
        dateOfJoining:    (d['date_of_joining'] as String?) ?? '',
      );
      await UserStore.upsertOne(user);
      await Supabase.instance.client
          .from('onboarding_forms')
          .update({'status': 'access_granted'})
          .eq('id', d['id'].toString());
      widget.onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Account created for ${user.name} (${user.email})'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      setState(() => _acting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 8),
        ));
      }
    }
  }

  Future<void> _denyManagement() async {
    setState(() => _acting = true);
    try {
      await Supabase.instance.client
          .from('onboarding_forms')
          .update({'status': 'mgmt_denied'})
          .eq('id', widget.data['id'].toString());
      widget.onRefresh();
    } catch (_) {
      setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = ((d['name'] as String?) ?? '').isNotEmpty
        ? d['name'] as String
        : (d['full_name'] as String?) ?? 'Unknown';
    final submittedAt = d['submitted_at'] != null
        ? DateTime.tryParse(d['submitted_at'] as String)?.toLocal()
        : null;
    final dateStr = submittedAt != null
        ? '${submittedAt.day.toString().padLeft(2,'0')}/${submittedAt.month.toString().padLeft(2,'0')}/${submittedAt.year}'
        : '—';
    final status = (d['status'] as String?) ?? 'pending';
    final isPending = status == 'pending';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.lightBlue)),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _expanded = !_expanded);
            if (_expanded) _fetchLinkedInterview();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _avatarColor(name).withValues(alpha: 0.15),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(color: _avatarColor(name), fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text([
                    if (((d['assigned_emp_id'] as String?) ?? '').isNotEmpty) d['assigned_emp_id'] as String,
                    if (((d['designation'] as String?) ?? '').isNotEmpty) d['designation'] as String,
                  ].join('  ·  '),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  if (((d['phone_number'] as String?) ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text(d['phone_number'] as String,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ]),
                  ],
                  const SizedBox(height: 2),
                  Text('Submitted: $dateStr',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFFB0B7C3))),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(status),
                      style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                Text(_expanded ? 'Hide profile' : 'View profile',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _blue)),
              ]),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF6B7280)),
                onSelected: (v) {
                  if (v == 'delete') _delete(context);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Linked interview record indicator
              if (_linkedInterview != null) ...[
                _LinkedInterviewBanner(data: _linkedInterview!),
                const SizedBox(height: 12),
              ],
              _section('Basic Information', [
                _row('Name',            d['name']),
                _row('Phone Number',    d['phone_number']),
                _row('Father Name',     d['father_name']),
                _row('Designation',     d['designation']),
                _row('Date of Joining', d['date_of_joining']),
              ]),
              _section('Personal Data', [
                _row('Full Name',         d['full_name']),
                _row('Date of Birth',     d['date_of_birth']),
                _row('Postal Address',    d['postal_address']),
                _row('Permanent Address', d['permanent_address']),
              ]),
              _jsonSection('Family Details', d['family_details'],
                  ['name','age','gender','relation','occupation','aadhar']),
              _jsonSection('Education Qualification', d['education'],
                  ['qualification','university','year','marks','subject']),
              _jsonSection('Experience', d['experience'],
                  ['organisation','from','to','desig_joining','desig_relieving','job_resp','superior','salary','reason']),
              _section('Last Position Held', [
                _row('Last Reporting Person',      d['last_reporting_name']),
                _row('Last Reporting Designation', d['last_reporting_designation']),
                _row('Last Company',               d['last_company']),
                _row('Reference 1',                d['reference1']),
                _row('Reference 2',                d['reference2']),
              ]),
              _section('Additional Information', [
                _row('ESI Number',              d['esi_number']),
                _row('PF Number',               d['pf_number']),
                _row('Languages Known',         d['languages_known']),
                _row('Hobbies',                 d['hobbies']),
                _row('Interests',               d['interests']),
                _row('Related to Employee',     d['related_to_employee']),
                _row('Professional Membership', d['professional_membership']),
                _row('Specialized Training',    d['specialized_training']),
                _row('Other Information',       d['other_information']),
              ]),
              _section('Emergency Details', [
                _row('Blood Group',               d['blood_group']),
                _row('Allergic To',               d['allergic_to']),
                _row('Major Illness',             d['major_illness']),
                _row('Emergency Contact Name',    d['emergency_contact_name']),
                _row('Emergency Contact Number',  d['emergency_contact_number']),
                _row('Emergency Contact Address', d['emergency_contact_address']),
                _row('Aadhar Number',             d['aadhar_number']),
              ]),
              _section('Declaration', [
                _row('Date',  d['declaration_date']),
                _row('Place', d['declaration_place']),
              ]),
              _attachmentsSection(d['attachments']),

              // HR: Approve/Deny on pending
              if (isPending) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Deny'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _acting ? null : () => _updateStatus('hr_denied'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Send to Management'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _acting ? null : () => _sendToManagement(context),
                    ),
                  ),
                ]),
              ],
              // Show assigned details once forwarded
              if (status == 'hr_approved') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Forwarded with details:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _blue)),
                    const SizedBox(height: 4),
                    Text('Email: ${d['assigned_email'] ?? '—'}', style: TextStyle(fontSize: 11, color: _blue)),
                    Text('Emp ID: ${d['assigned_emp_id'] ?? '—'}', style: TextStyle(fontSize: 11, color: _blue)),
                    Text('Manager: ${d['assigned_manager'] ?? '—'}', style: TextStyle(fontSize: 11, color: _blue)),
                  ]),
                ),
                // Management: final approve/deny — creates the employee account.
                if (UserSession.role == UserRole.management) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Deny'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _acting ? null : _denyManagement,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _acting ? null : () => _approveManagement(context),
                      ),
                    ),
                  ]),
                ],
              ],
            ]),
          ),
        ],
      ]),
    );
  }

}

// Shared read-only rendering helpers — used by _SubmissionCard's expanded
// view and by MyOnboardingFormPage (the employee's own read-only viewer).
Widget _section(String title, List<Widget> rows) {
  final visible = rows.whereType<Padding>().toList();
  if (visible.isEmpty) return const SizedBox.shrink();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 14),
    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
    const Divider(height: 10),
    ...rows,
  ]);
}

Widget _row(String label, dynamic value) {
  final v = (value?.toString() ?? '').trim();
  if (v.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 190,
          child: Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 12, color: Color(0xFF111827)))),
    ]),
  );
}

Widget _jsonSection(String title, dynamic jsonData, List<String> keys) {
  final rows = jsonData is List ? jsonData : [];
  final nonEmpty = rows.where((item) =>
      item is Map && keys.any((k) => (item[k]?.toString() ?? '').isNotEmpty)).toList();
  if (nonEmpty.isEmpty) return const SizedBox.shrink();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 14),
    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
    const Divider(height: 10),
    ...nonEmpty.asMap().entries.map((e) {
      final item = e.value as Map;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: keys.map((k) => _row(_keyLabel(k), item[k])).toList()),
      );
    }),
  ]);
}

Widget _attachmentsSection(dynamic data) {
  final items = data is List ? data : [];
  if (items.isEmpty) return const SizedBox.shrink();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 14),
    Text('Attachments', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
    const Divider(height: 10),
    ...items.map((item) {
      final name = item['name']?.toString() ?? '';
      final type = item['doc_type']?.toString() ?? '';
      final url  = item['url']?.toString() ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(Icons.insert_drive_file_rounded, size: 14, color: _blue),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(type, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
          ])),
          if (url.isNotEmpty) ...[
            TextButton(
              onPressed: () => viewAttachment(url),
              child: const Text('View', style: TextStyle(fontSize: 12)),
            ),
            IconButton(
              onPressed: () => downloadUrl(url),
              icon: const Icon(Icons.download_rounded, size: 16),
              tooltip: 'Download',
              color: _blue,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ]),
      );
    }),
  ]);
}

String _keyLabel(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

// ── Read-only detail body — reused by the employee's "My Onboarding Form" page ──
class OnboardingFormReadOnlyBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const OnboardingFormReadOnlyBody({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('Basic Information', [
        _row('Name',            d['name']),
        _row('Phone Number',    d['phone_number']),
        _row('Father Name',     d['father_name']),
        _row('Designation',     d['designation']),
        _row('Date of Joining', d['date_of_joining']),
      ]),
      _section('Personal Data', [
        _row('Full Name',         d['full_name']),
        _row('Date of Birth',     d['date_of_birth']),
        _row('Postal Address',    d['postal_address']),
        _row('Permanent Address', d['permanent_address']),
      ]),
      _jsonSection('Family Details', d['family_details'],
          ['name','age','gender','relation','occupation','aadhar']),
      _jsonSection('Education Qualification', d['education'],
          ['qualification','university','year','marks','subject']),
      _jsonSection('Experience', d['experience'],
          ['organisation','from','to','desig_joining','desig_relieving','job_resp','superior','salary','reason']),
      _section('Last Position Held', [
        _row('Last Reporting Person',      d['last_reporting_name']),
        _row('Last Reporting Designation', d['last_reporting_designation']),
        _row('Last Company',               d['last_company']),
        _row('Reference 1',                d['reference1']),
        _row('Reference 2',                d['reference2']),
      ]),
      _section('Additional Information', [
        _row('ESI Number',              d['esi_number']),
        _row('PF Number',               d['pf_number']),
        _row('Languages Known',         d['languages_known']),
        _row('Hobbies',                 d['hobbies']),
        _row('Interests',               d['interests']),
        _row('Related to Employee',     d['related_to_employee']),
        _row('Professional Membership', d['professional_membership']),
        _row('Specialized Training',    d['specialized_training']),
        _row('Other Information',       d['other_information']),
      ]),
      _section('Emergency Details', [
        _row('Blood Group',               d['blood_group']),
        _row('Allergic To',               d['allergic_to']),
        _row('Major Illness',             d['major_illness']),
        _row('Emergency Contact Name',    d['emergency_contact_name']),
        _row('Emergency Contact Number',  d['emergency_contact_number']),
        _row('Emergency Contact Address', d['emergency_contact_address']),
        _row('Aadhar Number',             d['aadhar_number']),
      ]),
      _section('Declaration', [
        _row('Date',  d['declaration_date']),
        _row('Place', d['declaration_place']),
      ]),
      _attachmentsSection(d['attachments']),
    ]);
  }
}

// ── Linked interview banner ────────────────────────────────────────────────────
class _LinkedInterviewBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LinkedInterviewBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final post   = (data['post_applied'] ?? '').toString();
    final hrS    = (data['hr_status'] ?? 'pending').toString();
    final mgrS   = (data['manager_status'] ?? 'pending').toString();
    final mgmtS  = (data['management_status'] ?? 'pending').toString();

    bool _ok(String s) => s == 'accepted' || s == 'approved';
    final allDone = _ok(hrS) && _ok(mgrS) && _ok(mgmtS);

    Widget _chip(String label, String s) {
      final ok  = _ok(s);
      final rej = s == 'rejected';
      final c   = ok ? const Color(0xFF22C55E) : rej ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
      final bg  = ok ? const Color(0xFFDCFCE7) : rej ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text('$label: ${ok ? "✓" : rej ? "✗" : "…"}',
            style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: allDone ? const Color(0xFFDCFCE7) : AppTheme.lightBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: allDone ? const Color(0xFF22C55E) : _blue,
          width: 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            allDone ? Icons.verified_rounded : Icons.assignment_rounded,
            size: 14,
            color: allDone ? const Color(0xFF22C55E) : _blue,
          ),
          const SizedBox(width: 6),
          Text(
            allDone ? 'Interview Done — All Approvals Received' : 'Matched Interview Application',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: allDone ? const Color(0xFF22C55E) : _blue,
            ),
          ),
        ]),
        if (post.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Applied for: $post',
              style: TextStyle(fontSize: 11, color: allDone ? const Color(0xFF388E3C) : const Color(0xFF6B7280))),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _chip('HR', hrS),
          _chip('Manager', mgrS),
          _chip('Management', mgmtS),
        ]),
      ]),
    );
  }
}

// ── Form diff helpers ──────────────────────────────────────────────────────────
enum _DS { added, removed, modified, disabled, unchanged }

class _SectionDiff {
  final Map<String, dynamic> section;
  final _DS status;
  final List<String> addedFields;
  final List<String> removedFields;
  final List<String> hiddenChanged; // field ids whose visibility changed
  const _SectionDiff({
    required this.section,
    required this.status,
    this.addedFields = const [],
    this.removedFields = const [],
    this.hiddenChanged = const [],
  });
}

List<_SectionDiff> _computeDiff(
    List<Map<String, dynamic>> pending,
    List<Map<String, dynamic>> active) {
  final result = <_SectionDiff>[];
  for (final s in pending) {
    final id = (s['id'] as String?) ?? '';
    final enabled = (s['enabled'] as bool?) ?? true;
    final aIdx = active.indexWhere((a) => a['id'] == id);
    if (aIdx == -1) {
      result.add(_SectionDiff(section: s, status: _DS.added));
      continue;
    }
    if (!enabled) {
      result.add(_SectionDiff(section: s, status: _DS.disabled));
      continue;
    }
    final a = active[aIdx];
    final pCustom = OnboardingFormConfig.getCustomFields(s);
    final aCustom = OnboardingFormConfig.getCustomFields(a);
    final pHidden = OnboardingFormConfig.getHiddenFieldIds(s).toSet();
    final aHidden = OnboardingFormConfig.getHiddenFieldIds(a).toSet();
    final pIds = pCustom.map((f) => f['id'] as String? ?? '').toSet();
    final aIds = aCustom.map((f) => f['id'] as String? ?? '').toSet();
    final added   = pIds.difference(aIds).toList();
    final removed = aIds.difference(pIds).toList();
    final hidChg  = [...pHidden.difference(aHidden), ...aHidden.difference(pHidden)];
    final policyChg = id == 'hr_policy' &&
        ((s['policy_text'] as String?) ?? '') != ((a['policy_text'] as String?) ?? '');
    final titleChg = (s['title'] as String?) != (a['title'] as String?);
    final isModified = added.isNotEmpty || removed.isNotEmpty ||
        hidChg.isNotEmpty || policyChg || titleChg;
    result.add(_SectionDiff(
      section: s,
      status: isModified ? _DS.modified : _DS.unchanged,
      addedFields: added,
      removedFields: removed,
      hiddenChanged: hidChg,
    ));
  }
  // Sections removed from pending (exist in active but not in pending)
  for (final a in active) {
    final id = (a['id'] as String?) ?? '';
    if (!pending.any((p) => p['id'] == id)) {
      result.add(_SectionDiff(section: a, status: _DS.removed));
    }
  }
  return result;
}

// ── Pending onboarding form version card ───────────────────────────────────────
class _PendingVersionCard extends StatefulWidget {
  final Map<String, dynamic> version;
  final List<Map<String, dynamic>> activeSections;
  final String? label;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _PendingVersionCard({
    required this.version,
    required this.activeSections,
    this.label,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_PendingVersionCard> createState() => _PendingVersionCardState();
}

class _PendingVersionCardState extends State<_PendingVersionCard> {
  bool _acting = false;
  final Set<String> _expandedSections = {};

  Future<void> _act(Future<void> Function() fn) async {
    setState(() => _acting = true);
    await fn();
    if (mounted) setState(() => _acting = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.version;
    final vNum = v['version_number'] as int? ?? 0;
    final vLabel = widget.label ?? 'v$vNum';
    final createdBy = (v['created_by'] as String?) ?? 'HR';
    final rawDate = v['created_at'] as String?;
    String dateStr = '';
    if (rawDate != null) {
      try {
        final d = DateTime.parse(rawDate).toLocal();
        dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      } catch (_) {}
    }
    final config = v['form_config'] as Map? ?? {};
    final pendingSections = OnboardingFormConfig.getSections(Map<String, dynamic>.from(config));
    final diffs = _computeDiff(pendingSections, widget.activeSections);

    final addedCount   = diffs.where((d) => d.status == _DS.added).length;
    final modifiedCount = diffs.where((d) => d.status == _DS.modified).length;
    final removedCount  = diffs.where((d) => d.status == _DS.removed || d.status == _DS.disabled).length;
    final hasChanges    = addedCount + modifiedCount + removedCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC02), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Card header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFDE7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(vLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Submitted by $createdBy',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF9800)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.pending_actions_rounded, size: 12, color: Color(0xFFF59E0B)),
                SizedBox(width: 4),
                Text('Pending Review', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
              ]),
            ),
          ]),
        ),

        // ── Changes summary ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            const Text('Changes vs current live form:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            const SizedBox(width: 8),
            if (!hasChanges)
              _DiffPill('No Changes', const Color(0xFF6B7280), const Color(0xFFF8FAFC))
            else ...[
              if (addedCount > 0) ...[
                _DiffPill('+$addedCount New', const Color(0xFF22C55E), const Color(0xFFDCFCE7)),
                const SizedBox(width: 4),
              ],
              if (modifiedCount > 0) ...[
                _DiffPill('~$modifiedCount Changed', const Color(0xFFF59E0B), const Color(0xFFFEF3C7)),
                const SizedBox(width: 4),
              ],
              if (removedCount > 0)
                _DiffPill('-$removedCount Removed', const Color(0xFFEF4444), const Color(0xFFFEE2E2)),
            ],
          ]),
        ),

        const Divider(height: 20, indent: 16, endIndent: 16),

        // ── Full form preview with diff ───────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Form Structure Preview',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            ...diffs.map((diff) => _SectionDiffTile(
                  diff: diff,
                  expanded: _expandedSections.contains((diff.section['id'] as String?) ?? ''),
                  onToggle: () {
                    final id = (diff.section['id'] as String?) ?? '';
                    setState(() {
                      if (_expandedSections.contains(id)) {
                        _expandedSections.remove(id);
                      } else {
                        _expandedSections.add(id);
                      }
                    });
                  },
                )),
          ]),
        ),

        // ── Action buttons ───────────────────────────────────────────
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _acting ? null : () => _act(() async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reject Form Version',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                      content: Text('Reject onboarding form $vLabel submitted by $createdBy?\n\nThe current live form will remain unchanged.',
                          style: const TextStyle(fontSize: 13, height: 1.5)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) widget.onReject();
                }),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _acting ? null : () => _act(() async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Approve & Publish',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                      content: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Publish onboarding form $vLabel?',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF22C55E)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'This version will immediately become the live form. The onboarding link is always the same — candidates using it will automatically receive this updated form.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF22C55E), height: 1.5),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Approve & Publish'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) widget.onApprove();
                }),
                icon: _acting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Approve & Publish', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Diff pill badge ────────────────────────────────────────────────────────────
class _DiffPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _DiffPill(this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

// ── Section diff tile ──────────────────────────────────────────────────────────
class _SectionDiffTile extends StatelessWidget {
  final _SectionDiff diff;
  final bool expanded;
  final VoidCallback onToggle;
  const _SectionDiffTile({required this.diff, required this.expanded, required this.onToggle});

  static const _icons = <String, IconData>{
    'basic_info':        Icons.person_rounded,
    'personal_data':     Icons.assignment_ind_rounded,
    'family_details':    Icons.family_restroom_rounded,
    'education':         Icons.school_rounded,
    'experience':        Icons.work_history_rounded,
    'last_position':     Icons.business_center_rounded,
    'additional_info':   Icons.info_outline_rounded,
    'emergency_details': Icons.emergency_rounded,
    'attachments':       Icons.attach_file_rounded,
    'hr_policy':         Icons.policy_rounded,
    'declaration':       Icons.verified_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final s     = diff.section;
    final id    = (s['id'] as String?) ?? '';
    final title = (s['title'] as String?) ?? id;
    final icon  = _icons[id] ?? Icons.segment_rounded;

    Color borderColor;
    Color bgColor;
    Color textColor;
    String? badge;
    Color badgeColor;
    Color badgeBg;
    bool strikethrough = false;

    switch (diff.status) {
      case _DS.added:
        borderColor = const Color(0xFF66BB6A);
        bgColor     = const Color(0xFFDCFCE7);
        textColor   = const Color(0xFF15803D);
        badge       = 'NEW';
        badgeColor  = const Color(0xFF15803D);
        badgeBg     = const Color(0xFF86EFAC);
      case _DS.removed:
        borderColor  = const Color(0xFFFCA5A5);
        bgColor      = const Color(0xFFFEE2E2);
        textColor    = const Color(0xFFB91C1C);
        badge        = 'REMOVED';
        badgeColor   = const Color(0xFFB91C1C);
        badgeBg      = const Color(0xFFFFCDD2);
        strikethrough = true;
      case _DS.disabled:
        borderColor  = const Color(0xFFE5E7EB);
        bgColor      = const Color(0xFFF8FAFC);
        textColor    = const Color(0xFF9E9E9E);
        badge        = 'DISABLED';
        badgeColor   = const Color(0xFF757575);
        badgeBg      = const Color(0xFFE5E7EB);
        strikethrough = true;
      case _DS.modified:
        borderColor = const Color(0xFFFFB74D);
        bgColor     = const Color(0xFFFEF3C7);
        textColor   = const Color(0xFFF59E0B);
        badge       = 'CHANGED';
        badgeColor  = const Color(0xFFF59E0B);
        badgeBg     = const Color(0xFFFFE0B2);
      case _DS.unchanged:
        borderColor = const Color(0xFFDBEAFE);
        bgColor     = const Color(0xFFEFF6FF);
        textColor   = _blue;
        badge       = null;
        badgeColor  = _blue;
        badgeBg     = const Color(0xFFDBEAFE);
    }

    final builtInDefs = OnboardingFormConfig.builtInFieldDefs[id] ?? [];
    final customFields = OnboardingFormConfig.getCustomFields(s);
    final hiddenIds    = OnboardingFormConfig.getHiddenFieldIds(s);
    final totalFields  = builtInDefs.length + customFields.length;
    final visibleFields = builtInDefs.where((f) => !hiddenIds.contains(f['id'])).length + customFields.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      decoration: strikethrough ? TextDecoration.lineThrough : null,
                    )),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor, letterSpacing: 0.4)),
                ),
                const SizedBox(width: 4),
              ],
              // Field count summary
              if (diff.status != _DS.removed)
                Text('$visibleFields/$totalFields fields',
                    style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7))),
              const SizedBox(width: 4),
              Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 16, color: textColor),
            ]),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Built-in fields
              if (builtInDefs.isNotEmpty) ...[
                Text('Built-in Fields:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 3,
                    children: builtInDefs.map((f) {
                      final fId     = f['id'] ?? '';
                      final fLabel  = f['label'] ?? fId;
                      final isHidden = hiddenIds.contains(fId);
                      final isHiddenChanged = diff.hiddenChanged.contains(fId);
                      Color fc = isHidden ? Colors.grey : textColor;
                      Color fb = isHidden ? const Color(0xFFE5E7EB) : bgColor;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isHiddenChanged ? const Color(0xFFFFF9C4) : fb,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isHiddenChanged ? const Color(0xFFFFEB3B) : borderColor),
                        ),
                        child: Text(
                          isHidden ? '$fLabel (hidden)' : fLabel,
                          style: TextStyle(
                              fontSize: 10, color: fc,
                              decoration: isHidden ? TextDecoration.lineThrough : null),
                        ),
                      );
                    }).toList()),
                const SizedBox(height: 6),
              ],
              // Custom fields
              if (customFields.isNotEmpty || diff.addedFields.isNotEmpty || diff.removedFields.isNotEmpty) ...[
                Text('Custom Fields:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 3,
                    children: [
                      ...customFields.map((f) {
                        final fId     = f['id'] as String? ?? '';
                        final fLabel  = (f['label'] as String?) ?? fId;
                        final isNew   = diff.addedFields.contains(fId);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isNew ? const Color(0xFFDCFCE7) : bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isNew ? const Color(0xFF66BB6A) : borderColor),
                          ),
                          child: Text(isNew ? '$fLabel ✦' : fLabel,
                              style: TextStyle(fontSize: 10,
                                  color: isNew ? const Color(0xFF15803D) : textColor,
                                  fontWeight: isNew ? FontWeight.w700 : FontWeight.normal)),
                        );
                      }),
                      ...diff.removedFields.map((fId) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text('$fId (removed)',
                            style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C),
                                decoration: TextDecoration.lineThrough)),
                      )),
                    ]),
              ],
              if (diff.status == _DS.unchanged && builtInDefs.isEmpty && customFields.isEmpty)
                Text('No fields configured', style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
            ]),
          ),
        ],
      ]),
    );
  }
}
