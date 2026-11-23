import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/agency_role.dart';
import '../utils/task_date_groups.dart';
import '../widgets/agent_details_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/agent_profile_photo.dart';

enum _TaskSortField { deadline, createdAt }

Future<bool> showTaskCompletionConfirmation(
  BuildContext context, {
  required String taskTitle,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF15803D), Color(0xFF22C55E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KONFIRMASI',
                          style: TextStyle(
                            color: Color(0xFFDCFCE7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Selesaikan Tugas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tugas berikut akan ditandai sebagai selesai:',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          color: Color(0xFF15803D),
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            taskTitle,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF15803D),
                        size: 17,
                      ),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Status tugas tidak dapat diubah kembali setelah selesai.',
                          style: TextStyle(
                            color: Color(0xFF166534),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE8EEF6))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Selesaikan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed == true;
}

class AgentTaskPage extends StatefulWidget {
  final Map<String, dynamic> agent;
  final String pageTitle;
  final bool canManageTasks;
  final bool canAddTasks;
  final bool showAgentProfile;

  const AgentTaskPage({
    super.key,
    required this.agent,
    this.pageTitle = 'Tugas Saya',
    this.canManageTasks = true,
    this.canAddTasks = true,
    this.showAgentProfile = false,
  });

  @override
  State<AgentTaskPage> createState() => _AgentTaskPageState();
}

class _DeadlineTimeWheelPicker extends StatefulWidget {
  const _DeadlineTimeWheelPicker({
    required this.deadlineDate,
    required this.initialTime,
    required this.earliestTime,
    required this.onChanged,
  });

  final DateTime deadlineDate;
  final TimeOfDay initialTime;
  final DateTime? earliestTime;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_DeadlineTimeWheelPicker> createState() =>
      _DeadlineTimeWheelPickerState();
}

