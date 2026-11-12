import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../services/api_service.dart';
import '../services/gps_tracking_service.dart';

const _blueDark = Color(0xFF0D47A1);
const _blue = Color(0xFF1B72D7);
const _pageStart = Color(0xFFF8FBFF);
const _pageEnd = Color(0xFFEAF3FF);
const _green = Color(0xFF15803D);
const _red = Color(0xFFDC2626);

class AgentTrackingPage extends StatefulWidget {
  const AgentTrackingPage({super.key});

  @override
  State<AgentTrackingPage> createState() => _AgentTrackingPageState();
}

class _AgentTrackingPageState extends State<AgentTrackingPage> {
  final flutter_map.MapController _mapController = flutter_map.MapController();

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<String?>? _locationWarningStream;
  Timer? _durationTimer;

  Position? _position;
  bool _isTracking = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _locationWarning;
  String? _trackingNotice;
  DateTime? _lastUpdated;
  DateTime? _taskStartedAt;
  Duration _taskDuration = Duration.zero;

  static const LatLng _defaultCenter = LatLng(-6.2000, 106.8167);

  @override
  void initState() {
    super.initState();
    unawaited(_restoreTrackingStatus());
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS belum aktif. Aktifkan lokasi di pengaturan HP.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi belum diberikan.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Aktifkan melalui pengaturan aplikasi.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> _restoreTrackingStatus() async {
    var serverTrackingActive = false;

    try {
      final result = await ApiService.getTrackingStatus();
      final data = result['data'];
      if (data is! Map<String, dynamic> || data['active'] is! bool) {
        throw Exception('Respons status tugas tidak valid.');
      }

      serverTrackingActive = data['active'] as bool;
      if (!serverTrackingActive) {
        if (!mounted) return;
        setState(() {
          _isTracking = false;
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _isTracking = true;
        _errorMessage = null;
      });

      // Timestamp mulai bertugas berada di dalam data.data dari respons API.
      // Ambil waktu tersebut agar durasi tetap berlanjut saat halaman dibuka ulang.
      final agentData = data['data'];
      final rawStartedAt = agentData is Map<String, dynamic>
          ? (agentData['startedAt'] ?? agentData['started_at'])
          : null;
      _taskStartedAt = rawStartedAt is String
          ? DateTime.tryParse(rawStartedAt)?.toLocal()
          : null;

      if (_taskStartedAt != null) {
        _startDurationTimer();
      }

      final trackingService = AgentGpsTrackingService.instance;
      _trackingNotice = _trackingPermissionNotice(trackingService);
      _locationWarning = trackingService.latestLocationWarning;
      final position =
          trackingService.latestPosition ?? await _getCurrentPosition();
      if (trackingService.latestPosition == null) {
        await _sendPosition(position);
      }

      if (!mounted) return;
      setState(() {
        _position = position;
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });

      _mapController.move(LatLng(position.latitude, position.longitude), 16);
      _listenForLocationUpdates();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isTracking = serverTrackingActive;
        _isLoading = false;
        _errorMessage = serverTrackingActive
            ? 'Tugas masih aktif, tetapi lokasi belum dapat diperbarui: ${_cleanError(error)}'
            : _cleanError(error);
      });
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _startDurationTimer() {
    _durationTimer?.cancel();
    void updateDuration() {
      if (!mounted || _taskStartedAt == null) return;
      setState(() {
        _taskDuration = DateTime.now().difference(_taskStartedAt!);
      });
    }

    updateDuration();
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateDuration(),
    );
  }

  void _recenterMap() {
    final position = _position;
    if (position == null) return;

    _mapController.move(LatLng(position.latitude, position.longitude), 16);
  }

  Future<void> _sendPosition(Position position) async {
    final result = await ApiService.sendTrackingLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      isMocked: position.isMocked,
    );

    final response = result['data'];
    if (response is Map && response['locationSuspicious'] == true) {
      final warnings = response['locationWarnings'];
      if (mounted) {
        setState(() {
          _locationWarning = warnings is List && warnings.isNotEmpty
              ? warnings.join(', ')
              : 'Perpindahan lokasi perlu diverifikasi.';
        });
      }
    } else {
      _updateLocationWarning(position);
    }
  }

  void _updateLocationWarning(Position position) {
    if (!mounted) return;
    setState(() {
      _locationWarning = position.isMocked
          ? 'Perangkat menandai lokasi ini sebagai mock; lokasi tetap dikirim untuk ditinjau.'
          : null;
    });
  }

