import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:flutter_svg/svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

// import 'package:lottie/lottie.dart';

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

Widget statusBadge(BuildContext context, String text, {IconData? icon}) {
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
        Text(text, style: theme.typography.small),
      ],
    ),
  );
}

// ==========================================
// MODEL CABANG
// ==========================================

class Cabang {
  final String nama;
  final String alamat;
  final double lat;
  final double lng;
  final String status;

  const Cabang({
    required this.nama,
    required this.alamat,
    required this.lat,
    required this.lng,
    required this.status,
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
        '/': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/maps': (context) => const MapsPage(),
      },
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

  void _handleLogin() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isNotEmpty && password.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home', arguments: username);
    } else {
      showToast(
        context: context,
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
                const Text('Username dan Password wajib diisi!'),
              ],
            ),
          );
        },
      );
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
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                padding: const EdgeInsets.fromLTRB(28, 38, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ====================================
                    // LOTTIE ANIMATION
                    // ====================================

                    Positioned(
                      top: 0,
                      child: SvgPicture.asset(
                        'assets/animations/Bumiputera.svg',
                        width: 80,
                        height: 80,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ====================================
                    // TITLE
                    // ====================================
                    const SizedBox(height: 6),

                    Text(
                      'Masuk dengan akun perusahaan yang terdaftar',
                      textAlign: TextAlign.center,
                      style: theme.typography.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ====================================
                    // USERNAME
                    // ====================================
                    Text(
                      'Username',
                      style: theme.typography.small.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _usernameController,
                      placeholder: const Text('Masukkan username'),
                      features: [
                        InputLeadingFeature(Icon(LucideIcons.user, size: 18)),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ====================================
                    // PASSWORD
                    // ====================================
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

                    const SizedBox(height: 28),

                    // ====================================
                    // LOGIN BUTTON
                    // ====================================
                    PrimaryButton(
                      onPressed: _handleLogin,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text('MASUK'), SizedBox(width: 8)],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ====================================
                    // FOOTER
                    // ====================================
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
              borderRadius: BorderRadius.circular(16),
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
                                    onPressed: () {
                                      closeOverlay(dialogContext);

                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/',
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'Admin Cabang';

    const cabangList = [
      Cabang(
        nama: 'Cabang Regional Aceh',
        alamat: 'Jl. T. Daud Beureueh, Banda Aceh',
        lat: 5.5483,
        lng: 95.3238,
        status: 'Aktif Operasional',
      ),
      Cabang(
        nama: 'Cabang Utama Jakarta',
        alamat: 'Jl. Wolter Monginsidi, Jakarta Selatan',
        lat: -6.2378,
        lng: 106.8143,
        status: 'Pusat Headquarter',
      ),
      Cabang(
        nama: 'Cabang Operasional Bekasi',
        alamat: 'Jl. Ahmad Yani, Kota Bekasi',
        lat: -6.2383,
        lng: 106.9756,
        status: 'Aktif Operasional',
      ),
    ];

    return Scaffold(
      headers: [
        AppBar(
          trailing: [
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang Kembali,',
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username.capitalize(),
                  style: theme.typography.h2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                statusBadge(
                  context,
                  '3 Titik Cabang Aktif Terpantau Realtime',
                  icon: LucideIcons.mapPin,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Daftar Cabang Perusahaan',
              style: theme.typography.h4.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cabangList.length,
              itemBuilder: (context, index) {
                final cabang = cabangList[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/maps', arguments: cabang);
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
                            LucideIcons.store,
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
                                style: theme.typography.p.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cabang.alamat,
                                style: theme.typography.small.copyWith(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 8),
                              statusBadge(context, cabang.status),
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
                );
              },
            ),
          ),
        ],
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

class _MapsPageState extends State<MapsPage> {
  final flutter_map.MapController _mapController = flutter_map.MapController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Cabang cabangData =
        ModalRoute.of(context)?.settings.arguments as Cabang? ??
        const Cabang(
          nama: 'Lokasi Cabang',
          alamat: 'Alamat tidak ditemukan',
          lat: -6.2088,
          lng: 106.8456,
          status: 'Tidak diketahui',
        );

    final LatLng targetLocation = LatLng(cabangData.lat, cabangData.lng);

    return Scaffold(
      headers: [
        AppBar(
          leading: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.arrowLeft, size: 20),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
          title: Text(cabangData.nama),
        ),
      ],

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
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.5),
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

                  // ================================
                  // STATUS
                  // ================================
                  statusBadge(context, cabangData.status),

                  const SizedBox(height: 8),

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
                    child: PrimaryButton(
                      onPressed: () {
                        _mapController.move(targetLocation, 16);
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
        ],
      ),
    );
  }
}
