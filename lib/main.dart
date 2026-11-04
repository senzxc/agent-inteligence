import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/agent_tracking.dart';

import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:flutter_svg/svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'pages/agent_home.dart';
import 'pages/agent_list.dart';
import 'pages/agent_monitoring.dart';
import 'pages/agent_team_home.dart';
import 'pages/kantor_list.dart';
import 'services/api_service.dart';
import 'services/gps_tracking_service.dart';
import 'utils/agency_role.dart';
import 'utils/dashboard_route_observer.dart';
import 'utils/kantor_type.dart';

// import 'package:lottie/lottie.dart';

const List<Color> _brandGradientColors = [Color(0xFF0D47A1), Color(0xFF1565C0)];
const List<Color> _agentMonitoringGradientColors = [
  Color.fromARGB(255, 14, 139, 62),
  Color(0xFF22C55E),
];

const LinearGradient _pageBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF8FBFF), Color(0xFFEAF3FF)],
);

const BoxShadow _softComponentShadow = BoxShadow(
  color: Color(0x260F172A),
  blurRadius: 14,
  offset: Offset(0, 6),
);

AbstractButtonStyle _brandButtonStyle() {
  return ButtonStyle.primary().copyWith(
    decoration: (_, _, defaultDecoration) {
      final decoration = defaultDecoration is BoxDecoration
          ? defaultDecoration
          : const BoxDecoration();
      return decoration.copyWith(
        color: null,
        gradient: const LinearGradient(
          colors: _brandGradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: const [_softComponentShadow],
      );
    },
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const BusinessIntelligenceApp());
}

// ==========================================
// STRING EXTENSION
// ==========================================

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;

    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}

Widget statusBadge(
  BuildContext context,
  String text, {
  IconData? icon,
  bool ellipsis = false,
}) {
  final theme = Theme.of(context);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: theme.colorScheme.muted,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: theme.colorScheme.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
        ],
        if (ellipsis)
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall,
            ),
          )
        else
          Text(text, style: theme.typography.xSmall),
      ],
    ),
  );
}

material.Widget _buildBranchInfoPill({
  required material.IconData icon,
  required String label,
  bool isBlue = false,
}) {
  final color = isBlue
      ? const material.Color(0xFF1565C0)
      : const material.Color(0xFF718096);

  return material.Container(
    padding: const material.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: material.BoxDecoration(
      color: isBlue
          ? const material.Color(0xFFEAF3FF)
          : const material.Color(0xFFF3F6FA),
      borderRadius: material.BorderRadius.circular(9),
    ),
    child: material.Row(
      mainAxisSize: material.MainAxisSize.min,
      children: [
        material.Icon(icon, size: 12, color: color),
        const material.SizedBox(width: 5),
        material.ConstrainedBox(
          constraints: const material.BoxConstraints(maxWidth: 170),
          child: material.Text(
            label,
            maxLines: 1,
            overflow: material.TextOverflow.ellipsis,
            style: material.TextStyle(
              fontSize: 10.5,
              fontWeight: material.FontWeight.w700,
              color: isBlue ? color : const material.Color(0xFF596579),
            ),
          ),
        ),
      ],
    ),
  );
}

// ==========================================
// MODEL CABANG
// ==========================================

class Cabang {
  final String kode;
  final String nama;
  final String alamat;
  final String email;
  final double lat;
  final double lng;
  final String jenisKantor;
  final Map<String, dynamic>? data;

  const Cabang({
    this.kode = '',
    required this.nama,
    required this.alamat,
    required this.email,
    required this.lat,
    required this.lng,
    required this.jenisKantor,
    this.data,
  });
}

// ==========================================
// ROOT APP
// ==========================================

class BusinessIntelligenceApp extends StatelessWidget {
  const BusinessIntelligenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      navigatorObservers: [dashboardRouteObserver],

      // ========================================
      // SHADCN THEME
      // ========================================
      //
      // shadcn_flutter 0.0.55:
      // ColorSchemes.darkViolet adalah constant.
      // Jadi TIDAK menggunakan ().
      //
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,

          // ========================================
          // BACKGROUND
          // ========================================
          background: const Color(0xFFEEEEEE),
          foreground: const Color(0xFF1F2937),

          // ========================================
          // CARD
          // ========================================
          card: const Color(0xFFFFFFFF),
          cardForeground: const Color(0xFF1F2937),

          // ========================================
          // POPOVER
          // ========================================
          popover: const Color(0xFFFFFFFF),
          popoverForeground: const Color(0xFF1F2937),

