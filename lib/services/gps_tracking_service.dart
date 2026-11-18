import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as location_plugin;

import '../services/api_service.dart';

enum _MovementMode { stationary, walking, driving }

class AgentGpsTrackingService with WidgetsBindingObserver {
  AgentGpsTrackingService._();

  static final AgentGpsTrackingService instance = AgentGpsTrackingService._();

  final location_plugin.Location _locationService = location_plugin.Location();
  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();
  final StreamController<String?> _locationWarnings =
      StreamController<String?>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _gpsStatusSubscription;
  Timer? _gpsRecoveryRetryTimer;
  final Set<Future<void>> _pendingLocationUpdates = {};
  Future<void> _locationUpdateQueue = Future<void>.value();
  Position? _latestPosition;
  Position? _lastSubmittedPosition;
  DateTime? _lastSubmittedAt;
  DateTime? _lastSubmittedTimestamp;
  String? _latestLocationWarning;
  bool? _backgroundLocationAllowed;
  _MovementMode _movementMode = _MovementMode.stationary;
  _MovementMode? _candidateMovementMode;
  int _candidateMovementModeSamples = 0;
  int _positionStreamGeneration = 0;
  int _gpsRecoveryRetryAttempt = 0;

  bool _isTracking = false;
  bool _isStarting = false;
  bool _isRecoveringGps = false;
  bool _observerRegistered = false;

  bool get isTracking => _isTracking;
  Position? get latestPosition => _latestPosition;
  Stream<Position> get positions => _positions.stream;
  Stream<String?> get locationWarnings => _locationWarnings.stream;
  String? get latestLocationWarning => _latestLocationWarning;
  bool? get backgroundLocationAllowed => _backgroundLocationAllowed;
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const double _maximumReportedAccuracyMeters = 50;
  static const List<Duration> _gpsRecoveryRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

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

    if (_isAndroid && permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (_isAndroid) {
      _backgroundLocationAllowed = permission == LocationPermission.always;
    }
  }

