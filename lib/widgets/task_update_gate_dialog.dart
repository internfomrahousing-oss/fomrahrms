import 'package:flutter/material.dart';
import '../models/task_store.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Blocks logout until the signed-in employee has posted today's comment on
/// every task in [pending]. Returns true once all are cleared and the caller
/// should proceed with signing out; false/null if they backed out instead.
Future<bool?> showTaskUpdateGateDialog(BuildContext context, List<Task> pending) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _TaskUpdateGateDialog(initialPending: pending),
  );
}

class _TaskUpdateGateDialog extends StatefulWidget {
  final List<Task> initialPending;
  const _TaskUpdateGateDialog({required this.initialPending});

  @override
  State<_TaskUpdateGateDialog> createState() => _TaskUpdateGateDialogState();
}

class _TaskUpdateGateDialogState extends State<_TaskUpdateGateDialog> {
  late List<Task> _pending;
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _posting = {};

  @override
  void initState() {
    super.initState();
    _pending = List.of(widget.initialPending);
    for (final t in _pending) {
      _controllers[t.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _post(Task t) async {
    final ctrl = _controllers[t.id]!;
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting.add(t.id));
    final ok = await SupabaseService.addTaskUpdate(t.id, UserSession.name.trim(), text);
    if (!mounted) return;
    setState(() {
      _posting.remove(t.id);
      if (ok) _pending.removeWhere((p) => p.id == t.id);
    });
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save update — try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Update your tasks before logging out'),
      content: SizedBox(
        width: 420,
        child: _pending.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('All caught up — you can log out now.'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You have ${_pending.length} task${_pending.length == 1 ? '' : 's'} "
                    "without today's update. Add a quick progress note on each "
                    "before logging out.",
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: Column(children: [
                        for (final t in _pending) ...[
                          _TaskUpdateRow(
                            task: t,
                            controller: _controllers[t.id]!,
                            posting: _posting.contains(t.id),
                            onPost: () => _post(t),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: _pending.isEmpty ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error, foregroundColor: Colors.white),
          child: const Text('Log Out'),
        ),
      ],
    );
  }
}

class _TaskUpdateRow extends StatelessWidget {
  final Task task;
  final TextEditingController controller;
  final bool posting;
  final VoidCallback onPost;
  const _TaskUpdateRow({
    required this.task,
    required this.controller,
    required this.posting,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !posting,
              maxLines: 2,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: "Today's update...",
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          posting
              ? const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  onPressed: onPost,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  tooltip: 'Post update',
                ),
        ]),
      ]),
    );
  }
}