          // ========================================
          // PRIMARY BLUE
          // ========================================
          primary: const Color(0xFF1565C0),
          primaryForeground: const Color(0xFFFFFFFF),

          // ========================================
          // SECONDARY
          // ========================================
          secondary: const Color(0xFFE3F2FD),
          secondaryForeground: const Color(0xFF1565C0),

          // ========================================
          // MUTED
          // ========================================
          muted: const Color(0xFFF3F4F6),
          mutedForeground: const Color(0xFF6B7280),

          // ========================================
          // ACCENT
          // ========================================
          accent: const Color(0xFFE3F2FD),
          accentForeground: const Color(0xFF1565C0),

          // ========================================
          // ERROR
          // ========================================
          destructive: const Color(0xFFDC2626),
          destructiveForeground: const Color(0xFFFFFFFF),

          // ========================================
          // BORDER & INPUT
          // ========================================
          border: const Color(0xFFE5E7EB),
          input: const Color(0xFFE5E7EB),

          // ========================================
          // FOCUS RING
          // ========================================
          ring: const Color(0xFF1565C0),

          // ========================================
          // CHART COLORS
          // ========================================
          chart1: const Color(0xFF1565C0),
          chart2: const Color(0xFF1976D2),
          chart3: const Color(0xFF42A5F5),
          chart4: const Color(0xFF0D47A1),
          chart5: const Color(0xFF64B5F6),
        ),
        radius: 0.75,
      ),

      initialRoute: '/',
      routes: {
        '/': (context) => const SessionGatePage(),
        '/home': (context) => const HomePage(),
        '/agent-tracking': (context) => const AgentTrackingPage(),
        '/agent-monitoring': (context) => const AgentMonitoringPage(),
        '/agent-list': (context) => const AgentListPage(),
        '/kantor-list': (context) => const KantorListPage(),
        '/kantor-active-map': (context) =>
            const KantorListPage(showMiniMap: true),
      },
    );
  }
}

class SessionGatePage extends StatefulWidget {
  const SessionGatePage({super.key});

  @override
  State<SessionGatePage> createState() => _SessionGatePageState();
}

