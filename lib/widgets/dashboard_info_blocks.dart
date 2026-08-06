import 'dart:math' as math;
import 'celebrating_trophy.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/task_transitions.dart';
import '../services/user_store.dart';
import '../theme/app_theme.dart';
import 'hover_lift.dart';

Color get _purple => AppTheme.primaryBlue;
const _months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];

// Cap for the scrollable list area inside Announcements / Holidays /
// Birthdays cards, so the card itself stops growing once data piles up —
// extra items scroll within this height instead of pushing the layout.
const double _listMaxHeight = 260;

// Wraps a list Column in a fixed-height scroll area (used by the three
// growing-list cards above) so long lists scroll instead of resizing the card.
Widget _scrollableList(Widget column) => SizedBox(
      height: _listMaxHeight,
      child: Scrollbar(
        child: SingleChildScrollView(child: column),
      ),
    );

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';

// Shared task status → color/label, reused by MyTasksBlock and TaskAnalyticsBlock.
Color taskStatusColor(TaskStatus s) => switch (s) {
      TaskStatus.assigned   => const Color(0xFF3B82F6),
      TaskStatus.pending    => Colors.orange.shade700,
      TaskStatus.inProgress => const Color(0xFF2563EB),
      TaskStatus.completed  => Colors.green.shade700,
      TaskStatus.delayed    => Colors.red.shade700,
    };

String taskStatusLabel(TaskStatus s) => switch (s) {
      TaskStatus.assigned   => 'Assigned',
      TaskStatus.pending    => 'Pending',
      TaskStatus.inProgress => 'In Progress',
      TaskStatus.completed  => 'Completed',
      TaskStatus.delayed    => 'Delayed',
    };

Color taskPriorityColor(TaskPriority p) => switch (p) {
      TaskPriority.low      => Colors.green.shade600,
      TaskPriority.medium   => Colors.orange.shade700,
      TaskPriority.high     => Colors.deepOrange.shade700,
      TaskPriority.critical => Colors.red.shade800,
    };

String taskPriorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.low      => 'Low',
      TaskPriority.medium   => 'Medium',
      TaskPriority.high     => 'High',
      TaskPriority.critical => 'Critical',
    };

// Coarse completion percent per status stage, used for the ring shown on
// each task row (there's no real progress-% field on Task).
int taskStatusStagePercent(TaskStatus s) => switch (s) {
      TaskStatus.assigned   => 0,
      TaskStatus.pending    => 25,
      TaskStatus.inProgress => 50,
      TaskStatus.delayed    => 75,
      TaskStatus.completed  => 100,
    };

// ── Public widget ─────────────────────────────────────────────────────────────

