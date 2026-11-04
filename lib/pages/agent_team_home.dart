import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';

import '../services/api_service.dart';
import '../services/gps_tracking_service.dart';
import '../utils/agency_role.dart';
import '../utils/dashboard_route_observer.dart';
import '../widgets/agent_marker.dart';
import 'agent_task.dart';

enum _AgentQuickAction {
  details,
  location,
  centerAgent,
  locationDetails,
  tasks,
}

class AgentTeamHomePage extends StatefulWidget {
  const AgentTeamHomePage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AgentTeamHomePage> createState() => _AgentTeamHomePageState();
}

class _AgentTeamHomePageState extends State<AgentTeamHomePage> with RouteAware {
  PageRoute<dynamic>? _dashboardRoute;
  static const Color _pageStart = Color(0xFFF8FBFF);
  static const Color _pageEnd = Color(0xFFEAF3FF);
  static const Color _primary = Color(0xFF1565C0);
  static const Color _ink = Color(0xFF172033);
  static const Color _muted = Color(0xFF64748B);

  List<Map<String, dynamic>> _agents = [];
  int? _onlineAgentCount;
  int? _offlineAgentCount;
  int? _totalAgentCount;
  bool _isLoading = true;
  String? _error;

  String get _agencyRole =>
      (widget.user['C_AGENCY_JABATAN'] ?? '').toString().trim().toUpperCase();

  String get _officeCode =>
      (widget.user['KODE_KANTOR'] ??
              widget.user['KANTOR'] ??
              widget.user['kantor'] ??
              '')
          .toString()
          .trim();

  String get _officeName =>
      (widget.user['NAMA_KANTOR'] ?? widget.user['namaKantor'] ?? '')
          .toString()
          .trim();

  String get _displayName =>
      (widget.user['NAMA_AGEN'] ??
              widget.user['NAMA'] ??
              widget.user['nama'] ??
              'Agen')
          .toString()
          .trim();

  String get _agentId =>
      (widget.user['I_AGEN'] ??
              widget.user['NOMOR_AGEN'] ??
              widget.user['STAMBUK'] ??
              widget.user['stambuk'] ??
              '-')
          .toString();

  String get _visibleRolesLabel => switch (_agencyRole) {
    'AD' => 'AM, AS, dan WA',
    'AM' => 'AS dan WA',
    'AS' => 'WA',
    _ => 'agen',
  };

  @override
  void initState() {
    super.initState();
    _loadAgents();
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
    _loadAgents();
  }

