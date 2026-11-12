import 'dart:async';

import 'package:flutter/material.dart'
    as material
    show Icons, showDialog, Tooltip;
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../services/api_service.dart';

const Color _blue = Color(0xFF1565C0);
const Color _pageStart = Color(0xFFF8FBFF);
const Color _pageEnd = Color(0xFFEAF3FF);

class AgentMonitoringPage extends StatefulWidget {
  const AgentMonitoringPage({super.key});

  @override
  State<AgentMonitoringPage> createState() => _AgentMonitoringPageState();
}

class _AgentMonitoringPageState extends State<AgentMonitoringPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _centerAnimationController;
  final flutter_map.MapController _mapController = flutter_map.MapController();
  LatLng? _animationStartCenter;
  LatLng? _animationTargetCenter;
  double _animationStartZoom = 11;

  // Palet warna khusus untuk marker agen.
  // Marker kantor cabang di MapsPage tidak terpengaruh.
  static const List<Color> _agentMarkerColors = [
    Color(0xFF0284C7), // Biru
    Color(0xFFDB2777), // Pink
    Color(0xFF16A34A), // Hijau
    Color(0xFF9333EA), // Ungu
    Color(0xFFEA580C), // Oranye
    Color(0xFF0D9488), // Teal
    Color(0xFFDC2626), // Merah
    Color(0xFF4F46E5), // Indigo
    Color(0xFFCA8A04), // Kuning gelap
    Color(0xFFC026D3), // Magenta
    Color(0xFF7C3AED), // Violet
    Color(0xFF0891B2), // Cyan
  ];

  // Mengambil dua huruf pertama nama agen.
  String _agentInitials(dynamic value) {
    final name = (value ?? '').toString().trim();

    if (name.isEmpty) return '??';

    final letters = name.characters.take(2).toString().toUpperCase();
    return letters;
  }

  // Hash deterministik agar warna agen tetap konsisten.
  Color _agentMarkerColor(dynamic identity) {
    final key = (identity ?? '').toString().trim().toUpperCase();

    if (key.isEmpty) {
      return _agentMarkerColors[0];
    }

    var hash = 0;

    for (final codeUnit in key.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
    }

    return _agentMarkerColors[hash % _agentMarkerColors.length];
  }

  Widget _agentMarker(String name, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _agentInitials(name),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _agents = [];
  bool _loading = true;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _centerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(_updateMapCenterAnimation);
    _loadAgents();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _loadAgents());
  }

  void _updateMapCenterAnimation() {
    final start = _animationStartCenter;
    final target = _animationTargetCenter;
    if (start == null || target == null) return;

    final progress = Curves.easeInOutCubic.transform(
      _centerAnimationController.value,
    );
    final center = LatLng(
      start.latitude + (target.latitude - start.latitude) * progress,
      start.longitude + (target.longitude - start.longitude) * progress,
    );
    final zoom = _animationStartZoom + (16 - _animationStartZoom) * progress;
    _mapController.move(center, zoom);
  }

  void _animateMapToAgent(LatLng targetLocation) {
    _animationStartCenter = _mapController.camera.center;
    _animationTargetCenter = targetLocation;
    _animationStartZoom = _mapController.camera.zoom;
    _centerAnimationController.forward(from: 0);
  }

  Future<void> _loadAgents() async {
    if (!mounted) return;

    try {
      final result = await ApiService.getAgents();
      final data = result['data'];

      if (data is! Map || data['success'] != true) {
        throw Exception('Respons API tidak valid.');
      }

      final rawAgents = data['data'];
      if (rawAgents is! List) {
        throw Exception('Format daftar agen tidak valid.');
      }

      final agents = rawAgents
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((agent) {
            final lat = double.tryParse(agent['latitude']?.toString() ?? '');
            final lng = double.tryParse(agent['longitude']?.toString() ?? '');
            return lat != null &&
                lng != null &&
                lat >= -90 &&
                lat <= 90 &&
                lng >= -180 &&
                lng <= 180;
          })
          .toList();

      if (!mounted) return;

      setState(() {
        _agents = agents;
        _loading = false;
        _error = null;
        _lastUpdated = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  LatLng _coordinates(Map<String, dynamic> agent) {
    return LatLng(
      double.parse(agent['latitude'].toString()),
      double.parse(agent['longitude'].toString()),
    );
  }

  String _updatedAt(Map<String, dynamic> agent) {
    final raw = agent['lastUpdated']?.toString();
    if (raw == null) return 'Belum tersedia';

    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return 'Belum tersedia';

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _centerAnimationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final user = arguments is Map
        ? Map<String, dynamic>.from(arguments)
        : <String, dynamic>{};

    final level =
        (user['LEVEL_USER'] ?? user['level_user'] ?? user['level'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
    final appRole = (user['APP_ROLE'] ?? '').toString().trim().toUpperCase();
    final agencyRole = (user['C_AGENCY_JABATAN'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final canMonitorAgents =
        appRole == 'HEAD_MARKETING' ||
        appRole == 'HEAD_AGENT' ||
        agencyRole == 'KD' ||
        agencyRole == 'AD' ||
        level == '1' ||
        level == '2';

    // Backend tetap memverifikasi hak akses untuk endpoint tracking.
    if (!canMonitorAgents) {
      return Scaffold(
        headers: [
          AppBar(
            title: const Text(
              'Agent Monitoring',
              style: TextStyle(
                color: Color(0xFF14264D),
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            leading: [
              material.Tooltip(
                message: 'Kembali',
                child: IconButton(
                  variance: ButtonVariance.ghost,
                  icon: const Icon(
                    material.Icons.arrow_back_rounded,
                    size: 24,
                    color: Color(0xFF14264D),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Akses hanya tersedia untuk admin.'),
          ),
        ),
      );
    }

    final center = _agents.isNotEmpty
        ? _coordinates(_agents.first)
        : const LatLng(-6.2000, 106.8167);

    return Scaffold(
      headers: [
        AppBar(
          title: const Text(
            'Agent Monitoring',
            style: TextStyle(
              color: Color(0xFF14264D),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          leading: [
            material.Tooltip(
              message: 'Kembali',
              child: IconButton(
                variance: ButtonVariance.ghost,
                icon: const Icon(
                  material.Icons.arrow_back_rounded,
                  size: 24,
                  color: Color(0xFF14264D),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
          trailing: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: _loadAgents,
            ),
          ],
        ),
      ],
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_pageStart, _pageEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1B72D7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x260D47A1),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.users,
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
                            'Agen sedang bertugas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pantau lokasi agen secara realtime',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      constraints: const BoxConstraints(minWidth: 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_agents.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                  child: Text(
                    'Gagal memuat agen: $_error',
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 300,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: flutter_map.FlutterMap(
                      mapController: _mapController,
                      options: flutter_map.MapOptions(
                        initialCenter: center,
                        initialZoom: 11,
                      ),
                      children: [
                        flutter_map.TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.agent_inteligence',
                        ),
                        flutter_map.MarkerLayer(
                          markers: _agents.map((agent) {
                            return flutter_map.Marker(
                              point: LatLng(
                                (agent['latitude'] as num).toDouble(),
                                (agent['longitude'] as num).toDouble(),
                              ),
                              width: 52,
                              height: 60,
                              child: Builder(
                                builder: (context) {
                                  final nama = (agent['nama'] ?? 'Agen')
                                      .toString();
                                  final stambuk = agent['stambuk'];
                                  final markerColor = _agentMarkerColor(
                                    stambuk,
                                  );
                                  final suspicious =
                                      agent['locationSuspicious'] == true;

                                  return GestureDetector(
                                    onTap: () {
                                      material.showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(nama),
                                          content: Text(
                                            'Stambuk: ${stambuk ?? '-'}\n'
                                            'Kantor: ${agent['kantor'] ?? '-'}\n'
                                            'Latitude: ${agent['latitude']}\n'
                                            'Longitude: ${agent['longitude']}'
                                            '${suspicious ? '\n\nLokasi perlu diverifikasi:\n${(agent['locationWarnings'] as List? ?? []).join(', ')}' : ''}',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Tutup'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: _agentMarker(
                                      nama,
                                      suspicious
                                          ? const Color(0xFFDC2626)
                                          : markerColor,
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _lastUpdated == null
                        ? 'Belum diperbarui'
                        : 'Diperbarui pukul '
                              '${_updatedAt({'lastUpdated': _lastUpdated!.toIso8601String()})}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Daftar agen bertugas',
                    style: TextStyle(
                      color: Color(0xFF14264D),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _agents.isEmpty && !_loading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            _error == null
                                ? 'Belum ada agen aktif dengan lokasi.'
                                : 'Data agen belum dapat ditampilkan.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                        itemCount: _agents.length,
                        itemBuilder: (context, index) {
                          final agent = _agents[index];
                          final point = _coordinates(agent);
                          final nama = (agent['nama'] ?? 'Agen').toString();
                          final markerColor = _agentMarkerColor(
                            agent['stambuk'],
                          );
                          final suspicious =
                              agent['locationSuspicious'] ==
                                  true;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Card(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _animateMapToAgent(point);
                                },
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      children: [
                                        _agentMarker(
                                          nama,
                                          suspicious
                                              ? const Color(0xFFDC2626)
                                              : markerColor,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (agent['nama'] ??
                                                        agent['stambuk'] ??
                                                        'Agen')
                                                    .toString(),
                                                style: const TextStyle(
                                                  color: Color(0xFF14264D),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              if (suspicious) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Lokasi perlu diverifikasi: '
                                                  '${(agent['locationWarnings'] as List? ?? []).join(', ')}',
                                                  style: const TextStyle(
                                                    color: Color(0xFFB91C1C),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 5),
                                              Text(
                                                'Kantor: ${agent['kantor'] ?? '-'}',
                                                style: const TextStyle(
                                                  color: Color(0xFF475569),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${point.latitude.toStringAsFixed(6)}, '
                                                '${point.longitude.toStringAsFixed(6)}',
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Update: ${_updatedAt(agent)}',
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          LucideIcons.chevronRight,
                                          size: 19,
                                          color: Color(0xFF94A3B8),
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
        ),
      ),
    );
  }
}
