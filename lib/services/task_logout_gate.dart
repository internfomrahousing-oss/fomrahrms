import '../models/task_store.dart';
import '../models/user_session.dart';
import '../utils/weekly_off.dart';
import 'supabase_service.dart';
import 'task_transitions.dart';
import 'user_store.dart';

// Effective status: group task -> member's individual status; single -> overall.
// Mirrors MyTasksPage._effectiveStatus.
TaskStatus _effectiveStatusFor(Task t, String name) {
  if (t.teamMembers.any((m) => m.trim() == name)) {
    return TaskStatus.values.firstWhere(
      (s) => s.name == (t.teamMemberStatuses[name] ?? 'assigned'),
      orElse: () => TaskStatus.assigned,
    );
  }
  return t.status;
}

/// Tasks belonging to the signed-in user that still need a comment posted
/// today before they can log out — not yet Completed, already started, and
/// no task_updates row for today. Empty (never blocks) on the employee's
/// weekly-off day, a company holiday, or if their profile/tasks can't be
/// loaded — this gate should only ever fire on data it's confident about.
Future<List<Task>> tasksNeedingUpdateToday() async {
  final name = UserSession.name.trim();
  if (name.isEmpty) return [];

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  final users = await UserStore.load();
  final me = users.where((u) => u.name == name).firstOrNull;
  if (me == null) return [];
  if (todayDate.weekday == weeklyOffWeekdayFor(me.effectiveWeeklyOffDay)) return [];

  final holidays = await SupabaseService.fetchHolidays(today.year);
  final isHoliday = holidays.any((h) {
    final d = DateTime.tryParse(h['holiday_date'] as String? ?? '');
    return d != null && d.year == todayDate.year &&
        d.month == todayDate.month && d.day == todayDate.day;
  });
  if (isHoliday) return [];

  final allTasks = await SupabaseService.fetchTasks();
  applyTaskAutoTransitions(allTasks);
  final mine = allTasks.where((t) {
    final belongs = t.assignedEmployee.trim() == name ||
        t.teamMembers.any((m) => m.trim() == name);
    if (!belongs) return false;
    if (_effectiveStatusFor(t, name) == TaskStatus.completed) return false;
    final start = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
    return !todayDate.isBefore(start);
  }).toList();
  if (mine.isEmpty) return [];

  final updatedTaskIds = await SupabaseService.fetchTaskUpdateTaskIdsFor(name, todayDate);
  return mine.where((t) => !updatedTaskIds.contains(t.id)).toList();
}