  @override
  void dispose() {
    dashboardRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getAgentProfiles(kantor: _officeCode),
        ApiService.getAgents(),
      ]);
      final profileData = results[0]['data'];
      if (results[0]['statusCode'] != 200 ||
          profileData is! Map ||
          profileData['success'] != true ||
          profileData['data'] is! List) {
        throw Exception(
          profileData is Map
              ? profileData['message']?.toString() ??
                    'Gagal memuat daftar agen.'
              : 'Format respons daftar agen tidak valid.',
        );
      }

      final trackingData = results[1]['data'];
      if (results[1]['statusCode'] != 200 ||
          trackingData is! Map ||
          trackingData['success'] != true ||
          trackingData['data'] is! List) {
        throw Exception(
          trackingData is Map
              ? trackingData['message']?.toString() ??
                    'Gagal memuat status tracking agen.'
              : 'Format respons status tracking tidak valid.',
        );
      }

      final trackingAgentsById = <String, Map>{};
      for (final trackingAgent
          in (trackingData['data'] as List).whereType<Map>()) {
        final id =
            (trackingAgent['stambuk'] ??
                    trackingAgent['I_AGEN'] ??
                    trackingAgent['NOMOR_AGEN'])
                ?.toString()
                .trim();
        if (id != null && id.isNotEmpty) {
          trackingAgentsById[id.toUpperCase()] = trackingAgent;
        }
      }
      final allAgents = (profileData['data'] as List).whereType<Map>().map((
        agent,
      ) {
        final profile = Map<String, dynamic>.from(agent);
        final agentId = (profile['NOMOR_AGEN'] ?? profile['I_AGEN'])
            ?.toString()
            .trim();
        final trackingAgent = agentId == null
            ? null
            : trackingAgentsById[agentId.toUpperCase()];
        profile
          ..['isTracking'] = trackingAgent != null
          ..['trackingStartedAt'] = trackingAgent?['startedAt']
          ..['latitude'] = trackingAgent?['latitude']
          ..['longitude'] = trackingAgent?['longitude']
          ..['accuracy'] = trackingAgent?['accuracy']
          ..['speed'] = trackingAgent?['speed']
          ..['lastUpdated'] = trackingAgent?['lastUpdated'];
        return profile;
      }).toList();
      final onlineAgents =
          allAgents.where((agent) => agent['isTracking'] == true).toList()
            ..sort((first, second) {
              final firstStartedAt = DateTime.tryParse(
                first['trackingStartedAt']?.toString() ?? '',
              );
              final secondStartedAt = DateTime.tryParse(
                second['trackingStartedAt']?.toString() ?? '',
              );
              if (firstStartedAt == null) {
                return secondStartedAt == null ? 0 : 1;
              }
              if (secondStartedAt == null) {
                return -1;
              }
              return secondStartedAt.compareTo(firstStartedAt);
            });
      final onlineAgentCount = onlineAgents.length;
      final totalAgentCount = allAgents.length;
      if (!mounted) {
        return;
      }

      setState(() {
        _agents = onlineAgents.take(5).toList();
        _onlineAgentCount = onlineAgentCount;
        _offlineAgentCount = totalAgentCount - onlineAgentCount;
        _totalAgentCount = totalAgentCount;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openAgentMap({String? agentId}) async {
    await Navigator.pushNamed(
      context,
      '/agent-list',
      arguments: {
        ...widget.user,
        'KODE_KANTOR': _officeCode,
        'FOCUS_AGENT_ID': ?agentId,
      },
    );
  }

  void _openAgentList(String statusFilter) {
    final appRole = switch (_agencyRole) {
      'KD' => 'HEAD_MARKETING',
      'AD' => 'HEAD_AGENT',
      _ => 'AGENT',
    };
    Navigator.pushNamed(
      context,
      '/agent-list',
      arguments: {
        ...widget.user,
        'APP_ROLE': appRole,
        'KODE_KANTOR': _officeCode,
        'INITIAL_STATUS_FILTER': statusFilter,
        'VIEW_ALL_BRANCHES': false,
        'SHOW_INDONESIA_MAP_BUTTON': false,
      },
    );
  }

  Future<void> _showAgentQuickMenu(
    Map<String, dynamic> agent,
    Offset tapPosition,
  ) async {
    final screenSize = MediaQuery.sizeOf(context);
    final action = await showMenu<_AgentQuickAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        screenSize.width - tapPosition.dx,
        screenSize.height - tapPosition.dy,
      ),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x1A0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      items: [
        const PopupMenuItem(
          value: _AgentQuickAction.details,
          padding: EdgeInsets.only(left: 8, right: 0),
          child: _AgentQuickMenuItem(
            icon: Icons.badge_outlined,
            label: 'Detail Agen',
            width: 160,
          ),
        ),
        const PopupMenuItem(
          value: _AgentQuickAction.location,
          padding: EdgeInsets.only(left: 8, right: 0),
          child: _AgentQuickMenuItem(
            icon: Icons.location_on_outlined,
            label: 'Lokasi Agen',
            width: 160,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const PopupMenuItem(
          value: _AgentQuickAction.tasks,
          padding: EdgeInsets.only(left: 8, right: 0),
          child: _AgentQuickMenuItem(
            icon: Icons.checklist_rounded,
            label: 'Tugas Agen',
            width: 160,
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _AgentQuickAction.details:
        await _showAgentDetails(agent);
      case _AgentQuickAction.location:
        await _showAgentLocationMenu(agent, tapPosition);
      case _AgentQuickAction.centerAgent:
      case _AgentQuickAction.locationDetails:
        break;
      case _AgentQuickAction.tasks:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AgentTaskPage(
              agent: agent,
              canManageTasks: !['KD', 'AD', 'AM', 'AS'].contains(_agencyRole),
              canAddTasks: false,
            ),
          ),
        );
    }
  }

  Future<void> _showAgentLocationMenu(
    Map<String, dynamic> agent,
    Offset tapPosition,
  ) async {
    final screenSize = MediaQuery.sizeOf(context);
    final submenuPosition = Offset(
      tapPosition.dx + 170 < screenSize.width
          ? tapPosition.dx + 170
          : tapPosition.dx - 170,
      tapPosition.dy,
    );
    final action = await showMenu<_AgentQuickAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        submenuPosition.dx,
        submenuPosition.dy,
        screenSize.width - submenuPosition.dx,
        screenSize.height - submenuPosition.dy,
      ),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x1A0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      items: const [
        PopupMenuItem(
          value: _AgentQuickAction.centerAgent,
          child: _AgentQuickMenuItem(
            icon: Icons.my_location_rounded,
            label: 'Pusatkan',
          ),
        ),
        PopupMenuItem(
          value: _AgentQuickAction.locationDetails,
          child: _AgentQuickMenuItem(
            icon: Icons.info_outline_rounded,
            label: 'Detail Lokasi',
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _AgentQuickAction.centerAgent:
        await _openAgentMap(agentId: _agentIdFor(agent));
      case _AgentQuickAction.locationDetails:
        await _showAgentLocationDetails(agent);
      case _AgentQuickAction.details:
      case _AgentQuickAction.location:
      case _AgentQuickAction.tasks:
        break;
    }
  }

  String _agentIdFor(Map<String, dynamic> agent) =>
      (agent['NOMOR_AGEN'] ?? agent['I_AGEN'] ?? '').toString().trim();

  Future<void> _showAgentDetails(Map<String, dynamic> agent) async {
    final name = (agent['NAMA_AGEN'] ?? '-').toString();
    final officeName = (agent['NAMA_KANTOR'] ?? '').toString().trim();
    final officeCode = (agent['KODE_KANTOR'] ?? '').toString().trim();
    final office = officeName.isNotEmpty
        ? '$officeName${officeCode.isEmpty ? '' : ' ($officeCode)'}'
        : (officeCode.isEmpty ? '-' : officeCode);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          _agentInitials(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PROFIL AGEN',
                              style: TextStyle(
                                color: Color(0xFFDCEBFF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                        onPressed: () => Navigator.pop(dialogContext),
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
                            color: const Color(0xFF15803D)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF15803D)
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.radio_button_checked,
                                size: 16,
                                color: Color(0xFF15803D),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Sedang tracking',
                                style: TextStyle(
                                  color: Color(0xFF15803D),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'INFORMASI AGEN',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _AgentDetailTile(
                          icon: Icons.badge_outlined,
                          label: 'Nomor Agen',
                          value: _agentIdFor(agent),
                        ),
                        _AgentDetailTile(
                          icon: Icons.work_outline,
                          label: 'Jabatan',
                          value: _agentValue(agent['C_AGENCY_JABATAN']),
                        ),
                        _AgentDetailTile(
                          icon: Icons.apartment_rounded,
                          label: 'Kantor',
                          value: office,
                        ),
                        _AgentDetailTile(
                          icon: Icons.location_on_outlined,
                          label: 'Alamat',
                          value: _agentValue(agent['ALAMAT']),
                        ),
                        _AgentDetailTile(
                          icon: Icons.phone_outlined,
                          label: 'Nomor HP',
                          value: _agentValue(agent['NOMOR_HP']),
                        ),
                        _AgentDetailTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _agentValue(
                            agent['A_EMAIL'] ?? agent['EMAIL'],
                          ),
                        ),
                        _AgentDetailTile(
                          icon: Icons.cake_outlined,
                          label: 'Tanggal Lahir',
                          value: _agentValue(agent['TANGGAL_LAHIR']),
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
                    border: Border(top: BorderSide(color: Color(0xFFE8EEF6))),
                  ),
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Tutup'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _agentValue(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? 'Belum tersedia' : text;
  }

  String _agentInitials(Object? value) {
    final name = (value ?? '').toString().trim();
    if (name.isEmpty) return '??';
    return name.characters.take(2).toString().toUpperCase();
  }

  double? _agentCoordinate(Object? value) {
    final coordinate = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim() ?? '');
    return coordinate != null && coordinate.isFinite ? coordinate : null;
  }

  Future<String> _agentLocationAddress(
    double latitude,
    double longitude,
  ) async {
    List<Placemark> placemarks;
    try {
      placemarks = await Geocoding().placemarkFromCoordinates(
        latitude,
        longitude,
      );
    } on PlatformException {
      return 'Alamat belum dapat ditemukan';
    }
    if (placemarks.isEmpty) return 'Alamat belum dapat ditemukan';

    final place = placemarks.first;
    final parts =
        [
              place.street,
              place.subLocality,
              place.locality,
              place.subAdministrativeArea,
              place.administrativeArea,
              place.postalCode,
              place.country,
            ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty);
    final uniqueParts = <String>[];
    for (final part in parts) {
      if (!uniqueParts.any(
        (existing) => existing.toLowerCase() == part.toLowerCase(),
      )) {
        uniqueParts.add(part);
      }
    }
    return uniqueParts.isEmpty
        ? 'Alamat belum dapat ditemukan'
        : uniqueParts.join(', ');
  }

  String _agentLastUpdate(Map<String, dynamic> agent) {
    final value =
        agent['lastUpdated'] ??
        agent['LAST_UPDATE'] ??
        agent['updatedAt'] ??
        agent['timestamp'];
    if (value == null || value.toString().trim().isEmpty) {
      return 'Belum tersedia dari server';
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final local = parsed.toLocal();
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}-${twoDigits(local.month)}-${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
  }

  Future<void> _showAgentLocationDetails(Map<String, dynamic> agent) async {
    final latitude = _agentCoordinate(agent['latitude']);
    final longitude = _agentCoordinate(agent['longitude']);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat lokasi agen belum tersedia.')),
      );
      return;
    }
    final addressFuture = _agentLocationAddress(latitude, longitude);
    final coordinates =
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1B72D7)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DETAIL LOKASI',
                            style: TextStyle(
                              color: Color(0xFFDCEBFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (agent['NAMA_AGEN'] ?? 'Agen').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(18),
                  children: [
                    const Text(
                      'ALAMAT TERDETEKSI',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 9),
                    FutureBuilder<String>(
                      future: addressFuture,
                      builder: (context, snapshot) => Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.map_rounded,
                              color: _primary,
                              size: 21,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? 'Mencari alamat...'
                                    : snapshot.data ??
                                          'Alamat belum dapat ditemukan',
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'INFORMASI TRACKING',
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
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.radio_button_checked_rounded,
                            color: Color(0xFF15803D),
                            size: 21,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Status Agen',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            'Tracking',
                            style: TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _AgentDetailTile(
                      icon: Icons.access_time_rounded,
                      label: 'Update Terakhir',
                      value: _agentLastUpdate(agent),
                    ),
                    if (agent['accuracy'] != null)
                      _AgentDetailTile(
                        icon: Icons.gps_fixed_rounded,
                        label: 'Akurasi',
                        value: '${agent['accuracy']} m',
                      ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EEF6)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F0FF),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.my_location_rounded,
                              color: Color(0xFF1565C0),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Koordinat GPS',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  coordinates,
                                  style: const TextStyle(
                                    color: Color(0xFF14264D),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Salin koordinat',
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: coordinates),
                              );
                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Koordinat berhasil disalin.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: Color(0xFF1565C0),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final address = await addressFuture;
                        if (!dialogContext.mounted) return;
                        if (address.startsWith('Alamat ')) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Alamat belum tersedia untuk disalin.',
                              ),
                            ),
                          );
                          return;
                        }
                        await Clipboard.setData(ClipboardData(text: address));
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Alamat berhasil disalin.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Salin Alamat'),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _openAgentMap(agentId: _agentIdFor(agent));
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Lihat di Peta'),
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

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
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
                        color: Color(0xFF64748B),
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
    if (shouldLogout != true || !mounted) return;

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
        title: const Text(
          'Dashboard Kantor',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
          ),
          IconButton(
            tooltip: 'Muat ulang daftar agen',
            onPressed: _isLoading ? null : _loadAgents,
            icon: const Icon(Icons.refresh_rounded, color: _primary),
          ),
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
          onRefresh: _loadAgents,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), _primary],
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
                                _displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _HeaderInfoRow(
                      icon: Icons.badge_outlined,
                      label: 'ID: $_agentId',
                    ),
                    const SizedBox(height: 9),
                    _HeaderInfoRow(
                      icon: Icons.business_outlined,
                      label:
                          'Kantor: ${_officeName.isEmpty ? (_officeCode.isEmpty ? '-' : _officeCode) : _officeName}',
                    ),
                    const SizedBox(height: 9),
                    _HeaderInfoRow(
                      icon: Icons.work_outline,
                      label: 'Jabatan: ${formatAgencyRole(_agencyRole)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _AgentMetricCard(
                      label: 'Online',
                      value: _onlineAgentCount?.toString() ?? '—',
                      icon: Icons.wifi_rounded,
                      color: const Color(0xFF16A34A),
                      onTap: () => _openAgentList('online'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _AgentMetricCard(
                      label: 'Offline',
                      value: _offlineAgentCount?.toString() ?? '—',
                      icon: Icons.wifi_off_rounded,
                      color: const Color(0xFF64748B),
                      onTap: () => _openAgentList('offline'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _AgentMetricCard(
                      label: 'Total agen',
                      value: _totalAgentCount?.toString() ?? '—',
                      icon: Icons.groups_rounded,
                      color: _primary,
                      onTap: () => _openAgentList('all'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Daftar Agen Online',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Agen $_visibleRolesLabel yang sedang aktif di cabang ini.',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(
                    child: CircularProgressIndicator(color: _primary),
                  ),
                )
              else if (_error != null)
                _StatusCard(
                  icon: Icons.cloud_off_rounded,
                  message: _error!,
                  actionLabel: 'Coba lagi',
                  onPressed: _loadAgents,
                )
              else if (_agents.isEmpty)
                const _StatusCard(
                  icon: Icons.wifi_off_rounded,
                  message: 'Tidak ada agen yang sedang online saat ini.',
                )
              else
                for (final agent in _agents)
                  _AgentCard(
                    agent: agent,
                    onTap: (position) => _showAgentQuickMenu(agent, position),
                  ),
              if (!_isLoading && _error == null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openAgentMap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    backgroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Color(0xFFBBD5F5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.groups_rounded),
                  label: const Text(
                    'Lihat Seluruh Agen',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentMetricCard extends StatelessWidget {
  const _AgentMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.12)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D172033),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent, required this.onTap});

  final Map<String, dynamic> agent;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    final name = (agent['NAMA_AGEN'] ?? 'Nama tidak tersedia').toString();
    final id = (agent['NOMOR_AGEN'] ?? '-').toString();
    final role = (agent['C_AGENCY_JABATAN'] ?? '-').toString();
    final phone = (agent['NOMOR_HP'] ?? '').toString().trim();
    Offset? tapPosition;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => tapPosition = details.globalPosition,
      onTap: () {
        final position = tapPosition;
        if (position != null) onTap(position);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          leading: AgentMarker(name: name, identity: id, isOnline: true),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text('Online · ID: $id${phone.isEmpty ? '' : ' · $phone'}'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              role,
              style: const TextStyle(
                color: Color(0xFF1565C0),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentQuickMenuItem extends StatelessWidget {
  const _AgentQuickMenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.width = 156,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1565C0), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _AgentDetailTile extends StatelessWidget {
  const _AgentDetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F0FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF1565C0), size: 19),
          ),
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
}

class _HeaderInfoRow extends StatelessWidget {
  const _HeaderInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF64748B), size: 32),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onPressed, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
