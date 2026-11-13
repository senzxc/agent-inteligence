import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../utils/kantor_type.dart';
import '../widgets/press_bounce.dart';

enum _KantorSortField { name, type }

const _officeDetailFields = [
  'NOMOR_KANTOR',
  'NAMA_KANTOR',
  'KODE_JENIS_KANTOR',
  'KODE_KANTOR',
  'ALAMAT_KANTOR_MUTASI',
  'LATITUDE',
  'LONGITUDE',
];

const Color _pageTop = Color(0xFFF8FBFF);
const Color _pageBottom = Color(0xFFEAF3FF);
const Color _brandBlue = Color(0xFF1565C0);
const Color _ink = Color(0xFF172033);
const Color _muted = Color(0xFF718096);
const BoxShadow _cardShadow = BoxShadow(
  color: Color(0x180F172A),
  blurRadius: 18,
  offset: Offset(0, 7),
);

class _OfficeLabelPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.3,
        size.width / 2,
        size.height,
      )
      ..quadraticBezierTo(size.width * 0.28, size.height * 0.3, 0, 0)
      ..close();
    canvas.drawShadow(path, const Color(0x55334155), 3, true);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xEEF1F3F5)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _OfficeLabelPointerPainter oldDelegate) => false;
}

class _OfficeMarkerTransition {
  const _OfficeMarkerTransition({
    required this.office,
    required this.from,
    required this.to,
    required this.fromScale,
    required this.toScale,
  });

  final Map<String, dynamic> office;
  final LatLng from;
  final LatLng to;
  final double fromScale;
  final double toScale;
}

class KantorListPage extends StatefulWidget {
  const KantorListPage({super.key, this.showMiniMap = false});

  final bool showMiniMap;

  @override
  State<KantorListPage> createState() => _KantorListPageState();
}

