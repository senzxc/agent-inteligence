import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/agent_profile_photo.dart';

enum _TaskSortField { deadline, createdAt }

class AgentTaskPage extends StatefulWidget {
  final Map<String, dynamic> agent;
  final String pageTitle;
  final bool canManageTasks;
  final bool canAddTasks;

  const AgentTaskPage({
    super.key,
    required this.agent,
    this.pageTitle = 'Tugas Agen',
    this.canManageTasks = true,
    this.canAddTasks = true,
  });

  @override
  State<AgentTaskPage> createState() => _AgentTaskPageState();
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
  Timer? _taskRefreshTimer;

  bool _isLoading = true;
  bool _isRefreshingTasks = false;
  bool _isSelectionMode = false;
  bool _isBulkDeleting = false;
  Uint8List? _agentPhotoBytes;
  String? _loadedPhotoAgentId;
  String? _errorMessage;
  String? _refreshError;
  String _selectedTaskStatus = '';
  _TaskSortField _taskSortField = _TaskSortField.createdAt;
  bool _sortAscending = false;
  bool _showTaskSearch = false;

  String _firstValue(List<String> keys, {String fallback = '-'}) {
    for (final key in keys) {
      final value = widget.agent[key]?.toString().trim();

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

  String get _agentId => _firstValue([
    'I_AGEN',
    'NOMOR_AGEN',
    'STAMBUK',
    'nomorAgen',
    'stambuk',
  ], fallback: '');

  String get _agentPhone =>
      _firstValue(['NOMOR_HP', 'I_TELEPON_HP', 'NO_HP', 'nomorHp']);

  String get _agentEmail => _firstValue(['A_EMAIL', 'EMAIL', 'email']);

  String get _agentAddress => _firstValue([
    'ALAMAT',
    'A_RUMAH',
    'ALAMAT_USER',
  ], fallback: 'Alamat belum tersedia');

  String get _today {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    const months = [
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
    ];

    final now = DateTime.now();

    return '${days[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  int get _totalTasks => _tasks.length;

  int get _runningTasks => _tasks.where((task) {
    return _taskStatus(task) == 'Berjalan';
  }).length;

  int get _completedTasks => _tasks.where((task) {
    return _taskStatus(task) == 'Selesai';
  }).length;

  Set<String> get _selectableTaskIds =>
      _tasks.map(_taskId).where((taskId) => taskId.isNotEmpty).toSet();

  List<Map<String, dynamic>> get _visibleTasks {
    final query = _taskSearchController.text.trim().toLowerCase();
    final tasks = _tasks.where((task) {
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
    return tasks;
  }

  @override
  void initState() {
    super.initState();
    _loadAgentProfilePhoto();
    _loadTasks();
    _taskRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadTasks(showLoading: false),
    );
  }

  Future<void> _loadAgentProfilePhoto() async {
    final agentId = _agentId.trim();
    if (agentId.isEmpty || agentId == '-') return;
    if (_loadedPhotoAgentId == agentId) return;
    _loadedPhotoAgentId = agentId;

    try {
      final photo = await ApiService.getAgentProfilePhoto(agentId);
      if (mounted) setState(() => _agentPhotoBytes = photo);
    } catch (error) {
      debugPrint('Gagal memuat foto profil agen untuk halaman tugas: $error');
    }
  }

  @override
  void dispose() {
    _taskRefreshTimer?.cancel();
    _taskSearchController.dispose();
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

  String _taskDeadline(Map<String, dynamic> task) {
    final raw = (task['tenggat'] ?? task['deadline'] ?? '').toString();

    if (raw.isEmpty) return 'Tidak ditentukan';

    final date = DateTime.tryParse(raw);
    if (date == null) return raw;

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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  DateTime? _taskCreatedDate(Map<String, dynamic> task) {
    final raw = (task['createdAt'] ?? task['created_at'] ?? task['created'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _taskCreatedAt(Map<String, dynamic> task) {
    final date = _taskCreatedDate(task);
    if (date == null) return 'Tanggal dibuat tidak tersedia';

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

  DateTime? _taskSortDate(Map<String, dynamic> task, _TaskSortField field) {
    if (field == _TaskSortField.createdAt) {
      return _taskCreatedDate(task);
    }

    final raw = (task['tenggat'] ?? task['deadline'] ?? '').toString().trim();
    return raw.isEmpty ? null : DateTime.tryParse(raw);
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
                              () =>
                                  sortField = value ?? _TaskSortField.createdAt,
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
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? const Color(0xFFEAF3FF)
                                    : Colors.white,
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith(
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
  }) async {
    try {
      await ApiService.createAgentTask(
        agentId: _agentNumber,
        judul: judul,
        deskripsi: deskripsi,
        tenggat: tenggat,
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
  }) async {
    try {
      await ApiService.updateAgentTask(
        taskId: taskId,
        judul: judul,
        deskripsi: deskripsi,
        tenggat: tenggat,
      );
      return null;
    } catch (error) {
      return _cleanError(error);
    }
  }

  Future<bool> _updateStatus(Map<String, dynamic> task, String status) async {
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
            var updated = false;
            try {
              updated = await _updateStatus(task, nextStatus);
            } finally {
              if (mounted && dialogContext.mounted) {
                setDialogState(() {
                  isUpdatingStatus = false;
                  if (updated) {
                    selectedStatus = nextStatus;
                  } else {
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
      _showMessage('Pilih setidaknya satu tugas untuk dihapus.', isError: true);
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

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('Tidak dapat menampilkan pesan tugas: $message');
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade700
            : const Color(0xFF15803D),
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

    final deadline = DateTime.now();
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
                '${deadline.day.toString().padLeft(2, '0')}-'
                '${deadline.month.toString().padLeft(2, '0')}-'
                '${deadline.year}';

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
                                          'Gagal menambahkan tugas: $submitError',
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
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F8FF),
                                  border: Border.all(
                                    color: const Color(0xFFD5E5FA),
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_outlined,
                                      size: 20,
                                      color: _primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Tenggat hari ini: $dateLabel',
                                        style: const TextStyle(
                                          color: _textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      color: _textSecondary,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tenggat tugas otomatis ditetapkan ke hari ini.',
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

                                      final formattedDeadline =
                                          '${deadline.year}-'
                                          '${deadline.month.toString().padLeft(2, '0')}-'
                                          '${deadline.day.toString().padLeft(2, '0')}';

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
                                            )
                                          : await _createTask(
                                              judul: titleController.text
                                                  .trim(),
                                              deskripsi: descriptionController
                                                  .text
                                                  .trim(),
                                              tenggat: formattedDeadline,
                                            );

                                      if (!dialogContext.mounted) return;

                                      if (errorMessage == null) {
                                        Navigator.of(dialogContext).pop(true);
                                      } else {
                                        setDialogState(() {
                                          isSubmitting = false;
                                          submitError =
                                              '${isEditing ? 'Gagal memperbarui' : 'Gagal menambahkan'} tugas: $errorMessage';
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
            tooltip: 'Muat ulang tugas',
            onPressed: _isLoading ? null : _loadTasks,
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
            onRefresh: _loadTasks,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
              children: [
                _buildAgentCard(),
                const SizedBox(height: 20),
                if (_refreshError != null) ...[
                  _buildTaskRefreshWarning(),
                  const SizedBox(height: 16),
                ],
                if (!widget.canManageTasks) ...[
                  _buildReadOnlyNotice(),
                  const SizedBox(height: 16),
                ],
                _buildDateHeader(),
                const SizedBox(height: 16),
                _buildSummary(),
                const SizedBox(height: 24),
                _buildTaskHeader(),
                if (_isSelectionMode && _selectableTaskIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSelectAllTasks(),
                ],
                if (_showTaskSearch) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _taskSearchController,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260D47A1),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgentProfilePhoto(
            photoBytes: _agentPhotoBytes,
            size: 52,
            borderRadius: 14,
            placeholder: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _agentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Nomor Agen: $_agentNumber',
                  style: const TextStyle(
                    color: Color(0xFFDCEBFF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                _agentInfoRow(Icons.phone_outlined, _agentPhone),
                const SizedBox(height: 7),
                _agentInfoRow(Icons.email_outlined, _agentEmail),
                const SizedBox(height: 7),
                _agentInfoRow(Icons.location_on_outlined, _agentAddress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E5FA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0D47A1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, color: _primary, size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode pemantauan',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Anda hanya dapat melihat tugas agen ini.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
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

  Widget _agentInfoRow(IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFDCEBFF), size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFFEAF3FF),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.calendar_today_rounded,
            color: _primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aktivitas Harian',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _today,
                style: const TextStyle(color: _textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'Total Tugas',
            value: '$_totalTasks',
            icon: Icons.checklist_rounded,
            color: const Color(0xFF2563EB),
            background: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Berjalan',
            value: '$_runningTasks',
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFD97706),
            background: const Color(0xFFFFF7ED),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Selesai',
            value: '$_completedTasks',
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF16A34A),
            background: const Color(0xFFF0FDF4),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Daftar Tugas',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
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
            setState(() {
              _showTaskSearch = !_showTaskSearch;
              if (!_showTaskSearch) _taskSearchController.clear();
            });
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
              'Gagal memperbarui status tugas: $_refreshError',
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
            onPressed: _isRefreshingTasks
                ? null
                : () => _loadTasks(showLoading: false),
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.search_off_rounded, color: _textSecondary, size: 34),
            SizedBox(height: 8),
            Text(
              'Tugas tidak ditemukan',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Coba ubah kata pencarian atau filter status.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: visibleTasks.map((task) {
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
      }).toList(),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = _taskStatus(task);
    final deadline = _taskDeadline(task);
    final taskId = _taskId(task);
    final isUpdating = _updatingTaskIds.contains(taskId);
    final isCompleted = status == 'Selesai';

    Color statusColor;
    Color statusBackground;
    IconData statusIcon;

    switch (status) {
      case 'Berjalan':
        statusColor = const Color(0xFFD97706);
        statusBackground = const Color(0xFFFFF7ED);
        statusIcon = Icons.autorenew_rounded;
        break;
      case 'Selesai':
        statusColor = const Color(0xFF15803D);
        statusBackground = const Color(0xFFF0FDF4);
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        statusColor = const Color(0xFF1565C0);
        statusBackground = const Color(0xFFEAF3FF);
        statusIcon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showTaskDetailsDialog(task),
                  borderRadius: BorderRadius.circular(13),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEAF3FF), Color(0xFFDCEBFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.assignment_rounded,
                            color: _primary,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _taskTitle(task),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    color: _textSecondary,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Dibuat pada ${_taskCreatedAt(task)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
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
              ),
              if (widget.canManageTasks)
                PopupMenuButton<String>(
                  tooltip: 'Aksi tugas',
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: _textSecondary,
                  ),
                  color: Colors.white,
                  elevation: 10,
                  shadowColor: const Color(0x260F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showAddTaskDialog(task: task);
                    } else if (action == 'delete') {
                      _deleteTask(task);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      height: 48,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: _primary, size: 20),
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
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _showTaskDetailsDialog(task),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _taskDescription(task),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 17,
                        color: _primary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          deadline == 'Tidak ditentukan'
                              ? 'Tanpa tenggat'
                              : deadline,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.canManageTasks)
            Container(
              padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F8FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0ECF9)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: isUpdating
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          )
                        : const Icon(
                            Icons.sync_alt_rounded,
                            color: _primary,
                            size: 18,
                          ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUpdating
                              ? 'Menyimpan perubahan...'
                              : isCompleted
                              ? 'Tugas sudah selesai'
                              : 'Ubah status',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFF1F5F9)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFFDCE6F2),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: status,
                        isDense: true,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isCompleted ? _textSecondary : _primary,
                        ),
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        items: _statuses.map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged:
                            !widget.canManageTasks ||
                                isUpdating ||
                                _isLoading ||
                                isCompleted
                            ? null
                            : (value) {
                                if (value != null && value != status) {
                                  _updateStatus(task, value);
                                }
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
