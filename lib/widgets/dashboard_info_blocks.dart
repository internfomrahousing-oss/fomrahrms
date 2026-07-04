import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

const _purple = Color(0xFF6A1B9A);
const _months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';

// ── Public widget ─────────────────────────────────────────────────────────────

class DashboardInfoBlocks extends StatelessWidget {
  final bool canEdit;
  const DashboardInfoBlocks({super.key, this.canEdit = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final wide = constraints.maxWidth > 700;
      final blocks = <Widget>[
        AnnouncementsBlock(canEdit: canEdit),
        HolidaysBlock(canEdit: canEdit),
        _QuickLinksBlock(canEdit: canEdit),
        BirthdaysBlock(canEdit: canEdit),
      ];
      if (wide) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: blocks[0]), const SizedBox(width: 12),
              Expanded(child: blocks[1]), const SizedBox(width: 12),
              Expanded(child: blocks[2]), const SizedBox(width: 12),
              Expanded(child: blocks[3]),
            ],
          ),
        );
      }
      return Column(children: [
        blocks[0], const SizedBox(height: 12),
        blocks[1], const SizedBox(height: 12),
        blocks[2], const SizedBox(height: 12),
        blocks[3],
      ]);
    });
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool canEdit;
  final VoidCallback? onAdd;
  final VoidCallback? onRefresh;
  final Widget child;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
    this.canEdit = false,
    this.onAdd,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _purple.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _purple.withValues(alpha: 0.18), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _purple, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: _purple)),
              ),
              if (canEdit && onAdd != null)
                GestureDetector(
                  onTap: onAdd,
                  child: Tooltip(
                    message: 'Add',
                    child: Icon(Icons.add_circle_outline_rounded,
                        color: _purple, size: 20),
                  ),
                ),
              if (!canEdit && onRefresh != null)
                GestureDetector(
                  onTap: onRefresh,
                  child: Tooltip(
                    message: 'Refresh',
                    child: Icon(Icons.refresh_rounded,
                        color: _purple.withValues(alpha: 0.55), size: 18),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Announcements ─────────────────────────────────────────────────────────────

class AnnouncementsBlock extends StatefulWidget {
  final bool canEdit;
  const AnnouncementsBlock({super.key, required this.canEdit});
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
    return _InfoCard(
      icon: Icons.campaign_rounded,
      title: 'Announcements',
      canEdit: widget.canEdit,
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
                        InkWell(
                          onTap: () => setState(() => _expanded = isExp ? null : i),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_fmtDate(date),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _purple)),
                                    const SizedBox(height: 2),
                                    Text(item['text'] as String? ?? '',
                                        maxLines: isExp ? null : 1,
                                        overflow: isExp
                                            ? TextOverflow.visible
                                            : TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface.withValues(alpha: 0.8))),
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
  const HolidaysBlock({super.key, required this.canEdit});
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
    return _InfoCard(
      icon: Icons.event_rounded,
      title: 'Holidays This Year',
      canEdit: widget.canEdit,
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
                              style: const TextStyle(
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

// ── Coming Soon (empty block) — kept public for quick_actions_bar ────────────

class EmptyBlock extends StatelessWidget {
  const EmptyBlock({super.key});
  @override
  Widget build(BuildContext context) => const _QuickLinksBlock(canEdit: false);
}

// ── Quick Links block (replaces the old "Coming Soon" slot) ──────────────────

const _qLinks = [
  (icon: Icons.campaign_rounded,     color: Color(0xFFE53935), label: 'Announcements'),
  (icon: Icons.event_rounded,        color: Color(0xFF43A047), label: 'Holidays'),
  (icon: Icons.emoji_events_rounded, color: Color(0xFFFB8C00), label: 'Emp of Month'),
  (icon: Icons.cake_rounded,         color: Color(0xFF8E24AA), label: 'Birthdays'),
];

class _QuickLinksBlock extends StatelessWidget {
  final bool canEdit;
  const _QuickLinksBlock({required this.canEdit});

  void _open(BuildContext ctx, Widget block) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, ctrl) => Column(children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.black12, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: block,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _blockFor(int i) {
    switch (i) {
      case 0: return AnnouncementsBlock(canEdit: canEdit);
      case 1: return HolidaysBlock(canEdit: canEdit);
      case 3: return BirthdaysBlock(canEdit: canEdit);
      default: return const EmptyBlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.emoji_events_rounded,
      title: 'Employee of the Month',
      child: const SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events_rounded, size: 40, color: Color(0xFFFB8C00)),
            SizedBox(height: 8),
            Text('Coming Soon',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFB8C00))),
            SizedBox(height: 4),
            Text('Employee of the month will be announced here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF90A4AE))),
          ]),
        ),
      ),
    );
  }
}

// ── Birthdays ─────────────────────────────────────────────────────────────────

class BirthdaysBlock extends StatefulWidget {
  final bool canEdit;
  const BirthdaysBlock({super.key, required this.canEdit});
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
    return _InfoCard(
      icon: Icons.cake_rounded,
      title: 'Birthdays This Month',
      canEdit: widget.canEdit,
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
                              style: const TextStyle(
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

// ── Tiny helpers ──────────────────────────────────────────────────────────────

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
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
