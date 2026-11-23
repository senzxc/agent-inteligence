typedef TaskDateGroups = ({
  List<Map<String, dynamic>> today,
  List<Map<String, dynamic>> upcoming,
});

typedef TaskCreationDateGroup = ({
  DateTime? date,
  List<Map<String, dynamic>> tasks,
});

enum TaskDatePeriod { past, today, upcoming, all }

List<TaskCreationDateGroup> groupTasksByCreationDate(
  Iterable<Map<String, dynamic>> tasks,
) {
  final groups = <DateTime?, List<Map<String, dynamic>>>{};
  for (final task in tasks) {
    final createdAt = _taskCreatedTimestamp(task);
    final date = createdAt == null
        ? null
        : DateTime(createdAt.year, createdAt.month, createdAt.day);
    groups.putIfAbsent(date, () => []).add(task);
  }

  final dates = groups.keys.whereType<DateTime>().toList()
    ..sort((left, right) => right.compareTo(left));

  return [
    for (final date in dates) (date: date, tasks: groups[date]!),
    if (groups.containsKey(null)) (date: null, tasks: groups[null]!),
  ];
}

int compareTasksByNewestCreation(
  Map<String, dynamic> left,
  Map<String, dynamic> right,
) {
  final leftDate = _taskCreatedTimestamp(left);
  final rightDate = _taskCreatedTimestamp(right);
  if (leftDate == null && rightDate != null) return 1;
  if (leftDate != null && rightDate == null) return -1;
  if (leftDate == null || rightDate == null) return 0;
  return rightDate.compareTo(leftDate);
}

bool taskDateIsInPeriod(
  DateTime? taskDate,
  TaskDatePeriod period, {
  required DateTime today,
}) {
  if (period == TaskDatePeriod.all) return true;

  final todayOnly = DateTime(today.year, today.month, today.day);
  final date = taskDate == null
      ? todayOnly
      : DateTime(taskDate.year, taskDate.month, taskDate.day);

  return switch (period) {
    TaskDatePeriod.past => date.isBefore(todayOnly),
    TaskDatePeriod.today => date == todayOnly,
    TaskDatePeriod.upcoming => date.isAfter(todayOnly),
    TaskDatePeriod.all => true,
  };
}

TaskDateGroups groupTasksByDeadline(
  Iterable<Map<String, dynamic>> tasks, {
  required DateTime today,
  required bool Function(Map<String, dynamic> task) isCompleted,
}) {
  final dateToday = DateTime(today.year, today.month, today.day);
  final todayTasks = <Map<String, dynamic>>[];
  final upcomingTasks = <Map<String, dynamic>>[];

  for (final task in tasks) {
    if (isCompleted(task)) continue;
    final deadline = _taskDeadlineDate(task);
    if (deadline == null || deadline.isAfter(dateToday)) {
      upcomingTasks.add(task);
    } else if (deadline == dateToday) {
      todayTasks.add(task);
    }
  }

  todayTasks.sort(compareTasksByNewestCreation);
  upcomingTasks.sort((left, right) {
    final leftDeadline = _taskDeadlineDate(left);
    final rightDeadline = _taskDeadlineDate(right);
    if (leftDeadline == null && rightDeadline != null) return 1;
    if (leftDeadline != null && rightDeadline == null) return -1;
    if (leftDeadline != null && rightDeadline != null) {
      final dateComparison = leftDeadline.compareTo(rightDeadline);
      if (dateComparison != 0) return dateComparison;
    }
    return compareTasksByNewestCreation(left, right);
  });

  return (today: todayTasks, upcoming: upcomingTasks);
}

DateTime? _taskDeadlineDate(Map<String, dynamic> task) {
  final raw = (task['tenggat'] ?? task['deadline'] ?? '').toString().trim();
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final date = raw.contains('T') && parsed.isUtc ? parsed.toLocal() : parsed;
  return DateTime(date.year, date.month, date.day);
}

DateTime? _taskCreatedTimestamp(Map<String, dynamic> task) {
  final raw = (task['createdAt'] ?? task['created_at'] ?? task['created'])
      ?.toString()
      .trim();
  if (raw == null || raw.isEmpty) return null;
  final date = DateTime.tryParse(raw);
  return date?.isUtc == true ? date!.toLocal() : date;
}
