typedef TaskDateGroups = ({
  List<Map<String, dynamic>> today,
  List<Map<String, dynamic>> upcoming,
});

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

  todayTasks.sort(_compareByNewestCreation);
  upcomingTasks.sort((left, right) {
    final leftDeadline = _taskDeadlineDate(left);
    final rightDeadline = _taskDeadlineDate(right);
    if (leftDeadline == null && rightDeadline != null) return 1;
    if (leftDeadline != null && rightDeadline == null) return -1;
    if (leftDeadline != null && rightDeadline != null) {
      final dateComparison = leftDeadline.compareTo(rightDeadline);
      if (dateComparison != 0) return dateComparison;
    }
    return _compareByNewestCreation(left, right);
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

int _compareByNewestCreation(
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
