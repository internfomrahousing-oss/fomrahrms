import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../services/task_transitions.dart';
import '../services/user_store.dart';
import '../theme/app_theme.dart';
import 'hover_lift.dart';

Color get _purple => AppTheme.primaryBlue;
const _months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];

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
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _purple;
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
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                if (showIcon) ...[
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(title, style: AppTheme.cardHeading),
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
              const SizedBox(height: 14),
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
    // Employees only see announcements from the past 7 days; HR sees all
    final filtered = widget.canEdit
        ? data
        : data.where((item) {
            final d = DateTime.tryParse(item['announced_on'] as String? ?? '');
            return d != null &&
                d.isAfter(DateTime.now().subtract(const Duration(days: 7)));
          }).toList();
    setState(() { _items = filtered; _loading = false; });
  }

  Future<void> _showAdd() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('New Announcement'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Announcement text',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dlgCtx);
              final err = await SupabaseService.addAnnouncement(text, DateTime.now());
              if (!mounted) return;
              if (err == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement posted'), backgroundColor: Colors.green),
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
              : Column(
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
                                        Text(_fmtDate(date),
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _purple)),
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
                ),
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
    if (mounted) setState(() { _items = data; _loading = false; });
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
              : Column(
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
                ),
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
  Map<String, dynamic>? _data;
  bool _loading = true;

  static const _orange = Color(0xFFFB8C00);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await SupabaseService.fetchEmployeeOfMonth();
    if (mounted) setState(() { _data = data; _loading = false; });
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

    final currentName = _data?['employee_name'] as String? ?? '';
    String? selectedName = names.contains(currentName) ? currentName : null;
    final reasonCtrl = TextEditingController(
        text: _data?['reason'] as String? ?? '');

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (sbCtx, setDlg) => AlertDialog(
          title: const Text('Employee of the Month'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: selectedName,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Employee Name',
                  border: OutlineInputBorder()),
              items: names
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) => setDlg(() => selectedName = v),
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
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = selectedName ?? '';
                final reason = reasonCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dlgCtx);
                final err = await SupabaseService.upsertEmployeeOfMonth(
                    name, reason, monthYear);
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
    final name   = _data?['employee_name'] as String?;
    final reason = _data?['reason'] as String?;
    final my     = _data?['month_year'] as String?;

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
          : name == null
              ? _Empty('Not announced yet')
              : SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          size: 36, color: _orange),
                      const SizedBox(height: 8),
                      if (monthLabel != null)
                        Text(monthLabel,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _orange)),
                      const SizedBox(height: 4),
                      Text(name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B7280))),
                      if (reason != null && reason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(reason,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF607D8B))),
                      ],
                    ],
                  ),
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
    final data =
        await SupabaseService.fetchBirthdaysForMonth(DateTime.now().month);
    if (mounted) setState(() { _items = data; _loading = false; });
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
      onAdd: _showAdd,
      child: _loading
          ? const _Loader()
          : _items.isEmpty
              ? _Empty('No birthdays this month')
              : Column(
                  children: _items.map((item) {
                    final date =
                        DateTime.tryParse(item['birthday_date'] as String? ?? '') ??
                        DateTime.now();
                    final name = item['name'] as String? ?? '';
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
                        if (widget.canEdit) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _delete(item['id'] as String),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 16,
                                color: _purple.withValues(alpha: 0.5)),
                          ),
                        ],
                      ]),
                    );
                  }).toList(),
                ),
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

  @override
  Widget build(BuildContext context) {
    final nextDue = tasks.isNotEmpty
        ? _MyTasksBlockState._urgency(tasks.first.dueDate, AppTheme.textSecondary).$1
        : '—';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Pending',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
      const SizedBox(height: 2),
      Text('${tasks.length}',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      const SizedBox(height: 12),
      const Text('Next Due',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
      const SizedBox(height: 2),
      Text(nextDue,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      const SizedBox(height: 14),
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
