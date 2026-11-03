import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as location_plugin;

import '../services/api_service.dart';

class AgentGpsTrackingService with WidgetsBindingObserver {
  AgentGpsTrackingService._();

  static final AgentGpsTrackingService instance = AgentGpsTrackingService._();
  static const MethodChannel _notificationPermissionChannel = MethodChannel(
    'com.example.agent_inteligence/notifications',
  );

  final location_plugin.Location _locationService = location_plugin.Location();
  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();
  final StreamController<String?> _locationWarnings =
      StreamController<String?>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _gpsStatusSubscription;
  Position? _latestPosition;
  String? _latestLocationWarning;
  bool? _notificationsAllowed;
  bool? _backgroundLocationAllowed;

  bool _isTracking = false;
  bool _isStarting = false;
  bool _isRecoveringGps = false;
  bool _observerRegistered = false;

  bool get isTracking => _isTracking;
  Position? get latestPosition => _latestPosition;
  Stream<Position> get positions => _positions.stream;
  Stream<String?> get locationWarnings => _locationWarnings.stream;
  String? get latestLocationWarning => _latestLocationWarning;
  bool? get notificationsAllowed => _notificationsAllowed;
  bool? get backgroundLocationAllowed => _backgroundLocationAllowed;
  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> ensureGpsReady() async {
    // Ulangi permintaan sistem sampai GPS aktif.
    while (!await Geolocator.isLocationServiceEnabled()) {
      final enabled = await _locationService.requestService();

      if (!enabled) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }

    var permission = await Geolocator.checkPermission();

    while (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();

      throw Exception(
        'Izin lokasi ditolak permanen. Aktifkan izin lokasi '
        'di pengaturan aplikasi, kemudian coba lagi.',
      );
    }

    if (_isAndroid &&
        permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (_isAndroid) {
      _backgroundLocationAllowed = permission == LocationPermission.always;
    }
  }

  Future<void> startAfterLogin() async {
    if (_isTracking || _isStarting) return;

    _isStarting = true;

    try {
      await ensureGpsReady();
      await _requestNotificationPermission();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      final trackingResult = await ApiService.getTrackingStatus();
      final trackingData = trackingResult['data'];
      if (trackingData is! Map || trackingData['active'] is! bool) {
        throw Exception('Format status tracking dari server tidak valid.');
      }

      if (trackingData['active'] != true) {
        await ApiService.startTracking();
      }

      _isTracking = true;

      _publishPosition(position);
      await _sendLocation(position);

      _registerGpsMonitoring();
      await _startPositionStream();
    } catch (_) {
      // Jangan menganggap tracking berhasil jika proses awal gagal.
      if (!_isTracking) {
        await _positionSubscription?.cancel();
        _positionSubscription = null;
      }
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!_isAndroid) return;

    _notificationsAllowed = await _notificationPermissionChannel
        .invokeMethod<bool>('requestNotificationPermission');

    if (_notificationsAllowed == false) {
      debugPrint(
        'Izin notifikasi ditolak; Android dapat menyembunyikan notifikasi '
        'foreground service dari panel notifikasi.',
      );
    }
  }

  LocationSettings _trackingLocationSettings() {
    if (_isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Pelacakan lokasi aktif',
          notificationText: 'Lokasi dibagikan selama Anda bertugas.',
          notificationChannelName: 'Pelacakan lokasi',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  void _publishPosition(Position position) {
    _latestPosition = position;
    if (!_positions.isClosed) {
      _positions.add(position);
    }
  }

  void _registerGpsMonitoring() {
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }

    _gpsStatusSubscription ??= Geolocator.getServiceStatusStream().listen((
      status,
    ) {
      if (status == ServiceStatus.disabled && _isTracking) {
        unawaited(_recoverGps());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Periksa lagi saat pengguna kembali ke aplikasi.
    if (state == AppLifecycleState.resumed && _isTracking) {
      unawaited(_recoverGps());
    }
  }

  Future<void> _startPositionStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _trackingLocationSettings(),
        ).listen(
          (position) {
            _publishPosition(position);
            unawaited(_sendLocation(position));
          },
          onError: (Object error) {
            // Pemulihan akan dicoba saat status GPS berubah
            // atau saat aplikasi kembali ke foreground.
            _positionSubscription = null;
          },
        );
  }

  Future<void> _recoverGps() async {
    if (!_isTracking || _isRecoveringGps) return;

    _isRecoveringGps = true;

    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      // Jika GPS dimatikan, minta aktifkan kembali.
      await ensureGpsReady();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      _publishPosition(position);
      await _sendLocation(position);
      await _startPositionStream();
    } catch (error) {
      debugPrint('Pemulihan GPS gagal: $error');
    } finally {
      _isRecoveringGps = false;
    }
  }

  Future<void> _sendLocation(Position position) async {
    try {
      final result = await ApiService.sendTrackingLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        isMocked: position.isMocked,
      );
      final response = result['data'];
      final warnings = response is Map ? response['locationWarnings'] : null;
      _latestLocationWarning =
          response is Map && response['locationSuspicious'] == true
          ? warnings is List && warnings.isNotEmpty
                ? warnings.join(', ')
                : 'Perpindahan lokasi perlu diverifikasi.'
          : position.isMocked
          ? 'Perangkat menandai lokasi ini sebagai mock.'
          : null;
      if (!_locationWarnings.isClosed) {
        _locationWarnings.add(_latestLocationWarning);
      }
    } catch (error) {
      debugPrint('Gagal mengirim lokasi: $error');
    }
  }

  Future<void> disposeTrackingStream() async {
    await stopLocationUpdates();

    await _gpsStatusSubscription?.cancel();
    _gpsStatusSubscription = null;

    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
  }

  Future<void> stopLocationUpdates() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    _isTracking = false;
  }
}