class _KantorListPageState extends State<KantorListPage>
    with TickerProviderStateMixin {
  final flutter_map.MapController _mapController = flutter_map.MapController();
  final DraggableScrollableController _officeSheetController =
      DraggableScrollableController();
  late final AnimationController _officeSheetAnimationController;
  late final AnimationController _mapCenterAnimationController;
  late final AnimationController _officeMarkerAnimationController;
  final Map<String, _OfficeMarkerTransition> _officeMarkerTransitions = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _kantorList = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _mapReady = false;
  bool _mapLabelRefreshScheduled = false;
  Map<String, dynamic>? _selectedOffice;
  Map<String, dynamic>? _officeSheetOffice;
  int _officeSheetAnimationId = 0;
  bool _isGeocodingOffices = false;
  bool _geocodingUnavailable = false;
  int _geocodingProgress = 0;
  int _geocodingTotal = 0;
  int _geocodingErrorCount = 0;
  int _geocodeBatchId = 0;
  bool _searchFocused = false;
  String _searchQuery = '';
  String _selectedKantorType = '';
  _KantorSortField _sortField = _KantorSortField.name;
  bool _sortAscending = true;
  LatLng? _animationStartCenter;
  LatLng? _animationTargetCenter;
  double _animationStartZoom = 4.2;
  double _animationTargetZoom = 13;

  @override
  void initState() {
    super.initState();
    _officeSheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _mapCenterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_updateMapCenterAnimation);
    _officeMarkerAnimationController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 850),
          )
          ..addListener(_onOfficeMarkerAnimationTick)
          ..addStatusListener(_onOfficeMarkerAnimationStatusChanged);
    _loadKantor();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
    _searchController.addListener(() {
      if (mounted) setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _mapCenterAnimationController.dispose();
    _officeMarkerAnimationController.dispose();
    _officeSheetAnimationController.dispose();
    _officeSheetController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onOfficeMarkerAnimationTick() {
    if (mounted) setState(() {});
  }

  void _onOfficeMarkerAnimationStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final removed = _officeMarkerTransitions.entries
        .where((entry) => entry.value.toScale < 1)
        .map((entry) => entry.key)
        .toList();
    if (removed.isEmpty) return;
    for (final key in removed) {
      _officeMarkerTransitions.remove(key);
    }
    if (mounted) setState(() {});
  }

  void _reconcileOfficeMarkers(List<Map<String, dynamic>> offices) {
    if (!widget.showMiniMap) return;
    final rawProgress = _officeMarkerAnimationController.value;
    final progress = Curves.easeInOutCubic.transform(rawProgress);
    final targets = <String, MapEntry<Map<String, dynamic>, LatLng>>{};
    for (final office in offices) {
      final location = _coordinatesFor(office);
      if (location == null) continue;
      final id = (office['KODE_KANTOR'] ?? office['NAMA_KANTOR'])
          .toString()
          .trim();
      if (id.isEmpty) continue;
      targets[id] = MapEntry(office, location);
    }

    final keys = {..._officeMarkerTransitions.keys, ...targets.keys};
    final next = <String, _OfficeMarkerTransition>{};
    var changed = false;
    for (final key in keys) {
      final existing = _officeMarkerTransitions[key];
      final target = targets[key];
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
          : _officeMarkerScale(existing, rawProgress);
      final destination = target?.value ?? currentPoint;
      final destinationScale = target == null ? 0.72 : 1.0;
      next[key] = _OfficeMarkerTransition(
        office: target?.key ?? existing!.office,
        from: currentPoint,
        to: destination,
        fromScale: currentScale,
        toScale: destinationScale,
      );
      if (currentPoint != destination || currentScale != destinationScale) {
        changed = true;
      }
    }

    _officeMarkerTransitions
      ..clear()
      ..addAll(next);
    if (changed) _officeMarkerAnimationController.forward(from: 0);
  }

  double _officeMarkerScale(
    _OfficeMarkerTransition transition,
    double progress,
  ) {
    final curve = transition.toScale > transition.fromScale
        ? Curves.easeOutBack
        : Curves.easeInBack;
    final curvedProgress = curve.transform(progress);
    return transition.fromScale +
        (transition.toScale - transition.fromScale) * curvedProgress;
  }

  Future<void> _loadKantor() async {
    _geocodeBatchId++;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final result = await ApiService.getKantor();
      final data = result['data'];
      if (result['statusCode'] == 200 &&
          data is Map<String, dynamic> &&
          data['success'] == true &&
          data['data'] is List) {
        final rows = (data['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (!mounted) return;
        setState(() {
          _kantorList = rows;
          _isLoading = false;
        });
        _reconcileOfficeMarkers(rows);
        if (_mapReady) _fitMapToOffices();
        if (widget.showMiniMap) {
          unawaited(_geocodeMissingOfficeLocations());
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredKantor {
    final query = _searchQuery.toLowerCase();
    final terms = query.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final results = _kantorList.where((kantor) {
      final typeCode = kantor['KODE_JENIS_KANTOR']?.toString().trim() ?? '';
      if (_selectedKantorType.isNotEmpty && typeCode != _selectedKantorType) {
        return false;
      }

      final searchable = [
        kantor['KODE_KANTOR'],
        kantor['NAMA_KANTOR'],
        kantor['ALAMAT_KANTOR_MUTASI'] ?? kantor['ALAMAT_KANTOR'],
        kantor['EMAIL'],
        kantor['KET_KANTOR'],
        jenisKantorLabel(typeCode),
        kantor['ZONA'],
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
      return terms.every(searchable.contains);
    }).toList();

    results.sort((left, right) {
      if (_sortField == _KantorSortField.type) {
        final leftType = int.tryParse(
          left['KODE_JENIS_KANTOR']?.toString().trim() ?? '',
        );
        final rightType = int.tryParse(
          right['KODE_JENIS_KANTOR']?.toString().trim() ?? '',
        );
        if (leftType == null || rightType == null) {
          if (leftType == null && rightType == null) return 0;
          return leftType == null ? 1 : -1;
        }
      }

      final comparison = _sortField == _KantorSortField.name
          ? (left['NAMA_KANTOR'] ?? '').toString().toLowerCase().compareTo(
              (right['NAMA_KANTOR'] ?? '').toString().toLowerCase(),
            )
          : _compareKantorTypes(
              left['KODE_JENIS_KANTOR'],
              right['KODE_JENIS_KANTOR'],
            );
      if (comparison == 0) {
        return (left['NAMA_KANTOR'] ?? '').toString().toLowerCase().compareTo(
          (right['NAMA_KANTOR'] ?? '').toString().toLowerCase(),
        );
      }
      return _sortAscending ? comparison : -comparison;
    });
    return results;
  }

  double? _parseCoordinate(Object? value) {
    final coordinate = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim() ?? '');
    return coordinate != null && coordinate.isFinite ? coordinate : null;
  }

  LatLng? _coordinatesFor(Map<String, dynamic> kantor) {
    final latitude = _parseCoordinate(kantor['LATITUDE']);
    final longitude = _parseCoordinate(kantor['LONGITUDE']);
    if (latitude == null ||
        longitude == null ||
        (latitude == 0 && longitude == 0) ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  String? _officeAddress(Map<String, dynamic> kantor) {
    final address = (kantor['ALAMAT_KANTOR_MUTASI'] ?? kantor['ALAMAT_KANTOR'])
        ?.toString()
        .trim();
    return address == null || address.isEmpty || address == '-'
        ? null
        : address;
  }

  Future<void> _geocodeMissingOfficeLocations() async {
    final batchId = ++_geocodeBatchId;
    final offices = List<Map<String, dynamic>>.from(_kantorList);
    final pendingOffices = offices
        .where(
          (office) =>
              _coordinatesFor(office) == null && _officeAddress(office) != null,
        )
        .toList();
    final missingAddressCount = offices
        .where(
          (office) =>
              _coordinatesFor(office) == null && _officeAddress(office) == null,
        )
        .length;

    if (!mounted) return;
    setState(() {
      _isGeocodingOffices = pendingOffices.isNotEmpty;
      _geocodingUnavailable = false;
      _geocodingProgress = 0;
      _geocodingTotal = pendingOffices.length;
      _geocodingErrorCount = missingAddressCount;
    });

    for (final office in pendingOffices) {
      if (!mounted || batchId != _geocodeBatchId) return;
      final address = _officeAddress(office)!;
      try {
        final searchAddress = address.toLowerCase().contains('indonesia')
            ? address
            : '$address, Indonesia';
        final locations = await Geocoding().locationFromAddress(searchAddress);
        if (locations.isNotEmpty) {
          final location = locations.first;
          final coordinates = LatLng(location.latitude, location.longitude);
          if (_isValidLocation(coordinates)) {
            office['LATITUDE'] = location.latitude;
            office['LONGITUDE'] = location.longitude;
            setState(() {
              _kantorList = offices;
            });
            _reconcileOfficeMarkers(offices);
          } else {
            _geocodingErrorCount++;
          }
        } else {
          _geocodingErrorCount++;
        }
      } on MissingPluginException catch (error) {
        debugPrint('Geocoding kantor tidak tersedia di platform ini: $error');
        if (!mounted || batchId != _geocodeBatchId) return;
        setState(() {
          _geocodingUnavailable = true;
          _geocodingErrorCount += pendingOffices.length - _geocodingProgress;
          _isGeocodingOffices = false;
        });
        return;
      } catch (error) {
        debugPrint('Geocoding alamat kantor gagal: $error');
        _geocodingErrorCount++;
      }

      if (!mounted || batchId != _geocodeBatchId) return;
      setState(() => _geocodingProgress++);
    }

    if (!mounted || batchId != _geocodeBatchId) return;
    setState(() {
      _isGeocodingOffices = false;
    });
    if (_mapReady) _fitMapToOffices();
  }

  bool _isValidLocation(LatLng location) {
    return location.latitude.isFinite &&
        location.longitude.isFinite &&
        !(location.latitude == 0 && location.longitude == 0) &&
        location.latitude >= -90 &&
        location.latitude <= 90 &&
        location.longitude >= -180 &&
        location.longitude <= 180;
  }

  List<flutter_map.Marker> _buildOfficeMarkers() {
    final rawProgress = _officeMarkerAnimationController.value;
    final progress = Curves.easeInOutCubic.transform(rawProgress);
    return _officeMarkerTransitions.entries.map((entry) {
      final transition = entry.value;
      final coordinates = LatLng(
        transition.from.latitude +
            (transition.to.latitude - transition.from.latitude) * progress,
        transition.from.longitude +
            (transition.to.longitude - transition.from.longitude) * progress,
      );
      final scale = _officeMarkerScale(transition, rawProgress);
      return flutter_map.Marker(
        point: coordinates,
        width: 48,
        height: 54,
        child: Transform.scale(
          scale: scale,
          child: PressBounce(
            onTap: transition.toScale < 1
                ? null
                : () => _selectOffice(transition.office),
            child: const Center(
              child: Icon(
                Icons.location_on_rounded,
                color: _brandBlue,
                size: 42,
                shadows: [Shadow(color: Color(0x550F172A), blurRadius: 8)],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildOfficeLabel() {
    final office = _selectedOffice;
    if (!_mapReady || office == null) {
      return const SizedBox.shrink(key: ValueKey('no-office-label'));
    }

    final camera = _mapController.camera;
    final coordinates = _coordinatesFor(office);
    final name = office['NAMA_KANTOR']?.toString().trim();
    if (coordinates == null || name == null || name.isEmpty) {
      return const SizedBox.shrink(key: ValueKey('no-office-label'));
    }

    final point = camera.latLngToScreenPoint(coordinates);
    final markerCenter = Offset(point.x, point.y);
    const labelWidth = 172.0;
    const bubbleHeight = 42.0;
    const pointerHeight = 9.0;
    final left = (markerCenter.dx - labelWidth / 2)
        .clamp(0.0, camera.nonRotatedSize.x - labelWidth)
        .toDouble();
    final top = (markerCenter.dy - 27 - bubbleHeight - pointerHeight)
        .clamp(4.0, camera.nonRotatedSize.y - bubbleHeight - pointerHeight)
        .toDouble();

    return Stack(
      key: ValueKey('${office['KODE_KANTOR'] ?? name}'),
      children: [
        Positioned(
          left: left,
          top: top,
          width: labelWidth,
          height: bubbleHeight + pointerHeight,
          child: PressBounce(
            onTap: () => _selectOffice(office),
            child: Column(
              children: [
                Container(
                  height: bubbleHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEEF1F3F5),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0x99FFFFFF),
                      width: 0.8,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3D334155),
                        blurRadius: 9,
                        spreadRadius: 0.5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 10,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                CustomPaint(
                  size: const Size(18, pointerHeight),
                  painter: _OfficeLabelPointerPainter(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onMapPositionChanged() {
    if (_mapLabelRefreshScheduled) return;
    _mapLabelRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapLabelRefreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _selectOffice(Map<String, dynamic> office) {
    final wasClosed = _officeSheetOffice == null;
    _officeSheetAnimationId++;
    setState(() {
      _selectedOffice = office;
      _officeSheetOffice = office;
    });
    if (wasClosed) {
      _officeSheetAnimationController.forward(from: 0);
    } else if (_officeSheetAnimationController.isAnimating &&
        _officeSheetAnimationController.status == AnimationStatus.reverse) {
      _officeSheetAnimationController.forward();
    }
  }

  void _centerOffice(Map<String, dynamic> office) {
    final coordinates = _coordinatesFor(office);
    if (coordinates == null || !_mapReady) return;
    _animationStartCenter = _mapController.camera.center;
    _animationTargetCenter = coordinates;
    _animationStartZoom = _mapController.camera.zoom;
    _animationTargetZoom = 13;
    _mapCenterAnimationController.forward(from: 0);
  }

  void _updateMapCenterAnimation() {
    final start = _animationStartCenter;
    final target = _animationTargetCenter;
    if (start == null || target == null || !_mapReady) return;

    final progress = Curves.easeInOutCubic.transform(
      _mapCenterAnimationController.value,
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

  Future<void> _closeOfficeSheet() async {
    final animationId = ++_officeSheetAnimationId;
    setState(() => _selectedOffice = null);
    await _officeSheetAnimationController.reverse();
    if (!mounted || animationId != _officeSheetAnimationId) return;
    setState(() => _officeSheetOffice = null);
  }

  LatLng get _mapCenter {
    final locations = _kantorList
        .map(_coordinatesFor)
        .whereType<LatLng>()
        .toList();
    if (locations.isEmpty) return const LatLng(-2.5, 118);

    return LatLng(
      locations.map((location) => location.latitude).reduce((a, b) => a + b) /
          locations.length,
      locations.map((location) => location.longitude).reduce((a, b) => a + b) /
          locations.length,
    );
  }

  void _fitMapToOffices({bool animate = false}) {
    final locations = _kantorList
        .map(_coordinatesFor)
        .whereType<LatLng>()
        .toList();
    if (locations.isEmpty || !_mapReady) return;

    late final LatLng targetCenter;
    late final double targetZoom;
    if (locations.length == 1 ||
        locations.every(
          (location) =>
              location.latitude == locations.first.latitude &&
              location.longitude == locations.first.longitude,
        )) {
      targetCenter = locations.first;
      targetZoom = 9;
    } else {
      final fittedCamera = flutter_map.CameraFit.bounds(
        bounds: flutter_map.LatLngBounds.fromPoints(locations),
        padding: const EdgeInsets.all(32),
      ).fit(_mapController.camera);
      targetCenter = fittedCamera.center;
      targetZoom = fittedCamera.zoom;
    }

    if (!animate) {
      _mapController.move(targetCenter, targetZoom);
      return;
    }

    _animationStartCenter = _mapController.camera.center;
    _animationTargetCenter = targetCenter;
    _animationStartZoom = _mapController.camera.zoom;
    _animationTargetZoom = targetZoom;
    _mapCenterAnimationController.forward(from: 0);
  }

  void _onMapReady() {
    _mapReady = true;
    _fitMapToOffices();
  }

  Widget _buildMiniMap() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - progress)),
          child: child,
        ),
      ),
      child: _buildMiniMapContents(),
    );
  }

  Widget _buildMiniMapContents() {
    final markerCount = _kantorList
        .where((kantor) => _coordinatesFor(kantor) != null)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 240,
          child: Stack(
            children: [
              flutter_map.FlutterMap(
                mapController: _mapController,
                options: flutter_map.MapOptions(
                  initialCenter: _mapCenter,
                  initialZoom: 4.2,
                  onMapReady: _onMapReady,
                  onPositionChanged: (_, _) => _onMapPositionChanged(),
                ),
                children: [
                  flutter_map.TileLayer(
                    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.devasatrio.bi_cabang_tracker',
                  ),
                  flutter_map.MarkerLayer(markers: _buildOfficeMarkers()),
                ],
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  reverseDuration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.82, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                  child: _buildOfficeLabel(),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: const [_cardShadow],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: _brandBlue,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$markerCount kantor dengan lokasi',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_isGeocodingOffices)
                            Text(
                              'Mencari lokasi $_geocodingProgress/$_geocodingTotal...',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            )
                          else if (_geocodingUnavailable)
                            const Text(
                              'Geocoding tidak tersedia di perangkat ini',
                              style: TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 10,
                              ),
                            )
                          else if (_geocodingErrorCount > 0)
                            Text(
                              '$_geocodingErrorCount alamat belum ditemukan',
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.showMiniMap)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Material(
                    color: Colors.white,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Tampilkan seluruh kantor',
                      onPressed: () => _fitMapToOffices(animate: true),
                      icon: const Icon(
                        Icons.zoom_out_map_rounded,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeSheet({
    required Map<String, dynamic> office,
    required double availableHeight,
  }) {
    final officeName = office['NAMA_KANTOR']?.toString().trim();
    final fields = [
      for (final fieldName in _officeDetailFields)
        MapEntry(fieldName, office[fieldName]),
    ];
    final minSheetSize =
        ((188 + MediaQuery.paddingOf(context).bottom) / availableHeight)
            .clamp(0.16, 0.48)
            .toDouble();
    final middleSheetSize = (0.42 + fields.length * 0.025)
        .clamp(minSheetSize + 0.06, 0.68)
        .toDouble();
    const maxSheetSize = 1.0;

    return DraggableScrollableSheet(
      controller: _officeSheetController,
      initialChildSize: middleSheetSize,
      minChildSize: minSheetSize,
      maxChildSize: maxSheetSize,
      expand: true,
      snap: true,
      snapSizes: [minSheetSize, middleSheetSize, maxSheetSize],
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
              _buildOfficeSheetDragHandle(
                availableHeight: availableHeight,
                minSheetSize: minSheetSize,
                middleSheetSize: middleSheetSize,
                maxSheetSize: maxSheetSize,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      officeName == null || officeName.isEmpty
                          ? 'Informasi kantor'
                          : officeName,
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
                    onPressed: _closeOfficeSheet,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _centerOffice(office),
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
                  _buildOfficeInfoRow(entry.key, entry.value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeSheetDragHandle({
    required double availableHeight,
    required double minSheetSize,
    required double middleSheetSize,
    required double maxSheetSize,
  }) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          if (!_officeSheetController.isAttached) return;
          final nextSize =
              _officeSheetController.size - details.delta.dy / availableHeight;
          _officeSheetController.jumpTo(
            nextSize.clamp(minSheetSize, maxSheetSize).toDouble(),
          );
        },
        onVerticalDragEnd: (_) {
          if (!_officeSheetController.isAttached) return;
          final snapPoints = [minSheetSize, middleSheetSize, maxSheetSize];
          final currentSize = _officeSheetController.size;
          final nearestSnap = snapPoints.reduce(
            (nearest, point) =>
                (point - currentSize).abs() < (nearest - currentSize).abs()
                ? point
                : nearest,
          );
          _officeSheetController.animateTo(
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

  Widget _buildOfficeInfoRow(String fieldName, Object? value) {
    final formattedValue =
        fieldName == 'KODE_JENIS_KANTOR' &&
            value != null &&
            value.toString().trim().isNotEmpty
        ? '${value.toString()} (${jenisKantorLabel(value)})'
        : value == null || value.toString().trim().isEmpty
        ? '-'
        : value is Map || value is List
        ? jsonEncode(value)
        : value.toString();
    final label = fieldName == 'ALAMAT_KANTOR_MUTASI'
        ? 'Alamat Kantor'
        : fieldName
              .replaceAll('_', ' ')
              .toLowerCase()
              .split(' ')
              .map(
                (word) => word.isEmpty
                    ? word
                    : '${word[0].toUpperCase()}${word.substring(1)}',
              )
              .join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_officeInfoIcon(fieldName), color: _brandBlue, size: 19),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formattedValue,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
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

  int _compareKantorTypes(Object? left, Object? right) {
    final leftType = int.tryParse(left?.toString().trim() ?? '');
    final rightType = int.tryParse(right?.toString().trim() ?? '');
    if (leftType == null && rightType == null) return 0;
    if (leftType == null) return 1;
    if (rightType == null) return -1;
    return leftType.compareTo(rightType);
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
        borderSide: const BorderSide(color: _brandBlue, width: 2),
      ),
    );
  }

  Widget _buildFilterSectionLabel({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: _brandBlue, size: 18),
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

  Future<void> _showKantorFilters() async {
    var selectedType = _selectedKantorType;
    var sortField = _sortField;
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
                                'Atur daftar kantor sesuai kebutuhan',
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
                            icon: Icons.business_outlined,
                            title: 'Jenis kantor',
                          ),
                          const SizedBox(height: 9),
                          DropdownButtonFormField<String>(
                            initialValue: selectedType,
                            decoration: _filterInputDecoration(
                              hint: 'Pilih jenis kantor',
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _brandBlue,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Semua jenis kantor'),
                              ),
                              for (var code = 1; code <= 6; code++)
                                DropdownMenuItem(
                                  value: '$code',
                                  child: Text(jenisKantorLabel(code)),
                                ),
                            ],
                            onChanged: (value) =>
                                setSheetState(() => selectedType = value ?? ''),
                          ),
                          const SizedBox(height: 20),
                          _buildFilterSectionLabel(
                            icon: Icons.sort_by_alpha_rounded,
                            title: 'Urutkan daftar',
                          ),
                          const SizedBox(height: 9),
                          DropdownButtonFormField<_KantorSortField>(
                            initialValue: sortField,
                            decoration: _filterInputDecoration(
                              hint: 'Urutkan berdasarkan',
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _brandBlue,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: _KantorSortField.name,
                                child: Text('Nama kantor'),
                              ),
                              DropdownMenuItem(
                                value: _KantorSortField.type,
                                child: Text('Jenis kantor'),
                              ),
                            ],
                            onChanged: (value) => setSheetState(
                              () => sortField = value ?? _KantorSortField.name,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildFilterSectionLabel(
                            icon: Icons.swap_vert_rounded,
                            title: sortField == _KantorSortField.name
                                ? 'Urutan abjad'
                                : 'Urutan jenis kantor',
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
                                      _selectedKantorType = '';
                                      _sortField = _KantorSortField.name;
                                      _sortAscending = true;
                                    });
                                    Navigator.pop(sheetContext);
                                  },
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text('Reset'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _brandBlue,
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
                                        _selectedKantorType = selectedType;
                                        _sortField = sortField;
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

  void _openKantor(Map<String, dynamic> kantor) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final user = args is Map ? args : const <String, dynamic>{};
    Navigator.pushNamed(
      context,
      '/agent-list',
      arguments: {
        'KODE_KANTOR': kantor['KODE_KANTOR']?.toString() ?? '',
        'NAMA_KANTOR': kantor['NAMA_KANTOR']?.toString() ?? '-',
        'ALAMAT_KANTOR':
            (kantor['ALAMAT_KANTOR_MUTASI'] ?? kantor['ALAMAT_KANTOR'])
                ?.toString() ??
            '-',
        'LATITUDE': (kantor['LATITUDE'] as num?)?.toDouble() ?? 0.0,
        'LONGITUDE': (kantor['LONGITUDE'] as num?)?.toDouble() ?? 0.0,
        'DATA_KANTOR': kantor,
        'APP_ROLE': (user['APP_ROLE'] ?? '').toString(),
        'LEVEL_USER': (user['LEVEL_USER'] ?? '').toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredKantor;
    final officeSheetOffice = _officeSheetOffice;

    return Scaffold(
      backgroundColor: _pageBottom,
      appBar: AppBar(
        backgroundColor: _pageTop,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        title: const Text(
          'Daftar Kantor',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Muat ulang daftar kantor',
            onPressed: _isLoading ? null : _loadKantor,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _brandBlue,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: _brandBlue),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_pageTop, _pageBottom],
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Semua kantor cabang',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _isLoading
                                  ? 'Memuat data kantor…'
                                  : '${_kantorList.length} kantor terdaftar',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCEBFF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: _brandBlue,
                          size: 23,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showMiniMap) _buildMiniMap(),
                const SizedBox(height: 88),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: _brandBlue),
                        )
                      : _hasError
                      ? _ErrorState(onRetry: _loadKantor)
                      : results.isEmpty
                      ? _EmptyState(query: _searchQuery)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                          itemCount: results.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final kantor = results[index];
                            final kode =
                                kantor['KODE_KANTOR']?.toString() ?? '-';
                            final nama = kantor['NAMA_KANTOR']
                                ?.toString()
                                .trim();
                            final alamat =
                                (kantor['ALAMAT_KANTOR_MUTASI'] ??
                                        kantor['ALAMAT_KANTOR'])
                                    ?.toString()
                                    .trim();
                            final jenisKantor = kantor['KODE_JENIS_KANTOR'];
                            final isCenter = isKantorPusat(jenisKantor);
                            final statusLabel = jenisKantorLabel(jenisKantor);
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _openKantor(kantor),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [_cardShadow],
                                    border: Border.all(
                                      color: const Color(0xFFEAF0F8),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFEAF3FF),
                                              Color(0xFFD8E9FF),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.storefront_rounded,
                                          color: _brandBlue,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nama == null || nama.isEmpty
                                                  ? 'Nama kantor tidak tersedia'
                                                  : nama,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: _ink,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15.5,
                                                height: 1.25,
                                              ),
                                            ),
                                            const SizedBox(height: 7),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 15,
                                                  color: _muted,
                                                ),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    alamat == null ||
                                                            alamat.isEmpty
                                                        ? 'Alamat belum tersedia'
                                                        : alamat,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: _muted,
                                                      fontSize: 12.5,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 11),
                                            Wrap(
                                              spacing: 7,
                                              runSpacing: 6,
                                              children: [
                                                _InfoPill(
                                                  icon: Icons.tag_rounded,
                                                  label: kode,
                                                ),
                                                _InfoPill(
                                                  icon: isCenter
                                                      ? Icons.business_rounded
                                                      : Icons
                                                            .check_circle_outline_rounded,
                                                  label: statusLabel,
                                                  isBlue: true,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Padding(
                                        padding: EdgeInsets.only(top: 13),
                                        child: Icon(
                                          Icons.chevron_right_rounded,
                                          color: Color(0xFF9AA8BA),
                                          size: 23,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            top: widget.showMiniMap ? 360 : 104,
            left: 18,
            right: 18,
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.white,
                    elevation: _searchFocused ? 18 : 0,
                    shadowColor: const Color(0x66000000),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _searchFocused
                              ? const Color(0xFF8AB8F8)
                              : const Color(0xFFE3EAF4),
                          width: _searchFocused ? 1.5 : 1,
                        ),
                        boxShadow: _searchFocused
                            ? const [
                                BoxShadow(
                                  color: Color(0x332563EB),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ]
                            : const [_cardShadow],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Cari nama, kode, atau alamat kantor…',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9AA7B8),
                            fontSize: 13.5,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _brandBlue,
                            size: 23,
                          ),
                          suffixIcon: _searchQuery.isEmpty
                              ? (_searchFocused
                                    ? IconButton(
                                        onPressed: () =>
                                            _searchFocusNode.unfocus(),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: _muted,
                                        ),
                                      )
                                    : null)
                              : IconButton(
                                  tooltip: 'Hapus pencarian',
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchFocusNode.requestFocus();
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: _muted,
                                  ),
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 17,
                            horizontal: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  elevation: 1,
                  shadowColor: const Color(0x26000000),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _showKantorFilters,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 64,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              _selectedKantorType.isNotEmpty ||
                                  _sortField != _KantorSortField.name ||
                                  !_sortAscending
                              ? const Color(0xFF8AB8F8)
                              : const Color(0xFFE3EAF4),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color:
                                _selectedKantorType.isNotEmpty ||
                                    _sortField != _KantorSortField.name ||
                                    !_sortAscending
                                ? _brandBlue
                                : _muted,
                            size: 23,
                          ),
                          if (_selectedKantorType.isNotEmpty ||
                              _sortField != _KantorSortField.name ||
                              !_sortAscending)
                            Positioned(
                              top: 12,
                              right: 17,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _brandBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_searchFocused && _searchQuery.isNotEmpty)
            Positioned(
              top: widget.showMiniMap ? 426 : 170,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Text(
                  '${results.length} hasil ditemukan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (widget.showMiniMap && officeSheetOffice != null)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) => AnimatedBuilder(
                  animation: _officeSheetAnimationController,
                  child: _buildOfficeSheet(
                    office: officeSheetOffice,
                    availableHeight: constraints.maxHeight,
                  ),
                  builder: (context, child) {
                    final progress = Curves.easeOutCubic.transform(
                      _officeSheetAnimationController.value,
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
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.isBlue = false,
  });
  final IconData icon;
  final String label;
  final bool isBlue;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: isBlue ? const Color(0xFFEAF3FF) : const Color(0xFFF3F6FA),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: isBlue ? _brandBlue : _muted),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isBlue ? _brandBlue : const Color(0xFF596579),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xFFDCEBFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: _brandBlue,
              size: 35,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Kantor tidak ditemukan',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Tidak ada kantor yang cocok dengan “$query”. Coba kata kunci lain.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 46, color: _muted),
          const SizedBox(height: 12),
          const Text(
            'Data kantor belum bisa dimuat',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Periksa koneksi ke server, lalu coba lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}
