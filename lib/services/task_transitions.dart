import '../models/task_store.dart';
import 'supabase_service.dart';

/// Applies the standard task status auto-transitions in place, and fires
/// off the matching persistence call for each change. Call this right
/// after fetching tasks, anywhere in the app that lists or summarizes
/// tasks, so status reflects the same rules everywhere:
///   - Overdue (due date passed)                → delayed
///   - Still Assigned a day after the start date → pending
///   - In Progress for 2+ hours since received   → pending
void applyTaskAutoTransitions(List<Task> tasks) {
  final now = DateTime.now();
  for (final t in tasks) {
    if (t.status == TaskStatus.completed) continue;

    if (t.dueDate.isBefore(now) && t.status != TaskStatus.delayed) {
      t.status = TaskStatus.delayed;
      SupabaseService.updateTaskStatus(t.id, TaskStatus.delayed);
    } else if (t.status == TaskStatus.assigned &&
        now.difference(t.startDate).inDays >= 1) {
      t.status = TaskStatus.pending;
      SupabaseService.updateTaskStatus(t.id, TaskStatus.pending);
    } else if (t.status == TaskStatus.inProgress &&
        t.receivedAt != null &&
        now.difference(t.receivedAt!).inHours >= 2) {
      t.status = TaskStatus.pending;
      SupabaseService.updateTaskStatus(t.id, TaskStatus.pending);
    }
  }
}
