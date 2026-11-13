import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/gps_tracking_service.dart';
import '../utils/agency_role.dart';
import '../utils/kantor_type.dart';
import '../widgets/agent_marker.dart';
import '../widgets/agent_profile_photo.dart';
import '../widgets/press_bounce.dart';
import 'agent_task.dart';

const _branchMapGradientColors = [Color(0xFF0D47A1), Color(0xFF1565C0)];
const _pageStart = Color(0xFFF8FBFF);
const _pageEnd = Color(0xFFEAF3FF);
const _showCurrentAgentDebugMarker = true;
const _softCardShadow = BoxShadow(
  color: Color(0x260F172A),
  blurRadius: 14,
  offset: Offset(0, 6),
);

enum _AgentMenuAction {
  details,
  location,
  centerAgent,
  locationDetails,
  chat,
  tasks,
}

enum _AgentSortField { name, role }

enum _AgentStatusFilter { all, online, offline }

enum _MapLabelPosition { left, right, above, below }

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
      borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
    ),
  );
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1565C0), size: 18),
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
}

class _AgentMenuItem extends StatelessWidget {
  const _AgentMenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.width = 150,
    this.iconWidget,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final double width;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 46,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Center(
              child:
                  iconWidget ??
                  Icon(icon, color: const Color(0xFF1565C0), size: 18),
            ),
          ),
          const SizedBox(width: 11),
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

class _AgentMarkerTransition {
  const _AgentMarkerTransition({
    required this.agent,
    required this.from,
    required this.to,
    required this.fromScale,
    required this.toScale,
  });

  final Map<String, dynamic> agent;
  final LatLng from;
  final LatLng to;
  final double fromScale;
  final double toScale;
}

class AgentListPage extends StatefulWidget {
  const AgentListPage({super.key});