class _DeadlineTimeWheelPickerState extends State<_DeadlineTimeWheelPicker> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourController;

  int get _firstHour => widget.earliestTime?.hour ?? 0;

  int get _firstMinute =>
      widget.earliestTime != null && _hour == widget.earliestTime!.hour
      ? widget.earliestTime!.minute
      : 0;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour.clamp(_firstHour, 23).toInt();
    _minute = widget.initialTime.minute.clamp(_firstMinute, 59).toInt();
    _hourController = FixedExtentScrollController(
      initialItem: _hour - _firstHour,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    super.dispose();
  }

  void _emitChanged() {
    widget.onChanged(
      DateTime(
        widget.deadlineDate.year,
        widget.deadlineDate.month,
        widget.deadlineDate.day,
        _hour,
        _minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstMinute = _firstMinute;
    return Row(
      children: [
        Expanded(
          child: cupertino.CupertinoPicker(
            scrollController: _hourController,
            itemExtent: 36,
            backgroundColor: Colors.white,
            onSelectedItemChanged: (index) {
              final hour = _firstHour + index;
              final firstAllowedMinute =
                  widget.earliestTime != null &&
                      hour == widget.earliestTime!.hour
                  ? widget.earliestTime!.minute
                  : 0;
              setState(() {
                _hour = hour;
                if (_minute < firstAllowedMinute) {
                  _minute = firstAllowedMinute;
                }
              });
              _emitChanged();
            },
            children: List.generate(
              24 - _firstHour,
              (index) => Center(
                child: Text(
                  (_firstHour + index).toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
        const Text(
          ':',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: _DeadlineMinuteWheel(
            key: ValueKey(firstMinute),
            firstMinute: firstMinute,
            initialMinute: _minute,
            onChanged: (minute) {
              setState(() => _minute = minute);
              _emitChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _DeadlineMinuteWheel extends StatefulWidget {
  const _DeadlineMinuteWheel({
    super.key,
    required this.firstMinute,
    required this.initialMinute,
    required this.onChanged,
  });

  final int firstMinute;
  final int initialMinute;
  final ValueChanged<int> onChanged;

  @override
  State<_DeadlineMinuteWheel> createState() => _DeadlineMinuteWheelState();
}

class _DeadlineMinuteWheelState extends State<_DeadlineMinuteWheel> {
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: widget.initialMinute - widget.firstMinute,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return cupertino.CupertinoPicker(
      scrollController: _controller,
      itemExtent: 36,
      backgroundColor: Colors.white,
      onSelectedItemChanged: (index) {
        widget.onChanged(widget.firstMinute + index);
      },
      children: List.generate(
        60 - widget.firstMinute,
        (index) => Center(
          child: Text(
            (widget.firstMinute + index).toString().padLeft(2, '0'),
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 22),
          ),
        ),
      ),
    );
  }
}

class _AgentTaskPageState extends State<AgentTaskPage> {
  static const Color _pageStart = Color(0xFFF8FBFF);
  static const Color _pageEnd = Color(0xFFEAF3FF);
  static const Color _primary = Color(0xFF1565C0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  static const List<String> _statuses = [
    'Belum dimulai',
    'Berjalan',
    'Selesai',
  ];

  final List<Map<String, dynamic>> _tasks = [];
  final Set<String> _updatingTaskIds = {};
  final Set<String> _selectedTaskIds = {};
  final TextEditingController _taskSearchController = TextEditingController();
  final FocusNode _taskSearchFocusNode = FocusNode();
  late final PageController _datePageController;
  Timer? _taskRefreshTimer;

  static final DateTime _dateRangeStart = DateTime(2000);
  static const int _dateRangeLength = 36525;

  bool _isLoading = true;
  bool _isRefreshingTasks = false;
  bool _isSelectionMode = false;
  bool _isBulkDeleting = false;
  bool _isRefreshingAgentHeader = false;
  Uint8List? _agentPhotoBytes;
  late Map<String, dynamic> _agentProfile;
  String? _errorMessage;
  String? _refreshError;
  String? _agentHeaderRefreshError;
  String _selectedTaskStatus = '';
  _TaskSortField _taskSortField = _TaskSortField.createdAt;
  bool _sortAscending = false;
  bool _showTaskSearch = false;
  bool _isViewingOwnTasks = false;
  late DateTime _selectedDate;
  TaskDatePeriod _selectedTaskPeriod = TaskDatePeriod.today;

  String _firstValue(List<String> keys, {String fallback = '-'}) {
    for (final key in keys) {
      final value = _agentProfile[key]?.toString().trim();

      if (value != null && value.isNotEmpty && value != 'null') {
        return value;
      }
    }

    return fallback;
  }

  String get _agentName => _firstValue([
    'NAMA_AGEN',
    'NAMA_DEPAN',
    'NAMA',
    'N_AGEN',
    'nama',
  ], fallback: 'Agen');

  String get _agentNumber =>
      _firstValue(['NOMOR_AGEN', 'STAMBUK', 'I_AGEN', 'nomorAgen', 'stambuk']);

  String get _agentRole => formatAgencyRole(
    _firstValue([
      'C_AGENCY_JABATAN',
      'JABATAN',
      'jabatan',
    ], fallback: 'Jabatan belum tersedia'),
  );

  String get _agentId => _firstValue([
    'I_AGEN',
    'NOMOR_AGEN',
    'STAMBUK',
    'nomorAgen',
    'stambuk',
  ], fallback: '');

  int get _totalTasks => _tasks.length;

  int get _runningTasks => _tasks.where((task) {
    return _taskStatus(task) == 'Berjalan';
  }).length;

  int get _completedTasks => _tasks.where((task) {
    return _taskStatus(task) == 'Selesai';
  }).length;

  int get _notStartedTasks => _tasks.where((task) {
    return _taskStatus(task) == 'Belum dimulai';
  }).length;

  Set<String> get _selectableTaskIds =>
      _tasks.map(_taskId).where((taskId) => taskId.isNotEmpty).toSet();

  List<Map<String, dynamic>> get _visibleTasks {
    final query = _taskSearchController.text.trim().toLowerCase();
    final tasks = _tasks.where((task) {
      if (_selectedTaskPeriod == TaskDatePeriod.today) {
        if (!_taskMatchesSelectedDate(task)) return false;
      } else if (!taskDateIsInPeriod(
        _taskDeadlineDate(task),
        _selectedTaskPeriod,
        today: DateTime.now(),
      )) {
        return false;
      }

      if (_selectedTaskStatus.isNotEmpty &&
          _taskStatus(task) != _selectedTaskStatus) {
        return false;
      }

      if (query.isEmpty) return true;
      return [
        _taskTitle(task),
        _taskDescription(task),
        _taskStatus(task),
        _taskDeadline(task),
        _taskCreatedAt(task),
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();

    if (_selectedTaskPeriod == TaskDatePeriod.all) {
      tasks.sort((left, right) {
        final comparison = compareTasksByNewestCreation(left, right);
        if (comparison != 0) return comparison;
        return _taskTitle(left)
            .toLowerCase()
            .compareTo(_taskTitle(right).toLowerCase());
      });
    } else {
      tasks.sort((left, right) {
        final leftDate = _taskSortDate(left, _taskSortField);
        final rightDate = _taskSortDate(right, _taskSortField);
        if (leftDate == null && rightDate != null) return 1;
        if (leftDate != null && rightDate == null) return -1;
        if (leftDate != null && rightDate != null) {
          final comparison = leftDate.compareTo(rightDate);
          if (comparison != 0) {
            return _sortAscending ? comparison : -comparison;
          }
        }
        return _taskTitle(left)
            .toLowerCase()
            .compareTo(_taskTitle(right).toLowerCase());
      });
    }
    return tasks;
  }

  @override
  void initState() {
    super.initState();
    _agentProfile = Map<String, dynamic>.from(widget.agent);
    _selectedDate = _dateOnly(DateTime.now());
    _datePageController = PageController(
      initialPage: _dateIndexFor(_selectedDate),
      viewportFraction: 1 / 7,
    );
    _refreshPage(showLoading: true);
    _taskRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadTasks(showLoading: false),
    );
  }

  @override
  void didUpdateWidget(covariant AgentTaskPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.agent, widget.agent)) {
      _agentProfile = Map<String, dynamic>.from(widget.agent);
      _refreshPage();
    }
  }

  Future<void> _refreshPage({bool showLoading = false}) async {
    await Future.wait([
      _loadTasks(showLoading: showLoading),
      _refreshAgentHeader(),
    ]);
  }

  Future<void> _refreshAgentHeader() async {
    final agentId = _agentId.trim();
    if (agentId.isEmpty || agentId == '-' || _isRefreshingAgentHeader) return;
    _isRefreshingAgentHeader = true;

    try {
      final currentUser = await ApiService.getCurrentUser();
      final currentUserId = _profileAgentId(currentUser);
      final isViewingOwnTasks =
          currentUserId.toUpperCase() == agentId.toUpperCase();
      Map<String, dynamic>? latestProfile;

      if (isViewingOwnTasks) {
        latestProfile = currentUser;
      } else {
        final response = await ApiService.getAgentProfiles(search: agentId);
        final responseData = response['data'];
        if (responseData is! Map<String, dynamic> ||
            responseData['success'] != true) {
          throw Exception(
            responseData is Map
                ? responseData['message']?.toString() ??
                      'Gagal memuat profil agen.'
                : 'Format respons profil agen tidak valid.',
          );
        }

        final profiles = responseData['data'];
        if (profiles is! List) {
          throw Exception('Format daftar profil agen tidak valid.');
        }
        for (final profile in profiles.whereType<Map>()) {
          final candidate = Map<String, dynamic>.from(profile);
          if (_profileAgentId(candidate).toUpperCase() ==
              agentId.toUpperCase()) {
            latestProfile = candidate;
            break;
          }
        }
      }

      if (latestProfile == null) {
        throw Exception('Profil agen tidak ditemukan saat memperbarui header.');
      }

      if (mounted) {
        setState(() {
          _agentProfile.addAll(latestProfile!);
          _isViewingOwnTasks = isViewingOwnTasks;
        });
      }

      final photo = await ApiService.getAgentProfilePhoto(agentId);
      if (mounted) {
        setState(() {
          _agentPhotoBytes = photo;
          _agentHeaderRefreshError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _agentHeaderRefreshError = _cleanError(error);
        });
      }
    } finally {
      _isRefreshingAgentHeader = false;
    }
  }

  String _profileAgentId(Map<String, dynamic> profile) {
    for (final key in [
      'I_AGEN',
      'NOMOR_AGEN',
      'STAMBUK',
      'nomorAgen',
      'stambuk',
    ]) {
      final value = profile[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') {
        return value;
      }
    }
    return '';
  }

  String? get _refreshWarning {
    final errors = [
      _refreshError,
      if (_agentHeaderRefreshError != null)
        'Profil agen: $_agentHeaderRefreshError',
    ].whereType<String>().where((error) => error.isNotEmpty);
    return errors.isEmpty ? null : errors.join('\n');
  }

  @override
  void dispose() {
    _taskRefreshTimer?.cancel();
    _taskSearchController.dispose();
    _taskSearchFocusNode.dispose();
    _datePageController.dispose();
    super.dispose();
  }

  // Mendukung beberapa kemungkinan format respons API.
  List<Map<String, dynamic>> _parseTasks(Map<String, dynamic> response) {
    dynamic rawTasks = response['tasks'];

    rawTasks ??= response['data'];

    if (rawTasks is Map<String, dynamic>) {
      rawTasks = rawTasks['tasks'] ?? rawTasks['items'] ?? rawTasks['data'];
    }

    if (rawTasks is! List) {
      return [];
    }

    return rawTasks
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _taskStatus(Map<String, dynamic> task) {
    final status = (task['status'] ?? task['STATUS'] ?? 'Belum dimulai')
        .toString();

    if (_statuses.contains(status)) {
      return status;
    }

    return 'Belum dimulai';
  }

  String _taskId(Map<String, dynamic> task) {
    return (task['id'] ??
            task['taskId'] ??
            task['task_id'] ??
            task['idTugas'] ??
            '')
        .toString();
  }

  String _taskTitle(Map<String, dynamic> task) {
    return (task['judul'] ?? task['title'] ?? 'Tugas tanpa judul').toString();
  }

  String _taskDescription(Map<String, dynamic> task) {
    return (task['deskripsi'] ?? task['description'] ?? '').toString();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  int _dateIndexFor(DateTime date) {
    final dateIndex = _dateOnly(date).difference(_dateRangeStart).inDays;
    return dateIndex.clamp(0, _dateRangeLength - 1).toInt();
  }

  DateTime _dateForIndex(int index) =>
      _dateRangeStart.add(Duration(days: index));

  double _dateCardOpacity(int index) {
    var currentPage = _datePageController.initialPage.toDouble();
    if (_datePageController.hasClients &&
        _datePageController.position.hasViewportDimension) {
      currentPage =
          _datePageController.page ??
          _datePageController.initialPage.toDouble();
    }

    final distance = (index - currentPage).abs();
    if (distance <= 1) return 1 - (distance * 0.25);
    if (distance <= 2) return 0.75 - ((distance - 1) * 0.20);
    if (distance <= 3) return 0.55 - ((distance - 2) * 0.20);
    return 0.35;
  }

  bool _isSameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  bool _taskMatchesDate(Map<String, dynamic> task, DateTime date) {
    final deadline = _taskDeadlineDate(task);
    if (deadline == null) {
      return _isSameDate(date, DateTime.now());
    }
    return _isSameDate(deadline, date);
  }

  bool _taskMatchesSelectedDate(Map<String, dynamic> task) =>
      _taskMatchesDate(task, _selectedDate);

  bool _hasTasksOnDate(DateTime date) =>
      _tasks.any((task) => _taskMatchesDate(task, date));

  DateTime? _taskDeadlineDate(Map<String, dynamic> task) {
    final raw = (task['tenggat'] ?? task['deadline'] ?? '').toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final date = raw.contains('T') && parsed.isUtc ? parsed.toLocal() : parsed;
    return _dateOnly(date);
  }

  String? _taskDeadlineTime(Map<String, dynamic> task) {
    final rawTime =
        (task['tenggatJam'] ?? task['deadlineTime'] ?? task['deadline_time'])
            ?.toString()
            .trim();
    if (rawTime != null && rawTime.isNotEmpty) {
      final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)').firstMatch(rawTime);
      if (match != null) return '${match[1]}:${match[2]}';
    }

    final rawDeadline = (task['tenggat'] ?? task['deadline'] ?? '')
        .toString()
        .trim();
    if (!rawDeadline.contains('T')) return null;
    final parsed = DateTime.tryParse(rawDeadline);
    if (parsed == null) return null;
    final time = parsed.isUtc ? parsed.toLocal() : parsed;
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay? _taskDeadlineTimeOfDay(Map<String, dynamic> task) {
    final time = _taskDeadlineTime(task);
    if (time == null) return null;
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _taskDeadline(Map<String, dynamic> task) {
    final date = _taskDeadlineDate(task);
    if (date == null) return 'Tidak ditentukan';
    final time = _taskDeadlineTime(task);
    return '${_formatTaskDate(date)}${time == null ? '' : ' • $time'}';
  }

  DateTime? _taskCreatedDate(Map<String, dynamic> task) {
    final raw = (task['createdAt'] ?? task['created_at'] ?? task['created'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    final date = DateTime.tryParse(raw);
    return date?.isUtc == true ? date!.toLocal() : date;
  }

  DateTime? _taskCompletedDate(Map<String, dynamic> task) {
    final completedAt = (task['completedAt'] ?? task['completed_at'])
        ?.toString()
        .trim();
    if (completedAt != null && completedAt.isNotEmpty) {
      final date = DateTime.tryParse(completedAt);
      if (date != null) return date;
    }

    if (_taskStatus(task) != 'Selesai') return null;
    final updatedAt = (task['updatedAt'] ?? task['updated_at'])
        ?.toString()
        .trim();
    return updatedAt == null || updatedAt.isEmpty
        ? null
        : DateTime.tryParse(updatedAt);
  }

  String _formatTaskDate(DateTime date) {
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

  String _taskCreatedAt(Map<String, dynamic> task) {
    final date = _taskCreatedDate(task);
    if (date == null) return 'Tanggal dibuat tidak tersedia';

    return '${_formatTaskDate(date)} • ${_formatTime(date)}';
  }

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  String _formatTimeOfDay(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  bool _isTimeBefore(TimeOfDay first, TimeOfDay second) =>
      first.hour < second.hour ||
      (first.hour == second.hour && first.minute < second.minute);

  String _monthName(int month) => const [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ][month - 1];

  String _weekdayShort(int weekday) =>
      const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][weekday - 1];

  String _weekdayName(int weekday) => const [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ][weekday - 1];

  String _selectedDateTitle(DateTime date) =>
      '${_weekdayName(date.weekday)}, '
      '${date.day} ${_monthName(date.month)} ${date.year}';

  String _taskCompletedAt(Map<String, dynamic> task) {
    final date = _taskCompletedDate(task);
    return date == null ? '-' : _formatTaskDate(date);
  }

  DateTime? _taskSortDate(Map<String, dynamic> task, _TaskSortField field) {
    if (field == _TaskSortField.createdAt) {
      return _taskCreatedDate(task);
    }

    final date = _taskDeadlineDate(task);
    if (date == null) return null;
    final time = _taskDeadlineTime(task);
    if (time == null) return date;
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  InputDecoration _filterInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD5E5FA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD5E5FA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
    );
  }

  Widget _buildFilterSectionLabel({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _showTaskFilters() async {
    var selectedStatus = _selectedTaskStatus;
    var sortField = _taskSortField;
    var ascending = _sortAscending;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.only(top: 36),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1B72D7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter dan urutkan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Atur daftar tugas sesuai kebutuhan',
                                style: TextStyle(
                                  color: Color(0xFFDCEBFF),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        20 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFilterSectionLabel(
                            icon: Icons.flag_outlined,
                            title: 'Status tugas',
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                [
                                  ('', 'Semua'),
                                  ..._statuses.map(
                                    (status) => (status, status),
                                  ),
                                ].map((option) {
                                  final selected = selectedStatus == option.$1;
                                  final statusColor = switch (option.$1) {
                                    'Berjalan' => const Color(0xFFD97706),
                                    'Selesai' => const Color(0xFF15803D),
                                    _ => _primary,
                                  };
                                  final selectedBackground =
                                      switch (option.$1) {
                                        'Berjalan' => const Color(0xFFFFF7ED),
                                        'Selesai' => const Color(0xFFF0FDF4),
                                        _ => const Color(0xFFEAF3FF),
                                      };
                                  return ChoiceChip(
                                    label: Text(option.$2),
                                    selected: selected,
                                    onSelected: (_) => setSheetState(
                                      () => selectedStatus = option.$1,
                                    ),
                                    selectedColor: selectedBackground,
                                    backgroundColor: const Color(0xFFF8FAFC),
                                    side: BorderSide(
                                      color: selected
                                          ? statusColor.withValues(alpha: 0.4)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? statusColor
                                          : _textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 20),
                          if (_selectedTaskPeriod == TaskDatePeriod.all) ...[
                            _buildFilterSectionLabel(
                              icon: Icons.sort_rounded,
                              title: 'Urutkan daftar',
                            ),
                            const SizedBox(height: 9),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF3FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    color: _primary,
                                    size: 18,
                                  ),
                                  SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'Semua tanggal selalu diurutkan dari tugas terbaru dibuat.',
                                      style: TextStyle(
                                        color: _textPrimary,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            _buildFilterSectionLabel(
                              icon: Icons.sort_rounded,
                              title: 'Urutkan daftar',
                            ),
                            const SizedBox(height: 9),
                            DropdownButtonFormField<_TaskSortField>(
                              initialValue: sortField,
                              decoration: _filterInputDecoration(
                                hint: 'Urutkan berdasarkan',
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _primary,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: _TaskSortField.createdAt,
                                  child: Text('Tanggal dibuat'),
                                ),
                                DropdownMenuItem(
                                  value: _TaskSortField.deadline,
                                  child: Text('Tanggal tenggat'),
                                ),
                              ],
                              onChanged: (value) => setSheetState(
                                () => sortField =
                                    value ?? _TaskSortField.createdAt,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildFilterSectionLabel(
                              icon: Icons.swap_vert_rounded,
                              title: 'Urutan tanggal',
                            ),
                            const SizedBox(height: 9),
                            SegmentedButton<bool>(
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                          ? const Color(0xFFEAF3FF)
                                          : Colors.white,
                                    ),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                          ? const Color(0xFF0D47A1)
                                          : const Color(0xFF64748B),
                                    ),
                                side: WidgetStateProperty.all(
                                  const BorderSide(color: Color(0xFFD5E5FA)),
                                ),
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: true,
                                  icon: Icon(Icons.arrow_upward_rounded),
                                  label: Text('Ascending'),
                                ),
                                ButtonSegment(
                                  value: false,
                                  icon: Icon(Icons.arrow_downward_rounded),
                                  label: Text('Descending'),
                                ),
                              ],
                              selected: {ascending},
                              onSelectionChanged: (selection) => setSheetState(
                                () => ascending = selection.first,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedTaskStatus = '';
                                      _taskSortField = _TaskSortField.createdAt;
                                      _sortAscending = false;
                                      _taskSearchController.clear();
                                      _showTaskSearch = false;
                                    });
                                    Navigator.pop(sheetContext);
                                  },
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text('Reset'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _primary,
                                    side: const BorderSide(
                                      color: Color(0xFF9FC5F8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 19,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0D47A1),
                                        Color(0xFF1B72D7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _selectedTaskStatus = selectedStatus;
                                        _taskSortField = sortField;
                                        _sortAscending = ascending;
                                      });
                                      Navigator.pop(sheetContext);
                                    },
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Terapkan'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadTasks({bool showLoading = true}) async {
    if (_isRefreshingTasks) return;
    if (_agentNumber == '-') {
      if (showLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Nomor agen atau stambuk tidak ditemukan.';
        });
      }
      return;
    }

    _isRefreshingTasks = true;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await ApiService.getAgentTasks(_agentNumber);
      final data = result['data'] as Map<String, dynamic>;
      final tasks = _parseTasks(data);

      if (!mounted) return;

      final taskIds = tasks.map(_taskId).where((id) => id.isNotEmpty).toSet();
      setState(() {
        _tasks
          ..clear()
          ..addAll(tasks);
        _selectedTaskIds.removeWhere((id) => !taskIds.contains(id));
        _isLoading = false;
        _refreshError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        if (showLoading) {
          _isLoading = false;
          _errorMessage = _cleanError(error);
        } else {
          _refreshError = _cleanError(error);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingTasks = false;
        });
      } else {
        _isRefreshingTasks = false;
      }
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<String?> _createTask({
    required String judul,
    required String deskripsi,
    required String tenggat,
    required String tenggatJam,
  }) async {
    try {
      await ApiService.createAgentTask(
        agentId: _agentNumber,
        judul: judul,
        deskripsi: deskripsi,
        tenggat: tenggat,
        tenggatJam: tenggatJam,
      );
      return null;
    } catch (error) {
      return _cleanError(error);
    }
  }

  Future<String?> _editTask({
    required String taskId,
    required String judul,
    required String deskripsi,
    required String tenggat,
    required String tenggatJam,
  }) async {
    try {
      await ApiService.updateAgentTask(
        taskId: taskId,
        judul: judul,
        deskripsi: deskripsi,
        tenggat: tenggat,
        tenggatJam: tenggatJam,
      );
      return null;
    } catch (error) {
      return _cleanError(error);
    }
  }

  Future<bool> _confirmTaskCompletion(Map<String, dynamic> task) {
    return showTaskCompletionConfirmation(context, taskTitle: _taskTitle(task));
  }

  Future<bool?> _updateStatus(Map<String, dynamic> task, String status) async {
    final id = _taskId(task);

    if (_taskStatus(task) == 'Selesai') return false;

    if (id.isEmpty) {
      _showMessage(
        'ID tugas tidak ditemukan pada respons server.',
        isError: true,
      );
      return false;
    }

    if (_updatingTaskIds.contains(id)) return false;

    if (status == 'Selesai') {
      final confirmed = await _confirmTaskCompletion(task);
      if (!confirmed || !mounted) return null;
    }

    setState(() {
      _updatingTaskIds.add(id);
    });

    try {
      Map<String, dynamic> response;
      try {
        final result = await ApiService.updateTaskStatus(
          taskId: id,
          status: status,
        ).timeout(const Duration(seconds: 15));
        final resultData = result['data'];
        if (result['statusCode'] != 200 ||
            resultData is! Map<String, dynamic> ||
            resultData['success'] != true) {
          throw Exception(
            resultData is Map
                ? resultData['message']?.toString() ??
                      'Gagal memperbarui status tugas.'
                : 'Format respons perubahan status tidak valid.',
          );
        }
        response = resultData;
      } on TimeoutException {
        final refreshResult = await ApiService.getAgentTasks(_agentNumber)
            .timeout(const Duration(seconds: 10));
        final refreshData = refreshResult['data'];
        if (refreshResult['statusCode'] != 200 ||
            refreshData is! Map<String, dynamic> ||
            refreshData['success'] != true) {
          throw Exception(
            'Server terlalu lama merespons. Status tugas belum dapat dipastikan.',
          );
        }

        final refreshedTasks = _parseTasks(refreshData);
        Map<String, dynamic>? refreshedTask;
        for (final item in refreshedTasks) {
          if (_taskId(item) == id) {
            refreshedTask = item;
            break;
          }
        }
        if (refreshedTask == null || _taskStatus(refreshedTask) != status) {
          throw Exception(
            'Server terlalu lama merespons. Status tugas belum diperbarui.',
          );
        }
        response = {'success': true, 'data': refreshedTask};
      }

      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ?? 'Gagal memperbarui status tugas.',
        );
      }
      if (!mounted) return false;
      final updatedTask = response['data'];
      setState(() {
        final index = _tasks.indexWhere((item) => _taskId(item) == id);
        if (index >= 0) {
          _tasks[index] = {
            ..._tasks[index],
            if (updatedTask is Map) ...Map<String, dynamic>.from(updatedTask),
            'status': status,
            'updatedAt': DateTime.now().toIso8601String(),
            if (status == 'Selesai')
              'completedAt': DateTime.now().toIso8601String()
            else
              'completedAt': null,
          };
        }
      });
      _showMessage('Status tugas berhasil diperbarui.');
      return true;
    } catch (error) {
      if (!mounted) return false;
      _showMessage(
        'Gagal mengubah status: ${_cleanError(error)}',
        isError: true,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _updatingTaskIds.remove(id);
        });
      }
    }
  }

  Future<void> _showTaskDetailsDialog(Map<String, dynamic> task) async {
    var selectedStatus = _taskStatus(task);
    var completedAt = _taskCompletedAt(task);
    var isUpdatingStatus = false;
    String? statusError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isCompleted = selectedStatus == 'Selesai';
          final (
            statusColor,
            statusBackground,
            statusIcon,
          ) = switch (selectedStatus) {
            'Berjalan' => (
              const Color(0xFFD97706),
              const Color(0xFFFFF7ED),
              Icons.autorenew_rounded,
            ),
            'Selesai' => (
              const Color(0xFF15803D),
              const Color(0xFFF0FDF4),
              Icons.check_circle_outline_rounded,
            ),
            _ => (
              _primary,
              const Color(0xFFEAF3FF),
              Icons.radio_button_unchecked_rounded,
            ),
          };

          Future<void> selectStatus(String nextStatus) async {
            if (nextStatus == selectedStatus ||
                isUpdatingStatus ||
                isCompleted) {
              return;
            }

            setDialogState(() {
              isUpdatingStatus = true;
              statusError = null;
            });
            bool? updated;
            try {
              updated = await _updateStatus(task, nextStatus);
            } finally {
              if (mounted && dialogContext.mounted) {
                setDialogState(() {
                  isUpdatingStatus = false;
                  if (updated == true) {
                    selectedStatus = nextStatus;
                    if (nextStatus == 'Selesai') {
                      for (final updatedTask in _tasks) {
                        if (_taskId(updatedTask) == _taskId(task)) {
                          completedAt = _taskCompletedAt(updatedTask);
                          break;
                        }
                      }
                    }
                  } else if (updated == false) {
                    statusError = 'Status tugas gagal diperbarui. Coba lagi.';
                  }
                });
              }
            }
          }

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.86,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 22, 16, 22),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0D47A1), Color(0xFF1B72D7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                            child: const Icon(
                              Icons.assignment_outlined,
                              color: Colors.white,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DETAIL TUGAS',
                                  style: TextStyle(
                                    color: Color(0xFFDCEBFF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _taskTitle(task),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tutup',
                            onPressed: isUpdatingStatus
                                ? null
                                : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: statusBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    statusIcon,
                                    size: 15,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedStatus,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.canManageTasks) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'UBAH STATUS',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (final option in _statuses)
                                _buildTaskStatusChoice(
                                  option: option,
                                  selectedStatus: selectedStatus,
                                  enabled: !isCompleted && !isUpdatingStatus,
                                  onTap: () => selectStatus(option),
                                ),
                              if (isUpdatingStatus) ...[
                                const SizedBox(height: 6),
                                const LinearProgressIndicator(
                                  minHeight: 3,
                                  color: _primary,
                                  backgroundColor: Color(0xFFEAF3FF),
                                ),
                              ],
                              if (statusError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  statusError!,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (isCompleted) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Tugas yang sudah selesai tidak dapat diubah kembali.',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 18),
                            const Text(
                              'DESKRIPSI',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFD),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE8EEF6),
                                ),
                              ),
                              child: Text(
                                _taskDescription(task).isEmpty
                                    ? 'Tidak ada deskripsi.'
                                    : _taskDescription(task),
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 14,
                                  height: 1.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildTaskDetailTile(
                              icon: Icons.event_outlined,
                              label: 'Tenggat',
                              value: _taskDeadline(task),
                            ),
                            _buildTaskDetailTile(
                              icon: Icons.calendar_today_outlined,
                              label: 'Tanggal dibuat',
                              value: _taskCreatedAt(task),
                            ),
                            _buildTaskDetailTile(
                              icon: Icons.task_alt_rounded,
                              label: 'Selesai pada',
                              value: completedAt,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE8EEF6)),
                        ),
                      ),
                      child: SizedBox(
                        height: 46,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isUpdatingStatus
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: const Text('Tutup'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskStatusChoice({
    required String option,
    required String selectedStatus,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final isSelected = option == selectedStatus;
    final (color, background, icon) = switch (option) {
      'Berjalan' => (
        const Color(0xFFD97706),
        const Color(0xFFFFF7ED),
        Icons.autorenew_rounded,
      ),
      'Selesai' => (
        const Color(0xFF15803D),
        const Color(0xFFF0FDF4),
        Icons.check_circle_outline_rounded,
      ),
      _ => (
        _primary,
        const Color(0xFFEAF3FF),
        Icons.radio_button_unchecked_rounded,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? background : const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.35)
                    : const Color(0xFFE8EEF6),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      color: enabled || isSelected
                          ? const Color(0xFF334155)
                          : const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: color, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF14264D),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final id = _taskId(task);

    if (id.isEmpty) {
      _showMessage(
        'ID tugas tidak ditemukan pada respons server.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KONFIRMASI',
                            style: TextStyle(
                              color: Color(0xFFDCEBFF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Hapus Tugas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tugas berikut akan dihapus secara permanen:',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            color: _primary,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _taskTitle(task),
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFB45309),
                          size: 17,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Tindakan ini tidak dapat dibatalkan.',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE8EEF6))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textSecondary,
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Hapus Tugas'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.deleteTask(id);
      await _loadTasks();

      if (!mounted) return;
      _showMessage('Tugas berhasil dihapus.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Gagal menghapus tugas: ${_cleanError(error)}',
        isError: true,
      );
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedTaskIds.clear();
    });
  }

  void _toggleTaskSelection(String taskId, bool selected) {
    if (taskId.isEmpty) return;
    setState(() {
      if (selected) {
        _selectedTaskIds.add(taskId);
      } else {
        _selectedTaskIds.remove(taskId);
      }
    });
  }

  void _toggleAllTaskSelection(bool selected) {
    setState(() {
      if (selected) {
        _selectedTaskIds.addAll(_selectableTaskIds);
      } else {
        _selectedTaskIds.clear();
      }
    });
  }

  Future<bool> _confirmBulkDelete(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KONFIRMASI',
                            style: TextStyle(
                              color: Color(0xFFFFE4E6),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hapus $count Tugas',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count tugas yang dipilih akan dihapus permanen. '
                      'Tindakan ini tidak dapat dibatalkan.',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _textSecondary,
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Batal'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Hapus'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteSelectedTasks() async {
    if (_isBulkDeleting || _selectedTaskIds.isEmpty) return;
    final selectedTasks = _tasks
        .where((task) => _selectedTaskIds.contains(_taskId(task)))
        .toList();
    if (selectedTasks.isEmpty) {
      _showMessage(
        'Pilih setidaknya satu tugas untuk dihapus.',
        isWarning: true,
      );
      return;
    }

    final confirmed = await _confirmBulkDelete(selectedTasks.length);
    if (!confirmed || !mounted) return;

    setState(() {
      _isBulkDeleting = true;
    });

    var deletedCount = 0;
    final failedTaskIds = <String>{};
    String? firstError;
    for (final task in selectedTasks) {
      final taskId = _taskId(task);
      try {
        await ApiService.deleteTask(taskId);
        deletedCount++;
      } catch (error) {
        failedTaskIds.add(taskId);
        firstError ??= _cleanError(error);
      }
    }

    if (!mounted) return;
    await _loadTasks();
    if (!mounted) return;

    setState(() {
      _selectedTaskIds
        ..clear()
        ..addAll(failedTaskIds);
      _isBulkDeleting = false;
      if (failedTaskIds.isEmpty) {
        _isSelectionMode = false;
      }
    });

    if (failedTaskIds.isEmpty) {
      _showMessage('$deletedCount tugas berhasil dihapus.');
    } else {
      _showMessage(
        '$deletedCount tugas berhasil dihapus, '
        '${failedTaskIds.length} gagal. ${firstError ?? ''}',
        isError: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    showAppToast(
      context,
      message,
      type: isError
          ? AppToastType.error
          : isWarning
          ? AppToastType.warning
          : AppToastType.success,
    );
  }

  Future<TimeOfDay?> _showDeadlineTimePicker({
    required BuildContext dialogContext,
    required DateTime deadlineDate,
    required TimeOfDay initialTime,
  }) {
    final now = DateTime.now();
    final isToday = _isSameDate(deadlineDate, now);
    final earliestAllowedTime = isToday
        ? DateTime(now.year, now.month, now.day, now.hour, now.minute)
        : null;
    var selectedDateTime = DateTime(
      deadlineDate.year,
      deadlineDate.month,
      deadlineDate.day,
      initialTime.hour,
      initialTime.minute,
    );
    if (earliestAllowedTime != null &&
        selectedDateTime.isBefore(earliestAllowedTime)) {
      selectedDateTime = earliestAllowedTime;
    }
    var selectedTime = TimeOfDay.fromDateTime(selectedDateTime);

    return showDialog<TimeOfDay>(
      context: dialogContext,
      builder: (pickerContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pilih jam tenggat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(pickerContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 164,
                child: cupertino.CupertinoTheme(
                  data: const cupertino.CupertinoThemeData(
                    primaryColor: _primary,
                  ),
                  child: _DeadlineTimeWheelPicker(
                    deadlineDate: deadlineDate,
                    initialTime: selectedTime,
                    earliestTime: earliestAllowedTime,
                    onChanged: (value) {
                      selectedTime = TimeOfDay.fromDateTime(value);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(pickerContext),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: _textSecondary,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.pop(pickerContext, selectedTime),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Pilih'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog({Map<String, dynamic>? task}) async {
    final isEditing = task != null;
    final taskId = isEditing ? _taskId(task) : '';
    if (isEditing && taskId.isEmpty) {
      _showMessage(
        'ID tugas tidak ditemukan pada respons server.',
        isError: true,
      );
      return;
    }

    final titleController = TextEditingController(
      text: isEditing ? _taskTitle(task) : '',
    );
    final descriptionController = TextEditingController(
      text: isEditing ? _taskDescription(task) : '',
    );

    final DateTime deadline = isEditing
        ? (_taskDeadlineDate(task) ?? _selectedDate)
        : _selectedDate;
    final now = DateTime.now();
    final initialDeadlineTime =
        (isEditing ? _taskDeadlineTimeOfDay(task) : null) ??
        TimeOfDay.fromDateTime(now);
    final currentTime = TimeOfDay.fromDateTime(now);
    TimeOfDay deadlineTime =
        _isSameDate(deadline, now) &&
            _isTimeBefore(initialDeadlineTime, currentTime)
        ? currentTime
        : initialDeadlineTime;
    bool isSubmitting = false;
    String? submitError;
    final formKey = GlobalKey<FormState>();

    final taskSaved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final dateLabel =
                '${deadline.day.toString().padLeft(2, '0')} '
                '${_monthName(deadline.month)} ${deadline.year}';
            final timeLabel = _formatTimeOfDay(deadlineTime);

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.88,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 20, 14, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Icon(
                              isEditing
                                  ? Icons.edit_note_rounded
                                  : Icons.add_task_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'EDIT TUGAS' : 'TUGAS BARU',
                                  style: TextStyle(
                                    color: Color(0xFFDCEBFF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  isEditing ? 'Edit Tugas' : 'Tambah Tugas',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tutup',
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Form(
                        key: formKey,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lengkapi informasi tugas untuk agen.',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              if (submitError != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFB91C1C),
                                        size: 19,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          submitError!,
                                          style: const TextStyle(
                                            color: Color(0xFF991B1B),
                                            fontSize: 12,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: titleController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: _taskInputDecoration(
                                  label: 'Judul tugas',
                                  hint: 'Contoh: Kunjungan nasabah',
                                  icon: Icons.assignment_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Judul tugas wajib diisi.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: descriptionController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                minLines: 3,
                                maxLines: 5,
                                decoration: _taskInputDecoration(
                                  label: 'Deskripsi',
                                  hint: 'Jelaskan detail tugas...',
                                  icon: Icons.notes_rounded,
                                  alignLabelWithHint: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Deskripsi tugas wajib diisi.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 54,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FBFF),
                                        borderRadius: BorderRadius.circular(13),
                                        border: Border.all(
                                          color: const Color(0xFFDCE6F2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_month_outlined,
                                            size: 18,
                                            color: _primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              dateLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: _textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.lock_outline_rounded,
                                            size: 16,
                                            color: _textSecondary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final picked =
                                            await _showDeadlineTimePicker(
                                              dialogContext: dialogContext,
                                              deadlineDate: deadline,
                                              initialTime: deadlineTime,
                                            );
                                        if (picked != null) {
                                          setDialogState(() {
                                            deadlineTime = picked;
                                            submitError = null;
                                          });
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.schedule_rounded,
                                        size: 18,
                                      ),
                                      label: Text(timeLabel),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _primary,
                                        minimumSize: const Size.fromHeight(54),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFB7D2F5),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tanggal mengikuti hari terpilih. Pilih jam dalam format 24 jam.',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE8EEF6)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _textSecondary,
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      final now = DateTime.now();
                                      if (_isSameDate(deadline, now) &&
                                          _isTimeBefore(
                                            deadlineTime,
                                            TimeOfDay.fromDateTime(now),
                                          )) {
                                        setDialogState(() {
                                          deadlineTime = TimeOfDay.fromDateTime(
                                            now,
                                          );
                                          submitError = 'Jam tenggat tidak boleh lebih awal dari waktu sekarang.';
                                        });
                                        return;
                                      }

                                      final formattedDeadline =
                                          '${deadline.year}-'
                                          '${deadline.month.toString().padLeft(2, '0')}-'
                                          '${deadline.day.toString().padLeft(2, '0')}';
                                      final formattedDeadlineTime =
                                          _formatTimeOfDay(deadlineTime);

                                      setDialogState(() {
                                        isSubmitting = true;
                                      });
                                      final errorMessage = isEditing
                                          ? await _editTask(
                                              taskId: taskId,
                                              judul: titleController.text
                                                  .trim(),
                                              deskripsi: descriptionController
                                                  .text
                                                  .trim(),
                                              tenggat: formattedDeadline,
                                              tenggatJam: formattedDeadlineTime,
                                            )
                                          : await _createTask(
                                              judul: titleController.text
                                                  .trim(),
                                              deskripsi: descriptionController
                                                  .text
                                                  .trim(),
                                              tenggat: formattedDeadline,
                                              tenggatJam: formattedDeadlineTime,
                                            );

                                      if (!dialogContext.mounted) return;

                                      if (errorMessage == null) {
                                        Navigator.of(dialogContext).pop(true);
                                      } else {
                                        setDialogState(() {
                                          isSubmitting = false;
                                          submitError = errorMessage;
                                        });
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      isEditing
                                          ? Icons.save_rounded
                                          : Icons.add_rounded,
                                    ),
                              label: Text(
                                isSubmitting
                                    ? 'Menyimpan...'
                                    : isEditing
                                    ? 'Simpan Perubahan'
                                    : 'Simpan Tugas',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    if (taskSaved != true || !mounted) return;

    await _loadTasks();

    if (!mounted) return;

    if (_errorMessage == null) {
      _showMessage(
        isEditing
            ? 'Tugas berhasil diperbarui.'
            : 'Tugas berhasil ditambahkan.',
      );
    } else {
      _showMessage(
        'Tugas berhasil ${isEditing ? 'diperbarui' : 'ditambahkan'}, '
        'tetapi daftar gagal diperbarui. '
        'Coba muat ulang.',
        isError: true,
      );
    }
  }

  InputDecoration _taskInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primary, size: 20),
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: const Color(0xFFF8FBFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE6F2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE6F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageEnd,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
        ),
        title: Text(
          widget.pageTitle,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang tugas dan profil',
            onPressed: _isLoading ? null : _refreshPage,
            icon: const Icon(Icons.refresh_rounded, color: _primary),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: widget.canManageTasks
          ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 620),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.centerRight,
                children: [...previousChildren, ?currentChild],
              ),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 3.5),
                  end: Offset.zero,
                ).animate(animation);
                return SlideTransition(position: slide, child: child);
              },
              child: _isSelectionMode
                  ? FloatingActionButton.extended(
                      key: const ValueKey<String>('bulk-delete'),
                      onPressed: _selectedTaskIds.isEmpty || _isBulkDeleting
                          ? null
                          : _deleteSelectedTasks,
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      icon: _isBulkDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.delete_sweep_outlined),
                      label: Text(
                        _isBulkDeleting
                            ? 'Menghapus...'
                            : 'Hapus (${_selectedTaskIds.length})',
                      ),
                    )
                  : widget.canAddTasks
                  ? FloatingActionButton.extended(
                      key: const ValueKey<String>('add-task'),
                      onPressed: _showAddTaskDialog,
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah Tugas'),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey<String>('no-task-action'),
                    ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_pageStart, _pageEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _refreshPage,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
              children: [
                if (widget.showAgentProfile && !_isViewingOwnTasks) ...[
                  _buildAgentCard(),
                  const SizedBox(height: 16),
                ],
                if (_refreshWarning != null) ...[
                  _buildTaskRefreshWarning(),
                  const SizedBox(height: 16),
                ],
                _buildSummary(),
                const SizedBox(height: 18),
                _buildTaskPeriodGroup(),
                const SizedBox(height: 12),
                _buildDatePickerGroup(),
                const SizedBox(height: 18),
                _buildTaskHeader(),
                if (_isSelectionMode && _selectableTaskIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSelectAllTasks(),
                ],
                if (_showTaskSearch) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _taskSearchController,
                    focusNode: _taskSearchFocusNode,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari judul, deskripsi, status, tanggal...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _primary,
                      ),
                      suffixIcon: _taskSearchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus pencarian',
                              onPressed: () {
                                _taskSearchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear_rounded),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCE6F2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCE6F2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _buildTaskContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgentCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F5)),
      ),
      child: Row(
        children: [
          AgentProfilePhoto(
            photoBytes: _agentPhotoBytes,
            size: 54,
            borderRadius: 14,
            placeholder: const Icon(
              Icons.person_outline_rounded,
              color: _primary,
              size: 29,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _agentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _agentRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      height: 13,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      color: const Color(0xFFCBD5E1),
                    ),
                    Flexible(
                      child: Text(
                        'ID $_agentNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => showAgentDetailsDialog(context, _agentProfile),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              minimumSize: const Size(0, 38),
              side: const BorderSide(color: Color(0xFFB7D2F5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text(
              'Detail',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerGroup() {
    if (_selectedTaskPeriod != TaskDatePeriod.today) {
      final today = _dateOnly(DateTime.now());
      final details = switch (_selectedTaskPeriod) {
        TaskDatePeriod.past =>
          'Menampilkan tugas dengan tenggat sebelum ${_selectedDateTitle(today)}.',
        TaskDatePeriod.upcoming =>
          'Menampilkan tugas dengan tenggat setelah ${_selectedDateTitle(today)}.',
        TaskDatePeriod.all =>
          'Menampilkan semua tugas, diurutkan dari yang terbaru dibuat.',
        TaskDatePeriod.today => '',
      };

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE8F5)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.filter_alt_rounded,
                color: _primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter periode tugas aktif: ${_taskPeriodLabel(_selectedTaskPeriod)}',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final lastDate = _dateForIndex(_dateRangeLength - 1);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthName(_selectedDate.month)} ${_selectedDate.year}',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _showTaskDatePicker(lastDate);
                  if (picked == null || !mounted) return;
                  await _datePageController.animateToPage(
                    _dateIndexFor(picked),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: const Icon(Icons.calendar_month_rounded, size: 17),
                label: const Text('Pilih tanggal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: Color(0xFFB7D2F5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 66,
            child: PageView.builder(
              controller: _datePageController,
              itemCount: _dateRangeLength,
              onPageChanged: (index) {
                setState(() {
                  _selectedDate = _dateForIndex(index);
                });
              },
              itemBuilder: (context, index) {
                final date = _dateForIndex(index);
                final isSelected = _isSameDate(date, _selectedDate);
                final hasTasks = _hasTasksOnDate(date);
                return AnimatedBuilder(
                  animation: _datePageController,
                  builder: (context, child) =>
                      Opacity(opacity: _dateCardOpacity(index), child: child),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: isSelected
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFFF8FBFF),
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        onTap: () => _datePageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF83B5F0)
                                  : const Color(0xFFE5EDF7),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _weekdayShort(date.weekday),
                                maxLines: 1,
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isSelected ? _primary : _textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 5,
                                height: 5,
                                child: hasTasks
                                    ? DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _primary
                                              : const Color(0xFF7FA6D7),
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _showTaskDatePicker(DateTime lastDate) {
    var displayedMonth = _selectedDate.month;
    var displayedYear = _selectedDate.year;
    var selectedDate = _selectedDate;
    var pickerView = 'calendar';
    final firstYear = _dateRangeStart.year;
    final lastYear = lastDate.year;
    final yearPickerController = ScrollController(
      initialScrollOffset: ((displayedYear - firstYear) ~/ 3) * 52.0,
    );

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final firstDayOfMonth = DateTime(displayedYear, displayedMonth, 1);
          final leadingDays = firstDayOfMonth.weekday % 7;
          final daysInMonth = DateTime(
            displayedYear,
            displayedMonth + 1,
            0,
          ).day;
          final dayCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
          final firstVisibleDate = DateTime(
            displayedYear,
            displayedMonth,
            1 - leadingDays,
          );
          final today = _dateOnly(DateTime.now());
          final weekdays = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDCE8F5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDateTitle(selectedDate),
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_calendar_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Bulan sebelumnya',
                                onPressed:
                                    DateTime(
                                      displayedYear,
                                      displayedMonth - 1,
                                      1,
                                    ).isBefore(DateTime(firstYear, 1, 1))
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          final previousMonth = DateTime(
                                            displayedYear,
                                            displayedMonth - 1,
                                            1,
                                          );
                                          displayedYear = previousMonth.year;
                                          displayedMonth = previousMonth.month;
                                          pickerView = 'calendar';
                                        });
                                      },
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: _primary,
                                ),
                              ),
                              Expanded(
                                child: _buildCalendarDropdown(
                                  label: _monthName(displayedMonth),
                                  isActive: pickerView == 'month',
                                  onPressed: () => setDialogState(
                                    () => pickerView = pickerView == 'month'
                                        ? 'calendar'
                                        : 'month',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Bulan berikutnya',
                                onPressed:
                                    displayedYear > lastYear ||
                                        (displayedYear == lastYear &&
                                            displayedMonth >= lastDate.month)
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          final nextMonth = DateTime(
                                            displayedYear,
                                            displayedMonth + 1,
                                            1,
                                          );
                                          displayedYear = nextMonth.year;
                                          displayedMonth = nextMonth.month;
                                          pickerView = 'calendar';
                                        });
                                      },
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: _primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Tahun sebelumnya',
                                onPressed: displayedYear <= firstYear
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          displayedYear--;
                                          pickerView = 'calendar';
                                        });
                                      },
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: _primary,
                                ),
                              ),
                              Expanded(
                                child: _buildCalendarDropdown(
                                  label: '$displayedYear',
                                  isActive: pickerView == 'year',
                                  onPressed: () => setDialogState(
                                    () => pickerView = pickerView == 'year'
                                        ? 'calendar'
                                        : 'year',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Tahun berikutnya',
                                onPressed: displayedYear >= lastYear
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          displayedYear++;
                                          if (displayedYear == lastYear &&
                                              displayedMonth > lastDate.month) {
                                            displayedMonth = lastDate.month;
                                          }
                                          pickerView = 'calendar';
                                        });
                                      },
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: _primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    if (pickerView == 'month')
                      SizedBox(
                        height: 248,
                        child: _buildCalendarChoiceGrid(
                          values: List.generate(12, (index) => index + 1),
                          selectedValue: displayedMonth,
                          labelFor: _monthName,
                          onSelected: (month) {
                            setDialogState(() {
                              displayedMonth = month;
                              pickerView = 'calendar';
                            });
                          },
                        ),
                      )
                    else if (pickerView == 'year')
                      SizedBox(
                        height: 248,
                        child: Scrollbar(
                          controller: yearPickerController,
                          thumbVisibility: true,
                          child: _buildCalendarChoiceGrid(
                            values: List.generate(
                              lastYear - firstYear + 1,
                              (index) => firstYear + index,
                            ),
                            selectedValue: displayedYear,
                            labelFor: (year) => '$year',
                            controller: yearPickerController,
                            onSelected: (year) {
                              setDialogState(() {
                                displayedYear = year;
                                pickerView = 'calendar';
                              });
                            },
                          ),
                        ),
                      )
                    else ...[
                      Row(
                        children: weekdays
                            .map(
                              (weekday) => Expanded(
                                child: Center(
                                  child: Text(
                                    weekday,
                                    style: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 7),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dayCount,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisExtent: 48,
                            ),
                        itemBuilder: (context, index) {
                          final date = firstVisibleDate.add(
                            Duration(days: index),
                          );
                          final isSelected = _isSameDate(date, selectedDate);
                          final isCurrentMonth = date.month == displayedMonth;
                          final isToday = _isSameDate(date, today);
                          final isInRange =
                              !date.isBefore(_dateRangeStart) &&
                              !date.isAfter(lastDate);
                          final hasTasks = _hasTasksOnDate(date);
                          final textColor = isSelected
                              ? Colors.white
                              : !isInRange || !isCurrentMonth
                              ? const Color(0xFFB8C5D4)
                              : _textPrimary;
                          final markerColor = isSelected
                              ? Colors.white
                              : !isInRange || !isCurrentMonth
                              ? _primary.withValues(alpha: 0.35)
                              : _primary;

                          return Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: InkWell(
                                onTap: isInRange
                                    ? () {
                                        setDialogState(() {
                                          selectedDate = date;
                                          displayedMonth = date.month;
                                          displayedYear = date.year;
                                        });
                                      }
                                    : null,
                                customBorder: const CircleBorder(),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: isSelected ? _primary : null,
                                    shape: BoxShape.circle,
                                    border: isToday && !isSelected
                                        ? Border.all(
                                            color: _primary.withValues(
                                              alpha: 0.45,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                          fontWeight: isSelected || isToday
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: hasTasks ? markerColor : null,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: _textSecondary,
                            minimumSize: const Size(72, 42),
                          ),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(selectedDate),
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(72, 42),
                          ),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(yearPickerController.dispose);
  }

  Widget _buildCalendarDropdown({
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _textPrimary,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: const BorderSide(color: Color(0xFFDCE8F5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Icon(
            isActive
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: _primary,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarChoiceGrid({
    required List<int> values,
    required int selectedValue,
    required String Function(int) labelFor,
    required ValueChanged<int> onSelected,
    ScrollController? controller,
  }) {
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
      itemCount: values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 44,
      ),
      itemBuilder: (context, index) {
        final value = values[index];
        final isSelected = value == selectedValue;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(value),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color: isSelected ? _primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _primary : const Color(0xFFDCE8F5),
                ),
              ),
              child: Center(
                child: Text(
                  labelFor(value),
                  style: TextStyle(
                    color: isSelected ? Colors.white : _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _taskPeriodLabel(TaskDatePeriod period) => switch (period) {
    TaskDatePeriod.past => 'Lampau',
    TaskDatePeriod.today => 'Hari ini',
    TaskDatePeriod.upcoming => 'Mendatang',
    TaskDatePeriod.all => 'Semua tanggal',
  };

  String _taskPeriodHeaderLabel(TaskDatePeriod period) => switch (period) {
    TaskDatePeriod.past => 'Tugas lampau',
    TaskDatePeriod.today => _selectedDateTitle(_selectedDate),
    TaskDatePeriod.upcoming => 'Tugas mendatang',
    TaskDatePeriod.all => 'Semua tanggal',
  };

  Widget _buildTaskPeriodGroup() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Periode Tugas',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTaskPeriodButton(TaskDatePeriod.past),
              const SizedBox(width: 6),
              _buildTaskPeriodButton(TaskDatePeriod.today),
              const SizedBox(width: 6),
              _buildTaskPeriodButton(TaskDatePeriod.upcoming),
              const SizedBox(width: 6),
              _buildTaskPeriodButton(TaskDatePeriod.all),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskPeriodButton(TaskDatePeriod period) {
    final isSelected = _selectedTaskPeriod == period;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {
          final today = _dateOnly(DateTime.now());
          setState(() {
            _selectedTaskPeriod = period;
            if (period == TaskDatePeriod.today) _selectedDate = today;
          });
          if (period == TaskDatePeriod.today) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_datePageController.hasClients) return;
              _datePageController.jumpToPage(_dateIndexFor(today));
            });
          }
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Color(0xFF1565C0),
                      cupertino.Color.fromARGB(255, 44, 147, 231),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFCBDDF3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Text(
              _taskPeriodLabel(period),
              style: TextStyle(
                color: isSelected ? Colors.white : _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return GridView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 68,
      ),
      children: [
        _summaryCard(
          title: 'Total Tugas',
          value: '$_totalTasks',
          filterStatus: '',
          icon: Icons.checklist_rounded,
          color: const Color(0xFF2563EB),
          background: const Color(0xFFEFF6FF),
        ),
        _summaryCard(
          title: 'Belum dimulai',
          value: '$_notStartedTasks',
          filterStatus: 'Belum dimulai',
          icon: Icons.assignment_late_outlined,
          color: const Color(0xFF7C3AED),
          background: const Color(0xFFF5F3FF),
        ),
        _summaryCard(
          title: 'Berjalan',
          value: '$_runningTasks',
          filterStatus: 'Berjalan',
          icon: Icons.pending_actions_rounded,
          color: const Color(0xFFD97706),
          background: const Color(0xFFFFF7ED),
        ),
        _summaryCard(
          title: 'Selesai',
          value: '$_completedTasks',
          filterStatus: 'Selesai',
          icon: Icons.task_alt_rounded,
          color: const Color(0xFF16A34A),
          background: const Color(0xFFF0FDF4),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required String filterStatus,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    final isSelected = _selectedTaskStatus == filterStatus;

    return Material(
      color: isSelected ? background.withValues(alpha: 0.35) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedTaskStatus = filterStatus),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.55)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 40,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _taskPeriodHeaderLabel(_selectedTaskPeriod),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // Text(
        //   _isSelectionMode
        //       ? '${_selectedTaskIds.length} dipilih'
        //       : _visibleTasks.length == _totalTasks
        //       ? '$_totalTasks tugas'
        //       : '${_visibleTasks.length} dari $_totalTasks tugas',
        //   style: const TextStyle(color: _textSecondary, fontSize: 12),
        // ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: _showTaskSearch ? 'Tutup pencarian' : 'Cari tugas',
          onPressed: () {
            final showSearch = !_showTaskSearch;
            setState(() {
              _showTaskSearch = showSearch;
              if (!_showTaskSearch) _taskSearchController.clear();
            });
            if (showSearch) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _showTaskSearch) {
                  _taskSearchFocusNode.requestFocus();
                }
              });
            } else {
              _taskSearchFocusNode.unfocus();
            }
          },
          icon: Icon(
            _showTaskSearch ? Icons.close_rounded : Icons.search_rounded,
            color: _showTaskSearch ? _primary : _textSecondary,
          ),
        ),
        IconButton(
          tooltip: 'Filter dan urutkan',
          onPressed: _showTaskFilters,
          icon: Icon(
            Icons.tune_rounded,
            color:
                _selectedTaskStatus.isNotEmpty ||
                    _selectedTaskPeriod != TaskDatePeriod.today ||
                    _taskSortField != _TaskSortField.createdAt ||
                    _sortAscending
                ? _primary
                : _textSecondary,
          ),
        ),
        if (widget.canManageTasks)
          IconButton(
            tooltip: _isSelectionMode ? 'Batal memilih tugas' : 'Pilih tugas',
            onPressed: _isLoading || (_tasks.isEmpty && !_isSelectionMode)
                ? null
                : _toggleSelectionMode,
            icon: Icon(
              _isSelectionMode ? Icons.close_rounded : Icons.check_box_outlined,
              color: _isSelectionMode ? _primary : _textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildSelectAllTasks() {
    final taskIds = _selectableTaskIds;
    final selectedCount = taskIds.where(_selectedTaskIds.contains).length;
    final bool? value = selectedCount == 0
        ? false
        : selectedCount == taskIds.length
        ? true
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: CheckboxListTile(
        value: value,
        tristate: true,
        onChanged: _isBulkDeleting
            ? null
            : (selected) => _toggleAllTaskSelection(selected == true),
        activeColor: _primary,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        dense: true,
        title: const Text(
          'Pilih semua tugas',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: const Text(
          'Termasuk tugas yang tidak tampil karena pencarian atau filter.',
          style: TextStyle(color: _textSecondary, fontSize: 11),
        ),
        secondary: Text(
          '$selectedCount/${taskIds.length}',
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRefreshWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            color: Color(0xFFB45309),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Gagal memperbarui data: $_refreshWarning',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Coba muat ulang',
            visualDensity: VisualDensity.compact,
            onPressed: _isRefreshingTasks || _isRefreshingAgentHeader
                ? null
                : () => _refreshPage(showLoading: false),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFB45309),
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal Memuat Tugas',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      return _buildEmptyState();
    }

    final visibleTasks = _visibleTasks;
    if (visibleTasks.isEmpty) {
      final hasSearchOrStatusFilter =
          _taskSearchController.text.trim().isNotEmpty ||
          _selectedTaskStatus.isNotEmpty;
      final emptyTitle = switch (_selectedTaskPeriod) {
        TaskDatePeriod.past => 'Tidak ada tugas lampau',
        TaskDatePeriod.today => 'Belum ada tugas pada tanggal ini',
        TaskDatePeriod.upcoming => 'Tidak ada tugas mendatang',
        TaskDatePeriod.all => 'Belum ada tugas pada semua tanggal',
      };
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: _textSecondary, size: 34),
            SizedBox(height: 8),
            Text(
              hasSearchOrStatusFilter ? 'Tugas tidak ditemukan' : emptyTitle,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              hasSearchOrStatusFilter
                  ? 'Coba ubah kata pencarian atau filter status.'
                  : _selectedTaskPeriod == TaskDatePeriod.today
                  ? 'Tugas untuk tanggal ini akan tampil di sini.'
                  : 'Tugas dalam periode ini akan tampil di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_selectedTaskPeriod == TaskDatePeriod.today) {
      return Column(children: visibleTasks.map(_buildTaskRow).toList());
    }

    final taskGroups = groupTasksByCreationDate(visibleTasks);
    return Column(
      children: [
        for (final group in taskGroups) ...[
          _buildTaskCreationDateHeader(group.date),
          ...group.tasks.map(_buildTaskRow),
        ],
      ],
    );
  }

  Widget _buildTaskCreationDateHeader(DateTime? date) {
    final title = date == null
        ? 'Tanggal dibuat tidak tersedia'
        : '${date.day} ${_monthName(date.month)} ${date.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 22, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(
              color: cupertino.Color.fromARGB(92, 63, 63, 63),
              thickness: 1.2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task) {
    final taskId = _taskId(task);
    return TweenAnimationBuilder<double>(
      key: ObjectKey(task),
      tween: Tween<double>(begin: 0, end: _isSelectionMode ? 1 : 0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        final isSelected = _selectedTaskIds.contains(taskId);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Transform.translate(
                  offset: Offset(-18 * (1 - progress), 0),
                  child: Opacity(
                    opacity: progress,
                    child: SizedBox(
                      width: 42,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: taskId.isEmpty || _isBulkDeleting
                            ? null
                            : (selected) => _toggleTaskSelection(
                                taskId,
                                selected ?? false,
                              ),
                        activeColor: _primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildTaskCard(task)),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = _taskStatus(task);
    final taskId = _taskId(task);
    final isUpdating = _updatingTaskIds.contains(taskId);
    final (statusColor, statusBackground, statusIcon) = switch (status) {
      'Berjalan' => (
        const Color(0xFFD97706),
        const Color(0xFFFFF7ED),
        Icons.autorenew_rounded,
      ),
      'Selesai' => (
        const Color(0xFF15803D),
        const Color(0xFFF0FDF4),
        Icons.check_circle_outline_rounded,
      ),
      _ => (
        const Color(0xFF1565C0),
        const Color(0xFFEAF3FF),
        Icons.radio_button_unchecked_rounded,
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0D47A1),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTaskDetailsDialog(task),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 28,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _taskDeadlineTime(task) ?? '--:--',
                              maxLines: 1,
                              style: const TextStyle(
                                color: cupertino.Color.fromARGB(
                                  255,
                                  48,
                                  48,
                                  48,
                                ),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SizedBox(
                            width: 16,
                            child: Column(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  color: const Color(0xFF94A3B8),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _taskTitle(task),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        color: _textSecondary,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Dibuat pada ${_taskCreatedAt(task)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _textSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (widget.canManageTasks)
                              PopupMenuButton<String>(
                                tooltip: 'Aksi tugas',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 42,
                                  minHeight: 42,
                                ),
                                color: Colors.white,
                                elevation: 10,
                                shadowColor: const Color(0x260F172A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: _textSecondary,
                                  size: 20,
                                ),
                                onSelected: (action) {
                                  if (action == 'edit' && status != 'Selesai') {
                                    _showAddTaskDialog(task: task);
                                  } else if (action == 'delete') {
                                    _deleteTask(task);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (status != 'Selesai')
                                    const PopupMenuItem(
                                      value: 'edit',
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            color: _primary,
                                            size: 20,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Edit tugas',
                                            style: TextStyle(
                                              color: _textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    height: 48,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFDC2626),
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Hapus tugas',
                                          style: TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (_taskDescription(task).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(right: 50),
                            child: Text(
                              _taskDescription(task),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: statusBackground,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isUpdating)
                                  SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: statusColor,
                                    ),
                                  )
                                else
                                  Icon(
                                    statusIcon,
                                    color: statusColor,
                                    size: 14,
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.playlist_add_check_rounded,
              color: _primary,
              size: 39,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum Ada Tugas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Belum ada tugas yang tercatat untuk agen ini. '
            'Tekan tombol Tambah Tugas untuk membuat tugas baru.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 16,
                  color: _textSecondary,
                ),
                SizedBox(width: 7),
                Text(
                  'Terhubung ke server',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