class _SessionGatePageState extends State<SessionGatePage> {
  bool _isCheckingSession = true;
  bool _showLogin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _isCheckingSession = true;
      _errorMessage = null;
    });

    try {
      final storedUser = await ApiService.restoreSession();
      if (storedUser == null) {
        if (mounted) {
          setState(() {
            _isCheckingSession = false;
            _showLogin = true;
          });
        }
        return;
      }

      final user = await ApiService.getCurrentUser();
      await AgentGpsTrackingService.instance.startAfterLogin();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home', arguments: user);
    } catch (error) {
      if (!mounted) return;
      if (!ApiService.hasSession) {
        setState(() {
          _isCheckingSession = false;
          _showLogin = true;
        });
        return;
      }

      setState(() {
        _isCheckingSession = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showLogin) return const LoginPage();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      child: Center(
        child: _isCheckingSession
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage ?? 'Sesi tidak dapat dipulihkan.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Button(
                      style: _brandButtonStyle(),
                      onPressed: _restoreSession,
                      child: const Text('COBA LAGI'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ==========================================
// 1. LOGIN PAGE
// ==========================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();
  bool _isLoggingIn = false;

  void _showLoginError(String message) {
    showToast(
      context: context,
      location: ToastLocation.topRight,
      dismissible: false,
      curve: Curves.easeOutCubic,
      entryDuration: const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 3),
      builder: (context, overlay) {
        return SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.circleAlert,
                size: 18,
                color: Theme.of(context).colorScheme.destructive,
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(message)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    final stambuk = _usernameController.text.trim();
    final password = _passwordController.text;

    if (stambuk.isEmpty || password.isEmpty) {
      _showLoginError('Stambuk dan Password wajib diisi!');
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      final result = await ApiService.login(stambuk, password);
      final statusCode = result['statusCode'];
      final data = result['data'];

      if (statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['success'] == true &&
          data['user'] is Map) {
        if (!mounted) return;

        try {
          final user = Map<String, dynamic>.from(data['user'] as Map);
          // GPS wajib aktif sebelum user masuk ke halaman utama.
          await AgentGpsTrackingService.instance.startAfterLogin();
          await ApiService.saveSession(user);

          if (!mounted) return;

          Navigator.pushReplacementNamed(context, '/home', arguments: user);
        } catch (error) {
          if (!mounted) return;

          _showLoginError(error.toString().replaceFirst('Exception: ', ''));
        }
      } else {
        final message = data is Map ? data['message']?.toString() : null;
        _showLoginError(message ?? 'Stambuk atau password salah.');
      }
    } catch (error) {
      _showLoginError('Tidak dapat terhubung ke server. Periksa koneksi Anda.');
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 38, 28, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SvgPicture.asset(
                          'assets/animations/Bumiputera.svg',
                          width: 80,
                          height: 80,
                        ),
                        const SizedBox(height: 25),

                        const SizedBox(height: 6),

                        Text(
                          'Masuk dengan akun perusahaan yang terdaftar',
                          textAlign: TextAlign.center,
                          style: theme.typography.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 30),

                        Text(
                          'Stambuk',
                          style: theme.typography.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: _usernameController,
                          placeholder: const Text('Masukkan Stambuk'),
                          features: [
                            InputLeadingFeature(
                              Icon(LucideIcons.user, size: 18),
                            ),
                          ],
                        ),

                        const SizedBox(height: 13),

                        Text(
                          'Password',
                          style: theme.typography.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          placeholder: const Text('Masukkan password'),
                          features: [
                            InputLeadingFeature(
                              Icon(LucideIcons.keyRound, size: 18),
                            ),

                            const InputPasswordToggleFeature(),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              showToast(
                                context: context,
                                builder: (context, overlay) {
                                  return const SurfaceCard(
                                    child: Text(
                                      "Fitur lupa password akan segera hadir.",
                                    ),
                                  );
                                },
                                location: ToastLocation.topRight,
                              );
                            },
                            child: const Text(
                              'Lupa Password?',
                              style: TextStyle(
                                color: Color(0xFF1565C0),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Button(
                          style: _brandButtonStyle(),
                          onPressed: _isLoggingIn ? null : _handleLogin,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('MASUK'),
                              const SizedBox(width: 7),
                              if (_isLoggingIn)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    '© Agent Intelligence Tracker 2026',
                    textAlign: TextAlign.center,
                    style: theme.typography.xSmall.copyWith(
                      color: theme.colorScheme.mutedForeground,
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

void _showLogoutDialog(BuildContext context) {
  final theme = Theme.of(context);

  showOverlay(
    context,
    const DialogConfiguration(
      barrierDismissible: true,
      barrierColor: Color.fromRGBO(0, 0, 0, 0.54),
    ),
    builder: (dialogContext) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ModalContainer(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ====================================
                  // HEADER MERAH
                  // ====================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    decoration: const BoxDecoration(color: Color(0xFFDC2626)),
                    child: Column(
                      children: [
                        // ICON
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.logOut,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // TITLE
                        const Text(
                          'Yakin ingin keluar?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ====================================
                  // BODY PUTIH
                  // ====================================
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.card,
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                    child: Column(
                      children: [
                        Text(
                          'Anda akan keluar dari sesi saat ini. '
                          'Pastikan semua pekerjaan yang sedang '
                          'dilakukan telah selesai sebelum keluar '
                          'dari aplikasi.',
                          textAlign: TextAlign.center,
                          style: theme.typography.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ==================================
                        // BUTTONS
                        // ==================================
                        Row(
                          children: [
                            // ==============================
                            // BATAL
                            // ==============================

                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: Button(
                                  style: const ButtonStyle.outline(),
                                  onPressed: () {
                                    closeOverlay(dialogContext);
                                  },
                                  child: const Center(child: Text('Batal')),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // ==============================
                            // KELUAR
                            // ==============================
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: ButtonStyleOverride(
                                  decoration: (_, _, defaultDecoration) {
                                    if (defaultDecoration is BoxDecoration) {
                                      return defaultDecoration.copyWith(
                                        color: const Color(0xFFDC2626),
                                      );
                                    }
                                    return const BoxDecoration(
                                      color: Color(0xFFDC2626),
                                    );
                                  },
                                  child: Button(
                                    style: const ButtonStyle.destructive(),
                                    onPressed: () async {
                                      await closeOverlay(dialogContext);
                                      if (!context.mounted) return;
                                      try {
                                        await AgentGpsTrackingService.instance
                                            .stopTracking();
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        material.ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          material.SnackBar(
                                            content: Text(
                                              'Gagal menghentikan tracking: '
                                              '${error.toString().replaceFirst('Exception: ', '')}',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      if (!context.mounted) return;
                                      await ApiService.clearSession();
                                      if (!context.mounted) return;
                                      Navigator.pushReplacement(
                                        context,
                                        ShadcnPageRoute<void>(
                                          settings: const RouteSettings(
                                            name: '/',
                                          ),
                                          builder: (context) =>
                                              const LoginPage(),
                                        ),
                                      );
                                    },
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(LucideIcons.logOut, size: 16),
                                        SizedBox(width: 6),
                                        Text('Keluar'),
                                      ],
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
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ==========================================
// 2. HOME PAGE
// ==========================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  PageRoute<dynamic>? _dashboardRoute;
  List<Map<String, dynamic>> _kantorList = [];
  bool _isLoadingKantor = true;
  bool _hasLoadedKantor = false;
  bool _canLoadDashboardStats = false;
  bool _isRefreshingDashboard = false;
  bool _isLoadingDashboardStats = true;
  int? _totalAgentCount;
  int? _onlineAgentCount;
  int? _offlineAgentCount;
  String? _dashboardStatsError;
  String? _kantorLoadError;
  bool _isAgentTrackingHovered = false;
  bool _isAgentTrackingPressed = false;
  bool _isAgentMonitoringHovered = false;
  bool _isAgentMonitoringPressed = false;

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

    if (_hasLoadedKantor) return;
    _hasLoadedKantor = true;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    final agencyRole = arguments is Map
        ? (arguments['C_AGENCY_JABATAN'] ?? '').toString().trim().toUpperCase()
        : '';
    if (['AD', 'AM', 'AS'].contains(agencyRole)) {
      _isLoadingKantor = false;
      return;
    }

    _loadKantor();

    final levelUser = arguments is Map
        ? (arguments['LEVEL_USER'] ?? arguments['level_user'] ?? '')
              .toString()
              .trim()
        : '';
    final appRole = arguments is Map
        ? (arguments['APP_ROLE'] ??
                  (agencyRole == 'KD'
                      ? 'HEAD_MARKETING'
                      : agencyRole == 'AD'
                      ? 'HEAD_AGENT'
                      : levelUser == '1'
                      ? 'HEAD_MARKETING'
                      : levelUser == '2'
                      ? 'HEAD_AGENT'
                      : ''))
              .toString()
              .trim()
              .toUpperCase()
        : '';
    _canLoadDashboardStats =
        appRole == 'HEAD_MARKETING' || appRole == 'HEAD_AGENT';
    if (_canLoadDashboardStats) {
      _loadDashboardStats();
    } else {
      _isLoadingDashboardStats = false;
    }
  }

  @override
  void didPopNext() {
    if (_canLoadDashboardStats) {
      _refreshDashboard();
    }
  }

  @override
  void dispose() {
    dashboardRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshingDashboard) return;
    setState(() => _isRefreshingDashboard = true);
    try {
      await Future.wait([
        _loadKantor(),
        if (_canLoadDashboardStats) _loadDashboardStats(),
      ]);
    } finally {
      if (mounted) setState(() => _isRefreshingDashboard = false);
    }
  }

  Future<void> _loadKantor() async {
    try {
      final result = await ApiService.getKantor();

      final statusCode = result['statusCode'];
      final data = result['data'];

      if (statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['success'] == true &&
          data['data'] is List) {
        final kantor = (data['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        if (!mounted) return;

        setState(() {
          _kantorList = kantor;
          _isLoadingKantor = false;
          _kantorLoadError = null;
        });

        debugPrint('Jumlah kantor: ${_kantorList.length}');
        debugPrint('Data kantor: $_kantorList');
      } else {
        if (!mounted) return;

        setState(() {
          _isLoadingKantor = false;
          _kantorLoadError = data is Map
              ? data['message']?.toString() ?? 'Gagal memuat data kantor.'
              : 'Format respons data kantor tidak valid.';
        });

        debugPrint('Gagal mengambil data kantor: ${data['message']}');
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingKantor = false;
        _kantorLoadError = error.toString().replaceFirst('Exception: ', '');
      });

      debugPrint('Error get kantor: $error');
    }
  }

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    if (!_isLoadingDashboardStats || _dashboardStatsError != null) {
      setState(() {
        _isLoadingDashboardStats = true;
        _dashboardStatsError = null;
      });
    }

    try {
      final response = await ApiService.getDashboardAgentStats();
      final responseData = response['data'];
      if (responseData is! Map ||
          responseData['success'] != true ||
          responseData['data'] is! Map) {
        throw Exception(
          responseData is Map
              ? responseData['message']?.toString() ??
                    'Format respons statistik agen tidak valid.'
              : 'Format respons statistik agen tidak valid.',
        );
      }

      final stats = responseData['data'] as Map;
      final totalAgents = stats['totalAgents'];
      final onlineAgents = stats['onlineAgents'];
      final offlineAgents = stats['offlineAgents'];
      if (totalAgents is! num ||
          onlineAgents is! num ||
          offlineAgents is! num) {
        throw Exception('Data statistik agen tidak lengkap atau tidak valid.');
      }

      if (!mounted) return;
      setState(() {
        _totalAgentCount = totalAgents.toInt();
        _onlineAgentCount = onlineAgents.toInt();
        _offlineAgentCount = offlineAgents.toInt();
        _isLoadingDashboardStats = false;
        _dashboardStatsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingDashboardStats = false;
        _dashboardStatsError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _buildDashboardStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color backgroundColor,
    VoidCallback? onTap,
  }) {
    return material.Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: material.InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 19,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
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
        ),
      ),
    );
  }

  void _openAgentList({
    required Map user,
    required String appRole,
    required String statusFilter,
    required bool viewAllBranches,
    bool showIndonesiaMapButton = false,
  }) {
    final arguments = Map<String, dynamic>.from(user)
      ..['APP_ROLE'] = appRole
      ..['INITIAL_STATUS_FILTER'] = statusFilter
      ..['VIEW_ALL_BRANCHES'] = viewAllBranches
      ..['SHOW_INDONESIA_MAP_BUTTON'] = showIndonesiaMapButton;
    Navigator.pushNamed(context, '/agent-list', arguments: arguments);
  }

  Widget _buildDashboardActionTile({
    required String label,
    required IconData icon,
    required List<Color> gradientColors,
    required bool hovered,
    required bool pressed,
    required ValueChanged<bool> onHoverChanged,
    required ValueChanged<bool> onPressedChanged,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        onTap: onTap,
        onTapDown: (_) => onPressedChanged(true),
        onTapUp: (_) => onPressedChanged(false),
        onTapCancel: () => onPressedChanged(false),
        child: AnimatedScale(
          scale: pressed
              ? 0.97
              : hovered
              ? 1.02
              : 1,
          duration: const Duration(milliseconds: 140),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.22),
                  blurRadius: hovered ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 23),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  LucideIcons.chevronRight,
                  color: Colors.white,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompactLayout = MediaQuery.sizeOf(context).width < 600;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final user = arguments is Map ? arguments : const <String, dynamic>{};
    final nama = (user['NAMA_AGEN'] ?? user['NAMA'] ?? user['nama'])
        ?.toString()
        .trim();
    final displayName = nama == null || nama.isEmpty ? 'Admin Cabang' : nama;
    final namaKantor = (user['NAMA_KANTOR'] ?? user['namaKantor'])
        ?.toString()
        .trim();
    final officeName = namaKantor == null || namaKantor.isEmpty
        ? '-'
        : namaKantor;
    final levelUser = (user['LEVEL_USER'] ?? user['level_user'] ?? '')
        .toString()
        .trim();
    final agencyRoleValue = (user['C_AGENCY_JABATAN'] ?? '').toString().trim();
    final agencyRole = agencyRoleValue.toUpperCase();
    final userRoleLabel = agencyRoleValue.isNotEmpty
        ? formatAgencyRole(agencyRoleValue)
        : levelUser == '1'
        ? 'Kepala Pemasaran'
        : levelUser == '2'
        ? 'Kepala Agen'
        : levelUser == '3'
        ? 'Agen'
        : 'User';
    final appRole =
        (user['APP_ROLE'] ??
                (agencyRole == 'KD'
                    ? 'HEAD_MARKETING'
                    : agencyRole == 'AD'
                    ? 'HEAD_AGENT'
                    : ['AM', 'AS', 'WA'].contains(agencyRole)
                    ? 'AGENT'
                    : levelUser == '1'
                    ? 'HEAD_MARKETING'
                    : levelUser == '2'
                    ? 'HEAD_AGENT'
                    : levelUser == '3'
                    ? 'AGENT'
                    : 'UNKNOWN'))
            .toString()
            .trim()
            .toUpperCase();

    if (['AD', 'AM', 'AS'].contains(agencyRole)) {
      return AgentTeamHomePage(user: Map<String, dynamic>.from(user));
    }

    // const cabangList = [
    //   Cabang(
    //     nama: 'Cabang Regional Aceh',
    //     alamat: 'Jl. T. Daud Beureueh, Banda Aceh',
    //     lat: 5.5483,
    //     lng: 95.3238,
    //     status: 'Aktif Operasional',
    //   ),
    //   Cabang(
    //     nama: 'Cabang Utama Jakarta',
    //     alamat: 'Jl. Wolter Monginsidi, Jakarta Selatan',
    //     lat: -6.2378,
    //     lng: 106.8143,
    //     status: 'Pusat Headquarter',
    //   ),
    //   Cabang(
    //     nama: 'Cabang Operasional Bekasi',
    //     alamat: 'Jl. Ahmad Yani, Kota Bekasi',
    //     lat: -6.2383,
    //     lng: 106.9756,
    //     status: 'Aktif Operasional',
    //   ),
    // ];

    // POV AGEN BIASA
    if (appRole == 'AGENT') {
      return AgentHomePage(user: Map<String, dynamic>.from(user));
    }

    final cabangList = _kantorList.map((kantor) {
      return Cabang(
        kode: kantor['KODE_KANTOR']?.toString() ?? '',
        nama: kantor['NAMA_KANTOR']?.toString() ?? '-',
        alamat:
            (kantor['ALAMAT_KANTOR_MUTASI'] ?? kantor['ALAMAT_KANTOR'])
                ?.toString() ??
            '-',
        email: kantor['EMAIL']?.toString() ?? '-',
        lat: (kantor['LATITUDE'] as num?)?.toDouble() ?? 0.0,
        lng: (kantor['LONGITUDE'] as num?)?.toDouble() ?? 0.0,
        jenisKantor: kantor['KODE_JENIS_KANTOR']?.toString() ?? '',
        data: kantor,
      );
    }).toList();
    final previewCabangList = cabangList.take(5).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      headerBackgroundColor: Colors.transparent,
      headers: [
        AppBar(
          backgroundColor: Colors.transparent,
          trailing: [
            IconButton(
              variance: ButtonVariance.ghost,
              onPressed: _isRefreshingDashboard ? null : _refreshDashboard,
              icon: _isRefreshingDashboard
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1565C0),
                      ),
                    )
                  : const Icon(
                      LucideIcons.refreshCw,
                      size: 18,
                      color: Color(0xFF1565C0),
                    ),
            ),
            IconButton(
              variance: ButtonVariance.ghost,
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(
                LucideIcons.logOut,
                size: 18,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ],
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _pageBackgroundGradient),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  isCompactLayout ? 14 : 20,
                ),
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
                            LucideIcons.user,
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
                                style: theme.typography.small.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // INFORMASI ID AGEN
                    Row(
                      children: [
                        Icon(
                          material.Icons.badge_outlined,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ID: ${(user['I_AGEN'] ?? user['NOMOR_AGEN'] ?? user['STAMBUK'] ?? user['stambuk'] ?? '-').toString()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.small.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 9),

                    // INFORMASI KANTOR
                    Row(
                      children: [
                        Icon(
                          material.Icons.business_outlined,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kantor: $officeName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.small.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 9),

                    // INFORMASI JABATAN
                    Row(
                      children: [
                        Icon(
                          material.Icons.work_outline,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Jabatan: $userRoleLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.small.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  isCompactLayout ? 8 : 16,
                  16,
                  0,
                ),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: isCompactLayout ? 8 : 10,
                  childAspectRatio: 3.00,
                  children: [
                    _buildDashboardStatTile(
                      icon: LucideIcons.building2,
                      label: 'Kantor Aktif',
                      value: _isLoadingKantor
                          ? '...'
                          : _kantorLoadError == null
                          ? '${_kantorList.length}'
                          : '—',
                      color: const Color(0xFF1565C0),
                      backgroundColor: const Color(0xFFEAF3FF),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/kantor-active-map',
                        arguments: user,
                      ),
                    ),
                    // _buildDashboardActionTile(
                    //   label: 'Mulai Bertugas Agen',
                    //   icon: LucideIcons.mapPin,
                    //   gradientColors: _brandGradientColors,
                    //   hovered: _isAgentTrackingHovered,
                    //   pressed: _isAgentTrackingPressed,
                    //   onHoverChanged: (value) {
                    //     setState(() => _isAgentTrackingHovered = value);
                    //   },
                    //   onPressedChanged: (value) {
                    //     setState(() => _isAgentTrackingPressed = value);
                    //   },
                    //   onTap: () {
                    //     Navigator.pushNamed(context, '/agent-tracking');
                    //   },
                    // ),
                    _buildDashboardStatTile(
                      icon: LucideIcons.users,
                      label: 'Total Agen',
                      value: _isLoadingDashboardStats
                          ? '...'
                          : '${_totalAgentCount ?? '—'}',
                      color: const Color(0xFF7C3AED),
                      backgroundColor: const Color(0xFFF3E8FF),
                      onTap: () => _openAgentList(
                        user: user,
                        appRole: appRole,
                        statusFilter: 'all',
                        viewAllBranches: appRole == 'HEAD_MARKETING',
                        showIndonesiaMapButton: true,
                      ),
                    ),
                    // if (appRole == 'HEAD_MARKETING' || appRole == 'HEAD_AGENT')
                    //   _buildDashboardActionTile(
                    //     label: 'Pantau Lokasi Agen',
                    //     icon: LucideIcons.map,
                    //     gradientColors: _agentMonitoringGradientColors,
                    //     hovered: _isAgentMonitoringHovered,
                    //     pressed: _isAgentMonitoringPressed,
                    //     onHoverChanged: (value) {
                    //       setState(() => _isAgentMonitoringHovered = value);
                    //     },
                    //     onPressedChanged: (value) {
                    //       setState(() => _isAgentMonitoringPressed = value);
                    //     },
                    //     onTap: () {
                    //       Navigator.pushNamed(
                    //         context,
                    //         '/agent-monitoring',
                    //         arguments: user,
                    //       );
                    //     },
                    //   ),
                    _buildDashboardStatTile(
                      icon: material.Icons.wifi_rounded,
                      label: 'Agen Online',
                      value: _isLoadingDashboardStats
                          ? '...'
                          : '${_onlineAgentCount ?? '—'}',
                      color: const Color(0xFF15803D),
                      backgroundColor: const Color(0xFFDCFCE7),
                      onTap: () => _openAgentList(
                        user: user,
                        appRole: appRole,
                        statusFilter: 'online',
                        viewAllBranches: appRole == 'HEAD_MARKETING',
                        showIndonesiaMapButton: true,
                      ),
                    ),
                    _buildDashboardStatTile(
                      icon: material.Icons.wifi_off_rounded,
                      label: 'Agen Offline',
                      value: _isLoadingDashboardStats
                          ? '...'
                          : '${_offlineAgentCount ?? '—'}',
                      color: const Color(0xFF64748B),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onTap: () => _openAgentList(
                        user: user,
                        appRole: appRole,
                        statusFilter: 'offline',
                        viewAllBranches: appRole == 'HEAD_MARKETING',
                        showIndonesiaMapButton: true,
                      ),
                    ),
                  ],
                ),
              ),
              if (_dashboardStatsError != null || _kantorLoadError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          material.Icons.info_outline_rounded,
                          color: Color(0xFFC2410C),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              if (_kantorLoadError != null)
                                'Kantor: $_kantorLoadError',
                              if (_dashboardStatsError != null)
                                'Statistik agen: $_dashboardStatsError',
                            ].join(' '),
                            style: const TextStyle(
                              color: Color(0xFF9A3412),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        material.IconButton(
                          tooltip: 'Muat ulang statistik',
                          visualDensity: material.VisualDensity.compact,
                          onPressed: () {
                            _refreshDashboard();
                          },
                          icon: const Icon(
                            material.Icons.refresh_rounded,
                            color: Color(0xFFC2410C),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  isCompactLayout ? 12 : 20,
                  20,
                  isCompactLayout ? 8 : 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daftar Cabang Perusahaan',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    material.TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/kantor-list',
                          arguments: user,
                        );
                      },
                      icon: const Icon(material.Icons.arrow_forward, size: 17),
                      label: const Text(
                        'Lihat semua',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingKantor)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: previewCabangList.length,
                  itemBuilder: (context, index) {
                    final cabang = previewCabangList[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ButtonStyleOverride(
                        decoration: (_, _, defaultDecoration) {
                          if (defaultDecoration is BoxDecoration) {
                            return defaultDecoration.copyWith(
                              boxShadow: const [_softComponentShadow],
                            );
                          }
                          return defaultDecoration;
                        },
                        child: CardButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/agent-list',
                              arguments: {
                                'KODE_KANTOR': cabang.kode,
                                'NAMA_KANTOR': cabang.nama,
                                'ALAMAT_KANTOR': cabang.alamat,
                                'LATITUDE': cabang.lat,
                                'LONGITUDE': cabang.lng,
                                'DATA_KANTOR': cabang.data,
                                'APP_ROLE': appRole,
                                'LEVEL_USER': levelUser,
                              },
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  material.Icons.storefront_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cabang.nama,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      cabang.alamat,
                                      style: theme.typography.xSmall.copyWith(
                                        color:
                                            theme.colorScheme.mutedForeground,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 6,
                                      children: [
                                        _buildBranchInfoPill(
                                          icon: material.Icons.tag_rounded,
                                          label: cabang.kode,
                                        ),
                                        _buildBranchInfoPill(
                                          icon: material
                                              .Icons
                                              .check_circle_outline_rounded,
                                          label: jenisKantorLabel(
                                            cabang.jenisKantor,
                                          ),
                                          isBlue: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                LucideIcons.chevronRight,
                                color: theme.colorScheme.mutedForeground,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (!_isLoadingKantor)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: material.OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/kantor-list',
                        arguments: user,
                      );
                    },
                    style: material.OutlinedButton.styleFrom(
                      foregroundColor: const material.Color(0xFF1565C0),
                      backgroundColor: material.Colors.white,
                      minimumSize: const material.Size(double.infinity, 50),
                      side: const material.BorderSide(
                        color: material.Color(0xFFBBD5F5),
                      ),
                      shape: material.RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const material.Icon(
                      material.Icons.storefront_rounded,
                    ),
                    label: const Text(
                      'Lihat Seluruh Cabang',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. MAPS PAGE
// ==========================================

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage>
    with SingleTickerProviderStateMixin {
  final flutter_map.MapController _mapController = flutter_map.MapController();
  late final AnimationController _centerAnimationController;
  LatLng? _animationStartCenter;
  LatLng? _animationTargetCenter;
  double _animationStartZoom = 15;

  @override
  void initState() {
    super.initState();
    _centerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(_updateMapCenterAnimation);
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

  void _animateMapToBranch(LatLng targetLocation) {
    _animationStartCenter = _mapController.camera.center;
    _animationTargetCenter = targetLocation;
    _animationStartZoom = _mapController.camera.zoom;
    _centerAnimationController.forward(from: 0);
  }

  @override
  void dispose() {
    _centerAnimationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Cabang cabangData =
        ModalRoute.of(context)?.settings.arguments as Cabang? ??
        const Cabang(
          nama: 'Lokasi Cabang',
          alamat: 'Alamat tidak ditemukan',
          email: 'Email tidak ditemukan',
          lat: -6.2088,
          lng: 106.8456,
          jenisKantor: '',
        );

    final LatLng targetLocation = LatLng(cabangData.lat, cabangData.lng);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      headerBackgroundColor: Colors.white,
      headers: [
        AppBar(
          backgroundColor: Colors.white,
          leading: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(
                LucideIcons.arrowLeft,
                size: 20,
                color: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
          title: Text(
            cabangData.nama,
            style: theme.typography.p.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],

      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _pageBackgroundGradient),
        child: Stack(
          children: [
            // ========================================
            // MAP
            // ========================================

            flutter_map.FlutterMap(
              mapController: _mapController,
              options: flutter_map.MapOptions(
                initialCenter: targetLocation,
                initialZoom: 15,
              ),
              children: [
                flutter_map.TileLayer(
                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.devasatrio.bi_cabang_tracker',
                ),

                // ==================================
                // MARKER
                // ==================================
                flutter_map.MarkerLayer(
                  markers: [
                    flutter_map.Marker(
                      point: targetLocation,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: _brandGradientColors,
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
                        child: Icon(
                          LucideIcons.mapPin,
                          color: theme.colorScheme.primaryForeground,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ========================================
            // FLOATING INFO CARD
            // ========================================
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [_softComponentShadow],
                ),
                child: Card(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================================
                      // TITLE
                      // ================================

                      Row(
                        children: [
                          Icon(
                            LucideIcons.building,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              cabangData.nama,
                              style: theme.typography.p.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ================================
                      // ADDRESS
                      // ================================
                      Text(
                        cabangData.alamat,
                        style: theme.typography.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          // ================================
                          // STATUS
                          // ================================

                          statusBadge(
                            context,
                            jenisKantorLabel(cabangData.jenisKantor),
                          ),

                          const SizedBox(width: 5),

                          // ================================
                          // EMAIL
                          // ================================
                          Flexible(
                            child: statusBadge(
                              context,
                              cabangData.email,
                              ellipsis: true,
                            ),
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),

                      SizedBox(height: 8),

                      // ================================
                      // COORDINATE
                      // ================================
                      statusBadge(
                        context,
                        'Koordinat: ${cabangData.lat}, ${cabangData.lng}',
                      ),

                      const SizedBox(height: 16),

                      // ================================
                      // CENTER MAP
                      // ================================
                      SizedBox(
                        width: double.infinity,
                        child: Button(
                          style: _brandButtonStyle(),
                          onPressed: () {
                            _animateMapToBranch(targetLocation);
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.locate, size: 18),
                              SizedBox(width: 8),
                              Text('Pusatkan ke Titik Cabang'),
                            ],
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
    );
  }
}
