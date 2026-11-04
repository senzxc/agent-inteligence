import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/gps_tracking_service.dart';
import '../utils/dashboard_route_observer.dart';
import '../pages/agent_task.dart';

class AgentHomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const AgentHomePage({super.key, required this.user});

  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage> with RouteAware {
  PageRoute<dynamic>? _dashboardRoute;
  static const Color _primary = Color(0xFF1565C0);
  static const Color _pageStart = Color(0xFFF8FBFF);
  static const Color _pageEnd = Color(0xFFEAF3FF);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _firstValue(List<String> keys, {String fallback = '-'}) {
    for (final key in keys) {
      final value = widget.user[key]?.toString().trim();

      if (value != null && value.isNotEmpty && value != 'null') {
        return value;
      }
    }

    return fallback;
  }

  String get _name => _firstValue([
    'NAMA_AGEN',
    'NAMA',
    'nama',
    'NAMA_DEPAN',
    'N_AGEN',
  ], fallback: 'Agen');

  String get _agentId =>
      _firstValue(['STAMBUK', 'stambuk', 'NOMOR_AGEN', 'I_AGEN', 'nomorAgen']);

  String get _officeCode => _firstValue(['KODE_KANTOR', 'KANTOR', 'kantor']);

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _dashboardRoute) {
      if (_dashboardRoute != null) {
        dashboardRouteObserver.unsubscribe(this);
      }
      _dashboardRoute = route;
      dashboardRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadTasks();
  }

  @override
  void dispose() {
    dashboardRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadTasks() async {
    if (_agentId == '-') {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ID agen akun tidak ditemukan.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getAgentTasks(_agentId);
      final statusCode = result['statusCode'];
      final responseData = result['data'];

      if (statusCode != 200 || responseData is! Map) {
        throw Exception(
          responseData is Map
              ? responseData['message']?.toString() ??
                    'Gagal mengambil daftar tugas.'
              : 'Format respons server tidak sesuai.',
        );
      }

      final payload = Map<String, dynamic>.from(responseData);
      dynamic rawTasks = payload['tasks'] ?? payload['data'];

      if (rawTasks is Map) {
        rawTasks = rawTasks['tasks'] ?? rawTasks['items'] ?? rawTasks['data'];
      }

      final parsedTasks = rawTasks is List
          ? rawTasks
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _tasks = parsedTasks;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _status(Map<String, dynamic> task) {
    final value = (task['status'] ?? task['STATUS'] ?? 'Belum dimulai')
        .toString();

    if (value == 'Berjalan' || value == 'Selesai') {
      return value;
    }

    return 'Belum dimulai';
  }

  String _title(Map<String, dynamic> task) {
    return (task['judul'] ?? task['title'] ?? 'Tugas tanpa judul').toString();
  }

  String _description(Map<String, dynamic> task) {
    return (task['deskripsi'] ?? task['description'] ?? '').toString().trim();
  }

  String _deadline(Map<String, dynamic> task) {
    final raw = (task['tenggat'] ?? task['deadline'] ?? '').toString();

    if (raw.isEmpty) return 'Tanpa tenggat';

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

  void _openAllTasks() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentTaskPage(agent: widget.user),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Yakin ingin keluar?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Column(
                  children: [
                    const Text(
                      'Anda akan keluar dari sesi akun saat ini. Pastikan semua pekerjaan yang sedang dilakukan telah selesai sebelum keluar dari aplikasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: const BorderSide(
                                  color: Color(0xFFBBD5F5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Batal'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Keluar'),
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

    if (confirmed != true || !mounted) return;

    try {
      await AgentGpsTrackingService.instance.stopTracking();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghentikan tracking: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;

    await ApiService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageEnd,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Beranda Agen',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_pageStart, _pageEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadTasks,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              // _buildSectionTitle(
              //   'Ringkasan Tugas',
              //   'Pantau progres tugasmu',
              // ),
              // const SizedBox(height: 12),
              _buildSummary(),
              // const SizedBox(height: 26),
              _buildTaskHeader(),
              const SizedBox(height: 12),
              _buildTaskContent(),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _openAllTasks,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Color(0xFFBBD5F5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text(
                  'Lihat Semua Tugas',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return const SizedBox.shrink();
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260D47A1),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat datang,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _welcomeInfo(Icons.badge_outlined, 'Stambuk: $_agentId'),
          const SizedBox(height: 9),
          _welcomeInfo(Icons.business_outlined, 'Kode Kantor: $_officeCode'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  color: Colors.white,
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Kelola dan selesaikan tugasmu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _welcomeInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tugas Saya',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Tugas terbaru yang kamu buat',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _openAllTasks,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lihat semua', style: TextStyle(color: Colors.black)),
              SizedBox(width: 3),
              Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 38,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 10),
            const Text(
              'Tugas belum dapat dimuat',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE8F5)),
        ),
        child: const Column(
          children: [
            Icon(Icons.assignment_outlined, size: 42, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text(
              'Belum ada tugas',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Tugas yang kamu buat akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final recentTasks = _tasks.take(3).toList();

    return Column(children: recentTasks.map(_buildTaskCard).toList());
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = _status(task);

    final Color statusColor;
    final Color statusBackground;
    final IconData statusIcon;

    switch (status) {
      case 'Berjalan':
        statusColor = const Color(0xFFC2410C);
        statusBackground = const Color(0xFFFFF7ED);
        statusIcon = Icons.autorenew_rounded;
        break;
      case 'Selesai':
        statusColor = const Color(0xFF15803D);
        statusBackground = const Color(0xFFF0FDF4);
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        statusColor = _primary;
        statusBackground = const Color(0xFFEAF3FF);
        statusIcon = Icons.radio_button_unchecked_rounded;
    }

    final description = _description(task);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFDCE8F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0D47A1),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(task),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusBackground,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: statusColor),
                            const SizedBox(width: 5),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 13),
          const Divider(height: 1, color: Color(0xFFE8EEF6)),
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: _textSecondary,
              ),
              const SizedBox(width: 7),
              const Text(
                'Tenggat',
                style: TextStyle(color: _textSecondary, fontSize: 11),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  _deadline(task),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