class DashboardInfoBlocks extends StatelessWidget {
  final bool canEdit;
  final bool showIcon;
  const DashboardInfoBlocks({super.key, this.canEdit = false, this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final wide = constraints.maxWidth > 700;
      final blocks = <Widget>[
        AnnouncementsBlock(canEdit: canEdit, showIcon: showIcon),
        HolidaysBlock(canEdit: canEdit, showIcon: showIcon),
        _EmployeeOfMonthBlock(canEdit: canEdit, showIcon: showIcon),
        BirthdaysBlock(canEdit: canEdit, showIcon: showIcon),
      ];
      if (wide) {
        // Announcements is the most important widget, so it spans 2 columns
        // while Holidays / Employee of Month / Birthdays each take 1.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: blocks[0]), const SizedBox(width: 16),
              Expanded(child: blocks[1]), const SizedBox(width: 16),
              Expanded(child: blocks[2]), const SizedBox(width: 16),
              Expanded(child: blocks[3]),
            ],
          ),
        );
      }
      return Column(children: [
        blocks[0], const SizedBox(height: 16),
        blocks[1], const SizedBox(height: 16),
        blocks[2], const SizedBox(height: 16),
        blocks[3],
      ]);
    });
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool canEdit;
  final bool showIcon;
  final VoidCallback? onAdd;
  final VoidCallback? onRefresh;
  final Widget child;
  final Color? accentColor;
  // Replaces the add/refresh icon in the header when set — e.g. a "View
  // all" link — leaving other InfoCard call sites unaffected.
  final Widget? trailing;
  // Tighter padding/header sizing for cards packed into a dense grid row
  // (e.g. the bottom "My Space" row) so they read visibly smaller.
  final bool compact;
  const InfoCard({
    required this.icon,
    required this.title,
    required this.child,
    this.canEdit = false,
    this.showIcon = true,
    this.onAdd,
    this.onRefresh,
    this.accentColor,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _purple;
    final iconBox = compact ? 26.0 : 32.0;
    return HoverLift(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Card(
        color: AppTheme.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                if (showIcon) ...[
                  Container(
                    width: iconBox, height: iconBox,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: compact ? 15 : 18),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                ],
                Expanded(
                  child: Text(title,
                      style: compact
                          ? AppTheme.cardHeading.copyWith(fontSize: 14)
                          : AppTheme.cardHeading),
                ),
                if (trailing != null)
                  trailing!
                else ...[
                  if (canEdit && onAdd != null)
                    GestureDetector(
                      onTap: onAdd,
                      child: Tooltip(
                        message: 'Add',
                        child: Icon(Icons.add_circle_outline_rounded,
                            color: accent, size: 20),
                      ),
                    ),
                  if (!canEdit && onRefresh != null)
                    GestureDetector(
                      onTap: onRefresh,
                      child: Tooltip(
                        message: 'Refresh',
                        child: Icon(Icons.refresh_rounded,
                            color: accent.withValues(alpha: 0.55), size: 18),
                      ),
                    ),
                ],
              ]),
              SizedBox(height: compact ? 10 : 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Announcements ─────────────────────────────────────────────────────────────

class AnnouncementsBlock extends StatefulWidget {
  final bool canEdit;
  final bool showIcon;
  const AnnouncementsBlock({super.key, required this.canEdit, this.showIcon = true});
  @override
  State<AnnouncementsBlock> createState() => _AnnouncementsBlockState();
}

class _AnnouncementsBlockState extends State<AnnouncementsBlock> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int? _expanded;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await SupabaseService.fetchAnnouncements();
    if (!mounted) return;
    // Employees/Managers only see broadcast announcements or ones targeted
    // at them, from the past 7 days. HR/Management see everything, ever.
    final myId = UserSession.employeeId;
    final filtered = widget.canEdit
        ? data
        : data.where((item) {
            final targetId = item['target_employee_id'] as String?;
            final isForMe = targetId == null || targetId.isEmpty || targetId == myId;
            if (!isForMe) return false;
            final d = DateTime.tryParse(item['announced_on'] as String? ?? '');
            return d != null &&
                d.isAfter(DateTime.now().subtract(const Duration(days: 7)));
          }).toList();
    setState(() { _items = filtered; _loading = false; });
  }

  Future<void> _showAdd() async {
    final ctrl = TextEditingController();
    final users = await UserStore.load();
    if (!mounted) return;
    final recipients = users
        .where((u) => u.role != 'Management' && u.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    AppUser? selected; // null = everyone

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (sbCtx, setDlg) => AlertDialog(
          title: const Text('New Announcement'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Announcement text',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<AppUser?>(
              value: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Send to',
                  border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<AppUser?>(value: null, child: Text('Everyone')),
                for (final u in recipients)
                  DropdownMenuItem<AppUser?>(value: u, child: Text(u.name)),
              ],
              onChanged: (v) => setDlg(() => selected = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(dlgCtx);
                final target = selected;
                final err = await SupabaseService.addAnnouncement(
                  text, DateTime.now(),
                  targetEmployeeId: target?.employeeId,
                  targetEmployeeName: target?.name,
                );
                if (!mounted) return;
                if (err == null) {
                  if (target == null) {
                    NotificationService.announcementPosted(text: text);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(target == null
                          ? 'Announcement posted'
                          : 'Sent privately to ${target.name}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _load();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 10),
                    ),
                  );
                }
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm('Delete this announcement?');
    if (!ok) return;
    await SupabaseService.deleteAnnouncement(id);
    _load();
  }

  Future<bool> _confirm(String msg) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dlgCtx, true), child: const Text('Delete')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InfoCard(
      icon: Icons.campaign_rounded,
      title: 'Announcements',
      accentColor: AppTheme.primaryBlue,
      canEdit: widget.canEdit,
      showIcon: widget.showIcon,
      onAdd: _showAdd,
      onRefresh: _load,
      child: _loading
          ? const _Loader()
          : _items.isEmpty
              ? _Empty('No announcements yet')
              : _scrollableList(Column(
                  children: _items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    final date =
                        DateTime.tryParse(item['announced_on'] as String? ?? '') ??
                        DateTime.now();
                    final isExp = _expanded == i;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HoverBuilder(
                          builder: (context, hovering) => AnimatedContainer(
                            duration: AppTheme.fastAnim,
                            decoration: BoxDecoration(
                              color: hovering ? _purple.withValues(alpha: 0.05) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              onTap: () => setState(() => _expanded = isExp ? null : i),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text(_fmtDate(date),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: _purple)),
                                          if ((item['target_employee_name'] as String?)
                                                  ?.isNotEmpty ==
                                              true) ...[
                                            const SizedBox(width: 6),
                                            Icon(Icons.lock_rounded,
                                                size: 10, color: _purple.withValues(alpha: 0.55)),
                                            const SizedBox(width: 2),
                                            Text(
                                                widget.canEdit
                                                    ? 'Private · ${item['target_employee_name']}'
                                                    : 'Private message',
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: _purple.withValues(alpha: 0.65))),
                                          ],
                                        ]),
                                        const SizedBox(height: 3),
                                        Text(item['text'] as String? ?? '',
                                            maxLines: isExp ? null : 1,
                                            overflow: isExp
                                                ? TextOverflow.visible
                                                : TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (widget.canEdit)
                                    GestureDetector(
                                      onTap: () => _delete(item['id'] as String),
                                      child: Icon(Icons.delete_outline_rounded,
                                          size: 16,
                                          color: _purple.withValues(alpha: 0.5)),
                                    )
                                  else
                                    Icon(
                                      isExp
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: cs.onSurface.withValues(alpha: 0.35),
                                    ),
                                ]),
                              ),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: _purple.withValues(alpha: 0.12)),
                      ],
                    );
                  }).toList(),
                )),
    );
  }
}