  @override
  State<AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<AgentListPage>
    with TickerProviderStateMixin {
  final flutter_map.MapController _mapController = flutter_map.MapController();
  final DraggableScrollableController _mapAgentSheetController =
      DraggableScrollableController();
  final ScrollController _pageScrollController = ScrollController();
  final TextEditingController _agentSearchController = TextEditingController();
  final FocusNode _agentSearchFocusNode = FocusNode();
  late final AnimationController _centerAnimationController;
  late final AnimationController _mapAgentSheetAnimationController;
  late final AnimationController _agentMarkerAnimationController;
  late final AnimationController _currentAgentMarkerAnimationController;
  StreamSubscription<Position>? _currentAgentPositionSubscription;
  final Map<String, _AgentMarkerTransition> _agentMarkerTransitions = {};
  LatLng? _currentAgentMarkerFrom;
  LatLng? _currentAgentMarkerTarget;
  Map<String, dynamic>? _currentAgentProfile;
  String? _currentAgentId;
  String? _currentAgentName;
  bool _currentAgentIdentityResolved = false;
  bool _didCenterMapOnCurrentAgent = false;
  LatLng? _animationStartCenter;
  LatLng? _animationTargetCenter;
  double _animationStartZoom = 15;
  double _animationTargetZoom = 16;

  List<Map<String, dynamic>> _agents = [];
  List<Map<String, dynamic>> _agentProfiles = [];
  DateTime? _agentProfilesLoadedAt;
  bool _loading = true;
  bool _isFetchingAgents = false;
  String? _error;
  String? _refreshError;
  Timer? _agentRefreshTimer;
  String? _kantor;
  String? _namaKantor;
  String? _alamatKantor;
  bool _isHeadMarketing = false;
  bool _viewAllBranches = false;
  bool _showIndonesiaMapButton = false;
  bool _mapReady = false;
  bool _canAddTasks = true;
  bool _canManageAgentTasks = true;
  double? _latitude;
  double? _longitude;
  String? _officeGeocodeError;
  Offset? _agentMenuTapPosition;
  bool _initialized = false;
  bool _didFocusRequestedAgent = false;
  String? _focusAgentId;
  String? _selectedMapAgentId;
  String? _lockedAgentId;
  bool _isOfficeInfoSelected = false;
  Map<String, dynamic> _officeData = {};
  bool _showAgentSearch = false;
  String _selectedAgentRole = '';
  _AgentStatusFilter _selectedAgentStatus = _AgentStatusFilter.all;
  _AgentSortField _agentSortField = _AgentSortField.name;
  bool _sortAscending = true;

  Map<String, dynamic>? get _selectedMapAgent {
    final selectedId = _selectedMapAgentId?.trim();
    if (selectedId == null || selectedId.isEmpty) return null;

    for (final agent in _agents) {
      if ((agent['NOMOR_AGEN'] ?? '').toString().trim() == selectedId) {
        return agent;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _visibleAgents {
    final query = _agentSearchController.text.trim().toLowerCase();
    final agents = _agents.where((agent) {
      final role = (agent['C_AGENCY_JABATAN'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      if (_selectedAgentRole.isNotEmpty && role != _selectedAgentRole) {
        return false;
      }

      final isOnline =
          agent['isTracking'] == true || agent['isTracking']?.toString() == '1';
      if (_selectedAgentStatus == _AgentStatusFilter.online && !isOnline) {
        return false;
      }
      if (_selectedAgentStatus == _AgentStatusFilter.offline && isOnline) {
        return false;
      }

      if (query.isEmpty) return true;
      return [
        agent['NAMA_AGEN'],
        agent['NOMOR_AGEN'],
        agent['NOMOR_HP'],
        agent['A_EMAIL'] ?? agent['EMAIL'],
        agent['C_AGENCY_JABATAN'],
      ].any((value) => (value ?? '').toString().toLowerCase().contains(query));
    }).toList();

    agents.sort((left, right) {
      final leftOnline = left['isTracking'] == true;
      final rightOnline = right['isTracking'] == true;
      if (leftOnline != rightOnline) return leftOnline ? -1 : 1;

      final leftValue = _agentSortField == _AgentSortField.name
          ? left['NAMA_AGEN']
          : left['C_AGENCY_JABATAN'];
      final rightValue = _agentSortField == _AgentSortField.name
          ? right['NAMA_AGEN']
          : right['C_AGENCY_JABATAN'];
      final comparison = (leftValue ?? '').toString().toLowerCase().compareTo(
        (rightValue ?? '').toString().toLowerCase(),
      );
      if (comparison == 0) {
        return (left['NAMA_AGEN'] ?? '').toString().toLowerCase().compareTo(
          (right['NAMA_AGEN'] ?? '').toString().toLowerCase(),
        );
      }
      return _sortAscending ? comparison : -comparison;
    });
    return agents;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    _resolveCurrentAgentIdentity(arguments);
    if (arguments is Map) {
      final appRole = (arguments['APP_ROLE'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final levelUser = (arguments['LEVEL_USER'] ?? '').toString().trim();
      final agencyRole = (arguments['C_AGENCY_JABATAN'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      _isHeadMarketing =
          appRole == 'HEAD_MARKETING' || agencyRole == 'KD' || levelUser == '1';
      _viewAllBranches =
          arguments['VIEW_ALL_BRANCHES'] == true && _isHeadMarketing;
      _showIndonesiaMapButton = arguments['SHOW_INDONESIA_MAP_BUTTON'] == true;
      _canAddTasks =
          !_isHeadMarketing &&
          appRole != 'HEAD_AGENT' &&
          !['AD', 'AM', 'AS'].contains(agencyRole);
      _canManageAgentTasks =
          !_isHeadMarketing && !['AD', 'AM', 'AS'].contains(agencyRole);
      _kantor = _viewAllBranches
          ? null
          : arguments['KODE_KANTOR']?.toString().trim();
      final officeData = arguments['DATA_KANTOR'];
      if (officeData is Map) {
        _officeData = Map<String, dynamic>.from(officeData);
      }
      _namaKantor = arguments['NAMA_KANTOR']?.toString().trim();
      _alamatKantor = arguments['ALAMAT_KANTOR']?.toString().trim();
      _latitude = _viewAllBranches
          ? null
          : _parseCoordinate(arguments['LATITUDE']);
      _longitude = _viewAllBranches
          ? null
          : _parseCoordinate(arguments['LONGITUDE']);
      _focusAgentId = arguments['FOCUS_AGENT_ID']?.toString().trim();
      _selectedAgentStatus = switch (arguments['INITIAL_STATUS_FILTER']
          ?.toString()
          .trim()
          .toLowerCase()) {
        'online' => _AgentStatusFilter.online,
        'offline' => _AgentStatusFilter.offline,
        _ => _AgentStatusFilter.all,
      };
      if (!_viewAllBranches && !_hasValidCoordinates) {
        unawaited(_geocodeOfficeAddress());
      }
    } else if (arguments is String) {
      _kantor = arguments.trim();
    }

    if ((_kantor == null || _kantor!.isEmpty) && !_isHeadMarketing) return;
    _loadAgents();
    _agentRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_loadAgents(showLoading: false)),
    );
  }

  @override
  void initState() {
    super.initState();
    _centerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(_updateMapCenterAnimation);
    _mapAgentSheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _currentAgentMarkerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addListener(_onCurrentAgentMarkerAnimationTick);
    _agentMarkerAnimationController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 850),
          )
          ..addListener(_onAgentMarkerAnimationTick)
          ..addStatusListener(_onAgentMarkerAnimationStatusChanged);
    if (_showCurrentAgentDebugMarker) {
      final trackingService = AgentGpsTrackingService.instance;
      final latestPosition = trackingService.latestPosition;
      if (latestPosition != null) {
        _updateCurrentAgentMarkerPosition(latestPosition);
      }
      _currentAgentPositionSubscription = trackingService.positions.listen(
        _updateCurrentAgentMarkerPosition,
      );
    }
  }

  void _onCurrentAgentMarkerAnimationTick() {
    _followLockedAgent();
    if (mounted) setState(() {});
  }

  void _resolveCurrentAgentIdentity(Object? arguments) {
    if (_currentAgentIdentityResolved) return;
    _currentAgentIdentityResolved = true;

    if (arguments is Map) {
      final user = Map<String, dynamic>.from(arguments);
      _setCurrentAgentIdentity(user);
    }

    if (_currentAgentId == null) {
      unawaited(_loadCurrentAgentIdentity());
    }
  }

  void _setCurrentAgentIdentity(Map<String, dynamic> user) {
    final id =
        (user['I_AGEN'] ??
                user['NOMOR_AGEN'] ??
                user['STAMBUK'] ??
                user['stambuk'] ??
                '')
            .toString()
            .trim();
    if (id.isEmpty || id == '-') return;

    _currentAgentId = id;
    _currentAgentName = (user['NAMA_AGEN'] ?? user['NAMA'] ?? user['nama'])
        ?.toString()
        .trim();
    _currentAgentProfile = user;
    final trackingService = AgentGpsTrackingService.instance;
    final latestPosition = trackingService.isTracking
        ? trackingService.latestPosition
        : null;
    if (latestPosition != null) {
      _updateCurrentAgentMarkerPosition(latestPosition);
    }
  }

  Future<void> _loadCurrentAgentIdentity() async {
    try {
      final user = await ApiService.getCurrentUser();
      if (!mounted) return;
      _setCurrentAgentIdentity(user);
      final profile = _currentAgentProfile;
      final trackingService = AgentGpsTrackingService.instance;
      final currentPosition = trackingService.isTracking
          ? trackingService.latestPosition
          : null;
      if (profile != null && currentPosition == null) {
        Map<String, dynamic>? serverAgent;
        for (final agent in _agents) {
          if (_agentId(agent)?.toUpperCase() ==
              _currentAgentId?.toUpperCase()) {
            serverAgent = agent;
            break;
          }
        }
        final coordinates = serverAgent == null
            ? null
            : _agentCoordinates(serverAgent);
        if (coordinates != null) {
          _setCurrentAgentMarkerTarget(coordinates, serverAgent!);
        }
      }
    } catch (error) {
      debugPrint(
        'Gagal mendapatkan identitas agen untuk marker sementara: $error',
      );
    }
  }

  String? _agentId(Map<String, dynamic> agent) {
    final id =
        (agent['NOMOR_AGEN'] ??
                agent['I_AGEN'] ??
                agent['STAMBUK'] ??
                agent['stambuk'])
            ?.toString()
            .trim();
    return id == null || id.isEmpty ? null : id;
  }

  void _updateCurrentAgentMarkerPosition(Position position) {
    if (!_showCurrentAgentDebugMarker ||
        !AgentGpsTrackingService.instance.isTracking ||
        _currentAgentId == null ||
        !_isValidCurrentAgentPosition(position)) {
      return;
    }
    _setCurrentAgentMarkerTarget(
      LatLng(position.latitude, position.longitude),
      {
        ...?_currentAgentProfile,
        'NOMOR_AGEN': _currentAgentId,
        'NAMA_AGEN': _currentAgentName ?? 'Agen saya',
        'isTracking': true,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'lastUpdated': position.timestamp.toIso8601String(),
      },
    );
  }

  bool _isValidCurrentAgentPosition(Position position) =>
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      position.latitude >= -90 &&
      position.latitude <= 90 &&
      position.longitude >= -180 &&
      position.longitude <= 180 &&
      position.accuracy.isFinite &&
      position.accuracy >= 0 &&
      position.accuracy <= 50;

  void _setCurrentAgentMarkerTarget(
    LatLng target,
    Map<String, dynamic> profile,
  ) {
    final previousProfile = _currentAgentProfile;
    _currentAgentProfile = profile;
    _currentAgentName ??=
        (profile['NAMA_AGEN'] ?? profile['NAMA'] ?? profile['nama'])
            ?.toString()
            .trim();
    final previousTarget = _currentAgentMarkerTarget;
    if (previousTarget == null) {
      _currentAgentMarkerFrom = target;
      _currentAgentMarkerTarget = target;
      _centerMapOnCurrentAgentOnce();
      if (mounted) setState(() {});
      return;
    }
    if (previousTarget.latitude == target.latitude &&
        previousTarget.longitude == target.longitude) {
      if (mounted && previousProfile?['isTracking'] != profile['isTracking']) {
        setState(() {});
      }
      return;
    }

    final progress = Curves.easeInOutCubic.transform(
      _currentAgentMarkerAnimationController.value,
    );
    final from = LatLng(
      _currentAgentMarkerFrom!.latitude +
          (previousTarget.latitude - _currentAgentMarkerFrom!.latitude) *
              progress,
      _currentAgentMarkerFrom!.longitude +
          (previousTarget.longitude - _currentAgentMarkerFrom!.longitude) *
              progress,
    );
    _currentAgentMarkerFrom = from;
    _currentAgentMarkerTarget = target;
    _currentAgentMarkerAnimationController.forward(from: 0);
  }

  void _centerMapOnCurrentAgentOnce() {
    final target = _currentAgentMarkerTarget;
    if (!_showCurrentAgentDebugMarker ||
        _didCenterMapOnCurrentAgent ||
        !_mapReady ||
        target == null) {
      return;
    }

    _didCenterMapOnCurrentAgent = true;
    _animationStartCenter = _mapController.camera.center;
    _animationTargetCenter = target;
    _animationStartZoom = _mapController.camera.zoom;
    _animationTargetZoom = 16;
    _centerAnimationController.forward(from: 0);
  }

  flutter_map.Marker? _currentAgentMarker() {
    if (!_showCurrentAgentDebugMarker ||
        _currentAgentId == null ||
        _currentAgentMarkerFrom == null ||
        _currentAgentMarkerTarget == null) {
      return null;
    }

    final isOnline =
        _currentAgentProfile?['isTracking'] == true ||
        _currentAgentProfile?['isTracking']?.toString() == '1';
    if (_selectedAgentStatus == _AgentStatusFilter.online && !isOnline ||
        _selectedAgentStatus == _AgentStatusFilter.offline && isOnline) {
      return null;
    }

    final progress = Curves.easeInOutCubic.transform(
      _currentAgentMarkerAnimationController.value,
    );
    final from = _currentAgentMarkerFrom!;
    final target = _currentAgentMarkerTarget!;
    final location = LatLng(
      from.latitude + (target.latitude - from.latitude) * progress,
      from.longitude + (target.longitude - from.longitude) * progress,
    );
    final name = _currentAgentName ?? 'Agen saya';

    return flutter_map.Marker(
      point: location,
      width: 200,
      height: 100,
      child: _buildMapMarkerWithLabel(
        identity: _currentAgentId,
        label: 'SAYA - $name',
        preferredPosition: _MapLabelPosition.above,
        marker: Transform.scale(
          scale: 1.15,
          child: AgentMarker(
            name: 'Saya',
            identity: _currentAgentId,
            isOnline: isOnline,
            offlineColor: const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _onAgentMarkerAnimationTick() {
    _followLockedAgent();
    if (mounted) setState(() {});
  }

  void _onAgentMarkerAnimationStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final removed = _agentMarkerTransitions.entries
        .where((entry) => entry.value.toScale < 1)
        .map((entry) => entry.key)
        .toList();
    if (removed.isEmpty) return;
    for (final key in removed) {
      _agentMarkerTransitions.remove(key);
    }
    if (mounted) setState(() {});
  }

  void _reconcileAgentMarkers(List<Map<String, dynamic>> agents) {
    final rawProgress = _agentMarkerAnimationController.value;
    final progress = Curves.easeInOutCubic.transform(rawProgress);
    final targets = <String, MapEntry<Map<String, dynamic>, LatLng>>{};
    for (final agent in agents) {
      final location = _agentCoordinates(agent);
      if (location == null) continue;
      final id = (agent['NOMOR_AGEN'] ?? agent['I_AGEN'] ?? agent['NAMA_AGEN'])
          .toString()
          .trim();
      if (id.isEmpty) continue;
      if (_showCurrentAgentDebugMarker &&
          _currentAgentId != null &&
          id.toUpperCase() == _currentAgentId!.toUpperCase()) {
        final trackingService = AgentGpsTrackingService.instance;
        if (!trackingService.isTracking ||
            trackingService.latestPosition == null) {
          _setCurrentAgentMarkerTarget(location, agent);
        }
        continue;
      }
      targets[id] = MapEntry(agent, location);
    }

    final keys = {..._agentMarkerTransitions.keys, ...targets.keys};
    final next = <String, _AgentMarkerTransition>{};
    var changed = false;
    for (final key in keys) {
      final existing = _agentMarkerTransitions[key];
      final target = targets[key];
      if (existing != null &&
          target != null &&
          existing.toScale == 1 &&
          existing.to.latitude == target.value.latitude &&
          existing.to.longitude == target.value.longitude) {
        next[key] = _AgentMarkerTransition(
          agent: target.key,
          from: existing.from,
          to: existing.to,
          fromScale: existing.fromScale,
          toScale: existing.toScale,
        );
        continue;
      }

      final currentPoint = existing == null
          ? target!.value
          : LatLng(
              existing.from.latitude +
                  (existing.to.latitude - existing.from.latitude) * progress,
              existing.from.longitude +
                  (existing.to.longitude - existing.from.longitude) * progress,
            );
      final currentScale = existing == null
          ? 0.72
          : _agentMarkerScale(existing, rawProgress);
      final destination = target?.value ?? currentPoint;
      final destinationScale = target == null ? 0.72 : 1.0;
      final updated = _AgentMarkerTransition(
        agent: target?.key ?? existing!.agent,
        from: currentPoint,
        to: destination,
        fromScale: currentScale,
        toScale: destinationScale,
      );
      next[key] = updated;
      if (currentPoint != destination || currentScale != destinationScale) {
        changed = true;
      }
    }

    _agentMarkerTransitions
      ..clear()
      ..addAll(next);
    if (changed) _agentMarkerAnimationController.forward(from: 0);
  }

  String? _agentMarkerId(Map<String, dynamic> agent) {
    final id = (agent['NOMOR_AGEN'] ?? agent['I_AGEN'] ?? agent['NAMA_AGEN'])
        ?.toString()
        .trim();
    return id == null || id.isEmpty ? null : id;
  }

  LatLng? _lockedAgentLocation() {
    final lockedId = _lockedAgentId?.toUpperCase();
    if (lockedId == null) return null;

    if (_currentAgentId?.toUpperCase() == lockedId &&
        _currentAgentMarkerFrom != null &&
        _currentAgentMarkerTarget != null) {
      final progress = Curves.easeInOutCubic.transform(
        _currentAgentMarkerAnimationController.value,
      );
      final from = _currentAgentMarkerFrom!;
      final target = _currentAgentMarkerTarget!;
      return LatLng(
        from.latitude + (target.latitude - from.latitude) * progress,
        from.longitude + (target.longitude - from.longitude) * progress,
      );
    }

    final progress = Curves.easeInOutCubic.transform(
      _agentMarkerAnimationController.value,
    );
    for (final entry in _agentMarkerTransitions.entries) {
      if (entry.key.toUpperCase() != lockedId) continue;
      final transition = entry.value;
      return LatLng(
        transition.from.latitude +
            (transition.to.latitude - transition.from.latitude) * progress,
        transition.from.longitude +
            (transition.to.longitude - transition.from.longitude) * progress,
      );
    }

    for (final agent in _agents) {
      if (_agentMarkerId(agent)?.toUpperCase() == lockedId) {
        return _agentCoordinates(agent);
      }
    }
    return null;
  }

  void _followLockedAgent() {
    if (!_mapReady ||
        _lockedAgentId == null ||
        _centerAnimationController.isAnimating) {
      return;
    }
    final location = _lockedAgentLocation();
    if (location != null) {
      _mapController.move(location, _mapController.camera.zoom);
    }
  }

  void _onMapPositionChanged(flutter_map.MapCamera camera, bool hasGesture) {
    if (!hasGesture || _lockedAgentId == null) return;
    _lockedAgentId = null;
    _centerAnimationController.stop();
  }

  double _agentMarkerScale(_AgentMarkerTransition transition, double progress) {
    final curve = transition.toScale > transition.fromScale
        ? Curves.easeOutBack
        : Curves.easeInBack;
    final curvedProgress = curve.transform(progress);
    return transition.fromScale +
        (transition.toScale - transition.fromScale) * curvedProgress;
  }

  void _selectMapAgent(String agentId) {
    final wasClosed = _selectedMapAgentId == null;
    setState(() {
      _isOfficeInfoSelected = false;
      _selectedMapAgentId = agentId;
    });
    if (wasClosed) {
      _mapAgentSheetAnimationController.forward(from: 0);
    } else if (_mapAgentSheetAnimationController.isAnimating &&
        _mapAgentSheetAnimationController.status == AnimationStatus.reverse) {
      _mapAgentSheetAnimationController.forward();
    }
  }

  void _selectOfficeOnMap() {
    final wasClosed = _selectedMapAgentId == null && !_isOfficeInfoSelected;
    setState(() {
      _selectedMapAgentId = null;
      _isOfficeInfoSelected = true;
    });
    if (wasClosed) {
      _mapAgentSheetAnimationController.forward(from: 0);
    } else if (_mapAgentSheetAnimationController.isAnimating &&
        _mapAgentSheetAnimationController.status == AnimationStatus.reverse) {
      _mapAgentSheetAnimationController.forward();
    }
  }

  Future<void> _closeMapAgentSheet() async {
    await _mapAgentSheetAnimationController.reverse();
    if (!mounted) return;
    setState(() {
      _selectedMapAgentId = null;
      _isOfficeInfoSelected = false;
    });
  }

  void _updateMapCenterAnimation() {
    final start = _animationStartCenter;
    final target = _lockedAgentLocation() ?? _animationTargetCenter;
    if (start == null || target == null) return;

    final progress = Curves.easeInOutCubic.transform(
      _centerAnimationController.value,
    );
    final center = LatLng(
      start.latitude + (target.latitude - start.latitude) * progress,
      start.longitude + (target.longitude - start.longitude) * progress,
    );
    final zoom =
        _animationStartZoom +
        (_animationTargetZoom - _animationStartZoom) * progress;
    _mapController.move(center, zoom);
  }

  double? _parseCoordinate(Object? value) {
    final coordinate = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim() ?? '');
    return coordinate != null && coordinate.isFinite ? coordinate : null;
  }

  bool get _hasValidCoordinates {
    final latitude = _latitude;
    final longitude = _longitude;
    return latitude != null &&
        longitude != null &&
        !(latitude == 0 && longitude == 0) &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  LatLng get _initialMapCenter {
    if (_hasValidCoordinates) return LatLng(_latitude!, _longitude!);
    return const LatLng(-2.5, 118);
  }

  void _recenterMap() {
    if (!_mapReady || !_hasValidCoordinates) return;
    _lockedAgentId = null;
    _animationStartCenter = _mapController.camera.center;
    _animationTargetCenter = LatLng(_latitude!, _longitude!);
    _animationStartZoom = _mapController.camera.zoom;
    _animationTargetZoom = 16;
    _centerAnimationController.forward(from: 0);
  }

  void _centerIndonesiaMap() {
    if (!_mapReady) return;
    _lockedAgentId = null;
    _animationStartCenter = _mapController.camera.center;
    _animationTargetCenter = _initialMapCenter;
    _animationStartZoom = _mapController.camera.zoom;
    _animationTargetZoom = 4.2;
    _centerAnimationController.forward(from: 0);
  }

  void _onMapReady() {
    _mapReady = true;
    if (_showCurrentAgentDebugMarker && _currentAgentMarkerTarget != null) {
      _centerMapOnCurrentAgentOnce();
    } else {
      _recenterMap();
    }
  }

  Future<void> _geocodeOfficeAddress() async {
    final address = _alamatKantor?.trim();
    if (address == null || address.isEmpty || address == '-') {
      if (mounted) {
        setState(() => _officeGeocodeError = 'Alamat kantor belum tersedia.');
      }
      return;
    }

    try {
      final locations = await Geocoding().locationFromAddress(address);
      if (locations.isEmpty) {
        throw Exception('Alamat kantor tidak ditemukan.');
      }

      final location = locations.first;
      if (!location.latitude.isFinite ||
          !location.longitude.isFinite ||
          location.latitude < -90 ||
          location.latitude > 90 ||
          location.longitude < -180 ||
          location.longitude > 180) {
        throw Exception('Koordinat hasil pencarian alamat tidak valid.');
      }

      if (!mounted) return;
      setState(() {
        _latitude = location.latitude;
        _longitude = location.longitude;
        _officeGeocodeError = null;
      });
      _recenterMap();
    } catch (error) {
      debugPrint('Geocoding alamat kantor gagal: $error');
      if (!mounted) return;
      setState(() {
        _officeGeocodeError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  LatLng? _agentCoordinates(Map<String, dynamic> agent) {
    final latitude = _parseCoordinate(agent['latitude'] ?? agent['LATITUDE']);
    final longitude = _parseCoordinate(
      agent['longitude'] ?? agent['LONGITUDE'],
    );
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  List<flutter_map.Marker> _agentMarkers() {
    final rawProgress = _agentMarkerAnimationController.value;
    final progress = Curves.easeInOutCubic.transform(rawProgress);
    return _agentMarkerTransitions.entries
        .where((entry) {
          final agent = entry.value.agent;
          final agentId = _agentId(agent);
          if (_showCurrentAgentDebugMarker &&
              _currentAgentId != null &&
              agentId?.toUpperCase() == _currentAgentId!.toUpperCase()) {
            return false;
          }
          final isOnline =
              agent['isTracking'] == true ||
              agent['isTracking']?.toString() == '1';
          return switch (_selectedAgentStatus) {
            _AgentStatusFilter.online => isOnline,
            _AgentStatusFilter.offline => !isOnline,
            _AgentStatusFilter.all => true,
          };
        })
        .map((entry) {
          final transition = entry.value;
          final agent = transition.agent;
          final location = LatLng(
            transition.from.latitude +
                (transition.to.latitude - transition.from.latitude) * progress,
            transition.from.longitude +
                (transition.to.longitude - transition.from.longitude) *
                    progress,
          );
          final scale = _agentMarkerScale(transition, rawProgress);
          final name = (agent['NAMA_AGEN'] ?? 'Agen').toString();
          final isOnline =
              agent['isTracking'] == true ||
              agent['isTracking']?.toString() == '1';
          final agentId = agent['NOMOR_AGEN'] ?? agent['I_AGEN'];
          return flutter_map.Marker(
            point: location,
            width: 200,
            height: 100,
            child: Transform.scale(
              scale: scale,
              child: _buildMapMarkerWithLabel(
                identity: agentId,
                label: name,
                onTap: transition.toScale < 1
                    ? null
                    : () => _selectMapAgent((agentId ?? '').toString()),
                marker: AgentMarker(
                  name: name,
                  identity: agentId,
                  isOnline: isOnline,
                  offlineColor: const Color(0xFF64748B),
                ),
              ),
            ),
          );
        })
        .toList();
  }

  List<flutter_map.Marker> _currentAgentMarkers() {
    final marker = _currentAgentMarker();
    return marker == null ? const [] : [marker];
  }

  Widget _buildMapMarkerWithLabel({
    required Object? identity,
    required String label,
    required Widget marker,
    VoidCallback? onTap,
    _MapLabelPosition? preferredPosition,
  }) {
    final key = (identity ?? label).toString().trim().toUpperCase();
    var hash = 0;
    for (final codeUnit in key.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
    }
    final position = preferredPosition ?? _MapLabelPosition.values[hash % 4];

    final labelWidget = Container(
      width:
          position == _MapLabelPosition.above ||
              position == _MapLabelPosition.below
          ? 128
          : 84,
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE8F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget clickable(Widget child) =>
        onTap == null ? child : PressBounce(onTap: onTap, child: child);

    return SizedBox(
      width: 200,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          clickable(marker),
          if (position == _MapLabelPosition.left)
            Positioned(left: -8, child: clickable(labelWidget))
          else if (position == _MapLabelPosition.right)
            Positioned(right: -8, child: clickable(labelWidget))
          else if (position == _MapLabelPosition.above)
            Positioned(top: -4, child: clickable(labelWidget))
          else
            Positioned(bottom: -4, child: clickable(labelWidget)),
        ],
      ),
    );
  }

  Widget _buildMapAgentSheet(
    Map<String, dynamic> agent, {
    required double availableHeight,
  }) {
    final name = (agent['NAMA_AGEN'] ?? '-').toString().trim();
    final agentNumber = (agent['NOMOR_AGEN'] ?? '-').toString().trim();
    final role = formatAgencyRole(
      (agent['C_AGENCY_JABATAN'] ?? '-').toString(),
    );
    final office = (agent['NAMA_KANTOR'] ?? agent['KODE_KANTOR'] ?? '-')
        .toString()
        .trim();
    final phone = _agentPhoneNumber(agent);
    final email = (agent['A_EMAIL'] ?? agent['EMAIL'] ?? '').toString().trim();
    final address = (agent['ALAMAT'] ?? '').toString().trim();
    final isOnline =
        agent['isTracking'] == true || agent['isTracking']?.toString() == '1';

    final optionalInfoCount = [
      phone,
      email,
      address,
    ].where((value) => value.isNotEmpty).length;
    final minSheetSize =
        ((176 + MediaQuery.paddingOf(context).bottom) / availableHeight)
            .clamp(0.16, 0.48)
            .toDouble();
    final middleSheetSize = (0.43 + optionalInfoCount * 0.035)
        .clamp(minSheetSize + 0.06, 0.58)
        .toDouble();

    return DraggableScrollableSheet(
      controller: _mapAgentSheetController,
      initialChildSize: middleSheetSize,
      minChildSize: minSheetSize,
      maxChildSize: 1,
      expand: true,
      snap: true,
      snapSizes: [minSheetSize, middleSheetSize, 1],
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    if (!_mapAgentSheetController.isAttached) return;
                    final nextSize =
                        _mapAgentSheetController.size -
                        details.delta.dy / availableHeight;
                    _mapAgentSheetController.jumpTo(
                      nextSize.clamp(minSheetSize, 1).toDouble(),
                    );
                  },
                  onVerticalDragEnd: (_) {
                    if (!_mapAgentSheetController.isAttached) return;
                    final snapPoints = [minSheetSize, middleSheetSize, 1.0];
                    final currentSize = _mapAgentSheetController.size;
                    final nearestSnap = snapPoints.reduce(
                      (nearest, point) =>
                          (point - currentSize).abs() <
                              (nearest - currentSize).abs()
                          ? point
                          : nearest,
                    );
                    _mapAgentSheetController.animateTo(
                      nearestSnap,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 20,
                    alignment: Alignment.center,
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  AgentMarker(
                    name: name.isEmpty || name == '-' ? 'Agen' : name,
                    identity: agentNumber,
                    isOnline: isOnline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name.isEmpty ? 'Detail Agen' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF14264D),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: _closeMapAgentSheet,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline
                            ? const Color(0xFF15803D)
                            : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ID: $agentNumber',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (phone.isNotEmpty) ...[
                      _buildMapAgentChatButton(phone),
                      const SizedBox(width: 8),
                    ],
                    FilledButton.icon(
                      onPressed: () => _showAgentLocation(agent),
                      icon: const Icon(Icons.my_location_rounded, size: 17),
                      label: const Text('Pusatkan'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(112, 42),
                        backgroundColor: const Color(0xFF1565C0)
                            .withValues(alpha: 0.14),
                        foregroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showAgentDetails(agent),
                      icon: const Icon(Icons.badge_outlined, size: 17),
                      label: const Text('Detail Agen'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        backgroundColor: const Color(0xFF1565C0)
                            .withValues(alpha: 0.14),
                        foregroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showAgentLocationDetails(agent),
                      icon: const Icon(Icons.location_on_outlined, size: 17),
                      label: const Text('Detail Lokasi'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        backgroundColor: const Color(0xFF1565C0)
                            .withValues(alpha: 0.14),
                        foregroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _openAgentTasks(agent),
                      icon: const Icon(Icons.checklist_rounded, size: 17),
                      label: const Text('Tugas Agen'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        backgroundColor: const Color(0xFF1565C0)
                            .withValues(alpha: 0.14),
                        foregroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 4),
              _buildMapAgentInfoRow(
                icon: Icons.work_outline_rounded,
                label: 'Jabatan',
                value: role,
              ),
              _buildMapAgentInfoRow(
                icon: Icons.location_city_outlined,
                label: 'Cabang',
                value: office,
              ),
              if (phone.isNotEmpty)
                _buildMapAgentInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Nomor telepon',
                  value: phone,
                ),
              if (email.isNotEmpty)
                _buildMapAgentInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                ),
              _buildMapAgentInfoRow(
                icon: Icons.update_rounded,
                label: 'Terakhir Online',
                value: _agentLastUpdateText(agent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapOfficeSheet({required double availableHeight}) {
    final officeData = <String, dynamic>{
      ..._officeData,
      'KODE_KANTOR': _officeData['KODE_KANTOR'] ?? _kantor,
      'NAMA_KANTOR': _officeData['NAMA_KANTOR'] ?? _namaKantor,
      'ALAMAT_KANTOR': _officeData['ALAMAT_KANTOR'] ?? _alamatKantor,
      'LATITUDE': _officeData['LATITUDE'] ?? _latitude,
      'LONGITUDE': _officeData['LONGITUDE'] ?? _longitude,
    };
    final fields = officeData.entries.toList();
    final officeName = (_officeData['NAMA_KANTOR'] ?? _namaKantor ?? 'Kantor')
        .toString()
        .trim();
    final minSheetSize =
        ((188 + MediaQuery.paddingOf(context).bottom) / availableHeight)
            .clamp(0.16, 0.48)
            .toDouble();
    final middleSheetSize = (0.42 + fields.length * 0.025)
        .clamp(minSheetSize + 0.06, 0.68)
        .toDouble();

    return DraggableScrollableSheet(
      controller: _mapAgentSheetController,
      initialChildSize: middleSheetSize,
      minChildSize: minSheetSize,
      maxChildSize: 1,
      expand: true,
      snap: true,
      snapSizes: [minSheetSize, middleSheetSize, 1],
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              _buildMapSheetDragHandle(
                availableHeight: availableHeight,
                minSheetSize: minSheetSize,
                middleSheetSize: middleSheetSize,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      officeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF14264D),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: _closeMapAgentSheet,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _recenterMap,
                icon: const Icon(Icons.my_location_rounded, size: 17),
                label: const Text('Pusatkan'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(112, 42),
                  backgroundColor: const Color(0xFF1565C0)
                      .withValues(alpha: 0.14),
                  foregroundColor: const Color(0xFF0D47A1),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 4),
              if (fields.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Informasi kantor belum tersedia.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              else
                for (final entry in fields)
                  _buildMapAgentInfoRow(
                    icon: _officeInfoIcon(entry.key),
                    label: entry.key
                        .replaceAll('_', ' ')
                        .toLowerCase()
                        .split(' ')
                        .map(
                          (word) => word.isEmpty
                              ? word
                              : '${word[0].toUpperCase()}${word.substring(1)}',
                        )
                        .join(' '),
                    value:
                        entry.key == 'KODE_JENIS_KANTOR' &&
                            entry.value != null &&
                            entry.value.toString().trim().isNotEmpty
                        ? '${entry.value} (${jenisKantorLabel(entry.value)})'
                        : entry.value == null ||
                              entry.value.toString().trim().isEmpty
                        ? '-'
                        : entry.value is Map || entry.value is List
                        ? jsonEncode(entry.value)
                        : entry.value.toString(),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _officeInfoIcon(String fieldName) {
    switch (fieldName.toUpperCase()) {
      case 'KODE_KANTOR':
      case 'NOMOR_KANTOR':
        return Icons.tag_rounded;
      case 'NAMA_KANTOR':
        return Icons.business_rounded;
      case 'ALAMAT_KANTOR':
      case 'ALAMAT_KANTOR_MUTASI':
        return Icons.location_on_outlined;
      case 'KODE_JENIS_KANTOR':
        return Icons.category_outlined;
      case 'LATITUDE':
      case 'LONGITUDE':
        return Icons.map_outlined;
      case 'EMAIL':
        return Icons.email_outlined;
      case 'TELEPON':
      case 'NOMOR_TELEPON':
      case 'NO_TELEPON':
        return Icons.phone_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildMapSheetDragHandle({
    required double availableHeight,
    required double minSheetSize,
    required double middleSheetSize,
  }) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          if (!_mapAgentSheetController.isAttached) return;
          final nextSize =
              _mapAgentSheetController.size -
              details.delta.dy / availableHeight;
          _mapAgentSheetController.jumpTo(
            nextSize.clamp(minSheetSize, 1).toDouble(),
          );
        },
        onVerticalDragEnd: (_) {
          if (!_mapAgentSheetController.isAttached) return;
          final snapPoints = [minSheetSize, middleSheetSize, 1.0];
          final currentSize = _mapAgentSheetController.size;
          final nearestSnap = snapPoints.reduce(
            (nearest, point) =>
                (point - currentSize).abs() < (nearest - currentSize).abs()
                ? point
                : nearest,
          );
          _mapAgentSheetController.animateTo(
            nearestSnap,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        },
        child: Container(
          width: 48,
          height: 20,
          alignment: Alignment.center,
          child: Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapAgentChatButton(String phone) {
    return SizedBox(
      height: 42,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openWhatsAppChat(phone),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF17BE65), Color(0xFF25D366)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Colors.white,
                  size: 17,
                ),
                SizedBox(width: 7),
                Text(
                  'Chat Agen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsAppChat(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp agen belum tersedia.')),
      );
      return;
    }

    final whatsappNumber = digits.startsWith('0')
        ? '62${digits.substring(1)}'
        : digits.startsWith('8')
        ? '62$digits'
        : digits;
    final whatsappUri = Uri.https('wa.me', '/$whatsappNumber');

    try {
      final launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('WhatsApp tidak dapat dibuka pada perangkat ini.');
      }
    } catch (error) {
      debugPrint('Gagal membuka chat WhatsApp agen: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  String _agentPhoneNumber(Map<String, dynamic> agent) {
    for (final value in [agent['NOMOR_HP'], agent['I_TELEPON_HP']]) {
      final phone = (value ?? '').toString().trim();
      if (phone.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty) return phone;
    }
    return '';
  }

  Widget _buildMapAgentInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAgentMenu(
    BuildContext context,
    Map<String, dynamic> agent,
    Offset tapPosition,
  ) async {
    final screenSize = MediaQuery.sizeOf(context);
    const horizontalPadding = 8.0;
    const menuGap = 8.0;
    const menuMargin = 8.0;
    final hasLocation = _agentCoordinates(agent) != null;
    final phone = _agentPhoneNumber(agent);
    final menuWidth = ((screenSize.width - horizontalPadding * 2 - menuGap) / 2)
        .clamp(112.0, 166.0);
    final itemWidth = menuWidth - horizontalPadding * 2;
    final menuHeight = (hasLocation ? 248.0 : 200.0) - (phone.isEmpty ? 48 : 0);

    final requestedLeft = tapPosition.dx < screenSize.width / 2
        ? tapPosition.dx
        : tapPosition.dx - menuWidth;
    final initialLeft = requestedLeft.clamp(
      menuMargin,
      screenSize.width - menuWidth - menuMargin,
    );
    final canOpenRight =
        initialLeft + menuWidth + menuGap + menuWidth <=
        screenSize.width - menuMargin;
    final canOpenLeft = initialLeft - menuGap - menuWidth >= menuMargin;
    final opensSubmenuRight =
        canOpenRight ||
        (!canOpenLeft &&
            tapPosition.dx + menuWidth + menuGap + menuWidth <=
                screenSize.width - menuMargin);
    final menuGroupLeft = opensSubmenuRight
        ? initialLeft.clamp(
            menuMargin,
            screenSize.width - menuWidth * 2 - menuGap - menuMargin,
          )
        : (initialLeft - menuWidth - menuGap).clamp(
            menuMargin,
            screenSize.width - menuWidth * 2 - menuGap - menuMargin,
          );
    final primaryLeft = opensSubmenuRight
        ? menuGroupLeft
        : menuGroupLeft + menuWidth + menuGap;
    final primaryTop =
        (tapPosition.dy < screenSize.height / 2
                ? tapPosition.dy
                : tapPosition.dy - menuHeight)
            .clamp(menuMargin, screenSize.height - menuHeight - menuMargin);
    final primaryAnchorX = primaryLeft + menuWidth / 2 < screenSize.width / 2
        ? primaryLeft
        : primaryLeft + menuWidth;
    final primaryAnchorY = primaryTop + menuHeight / 2 < screenSize.height / 2
        ? primaryTop
        : primaryTop + menuHeight;

    final action = await showMenu<_AgentMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        primaryAnchorX,
        primaryAnchorY,
        screenSize.width - primaryAnchorX,
        screenSize.height - primaryAnchorY,
      ),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x260F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      items: [
        PopupMenuItem(
          value: _AgentMenuAction.details,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _AgentMenuItem(
            icon: Icons.badge_outlined,
            label: 'Detail Agen',
            width: itemWidth,
          ),
        ),
        if (hasLocation)
          PopupMenuItem(
            value: _AgentMenuAction.location,
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: IconTheme(
              data: const IconThemeData(opacity: 1),
              child: InkWell(
                onTap: () async {
                  await _showAgentLocationSubmenu(
                    context: context,
                    agent: agent,
                    screenSize: screenSize,
                    primaryLeft: primaryLeft,
                    primaryTop: primaryTop,
                    menuWidth: menuWidth,
                    menuGap: menuGap,
                    menuMargin: menuMargin,
                    opensSubmenuRight: opensSubmenuRight,
                    itemWidth: itemWidth,
                  );
                },
                child: _AgentMenuItem(
                  icon: Icons.location_on_outlined,
                  label: 'Lokasi Agen',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  width: itemWidth,
                ),
              ),
            ),
          ),
        if (phone.isNotEmpty)
          PopupMenuItem(
            value: _AgentMenuAction.chat,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _AgentMenuItem(
              icon: Icons.chat_rounded,
              iconWidget: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 18,
              ),
              label: 'Chat Agen',
              width: itemWidth,
            ),
          ),
        PopupMenuItem(
          value: _AgentMenuAction.tasks,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _AgentMenuItem(
            icon: Icons.checklist_rounded,
            label: 'Tugas Agen',
            width: itemWidth,
          ),
        ),
      ],
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case _AgentMenuAction.details:
        await _showAgentDetails(agent);
      case _AgentMenuAction.location:
        break;
      case _AgentMenuAction.centerAgent:
        await _showAgentLocation(agent);
      case _AgentMenuAction.locationDetails:
        await _showAgentLocationDetails(agent);
        break;
      case _AgentMenuAction.chat:
        await _openWhatsAppChat(phone);
      case _AgentMenuAction.tasks:
        await _openAgentTasks(agent);
    }
  }

  Future<void> _openAgentTasks(Map<String, dynamic> agent) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentTaskPage(
          agent: agent,
          canManageTasks: _canManageAgentTasks,
          canAddTasks: _canAddTasks,
        ),
      ),
    );
  }

  Future<void> _showAgentLocationSubmenu({
    required BuildContext context,
    required Map<String, dynamic> agent,
    required Size screenSize,
    required double primaryLeft,
    required double primaryTop,
    required double menuWidth,
    required double menuGap,
    required double menuMargin,
    required bool opensSubmenuRight,
    required double itemWidth,
  }) async {
    final submenuLeft = opensSubmenuRight
        ? primaryLeft + menuWidth + menuGap
        : primaryLeft - menuGap - menuWidth;
    const submenuHeight = 108.0;
    final submenuTop = (primaryTop + 60).clamp(
      menuMargin,
      screenSize.height - submenuHeight - menuMargin,
    );
    final submenuAnchorX = submenuLeft + menuWidth / 2 < screenSize.width / 2
        ? submenuLeft
        : submenuLeft + menuWidth;
    final submenuAnchorY =
        submenuTop + submenuHeight / 2 < screenSize.height / 2
        ? submenuTop
        : submenuTop + submenuHeight;
    final action = await showMenu<_AgentMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        submenuAnchorX,
        submenuAnchorY,
        screenSize.width - submenuAnchorX,
        screenSize.height - submenuAnchorY,
      ),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x260F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      items: [
        PopupMenuItem(
          value: _AgentMenuAction.centerAgent,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _AgentMenuItem(
            icon: Icons.my_location_rounded,
            label: 'Pusatkan',
            width: itemWidth,
          ),
        ),
        PopupMenuItem(
          value: _AgentMenuAction.locationDetails,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _AgentMenuItem(
            icon: Icons.info_outline_rounded,
            label: 'Detail Lokasi',
            width: itemWidth,
          ),
        ),
      ],
    );
    if (!context.mounted) return;

    // The submenu route closes first; pop its parent menu afterward so both
    // menus disappear together when the user taps outside or picks an action.
    Navigator.of(context).pop();
    if (action == null || !context.mounted) return;

    switch (action) {
      case _AgentMenuAction.centerAgent:
        await _showAgentLocation(agent);
      case _AgentMenuAction.locationDetails:
        await _showAgentLocationDetails(agent);
      case _AgentMenuAction.details:
      case _AgentMenuAction.location:
      case _AgentMenuAction.chat:
      case _AgentMenuAction.tasks:
        break;
    }
  }

  Future<void> _showAgentDetails(Map<String, dynamic> agent) {
    final name = (agent['NAMA_AGEN'] ?? '-').toString();
    final agentId = (agent['NOMOR_AGEN'] ?? agent['I_AGEN'] ?? '')
        .toString()
        .trim();
    final photoFuture = agentId.isEmpty
        ? Future<Uint8List?>.value()
        : ApiService.getAgentProfilePhoto(agentId);
    final agentNumber = (agent['NOMOR_AGEN'] ?? '-').toString();
    final namaKantor = (agent['NAMA_KANTOR'] ?? '').toString().trim();
    final kodeKantor = (agent['KODE_KANTOR'] ?? '').toString().trim();
    final kantor = namaKantor.isNotEmpty
        ? (kodeKantor.isNotEmpty ? '$namaKantor - ($kodeKantor)' : namaKantor)
        : (kodeKantor.isNotEmpty ? kodeKantor : '-');
    final tracking = agent['isTracking'] == true;
    final alamat = (agent['ALAMAT'] ?? 'Belum tersedia').toString().trim();
    final email = (agent['A_EMAIL'] ?? agent['EMAIL'] ?? 'Belum tersedia')
        .toString()
        .trim();
    final phone = (agent['NOMOR_HP'] ?? 'Belum tersedia').toString().trim();
    final jabatan = formatAgencyRole(
      (agent['C_AGENCY_JABATAN'] ?? 'Belum tersedia').toString(),
    );
    final tanggalLahir = (agent['TANGGAL_LAHIR'] ?? 'Belum tersedia')
        .toString()
        .trim();
    // final tanggalLisensi = (agent['TANGGAL_LISENSI'] ?? 'Belum tersedia')
    //     .toString()
    //     .trim();
    final statusColor = tracking
        ? const Color(0xFF15803D)
        : const Color(0xFF64748B);

    return showDialog<void>(
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
                      FutureBuilder<Uint8List?>(
                        future: photoFuture,
                        builder: (context, snapshot) {
                          final photo = snapshot.data;
                          return AgentProfilePhoto(
                            photoBytes: photo,
                            size: 54,
                            circleThumbnail: true,
                            semanticLabel: 'Perbesar foto profil $name',
                            placeholder: Text(
                              _agentInitials(name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
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
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tracking
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 16,
                                color: statusColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tracking ? 'Sedang tracking' : 'Offline',
                                style: TextStyle(
                                  color: statusColor,
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
                        _agentDetailTile(
                          icon: Icons.badge_outlined,
                          label: 'Nomor Agen',
                          value: agentNumber,
                        ),
                        _agentDetailTile(
                          icon: Icons.work_outline,
                          label: 'Jabatan',
                          value: jabatan,
                        ),
                        _agentDetailTile(
                          icon: Icons.apartment_rounded,
                          label: 'Kantor',
                          value: kantor,
                        ),
                        _agentDetailTile(
                          icon: Icons.location_on_outlined,
                          label: 'Alamat',
                          value: alamat.isEmpty ? 'Belum tersedia' : alamat,
                        ),
                        _agentDetailTile(
                          icon: Icons.phone_outlined,
                          label: 'Nomor HP',
                          value: phone.isEmpty ? 'Belum tersedia' : phone,
                        ),
                        _agentDetailTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: email.isEmpty ? 'Belum tersedia' : email,
                        ),
                        _agentDetailTile(
                          icon: Icons.cake_outlined,
                          label: 'Tanggal Lahir',
                          value: tanggalLahir,
                        ),
                        // _agentDetailTile(
                        //   icon: Icons.verified_outlined,
                        //   label: 'Tanggal Lisensi',
                        //   value: tanggalLisensi,
                        // ),
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

  Future<String> _reverseGeocode(LatLng location) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isEmpty) {
        return 'Alamat belum dapat ditemukan';
      }

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
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();

      // Hilangkan komponen alamat yang duplikat.
      final uniqueParts = <String>[];
      for (final part in parts) {
        if (!uniqueParts.any(
          (existing) => existing.toLowerCase() == part.toLowerCase(),
        )) {
          uniqueParts.add(part);
        }
      }

      if (uniqueParts.isEmpty) {
        return 'Alamat belum dapat ditemukan';
      }

      return uniqueParts.join(', ');
    } catch (e) {
      debugPrint('Reverse geocoding gagal: $e');
      return 'Alamat tidak dapat ditemukan saat ini';
    }
  }

  String _agentLastUpdateText(Map<String, dynamic> agent) {
    // Sesuaikan nama field jika API menggunakan nama lain.
    final candidates = [
      'lastUpdated',
      'LAST_UPDATED',
      'LAST_UPDATE',
      'last_update',
      'UPDATED_AT',
      'updated_at',
      'updatedAt',
      'WAKTU_UPDATE',
      'TGL_UPDATE',
      'TGL_TRACKING',
      'timestamp',
      'TIMESTAMP',
    ];

    Object? rawValue;

    for (final key in candidates) {
      final value = agent[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        rawValue = value;
        break;
      }
    }

    if (rawValue == null) {
      return 'Belum tersedia dari server';
    }

    DateTime? date;

    if (rawValue is DateTime) {
      date = rawValue;
    } else if (rawValue is num) {
      // Mendukung timestamp Unix dalam detik atau milidetik.
      final value = rawValue.toInt();
      date = DateTime.fromMillisecondsSinceEpoch(
        value.abs() < 100000000000 ? value * 1000 : value,
      );
    } else {
      date = DateTime.tryParse(rawValue.toString().trim());
    }

    if (date == null) {
      return rawValue.toString();
    }

    date = date.toLocal();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}-${twoDigits(date.month)}-${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}:${twoDigits(date.second)}';
  }

  Future<void> _showAgentLocationDetails(Map<String, dynamic> agent) async {
    final location = _agentCoordinates(agent);

    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat lokasi agen belum tersedia.')),
      );
      return;
    }

    final isTracking = agent['isTracking'] == true;
    final addressFuture = _reverseGeocode(location);
    final timestamp = _agentLastUpdateText(agent);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
                  // HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
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
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DETAIL LOKASI',
                                style: TextStyle(
                                  color: Color(0xFFDCEBFF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Lokasi Agen',
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
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // ISI DIALOG
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ALAMAT TERDETEKSI',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Alamat hasil reverse geocoding.
                          FutureBuilder<String>(
                            future: addressFuture,
                            builder: (context, snapshot) {
                              final loading =
                                  snapshot.connectionState ==
                                  ConnectionState.waiting;

                              final address =
                                  snapshot.data ??
                                  'Alamat belum dapat ditemukan';

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF3FF),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: const Color(0xFFD5E5FA),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.map_rounded,
                                      color: Color(0xFF1565C0),
                                      size: 23,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: loading
                                          ? const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 4,
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 17,
                                                    height: 17,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      'Mencari alamat...',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF475569,
                                                        ),
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Text(
                                              address,
                                              style: const TextStyle(
                                                color: Color(0xFF14264D),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                height: 1.5,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

                          // Status tracking.
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: isTracking
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isTracking
                                    ? const Color(0xFFBBF7D0)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isTracking
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isTracking
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF64748B),
                                  size: 21,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
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
                                  isTracking ? 'Tracking' : 'Offline',
                                  style: TextStyle(
                                    color: isTracking
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF64748B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          _agentDetailTile(
                            icon: Icons.access_time_rounded,
                            label: 'Terakhir Online',
                            value: timestamp,
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
                              border: Border.all(
                                color: const Color(0xFFE8EEF6),
                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        '${location.latitude.toStringAsFixed(6)}, '
                                        '${location.longitude.toStringAsFixed(6)}',
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
                                    final coordinates =
                                        '${location.latitude.toStringAsFixed(6)}, '
                                        '${location.longitude.toStringAsFixed(6)}';

                                    await Clipboard.setData(
                                      ClipboardData(text: coordinates),
                                    );

                                    if (!dialogContext.mounted) return;

                                    ScaffoldMessenger.of(dialogContext)
                                        .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Koordinat berhasil disalin.',
                                            ),
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

                          const SizedBox(height: 6),

                          // Tombol salin alamat.
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final address = await addressFuture;

                                if (!dialogContext.mounted) return;

                                if (address.startsWith('Alamat ')) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Alamat belum tersedia untuk disalin.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                await Clipboard.setData(
                                  ClipboardData(text: address),
                                );

                                if (!dialogContext.mounted) return;

                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text('Alamat berhasil disalin.'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Salin Alamat'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1565C0),
                                side: const BorderSide(
                                  color: Color(0xFF1565C0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Pusatkan peta ke agen.
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton.icon(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                await _showAgentLocation(agent);
                              },
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Lihat di Peta'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _agentDetailTile({
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

  Future<void> _showAgentLocation(Map<String, dynamic> agent) async {
    final location = _agentCoordinates(agent);
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lokasi agen belum tersedia atau belum aktif tracking.',
          ),
        ),
      );
      return;
    }

    if (_pageScrollController.hasClients) {
      await _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted) return;

    _lockedAgentId = _agentMarkerId(agent);
    _animationStartCenter = _mapController.camera.center;
    _animationTargetCenter = location;
    _animationStartZoom = _mapController.camera.zoom;
    _animationTargetZoom = 16;
    _centerAnimationController.forward(from: 0);
  }

  String _agentInitials(Object? value) {
    final name = (value ?? '').toString().trim();
    if (name.isEmpty) return '??';
    return name.characters.take(2).toString().toUpperCase();
  }

  Future<void> _loadAgents({bool showLoading = true}) async {
    if ((_kantor == null || _kantor!.isEmpty) && !_isHeadMarketing) return;
    if (_isFetchingAgents) return;
    _isFetchingAgents = true;

    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final shouldRefreshProfiles =
          showLoading ||
          _agentProfilesLoadedAt == null ||
          DateTime.now().difference(_agentProfilesLoadedAt!) >=
              const Duration(minutes: 1);
      final trackingFuture = ApiService.getAgents();
      final profileFuture = shouldRefreshProfiles
          ? ApiService.getAgentList(kantor: _kantor)
          : null;
      final trackingResult = await trackingFuture;
      final profileResult = profileFuture == null ? null : await profileFuture;

      if (profileResult != null) {
        final profileData = profileResult['data'];
        if (profileData is! Map || profileData['success'] != true) {
          throw Exception(
            profileData is Map
                ? profileData['message']?.toString() ??
                      'Gagal memuat daftar agen.'
                : 'Format respons server tidak valid.',
          );
        }

        final rawProfiles = profileData['data'];
        if (rawProfiles is! List) {
          throw Exception('Data agen dari server tidak valid.');
        }
        _agentProfiles = rawProfiles
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _agentProfilesLoadedAt = DateTime.now();
      }

      final profileRows = _agentProfiles;
      final trackingData = trackingResult['data'];
      if (trackingData is! Map || trackingData['success'] != true) {
        throw Exception(
          trackingData is Map
              ? trackingData['message']?.toString() ??
                    'Gagal memuat data tracking agen.'
              : 'Format respons tracking server tidak valid.',
        );
      }

      final trackingRows = trackingData['data'];
      if (trackingRows is! List) {
        throw Exception('Data tracking agen dari server tidak valid.');
      }

      final trackingByAgent = <String, Map<String, dynamic>>{};
      for (final item in trackingRows.whereType<Map>()) {
        final tracking = Map<String, dynamic>.from(item);
        final agentId =
            (tracking['stambuk'] ??
                    tracking['I_AGEN'] ??
                    tracking['NOMOR_AGEN'] ??
                    '')
                .toString()
                .trim();
        if (agentId.isNotEmpty) {
          trackingByAgent[agentId.toUpperCase()] = tracking;
        }
      }

      final agents = profileRows.whereType<Map>().map((item) {
        final profile = Map<String, dynamic>.from(item);
        final agentId = (profile['NOMOR_AGEN'] ?? '').toString().trim();
        final tracking = trackingByAgent[agentId.toUpperCase()];
        final trackingStatus = tracking?['status']?.toString().toLowerCase();
        final isTracking = tracking == null
            ? false
            : tracking['isTracking'] is bool
            ? tracking['isTracking'] == true
            : trackingStatus != 'offline';
        return {
          ...profile,
          if (tracking != null) ...{
            'latitude': tracking['latitude'],
            'longitude': tracking['longitude'],
            'accuracy': tracking['accuracy'],
            'speed': tracking['speed'],
            'lastUpdated': tracking['lastUpdated'],
          },
          'isTracking': isTracking,
        };
      }).toList();
      if (!mounted) return;

      setState(() {
        _agents = agents;
        _loading = false;
        _error = null;
        _refreshError = null;
      });
      _reconcileAgentMarkers(agents);
      if (_focusAgentId != null &&
          _focusAgentId!.isNotEmpty &&
          !_didFocusRequestedAgent) {
        _didFocusRequestedAgent = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final requestedId = _focusAgentId!.toUpperCase();
          Map<String, dynamic>? requestedAgent;
          for (final agent in _agents) {
            final agentId = (agent['NOMOR_AGEN'] ?? agent['I_AGEN'] ?? '')
                .toString()
                .trim()
                .toUpperCase();
            if (agentId == requestedId) {
              requestedAgent = agent;
              break;
            }
          }
          if (requestedAgent == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Agen tersebut tidak ditemukan di daftar cabang.',
                ),
              ),
            );
            return;
          }
          unawaited(_showAgentLocation(requestedAgent));
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        final message = e.toString().replaceFirst('Exception: ', '');
        if (showLoading || _agents.isEmpty) {
          _error = message;
        } else {
          _refreshError = message;
        }
      });
    } finally {
      _isFetchingAgents = false;
    }
  }

  Future<void> _showAgentFilters() async {
    var selectedRole = _selectedAgentRole;
    var selectedStatus = _selectedAgentStatus;
    var sortField = _agentSortField;
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
                                'Atur daftar agen sesuai kebutuhan',
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
                          const _FilterSectionLabel(
                            icon: Icons.work_outline_rounded,
                            title: 'Jabatan agen',
                          ),
                          const SizedBox(height: 9),
                          DropdownButtonFormField<String>(
                            initialValue: selectedRole,
                            decoration: _filterInputDecoration(
                              hint: 'Pilih jabatan',
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF1565C0),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: '',
                                child: Text('Semua jabatan'),
                              ),
                              DropdownMenuItem(value: 'AD', child: Text('AD')),
                              DropdownMenuItem(value: 'AM', child: Text('AM')),
                              DropdownMenuItem(value: 'AS', child: Text('AS')),
                              DropdownMenuItem(value: 'WA', child: Text('WA')),
                            ],
                            onChanged: (value) =>
                                setSheetState(() => selectedRole = value ?? ''),
                          ),
                          const SizedBox(height: 18),
                          const _FilterSectionLabel(
                            icon: Icons.wifi_tethering_rounded,
                            title: 'Status agen',
                          ),
                          const SizedBox(height: 9),
                          DropdownButtonFormField<_AgentStatusFilter>(
                            initialValue: selectedStatus,
                            decoration: _filterInputDecoration(
                              hint: 'Pilih status',
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF1565C0),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: _AgentStatusFilter.all,
                                child: Text('Semua status'),
                              ),
                              DropdownMenuItem(
                                value: _AgentStatusFilter.online,
                                child: Text('Online'),
                              ),
                              DropdownMenuItem(
                                value: _AgentStatusFilter.offline,
                                child: Text('Offline'),
                              ),
                            ],
                            onChanged: (value) => setSheetState(
                              () => selectedStatus =
                                  value ?? _AgentStatusFilter.all,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _FilterSectionLabel(
                            icon: Icons.sort_by_alpha_rounded,
                            title: 'Urutkan daftar',
                          ),
                          const SizedBox(height: 9),
                          DropdownButtonFormField<_AgentSortField>(
                            initialValue: sortField,
                            decoration: _filterInputDecoration(
                              hint: 'Urutkan berdasarkan',
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF1565C0),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: _AgentSortField.name,
                                child: Text('Nama agen'),
                              ),
                              DropdownMenuItem(
                                value: _AgentSortField.role,
                                child: Text('Jabatan'),
                              ),
                            ],
                            onChanged: (value) => setSheetState(
                              () => sortField = value ?? _AgentSortField.name,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _FilterSectionLabel(
                            icon: Icons.swap_vert_rounded,
                            title: 'Urutan abjad',
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
                                      _selectedAgentRole = '';
                                      _selectedAgentStatus =
                                          _AgentStatusFilter.all;
                                      _agentSortField = _AgentSortField.name;
                                      _sortAscending = true;
                                      _agentSearchController.clear();
                                      _showAgentSearch = false;
                                    });
                                    Navigator.pop(sheetContext);
                                  },
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text('Reset'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1565C0),
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
                                        _selectedAgentRole = selectedRole;
                                        _selectedAgentStatus = selectedStatus;
                                        _agentSortField = sortField;
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

  @override
  void dispose() {
    _agentRefreshTimer?.cancel();
    unawaited(_currentAgentPositionSubscription?.cancel());
    _agentSearchController.dispose();
    _agentSearchFocusNode.dispose();
    _pageScrollController.dispose();
    _centerAnimationController.dispose();
    _mapAgentSheetAnimationController.dispose();
    _agentMarkerAnimationController.dispose();
    _currentAgentMarkerAnimationController.dispose();
    _mapAgentSheetController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Widget _buildBranchHero() {
    final address = _alamatKantor;
    final isAllBranchesView =
        _isHeadMarketing && (_kantor == null || _kantor!.isEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F8)),
        boxShadow: const [_softCardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_city_rounded,
                color: Color(0xFF0D47A1),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAllBranchesView
                      ? 'Pantauan Lokasi Agen'
                      : _namaKantor ?? 'Lokasi Kantor',
                  style: const TextStyle(
                    color: Color(0xFF14264D),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (isAllBranchesView) ...[
            const SizedBox(height: 6),
            const Text(
              'Memantau lokasi agen dari seluruh cabang.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              address,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
          if (_officeGeocodeError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB91C1C),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Koordinat kantor belum tersedia: $_officeGeocodeError',
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _geocodeOfficeAddress,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ],
          if (_refreshError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Lokasi terakhir tetap ditampilkan; gagal memperbarui: '
              '$_refreshError',
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 280,
              child: Stack(
                children: [
                  flutter_map.FlutterMap(
                    mapController: _mapController,
                    options: flutter_map.MapOptions(
                      initialCenter: _initialMapCenter,
                      initialZoom: _hasValidCoordinates ? 15 : 4.2,
                      onMapReady: _onMapReady,
                      onPositionChanged: _onMapPositionChanged,
                    ),
                    children: [
                      flutter_map.TileLayer(
                        urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName:
                            'com.devasatrio.bi_cabang_tracker',
                      ),
                      flutter_map.MarkerLayer(
                        markers: [
                          if (_hasValidCoordinates)
                            flutter_map.Marker(
                              point: LatLng(_latitude!, _longitude!),
                              width: 200,
                              height: 100,
                              child: _buildMapMarkerWithLabel(
                                identity: _kantor ?? _namaKantor,
                                label: _namaKantor ?? 'Kantor',
                                onTap: _selectOfficeOnMap,
                                preferredPosition: _MapLabelPosition.above,
                                marker: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: _branchMapGradientColors,
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1565C0)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    shadcn.LucideIcons.mapPin,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ..._agentMarkers(),
                          ..._currentAgentMarkers(),
                        ],
                      ),
                      if (_showIndonesiaMapButton)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Material(
                            color: Colors.white,
                            elevation: 4,
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Tampilkan seluruh Indonesia',
                              onPressed: _centerIndonesiaMap,
                              icon: const Icon(
                                Icons.zoom_out_map_rounded,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_hasValidCoordinates)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Material(
                        color: Colors.white,
                        elevation: 4,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Pusatkan ke lokasi kantor',
                          onPressed: _recenterMap,
                          icon: const Icon(
                            Icons.my_location_rounded,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentSummary() {
    final onlineCount = _agents
        .where((agent) => agent['isTracking'] == true)
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildAgentSummaryItem(
            icon: Icons.groups_rounded,
            label: 'Agen Terdaftar',
            value: _agents.length,
            color: const Color(0xFF1565C0),
            backgroundColor: const Color(0xFFEAF3FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAgentSummaryItem(
            icon: Icons.wifi_tethering_rounded,
            label: 'Agen Online',
            value: onlineCount,
            color: const Color(0xFF15803D),
            backgroundColor: const Color(0xFFDCFCE7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAgentSummaryItem(
            icon: Icons.wifi_tethering_off_rounded,
            label: 'Agen Offline',
            value: _agents.length - onlineCount,
            color: const Color.fromARGB(255, 102, 102, 102),
            backgroundColor: const Color.fromARGB(59, 175, 175, 175),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentSummaryItem({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFDCE8F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
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

  @override
  Widget build(BuildContext context) {
    final visibleAgents = _visibleAgents;
    final selectedMapAgent = _selectedMapAgent;
    final showMapInfoSheet = selectedMapAgent != null || _isOfficeInfoSelected;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          _namaKantor == null || _namaKantor!.isEmpty
              ? _isHeadMarketing
                    ? 'Daftar Seluruh Agen'
                    : 'Daftar Agen'
              : 'Agen - $_namaKantor',
        ),
        actions: [
          if ((_kantor != null && _kantor!.isNotEmpty) || _isHeadMarketing)
            IconButton(
              onPressed: _loadAgents,
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh),
            ),
          const SizedBox(width: 10),
        ],
      ),
      backgroundColor: _pageStart,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if ((_kantor == null || _kantor!.isEmpty) && !_isHeadMarketing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Pilih cabang terlebih dahulu untuk melihat daftar agen.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _loadAgents,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_pageStart, _pageEnd],
                  ),
                ),
                child: ListView(
                  controller: _pageScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if ((_kantor != null && _kantor!.isNotEmpty) ||
                        _isHeadMarketing) ...[
                      _buildBranchHero(),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Daftar Agen',
                            style: TextStyle(
                              color: Color(0xFF14264D),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _showAgentSearch
                              ? 'Tutup pencarian'
                              : 'Cari agen',
                          onPressed: () {
                            final showSearch = !_showAgentSearch;
                            setState(() {
                              _showAgentSearch = showSearch;
                              if (!_showAgentSearch) {
                                _agentSearchController.clear();
                              }
                            });
                            if (showSearch) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && _showAgentSearch) {
                                  _agentSearchFocusNode.requestFocus();
                                }
                              });
                            } else {
                              _agentSearchFocusNode.unfocus();
                            }
                          },
                          icon: Icon(
                            _showAgentSearch
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Filter dan urutkan',
                          onPressed: _showAgentFilters,
                          icon: Icon(
                            Icons.tune_rounded,
                            color:
                                _selectedAgentRole.isNotEmpty ||
                                    _selectedAgentStatus !=
                                        _AgentStatusFilter.all ||
                                    _agentSortField != _AgentSortField.name ||
                                    !_sortAscending
                                ? const Color(0xFF1565C0)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (!_loading && _error == null) ...[
                      _buildAgentSummary(),
                      const SizedBox(height: 10),
                    ],
                    if (_showAgentSearch) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _agentSearchController,
                        focusNode: _agentSearchFocusNode,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Cari nama, ID, nomor telepon, email...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _agentSearchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Hapus pencarian',
                                  onPressed: () {
                                    _agentSearchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF1565C0),
                              width: 2,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFD5E5FA),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFD5E5FA),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 42,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadAgents,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    else if (_agents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Belum ada data agen.')),
                      )
                    else if (visibleAgents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Tidak ada agen yang cocok dengan pencarian atau filter.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      for (final agent in visibleAgents) ...[
                        _buildAgentCard(agent),
                        if (agent != visibleAgents.last)
                          const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            ),
          if (showMapInfoSheet)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) => AnimatedBuilder(
                  animation: _mapAgentSheetAnimationController,
                  child: selectedMapAgent != null
                      ? _buildMapAgentSheet(
                          selectedMapAgent,
                          availableHeight: constraints.maxHeight,
                        )
                      : _buildMapOfficeSheet(
                          availableHeight: constraints.maxHeight,
                        ),
                  builder: (context, child) {
                    final progress = Curves.easeOutCubic.transform(
                      _mapAgentSheetAnimationController.value,
                    );
                    return Transform.translate(
                      offset: Offset(0, constraints.maxHeight * (1 - progress)),
                      child: Opacity(opacity: progress, child: child),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final name = (agent['NAMA_AGEN'] ?? '-').toString();
    final agentNumber = (agent['NOMOR_AGEN'] ?? '-').toString();
    final tracking = agent['isTracking'] == true;
    final role = (agent['C_AGENCY_JABATAN'] ?? '-').toString();
    final phone = (agent['NOMOR_HP'] ?? '').toString().trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _agentMenuTapPosition = details.globalPosition,
      onTap: () {
        final tapPosition = _agentMenuTapPosition;
        if (tapPosition != null) {
          _showAgentMenu(context, agent, tapPosition);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [_softCardShadow],
        ),
        child: Card(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            minVerticalPadding: 12,
            titleAlignment: ListTileTitleAlignment.center,
            leading: SizedBox(
              width: 48,
              height: 56,
              child: Center(
                child: AgentMarker(
                  name: name,
                  identity: agentNumber,
                  isOnline: tracking,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tracking
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        tracking ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: tracking
                              ? const Color(0xFF15803D)
                              : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(
                    text:
                        ' · ID: $agentNumber${phone.isEmpty ? '' : ' · $phone'}',
                  ),
                ],
              ),
            ),
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
      ),
    );
  }
}