  void _listenForLocationUpdates() {
    unawaited(_positionStream?.cancel());
    _positionStream = AgentGpsTrackingService.instance.positions.listen(
      (position) {
        if (!mounted) return;

        setState(() {
          _position = position;
          _lastUpdated = DateTime.now();
          _errorMessage = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(
          () =>
              _errorMessage = 'Pembaruan GPS bermasalah: ${_cleanError(error)}',
        );
      },
    );
    unawaited(_locationWarningStream?.cancel());
    _locationWarningStream = AgentGpsTrackingService.instance.locationWarnings
        .listen((warning) {
          if (!mounted) return;
          setState(() {
            _locationWarning = warning;
          });
        });
  }

  Future<void> _confirmStartTracking(BuildContext localizedContext) async {
    final confirmed = await _showConfirmation(
      context: localizedContext,
      title: 'Mulai Bertugas?',
      message: 'Setelah dimulai, aplikasi akan mengambil dan mengirim lokasi perangkat selama sesi tugas sesuai izin lokasi yang diberikan. Pastikan GPS dan koneksi internet tersedia.',
      confirmLabel: 'Ya, Mulai Bertugas',
      confirmColor: _green,
      icon: Icons.play_circle_outline_rounded,
    );
    if (confirmed && mounted) await _startTracking();
  }

  Future<void> _confirmStopTracking(BuildContext localizedContext) async {
    final confirmed = await _showConfirmation(
      context: localizedContext,
      title: 'Selesaikan Tugas?',
      message: 'Sesi tugas akan diakhiri dan pengiriman lokasi untuk sesi ini dihentikan. Pastikan pekerjaan lapangan sudah selesai.',
      confirmLabel: 'Ya, Selesaikan',
      confirmColor: _red,
      icon: Icons.stop_circle_outlined,
    );
    if (confirmed && mounted) await _stopTracking();
  }

  Future<bool> _showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required IconData icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Localizations(
        locale: const Locale('en', 'US'),
        delegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(color: confirmColor),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                    child: Column(
                      children: [
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('Batal'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: confirmColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: Text(confirmLabel),
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
      ),
    );
    return result ?? false;
  }

  String? _trackingPermissionNotice(AgentGpsTrackingService service) {
    if (service.backgroundLocationAllowed == false) {
      return 'Izin lokasi “Sepanjang waktu” tidak aktif. Tracking tetap memakai layanan foreground, tetapi sistem dapat menghentikannya jika aplikasi ditutup paksa.';
    }
    return null;
  }

  Future<void> _startTracking() async {
    if (_isLoading || _isTracking) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trackingService = AgentGpsTrackingService.instance;
      await trackingService.startAfterLogin();
      _trackingNotice = _trackingPermissionNotice(trackingService);
      _locationWarning = trackingService.latestLocationWarning;
      final firstPosition =
          trackingService.latestPosition ?? await _getCurrentPosition();
      if (trackingService.latestPosition == null) {
        await _sendPosition(firstPosition);
      }

      if (!mounted) return;
      setState(() {
        _position = firstPosition;
        _lastUpdated = DateTime.now();
        _taskStartedAt = DateTime.now();
        _taskDuration = Duration.zero;
        _isTracking = true;
        _isLoading = false;
      });

      _startDurationTimer();
      _mapController.move(
        LatLng(firstPosition.latitude, firstPosition.longitude),
        16,
      );
      _listenForLocationUpdates();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanError(error);
        _isTracking = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _stopTracking() async {
    if (_isLoading || !_isTracking) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.stopTracking();
      await AgentGpsTrackingService.instance.stopLocationUpdates();
      await _positionStream?.cancel();
      _positionStream = null;
      await _locationWarningStream?.cancel();
      _locationWarningStream = null;
      _durationTimer?.cancel();
      _durationTimer = null;

      if (!mounted) return;
      setState(() {
        _isTracking = false;
        _isLoading = false;
        _taskStartedAt = null;
        _taskDuration = Duration.zero;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Gagal menghentikan tracking di server: ${_cleanError(error)}';
      });
    }
  }

  String _formatCoordinate(double? value) =>
      value == null ? '--' : value.toStringAsFixed(6);

  String _formatUpdatedAt() {
    final time = _lastUpdated;
    if (time == null) return 'Belum tersedia';
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    String? unit,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE6F0FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _blueDark, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF14264D),
                ),
              ),
              if (unit != null)
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    unawaited(_positionStream?.cancel());
    unawaited(_locationWarningStream?.cancel());
    _durationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    final center = position == null
        ? _defaultCenter
        : LatLng(position.latitude, position.longitude);

    final statusColor = _isTracking ? _green : const Color(0xFF64748B);
    final statusText = _isLoading
        ? 'MEMPROSES'
        : (_isTracking ? 'ON DUTY' : 'OFF DUTY');

    return Localizations(
      locale: const Locale('en', 'US'),
      delegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Builder(
        builder: (localizedContext) => Scaffold(
          backgroundColor: _pageStart,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text(
              'Agent Tracking',
              style: TextStyle(
                color: Color(0xFF14264D),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_pageStart, _pageEnd],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_blueDark, _blue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x260D47A1),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.my_location_rounded,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                    SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pelacakan Tugas',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 21,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            'Agent Intelligence Tracker',
                                            style: TextStyle(
                                              color: Color(0xFFDCEAFF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 18),
                                Container(
                                  width: 220,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Pantau perjalanan tugas lapangan Anda',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                                SizedBox(height: 7),
                                Text(
                                  'Aktifkan pelacakan saat mulai bertugas agar lokasi Anda dapat dipantau oleh sistem selama kegiatan berlangsung.',
                                  style: TextStyle(
                                    color: Color(0xFFE3EEFF),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _sectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        _isTracking
                                            ? Icons.gps_fixed_rounded
                                            : Icons.gps_off_rounded,
                                        color: statusColor,
                                        size: 23,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Status tugas',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _isTracking
                                                ? 'Sedang Bertugas'
                                                : 'Belum Bertugas',
                                            style: const TextStyle(
                                              color: Color(0xFF14264D),
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _infoTile(
                                        icon: Icons.timer_outlined,
                                        title: 'Durasi tugas',
                                        value: _isTracking
                                            ? (_taskStartedAt == null
                                                  ? '--:--:--'
                                                  : _formatDuration(
                                                      _taskDuration,
                                                    ))
                                            : '00:00:00',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _infoTile(
                                        icon: Icons.update_rounded,
                                        title: 'Pembaruan terakhir',
                                        value: _formatUpdatedAt(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 280,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFDCE8F8),
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Stack(
                                children: [
                                  flutter_map.FlutterMap(
                                    mapController: _mapController,
                                    options: flutter_map.MapOptions(
                                      initialCenter: center,
                                      initialZoom: position == null ? 11 : 16,
                                    ),
                                    children: [
                                      flutter_map.TileLayer(
                                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                            'com.devasatrio.bi_cabang_tracker',
                                      ),
                                      if (position != null)
                                        flutter_map.MarkerLayer(
                                          markers: [
                                            flutter_map.Marker(
                                              point: center,
                                              width: 50,
                                              height: 50,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          _blueDark,
                                                          _blue,
                                                        ],
                                                        begin: Alignment
                                                            .centerLeft,
                                                        end: Alignment
                                                            .centerRight,
                                                      ),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _blue.withValues(
                                                        alpha: 0.35,
                                                      ),
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
                                          ],
                                        ),
                                    ],
                                  ),
                                  if (position != null)
                                    Positioned(
                                      right: 12,
                                      bottom: 12,
                                      child: Material(
                                        color: Colors.white,
                                        elevation: 4,
                                        shape: const CircleBorder(),
                                        child: IconButton(
                                          tooltip: 'Kembali ke posisi saya',
                                          onPressed: _recenterMap,
                                          icon: const Icon(
                                            Icons.my_location_rounded,
                                            color: _blueDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (position == null)
                                    Positioned(
                                      left: 14,
                                      right: 14,
                                      bottom: 14,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.96,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'Lokasi akan ditampilkan setelah GPS berhasil diperoleh.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF334155),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: _isTracking
                                                ? _green
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            _isTracking
                                                ? 'Lokasi aktif'
                                                : 'Pratinjau peta',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF334155),
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
                          const SizedBox(height: 16),
                          _sectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Informasi Lokasi',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF14264D),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Koordinat perangkat dan kualitas sinyal GPS saat ini.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _infoTile(
                                        icon: Icons.location_on_outlined,
                                        title: 'Latitude',
                                        value: _formatCoordinate(
                                          position?.latitude,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _infoTile(
                                        icon: Icons.explore_outlined,
                                        title: 'Longitude',
                                        value: _formatCoordinate(
                                          position?.longitude,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _infoTile(
                                        icon: Icons.gps_fixed_rounded,
                                        title: 'Akurasi GPS',
                                        value: position == null
                                            ? '--'
                                            : position.accuracy.toStringAsFixed(
                                                1,
                                              ),
                                        unit: 'meter',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _infoTile(
                                        icon: Icons.speed_rounded,
                                        title: 'Kecepatan',
                                        value: position == null
                                            ? '--'
                                            : (position.speed * 3.6)
                                                  .toStringAsFixed(1),
                                        unit: 'km/jam',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_trackingNotice != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _trackingNotice!,
                                      style: const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_locationWarning != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFFED7AA),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Lokasi perlu diverifikasi: $_locationWarning',
                                      style: const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFFECACA),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: _red,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFF991B1B),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _isTracking ? _red : _blueDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    if (_isTracking) {
                                      _confirmStopTracking(localizedContext);
                                    } else {
                                      _confirmStartTracking(localizedContext);
                                    }
                                  },
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _isTracking
                                        ? Icons.stop_circle_outlined
                                        : Icons.play_circle_outline_rounded,
                                  ),
                            label: Text(
                              _isLoading
                                  ? 'Memproses...'
                                  : (_isTracking
                                        ? 'Selesaikan Tugas'
                                        : 'Mulai Bertugas'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.privacy_tip_outlined,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lokasi dikirim selama sesi tugas aktif sesuai izin perangkat dan kebijakan perusahaan. Pastikan tracking dihentikan setelah tugas selesai.',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  height: 1.5,
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
      ),
    );
  }
}