// ── Holidays ──────────────────────────────────────────────────────────────────

class HolidaysBlock extends StatefulWidget {
  final bool canEdit;
  final bool showIcon;
  const HolidaysBlock({super.key, required this.canEdit, this.showIcon = true});
  @override
  State<HolidaysBlock> createState() => _HolidaysBlockState();
}

class _HolidaysBlockState extends State<HolidaysBlock> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await SupabaseService.fetchHolidays(DateTime.now().year);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Only holidays still ahead — past ones drop off the list on their own,
    // same as the Birthdays card does for the current month.
    final upcoming = data.where((item) {
      final d = DateTime.tryParse(item['holiday_date'] as String? ?? '');
      return d != null && !d.isBefore(today);
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['holiday_date'] as String? ?? '') ?? DateTime(9999);
        final db = DateTime.tryParse(b['holiday_date'] as String? ?? '') ?? DateTime(9999);
        return da.compareTo(db);
      });
    if (mounted) setState(() { _items = upcoming; _loading = false; });
  }

  Future<void> _showAdd() async {
    final nameCtrl = TextEditingController();
    DateTime? picked;
    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (sbCtx, setDlg) => AlertDialog(
          title: const Text('Add Holiday'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Holiday Name',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(
                picked == null ? 'Pick Date' : _fmtDate(picked!),
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: sbCtx,
                  initialDate: now,
                  firstDate: DateTime(now.year, 1, 1),
                  lastDate: DateTime(now.year, 12, 31),
                );
                if (d != null) setDlg(() => picked = d);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty || picked == null) return;
                Navigator.pop(dlgCtx);
                await SupabaseService.addHoliday(name, picked!);
                _load();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    await SupabaseService.deleteHoliday(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InfoCard(
      icon: Icons.event_rounded,
      title: 'Holidays This Year',
      accentColor: AppTheme.warning,
      canEdit: widget.canEdit,
      showIcon: widget.showIcon,
      onAdd: _showAdd,
      child: _loading
          ? const _Loader()
          : _items.isEmpty
              ? _Empty('No holidays added yet')
              : _scrollableList(Column(
                  children: _items.map((item) {
                    final date =
                        DateTime.tryParse(item['holiday_date'] as String? ?? '') ??
                        DateTime.now();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Container(
                          width: 54,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_fmtDate(date),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _purple)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item['name'] as String? ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.8))),
                        ),
                        if (widget.canEdit)
                          GestureDetector(
                            onTap: () => _delete(item['id'] as String),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 16,
                                color: _purple.withValues(alpha: 0.5)),
                          ),
                      ]),
                    );
                  }).toList(),
                )),
    );
  }
}

