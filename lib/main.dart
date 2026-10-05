import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
      title: 'BI Tracker Cabang',
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
          brightness: Brightness.dark,
          background: const Color(0xFF09090B),
          foreground: const Color(0xFFFAFAFA),

          card: const Color(0xFF18181B),
          cardForeground: const Color(0xFFFAFAFA),

          popover: const Color(0xFF18181B),
          popoverForeground: const Color(0xFFFAFAFA),

          primary: const Color(0xFF8B5CF6),
          primaryForeground: const Color(0xFFFFFFFF),

          secondary: const Color(0xFF27272A),
          secondaryForeground: const Color(0xFFFAFAFA),

          muted: const Color(0xFF27272A),
          mutedForeground: const Color(0xFFA1A1AA),

          accent: const Color(0xFF27272A),
          accentForeground: const Color(0xFFFAFAFA),

          destructive: const Color(0xFFEF4444),
          destructiveForeground: const Color(0xFFFFFFFF),

          border: const Color(0xFF27272A),
          input: const Color(0xFF27272A),
          ring: const Color(0xFF8B5CF6),

          chart1: const Color(0xFF8B5CF6),
          chart2: const Color(0xFFA78BFA),
          chart3: const Color(0xFFC4B5FD),
          chart4: const Color(0xFF7C3AED),
          chart5: const Color(0xFF6D28D9),
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
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ====================================
                  // LOGO
                  // ====================================

                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.building2,
                        size: 42,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ====================================
                  // TITLE
                  // ====================================
                  Text(
                    'BI Tracker Cabang',
                    textAlign: TextAlign.center,
                    style: theme.typography.h3.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Masuk dengan akun perusahaan yang terdaftar',
                    textAlign: TextAlign.center,
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),

                  const SizedBox(height: 32),

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
                      InputLeadingFeature(Icon(LucideIcons.keyRound, size: 18)),

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
                      children: [
                        Text('MASUK KE DASHBOARD'),
                        SizedBox(width: 8),
                        Icon(LucideIcons.arrowRight, size: 16),
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

// ==========================================
// 2. HOME PAGE
// ==========================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String username =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'Admin Cabang';

    final List<Cabang> cabangList = [
      const Cabang(
        nama: 'Cabang Regional Aceh',
        alamat: 'Jl. T. Daud Beureueh, Banda Aceh',
        lat: 5.5483,
        lng: 95.3238,
        status: 'Aktif Operasional',
      ),
      const Cabang(
        nama: 'Cabang Utama Jakarta',
        alamat: 'Jl. Wolter Monginsidi, Jakarta Selatan',
        lat: -6.2378,
        lng: 106.8143,
        status: 'Pusat Headquarter',
      ),
      const Cabang(
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
          title: const Text('Dashboard BI Cabang'),
          trailing: [
            OutlineButton(
              density: ButtonDensity.compact,
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.logOut, size: 16),
                  SizedBox(width: 6),
                  Text('Keluar'),
                ],
              ),
            ),
          ],
        ),
      ],

      // ========================================
      // CONTENT
      // ========================================
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================================
          // WELCOME BANNER
          // ======================================

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

          // ======================================
          // SECTION TITLE
          // ======================================
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Daftar Cabang Perusahaan',
              style: theme.typography.h4.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          // ======================================
          // LIST CABANG
          // ======================================
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
                        // ========================
                        // ICON
                        // ========================

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            LucideIcons.store,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // ========================
                        // TEXT
                        // ========================
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
  final MapController _mapController = MapController();

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

          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: targetLocation, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.devasatrio.bi_cabang_tracker',
              ),

              // ==================================
              // MARKER
              // ==================================
              MarkerLayer(
                markers: [
                  Marker(
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
