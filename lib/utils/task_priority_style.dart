import 'package:flutter/material.dart';
import '../models/task_store.dart';

/// One definition of what each priority looks like.
///
/// This was written out separately in four files — add_task_page,
/// my_tasks_page, task_management_page and dashboard_info_blocks — and they
/// had drifted. High and Critical were `deepOrange.shade700` and
/// `red.shade800` in three of them, and `#BF360C` / `#B91C1C` in the fourth:
/// two dark reds close enough to be indistinguishable at chip size, so the
/// most urgent tasks did not stand out from merely important ones.
///
/// Kept as one map so a change lands everywhere at once. The same shape of
/// duplication produced the late-reason prompt bug, which existed in three
/// files with only one of them correct.

const _low = Color(0xFF16A34A);       // green
const _medium = Color(0xFFF59E0B);    // amber
const _high = Color(0xFFEA580C);      // orange — clearly not red
const _critical = Color(0xFFDC2626);  // red

Color taskPriorityColor(TaskPriority p) => switch (p) {
      TaskPriority.low => _low,
      TaskPriority.medium => _medium,
      TaskPriority.high => _high,
      TaskPriority.critical => _critical,
    };

String taskPriorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
      TaskPriority.critical => 'Critical',
    };

/// Priorities in ascending order, for pickers.
const taskPriorities = <TaskPriority>[
  TaskPriority.low,
  TaskPriority.medium,
  TaskPriority.high,
  TaskPriority.critical,
];