// ── Employee of the Month ─────────────────────────────────────────────────────

class EmptyBlock extends StatelessWidget {
  const EmptyBlock({super.key});
  @override
  Widget build(BuildContext context) =>
      const _EmployeeOfMonthBlock(canEdit: false);
}

class _EmployeeOfMonthBlock extends StatefulWidget {
  final bool canEdit;
  final bool showIcon;
  const _EmployeeOfMonthBlock({required this.canEdit, this.showIcon = true});

  @override
  State<_EmployeeOfMonthBlock> createState() => _EmployeeOfMonthBlockState();
}

class _EmployeeOfMonthBlockState extends State<_EmployeeOfMonthBlock> {
  List<Map<String, dynamic>> _data = [];
  /// Proposals awaiting Management sign-off. HR sees them so they know their
  /// entry was saved and is waiting — previously the entry simply did not
  /// appear and there was no way to tell whether it had failed.
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  bool _deciding = false;

  static const _orange = Color(0xFFFB8C00);

  bool get _canDecide => UserSession.role == UserRole.management;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await SupabaseService.fetchEmployeesOfMonth();
    // Only HR and Management can act on or explain a pending entry; there is
    // nothing useful to show an ordinary employee.
    final pending = (widget.canEdit || _canDecide)
        ? await SupabaseService.fetchPendingEmployeesOfMonth()
        : <Map<String, dynamic>>[];
    if (mounted) setState(() { _data = data; _pending = pending; _loading = false; });
  }

  Future<void> _decide(Map<String, dynamic> row, bool approve) async {
    setState(() => _deciding = true);
    final err = await SupabaseService.decideEmployeeOfMonth(
        (row['id'] ?? '').toString(), approve);
    if (!mounted) return;
    setState(() => _deciding = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(approve
          ? '${row['employee_name']} approved as Employee of the Month'
          : 'Proposal declined'),
      backgroundColor: approve ? Colors.green.shade700 : Colors.grey.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Banner for entries waiting on Management. Shows HR that their entry is
  /// saved but not yet published, and gives Management the decision.
  Widget _pendingBanner() {
    if (_pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _pending.map((row) {
        final name = row['employee_name'] as String? ?? '';
        final month = row['month_year'] as String? ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.hourglass_top_rounded, size: 15, color: Colors.amber.shade800),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _canDecide
                      ? '$name proposed for $month — awaiting your approval'
                      : '$name proposed for $month — awaiting Management approval',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900),
                ),
              ),
            ]),
            if (_canDecide) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deciding ? null : () => _decide(row, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Decline', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _deciding ? null : () => _decide(row, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Approve', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]),
            ],
          ]),
        );
      }).toList(),
    );
  }

  Future<void> _showEdit() async {
    final now = DateTime.now();
    final monthYear =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final users = await UserStore.load();
    if (!mounted) return;
    final names = users
        .where((u) => u.role != 'Management' && u.name.isNotEmpty)
        .map((u) => u.name)
        .toSet()
        .toList()
      ..sort();

    final currentNames = _data
        .map((d) => d['employee_name'] as String? ?? '')
        .where(names.contains)
        .toSet();
    final selected = <String>{...currentNames};
    // Reason is shared across everyone selected in this save — prefill from
    // whichever existing winner's reason, since it's a single field now.
    final reasonCtrl = TextEditingController(
        text: _data.isNotEmpty ? (_data.first['reason'] as String? ?? '') : '');

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (sbCtx, setDlg) => AlertDialog(
          title: const Text('Employee of the Month'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Select one or more employees',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: Scrollbar(
                  child: ListView(
                    shrinkWrap: true,
                    children: names.map((n) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(n),
                          value: selected.contains(n),
                          onChanged: (v) => setDlg(() {
                            if (v == true) {
                              selected.add(n);
                            } else {
                              selected.remove(n);
                            }
                          }),
                        )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Reason / Achievement',
                    border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonCtrl.text.trim();
                Navigator.pop(dlgCtx);
                final err = await SupabaseService.saveEmployeesOfMonth(
                    selected.toList(), reason, monthYear);
                if (!mounted) return;
                if (err == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Saved'), backgroundColor: Colors.green));
                  _load();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(err), backgroundColor: Colors.red));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final winners = _data;
    final my = winners.isNotEmpty ? winners.first['month_year'] as String? : null;

    String? monthLabel;
    if (my != null) {
      final parts = my.split('-');
      if (parts.length == 2) {
        final m = int.tryParse(parts[1]);
        if (m != null && m >= 1 && m <= 12) {
          monthLabel = '${_months[m - 1]} ${parts[0]}';
        }
      }
    }

    return InfoCard(
      icon: Icons.emoji_events_rounded,
      title: 'Employee of the Month',
      accentColor: _orange,
      canEdit: widget.canEdit,
      showIcon: widget.showIcon,
      onAdd: widget.canEdit ? _showEdit : null,
      onRefresh: _load,
      child: _loading
          ? const _Loader()
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Anything awaiting Management sits above the published
                // winner, so HR can see their entry was saved rather than
                // wondering whether it failed.
                _pendingBanner(),
                if (winners.isEmpty)
                  _Empty(_pending.isEmpty
                      ? 'Not announced yet'
                      : 'Awaiting approval')
                else
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Was a static icon — a flat way to present the one
                      // recognition the company gives. Now glows, sparkles and
                      // breathes continuously, and falls back to the plain
                      // icon when the device asks for reduced motion.
                      const CelebratingTrophy(size: 36, color: _orange),
                      const SizedBox(height: 8),
                      if (monthLabel != null)
                        Text(monthLabel,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _orange)),
                      const SizedBox(height: 8),
                      for (final w in winners) ...[
                        Text(w['employee_name'] as String? ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B7280))),
                        if (((w['reason'] as String?) ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(w['reason'] as String,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF607D8B))),
                        ],
                        if (w != winners.last) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Birthdays ─────────────────────────────────────────────────────────────────

class BirthdaysBlock extends StatefulWidget {
  final bool canEdit;
  final bool showIcon;
  const BirthdaysBlock({super.key, required this.canEdit, this.showIcon = true});
  @override
  State<BirthdaysBlock> createState() => _BirthdaysBlockState();
}

class _BirthdaysBlockState extends State<BirthdaysBlock> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final today = DateTime.now();
    final data = await SupabaseService.fetchBirthdaysForMonth(today.month);
    // Only upcoming birthdays for the rest of this month — ones that have
    // already happened this month drop off the list on their own.
    final upcoming = data.where((item) {
      final d = DateTime.tryParse(item['birthday_date'] as String? ?? '');
      return d != null && d.day >= today.day;
    }).toList();
    if (mounted) setState(() { _items = upcoming; _loading = false; });
  }

  Future<void> _showAdd() async {
    final nameCtrl = TextEditingController();
    DateTime? picked;
    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (sbCtx, setDlg) => AlertDialog(
          title: const Text('Add Birthday'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Birthdays are added automatically from the Date of Birth on '
                'each employee\'s onboarding form. Only use this for employees '
                'without one on file.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Employee Name',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(
                picked == null ? 'Pick Birthday' : _fmtDate(picked!),
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: sbCtx,
                  initialDate: DateTime(now.year, now.month, 1),
                  firstDate: DateTime(now.year, 1, 1),
                  lastDate: DateTime(now.year, 12, 31),
                );
                if (d != null) setDlg(() => picked = d);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty || picked == null) return;
                Navigator.pop(dlgCtx);
                await SupabaseService.addBirthday(name, picked!);
                _load();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    await SupabaseService.deleteBirthday(id);
    _load();
  }

  Future<void> _showAllBirthdays() async {
    final all = await SupabaseService.fetchAllBirthdays();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('All Birthdays'),
        content: SizedBox(
          width: 340,
          child: all.isEmpty
              ? const Text('No birthdays on file.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: all.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = all[i];
                    final date = DateTime.tryParse(
                            item['birthday_date'] as String? ?? '') ??
                        DateTime.now();
                    final name = item['name'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: _purple.withValues(alpha: 0.18),
                          child: Text(_initials(name),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _purple)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        Text(_fmtDate(date),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(1, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InfoCard(
      icon: Icons.cake_rounded,
      title: 'Birthdays This Month',
      accentColor: const Color(0xFFEC4899),
      canEdit: widget.canEdit,
      showIcon: widget.showIcon,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _showAllBirthdays,
          child: const Tooltip(
            message: 'View all birthdays',
            child: Icon(Icons.list_alt_rounded, color: Color(0xFFEC4899), size: 20),
          ),
        ),
        if (widget.canEdit) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _showAdd,
            child: const Tooltip(
              message: 'Add',
              child: Icon(Icons.add_circle_outline_rounded, color: Color(0xFFEC4899), size: 20),
            ),
          ),
        ],
      ]),
      child: _loading
          ? const _Loader()
          : _items.isEmpty
              ? _Empty('No birthdays this month')
              : _scrollableList(Column(
                  children: _items.map((item) {
                    final date =
                        DateTime.tryParse(item['birthday_date'] as String? ?? '') ??
                        DateTime.now();
                    final name = item['name'] as String? ?? '';
                    final id = item['id'] as String?; // null = auto-derived from onboarding DOB, not deletable
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _purple.withValues(alpha: 0.18),
                          child: Text(_initials(name),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _purple)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface)),
                        ),
                        Text(_fmtDate(date),
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        if (widget.canEdit && id != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _delete(id),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 16,
                                color: _purple.withValues(alpha: 0.5)),
                          ),
                        ],
                      ]),
                    );
                  }).toList(),
                )),
    );
  }
}

