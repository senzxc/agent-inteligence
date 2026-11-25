import 'package:flutter/material.dart';

class TaskDateTimeline extends StatelessWidget {
  const TaskDateTimeline({
    super.key,
    required this.task,
    required this.status,
    this.completedAtOverride,
  });

  final Map<String, dynamic> task;
  final String status;
  final DateTime? completedAtOverride;

  DateTime? _parseTimestamp(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  DateTime? _createdAt() => _parseTimestamp(
    task['createdAt'] ?? task['created_at'] ?? task['created'],
  );

  DateTime? _completedAt() {
    if (completedAtOverride != null) return completedAtOverride;
    final completedAt = _parseTimestamp(
      task['completedAt'] ?? task['completed_at'],
    );
    if (completedAt != null) return completedAt;
    if (status != 'Selesai') return null;
    return _parseTimestamp(task['updatedAt'] ?? task['updated_at']);
  }

  DateTime? _deadlineAt() {
    final rawDeadline = (task['tenggat'] ?? task['deadline'] ?? '')
        .toString()
        .trim();
    if (rawDeadline.isEmpty) return null;

    final parsedDeadline = DateTime.tryParse(rawDeadline);
    if (parsedDeadline == null) return null;
    final deadline = rawDeadline.contains('T') && parsedDeadline.isUtc
        ? parsedDeadline.toLocal()
        : parsedDeadline;

    final rawTime =
        (task['tenggatJam'] ?? task['deadlineTime'] ?? task['deadline_time'])
            ?.toString()
            .trim();
    final timeMatch = rawTime == null
        ? null
        : RegExp(r'^([01]\d|2[0-3]):([0-5]\d)').firstMatch(rawTime);
    if (timeMatch != null) {
      return DateTime(
        deadline.year,
        deadline.month,
        deadline.day,
        int.parse(timeMatch[1]!),
        int.parse(timeMatch[2]!),
      );
    }

    if (rawDeadline.contains('T')) return deadline;
    return DateTime(deadline.year, deadline.month, deadline.day, 23, 59, 59);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  String _formatDateTime(DateTime date) =>
      '${_formatDate(date)} • '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  String _deadlineValue(DateTime? deadline) {
    if (deadline == null) return 'Tidak ditentukan';
    final rawDeadline = (task['tenggat'] ?? task['deadline'] ?? '').toString();
    final rawTime =
        (task['tenggatJam'] ?? task['deadlineTime'] ?? task['deadline_time'])
            ?.toString()
            .trim();
    final hasExplicitTime =
        (rawTime != null &&
            RegExp(r'^([01]\d|2[0-3]):([0-5]\d)').hasMatch(rawTime)) ||
        rawDeadline.contains('T');
    return hasExplicitTime ? _formatDateTime(deadline) : _formatDate(deadline);
  }

  String? _deadlineLabel(DateTime? deadline, DateTime now) {
    if (deadline == null) return null;
    final remaining = deadline.difference(now);
    if (remaining <= Duration.zero) return 'Tenggat terlewat';
    if (remaining <= const Duration(hours: 24)) {
      final hours = remaining.inHours;
      return hours == 0 ? 'Kurang dari 1 jam lagi' : 'Tersisa $hours jam';
    }
    return '${remaining.inDays} hari lagi';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'Selesai';
    final now = DateTime.now();
    final deadlineAt = _deadlineAt();
    final completedAt = _completedAt();
    final createdAt = _createdAt();
    final remaining = deadlineAt?.difference(now);
    final deadlineLabel = isCompleted ? null : _deadlineLabel(deadlineAt, now);
    final deadlineColor =
        isCompleted ||
            remaining == null ||
            remaining > const Duration(hours: 24)
        ? const Color(0xFF1565C0)
        : remaining <= Duration.zero
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);
    final deadlineBackground = deadlineColor == const Color(0xFFDC2626)
        ? const Color(0xFFFEF2F2)
        : deadlineColor == const Color(0xFFD97706)
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFEAF3FF);
    final hasCompletionTiming =
        isCompleted && completedAt != null && deadlineAt != null;
    final isLate = hasCompletionTiming && completedAt.isAfter(deadlineAt);
    final completionColor = !isCompleted || !hasCompletionTiming
        ? const Color(0xFF64748B)
        : isLate
        ? const Color(0xFFDC2626)
        : const Color(0xFF15803D);
    final completionBackground = !isCompleted || !hasCompletionTiming
        ? const Color(0xFFF1F5F9)
        : isLate
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF0FDF4);
    final completionDetail = !isCompleted
        ? null
        : completedAt == null
        ? 'Waktu penyelesaian tidak tersedia'
        : deadlineAt == null
        ? 'Tenggat tidak tersedia untuk perbandingan'
        : isLate
        ? 'Selesai terlambat'
        : 'Selesai tepat waktu';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WAKTU TUGAS',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EEF6)),
          ),
          child: Column(
            children: [
              _TimelineItem(
                icon: Icons.calendar_today_outlined,
                label: 'Tanggal dibuat',
                value: createdAt == null
                    ? 'Tidak tersedia'
                    : _formatDateTime(createdAt),
                color: const Color(0xFF64748B),
                background: const Color(0xFFF1F5F9),
              ),
              _TimelineItem(
                icon: Icons.event_outlined,
                label: 'Tenggat',
                value: _deadlineValue(deadlineAt),
                detail: deadlineLabel,
                color: deadlineColor,
                background: deadlineBackground,
                highlighted: true,
              ),
              _TimelineItem(
                icon: Icons.task_alt_rounded,
                label: 'Selesai',
                value: !isCompleted
                    ? 'Belum selesai'
                    : completedAt == null
                    ? 'Waktu tidak tersedia'
                    : _formatDateTime(completedAt),
                detail: completionDetail,
                color: completionColor,
                background: completionBackground,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    this.detail,
    this.highlighted = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;
  final String? detail;
  final bool highlighted;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: const Color(0xFFDCE6F2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: EdgeInsets.symmetric(
                vertical: highlighted ? 10 : 9,
                horizontal: highlighted ? 11 : 0,
              ),
              decoration: highlighted
                  ? BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: highlighted ? color : const Color(0xFF14264D),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail!,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