  Future<void> startAfterLogin() async {
    if (_isStarting) return;
    if (_isTracking) {
      await _recoverGps();
      return;
    }

    _isStarting = true;

    try {
      await ensureGpsReady();

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
      _initializeMovementMode(position);

      _publishPosition(position);
      _registerGpsMonitoring();
      await _startPositionStream();
      unawaited(_sendLocation(position));
    } catch (_) {
      _isTracking = false;
      _clearGpsRecoveryRetry(resetAttempts: true);
      ++_positionStreamGeneration;
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      await _disposeGpsMonitoring();
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  LocationSettings _trackingLocationSettings() {
    if (_isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Duration(
          seconds: switch (_movementMode) {
            _MovementMode.stationary => 10,
            _MovementMode.walking => 5,
            _MovementMode.driving => 3,
          },
        ),
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

    if (kIsWeb) return;

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
    final generation = ++_positionStreamGeneration;
    final previousSubscription = _positionSubscription;
    _positionSubscription = null;
    await previousSubscription?.cancel();
    if (!_isTracking || generation != _positionStreamGeneration) return;

    var streamEnded = false;
    final subscription =
        Geolocator.getPositionStream(
          locationSettings: _trackingLocationSettings(),
        ).listen(
          (position) {
            if (!_isTracking || generation != _positionStreamGeneration) return;
            _clearGpsRecoveryRetry(resetAttempts: true);
            _publishPosition(position);
            if (_updateMovementMode(position)) {
              unawaited(_startPositionStream());
            }
            unawaited(_queueLocationUpdate(position));
          },
          onError: (Object error) {
            streamEnded = true;
            _handlePositionStreamFailure(generation, error);
          },
          onDone: () {
            streamEnded = true;
            _handlePositionStreamFailure(
              generation,
              StateError('Stream lokasi berhenti.'),
            );
          },
        );

    if (_isTracking &&
        generation == _positionStreamGeneration &&
        !streamEnded) {
      _positionSubscription = subscription;
    } else {
      await subscription.cancel();
    }
  }

  void _handlePositionStreamFailure(int generation, Object error) {
    if (!_isTracking || generation != _positionStreamGeneration) return;
    _positionSubscription = null;
    debugPrint('Stream lokasi berhenti: $error');
    _scheduleGpsRecovery();
  }

  void _scheduleGpsRecovery() {
    if (!_isTracking || (_gpsRecoveryRetryTimer?.isActive ?? false)) return;

    final retryIndex = _gpsRecoveryRetryAttempt;
    final delay = _gpsRecoveryRetryDelays[retryIndex];
    if (_gpsRecoveryRetryAttempt < _gpsRecoveryRetryDelays.length - 1) {
      _gpsRecoveryRetryAttempt++;
    }
    debugPrint(
      'Mencoba memulihkan stream lokasi dalam ${delay.inSeconds} detik.',
    );
    _gpsRecoveryRetryTimer = Timer(delay, () {
      _gpsRecoveryRetryTimer = null;
      unawaited(_recoverGps());
    });
  }

  void _clearGpsRecoveryRetry({bool resetAttempts = false}) {
    _gpsRecoveryRetryTimer?.cancel();
    _gpsRecoveryRetryTimer = null;
    if (resetAttempts) _gpsRecoveryRetryAttempt = 0;
  }

  Future<void> _recoverGps() async {
    if (!_isTracking || _isRecoveringGps) return;

    _clearGpsRecoveryRetry();
    _isRecoveringGps = true;

    try {
      final previousSubscription = _positionSubscription;
      _positionSubscription = null;
      ++_positionStreamGeneration;
      await previousSubscription?.cancel();

      // Jika GPS dimatikan, minta aktifkan kembali.
      await ensureGpsReady();
      if (!_isTracking) return;
      await _startPositionStream();
    } catch (error) {
      debugPrint('Pemulihan GPS gagal: $error');
      _scheduleGpsRecovery();
    } finally {
      _isRecoveringGps = false;
    }
  }

  Future<void> _sendLocation(
    Position position, {
    bool markSubmission = true,
  }) async {
    if (!_hasAcceptableLocation(position)) {
      debugPrint(
        'Lokasi tidak dikirim karena koordinat atau akurasinya tidak valid.',
      );
      return;
    }

    if (markSubmission) {
      final previousTimestamp = _lastSubmittedTimestamp;
      if (previousTimestamp != null &&
          !position.timestamp.isAfter(previousTimestamp)) {
        debugPrint('Lokasi lama diabaikan.');
        return;
      }

      _recordLocationSubmission(position);
    }

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

    await _disposeGpsMonitoring();
  }

  Future<void> stopTracking() async {
    final wasTracking = _isTracking;
    await stopLocationUpdates();
    await Future.wait(_pendingLocationUpdates.toList());
    try {
      await ApiService.stopTracking();
    } catch (_) {
      if (wasTracking) {
        _isTracking = true;
        _registerGpsMonitoring();
        await _startPositionStream();
      }
      rethrow;
    }
    await _disposeGpsMonitoring();
  }

  Future<void> _disposeGpsMonitoring() async {
    await _gpsStatusSubscription?.cancel();
    _gpsStatusSubscription = null;

    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
  }

  Future<void> _queueLocationUpdate(Position position) {
    if (!_shouldSubmitLocation(position)) {
      return Future<void>.value();
    }

    _recordLocationSubmission(position);
    late final Future<void> update;
    update = _locationUpdateQueue
        .then((_) => _sendLocation(position, markSubmission: false))
        .whenComplete(() {
          _pendingLocationUpdates.remove(update);
        });
    _locationUpdateQueue = update;
    _pendingLocationUpdates.add(update);
    return update;
  }

  void _recordLocationSubmission(Position position) {
    _lastSubmittedPosition = position;
    _lastSubmittedAt = DateTime.now();
    _lastSubmittedTimestamp = position.timestamp;
  }

  bool _hasAcceptableLocation(Position position) {
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180 &&
        position.accuracy.isFinite &&
        position.accuracy >= 0 &&
        position.accuracy <= _maximumReportedAccuracyMeters;
  }

  bool _shouldSubmitLocation(Position position) {
    if (!_hasAcceptableLocation(position)) return false;
    final previousTimestamp = _lastSubmittedTimestamp;
    if (previousTimestamp != null &&
        !position.timestamp.isAfter(previousTimestamp)) {
      return false;
    }

    final previousPosition = _lastSubmittedPosition;
    final previousSubmittedAt = _lastSubmittedAt;
    if (previousPosition == null || previousSubmittedAt == null) return true;

    final elapsed = DateTime.now().difference(previousSubmittedAt);
    final distanceMeters = Geolocator.distanceBetween(
      previousPosition.latitude,
      previousPosition.longitude,
      position.latitude,
      position.longitude,
    );
    final (
      minimumInterval,
      minimumDistance,
      maximumInterval,
    ) = switch (_movementMode) {
      _MovementMode.stationary => (
        const Duration(seconds: 30),
        15.0,
        const Duration(seconds: 60),
      ),
      _MovementMode.walking => (
        const Duration(seconds: 5),
        5.0,
        const Duration(seconds: 15),
      ),
      _MovementMode.driving => (
        const Duration(seconds: 3),
        15.0,
        const Duration(seconds: 10),
      ),
    };

    return elapsed >= maximumInterval ||
        (elapsed >= minimumInterval && distanceMeters >= minimumDistance);
  }

  bool _updateMovementMode(Position position) {
    if (!_hasAcceptableLocation(position) ||
        !position.speed.isFinite ||
        position.speed < 0) {
      return false;
    }

    final speed = position.speed;
    final detectedMode = switch (_movementMode) {
      _MovementMode.stationary =>
        speed >= 4
            ? _MovementMode.driving
            : speed >= 1
            ? _MovementMode.walking
            : _MovementMode.stationary,
      _MovementMode.walking =>
        speed >= 5
            ? _MovementMode.driving
            : speed < 0.5
            ? _MovementMode.stationary
            : _MovementMode.walking,
      _MovementMode.driving =>
        speed < 0.5
            ? _MovementMode.stationary
            : speed < 3
            ? _MovementMode.walking
            : _MovementMode.driving,
    };

    if (detectedMode == _movementMode) {
      _candidateMovementMode = null;
      _candidateMovementModeSamples = 0;
      return false;
    }

    if (_candidateMovementMode == detectedMode) {
      _candidateMovementModeSamples++;
    } else {
      _candidateMovementMode = detectedMode;
      _candidateMovementModeSamples = 1;
    }

    if (_candidateMovementModeSamples < 2) return false;

    _movementMode = detectedMode;
    _candidateMovementMode = null;
    _candidateMovementModeSamples = 0;
    return true;
  }

  void _initializeMovementMode(Position position) {
    if (!_hasAcceptableLocation(position) ||
        !position.speed.isFinite ||
        position.speed < 0) {
      return;
    }

    _movementMode = position.speed >= 5
        ? _MovementMode.driving
        : position.speed >= 1
        ? _MovementMode.walking
        : _MovementMode.stationary;
    _candidateMovementMode = null;
    _candidateMovementModeSamples = 0;
  }

  Future<void> stopLocationUpdates() async {
    _isTracking = false;
    _clearGpsRecoveryRetry(resetAttempts: true);
    ++_positionStreamGeneration;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