// ── My Tasks ──────────────────────────────────────────────────────────────────

class MyTasksBlock extends StatefulWidget {
  final bool showIcon;
  final String viewAllRoute;
  // Employee/Manager dashboards opt into the newer compact-checklist look;
  // HR keeps the original card style (modern defaults to false).
  final bool modern;
  const MyTasksBlock({super.key, this.showIcon = true, required this.viewAllRoute, this.modern = false});

  @override
  State<MyTasksBlock> createState() => _MyTasksBlockState();
}

class _MyTasksBlockState extends State<MyTasksBlock> {
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final all = await SupabaseService.fetchTasks();
    applyTaskAutoTransitions(all);
    final name = UserSession.name.trim();
    if (!mounted) return;
    final mine = name.isEmpty
        ? <Task>[]
        : all
            .where((t) =>
                t.assignedEmployee.trim() == name ||
                t.teamMembers.any((m) => m.trim() == name))
            .where((t) => t.status != TaskStatus.completed)
            .toList()
      ..sort((a, b) {
        // Most urgent first: earliest due date wins; same day → higher priority wins.
        final byDate = a.dueDate.compareTo(b.dueDate);
        if (byDate != 0) return byDate;
        return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
      });
    setState(() { _tasks = mine; _loading = false; });
  }

  static int _priorityRank(TaskPriority p) => switch (p) {
        TaskPriority.critical => 0,
        TaskPriority.high     => 1,
        TaskPriority.medium   => 2,
        TaskPriority.low      => 3,
      };

  // Label + color describing how urgent a due date is, so the most
  // time-critical tasks are visually obvious at the top of the list.
  static (String, Color) _urgency(DateTime due, Color defaultColor) {
    final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final day = DateTime(due.year, due.month, due.day);
    final diff = day.difference(now).inDays;
    if (diff < 0) return ('Overdue by ${-diff}d', Colors.red.shade700);
    if (diff == 0) return ('Due today', Colors.orange.shade800);
    if (diff == 1) return ('Due tomorrow', Colors.orange.shade700);
    if (diff <= 3) return ('Due in ${diff}d', Colors.amber.shade800);
    return ('Due ${_fmtDate(due)}', defaultColor);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = _tasks.take(5).toList();
    return InfoCard(
      icon: Icons.task_alt_rounded,
      title: 'My Tasks',
      showIcon: widget.showIcon,
      onRefresh: _load,
      // Sizes to its own content — the enclosing MySpaceRow no longer
      // clamps every card to a fixed height, so nothing here needs to
      // scroll internally; the dashboard's outer scroll view handles it.
      child: _loading
          ? const _Loader()
          : _tasks.isEmpty
              ? _Empty('No pending tasks')
              : widget.modern
                  ? _ModernTasksSummary(tasks: _tasks, viewAllRoute: widget.viewAllRoute)
                  : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final t in shown)
                      Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _purple.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _purple.withValues(alpha: 0.10)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: cs.onSurface)),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Builder(builder: (_) {
                                              final (label, color) = _urgency(
                                                  t.dueDate, cs.onSurface.withValues(alpha: 0.5));
                                              return Text(label,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: color));
                                            }),
                                            _MetaPill(taskPriorityLabel(t.priority), taskPriorityColor(t.priority)),
                                            if (t.department.isNotEmpty)
                                              _MetaPill(t.department, cs.onSurface.withValues(alpha: 0.55)),
                                            if (t.weightage > 0)
                                              _MetaPill('${t.weightage} pts', _purple),
                                          ],
                                        ),
                                        if (t.teamMembers.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                              t.teamMembers.length == 1
                                                  ? '1 member'
                                                  : '${t.teamMembers.length} members',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: cs.onSurface.withValues(alpha: 0.45))),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _TaskProgressRing(
                                    percent: taskStatusStagePercent(t.status),
                                    color: taskStatusColor(t.status),
                                  ),
                                ],
                              ),
                            ),
                    InkWell(
                      onTap: () => context.push(widget.viewAllRoute),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('View all',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _purple)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: _purple),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Modern compact summary (Employee/Manager dashboards) — matches the
// simple label/value/action-link layout used by My Leave / My Payslips /
// My Attendance, instead of listing every task individually.
class _ModernTasksSummary extends StatelessWidget {
  final List<Task> tasks;
  final String viewAllRoute;
  const _ModernTasksSummary({required this.tasks, required this.viewAllRoute});

  static const _rowHeight = 28.0;
  static const _maxVisibleRows = 3;

  // Only the tasks that actually need attention right now — already
  // overdue, or due tomorrow. Tasks due today/later are left to "View all"
  // instead of cluttering this list.
  static bool _isUrgent(Task t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    final diff = day.difference(today).inDays;
    return diff < 0 || diff == 1;
  }

  @override
  Widget build(BuildContext context) {
    final urgent = tasks.where(_isUrgent).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Pending',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
      const SizedBox(height: 2),
      Text('${tasks.length}',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      const SizedBox(height: 12),
      const Text('Due Soon',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
      const SizedBox(height: 6),
      if (urgent.isEmpty)
        const Text('Nothing overdue or due tomorrow',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
      else if (urgent.length <= _maxVisibleRows)
        for (final t in urgent) _TaskUrgencyRow(task: t, height: _rowHeight)
      else
        // More than fit — cap the card at 3 rows tall and let the rest
        // scroll inside it instead of growing the card indefinitely.
        SizedBox(
          height: _rowHeight * _maxVisibleRows,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemExtent: _rowHeight,
            itemCount: urgent.length,
            itemBuilder: (_, i) => _TaskUrgencyRow(task: urgent[i], height: _rowHeight),
          ),
        ),
      const SizedBox(height: 8),
      InkWell(
        onTap: () => context.push(viewAllRoute),
        borderRadius: BorderRadius.circular(6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('View all', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _purple)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 14, color: _purple),
        ]),
      ),
    ]);
  }
}

class _TaskUrgencyRow extends StatelessWidget {
  final Task task;
  final double height;
  const _TaskUrgencyRow({required this.task, required this.height});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _MyTasksBlockState._urgency(task.dueDate, AppTheme.textSecondary);
    return SizedBox(
      height: height,
      child: Row(children: [
        Expanded(
          child: Text(task.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ── Tiny helpers ──────────────────────────────────────────────────────────────

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: _purple))),
      );
}

Widget _Empty(String msg) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
          child: Text(msg,
              style: const TextStyle(
                  fontSize: 12, color: Color(0x666A1B9A)))),
    );

// Circular progress ring showing a task's status-stage percent, e.g. "50%".
class _TaskProgressRing extends StatelessWidget {
  final int percent;
  final Color color;
  const _TaskProgressRing({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46, height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(46, 46),
            painter: _RingPainter(percent: percent / 100, color: color),
          ),
          Text('$percent%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final Color color;
  const _RingPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);

    if (percent > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * percent, false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.color != color;
}

// Small labelled dot used for compact task metadata (priority, department, points).
class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ),
    ]);
  }
}
