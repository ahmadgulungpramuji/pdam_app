// lib/home_pelanggan_page.dart
// ignore_for_file: unused_element // Untuk _showSnackbar jika tidak ada error handling lain

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/login_page.dart'; // Untuk navigasi saat logout

class HomePelangganPage extends StatefulWidget {
  const HomePelangganPage({super.key});

  @override
  State<HomePelangganPage> createState() => _HomePelangganPageState();
}

class _HomePelangganPageState extends State<HomePelangganPage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;

  final List<Map<String, dynamic>> _menuItems = [
    {
      'icon': Ionicons.document_text_outline,
      'title': 'Buat Laporan',
      'subtitle': 'Keluhan & masalah layanan',
      'route': '/buat_laporan',
    },
    {
      'icon': Ionicons.search_circle_outline,
      'title': 'Lacak Laporan',
      'subtitle': 'Lihat progres laporan',
      'route': '/lacak_laporan_saya',
    },
    {
      'icon': Ionicons.receipt_outline,
      'title': 'Info Tagihan',
      'subtitle': 'Cek tunggakan & ID',
      'route': '/cek_tunggakan',
    },
    // --- ITEM MENU BARU ---
    {
      'icon': Ionicons.camera_outline, // <-- IKON BARU
      'title': 'Lapor Foto Meter', // <-- JUDUL BARU
      'subtitle': 'Kirim foto meteran Anda', // <-- SUBTITLE BARU
      'route': '/lapor_foto_meter', // <-- ROUTE BARU
    },
    // ----------------------
    {
      'icon': Ionicons.chatbubbles_outline,
      'title': 'Hubungi Kami',
      'subtitle': 'Admin & info PDAM',
      'route': '/chat_page',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.getUserProfile();
      if (mounted) {
        if (data != null) {
          setState(() {
            _userData = data;
            _isLoading = false;
          });
        } else {
          _showSnackbar(
            'Gagal memuat data pengguna. Sesi mungkin telah berakhir.',
            isError: true,
          );
          await _logout();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Tidak dapat memuat data Anda. Periksa koneksi internet dan coba lagi.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 10),
      ),
    );
  }

  // Helper function to darken a Color
  Color _darkenColor(Color color, [double amount = .15]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  // Helper function to lighten a Color
  Color _lightenColor(Color color, [double amount = .15]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    return hslLight.toColor();
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color, // Color now comes from parent build method
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Make icon and font sizes responsive
        double iconSize = constraints.maxWidth * 0.22;
        double titleFontSize = constraints.maxWidth * 0.1;
        double subtitleFontSize = constraints.maxWidth * 0.08;

        // Clamp values to ensure they don't get too small or too large
        iconSize = iconSize.clamp(32.0, 40.0); // Slightly larger icons
        titleFontSize = titleFontSize.clamp(
          15.0,
          18.0,
        ); // Slightly larger title
        subtitleFontSize = subtitleFontSize.clamp(
          12.0,
          14.0,
        ); // Slightly larger subtitle

        return Card(
          elevation: 4.0, // Increased elevation for more depth
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // More rounded corners
          ),
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ), // Adjusted padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      iconSize * 0.3,
                    ), // Adjusted padding relative to icon size
                    decoration: BoxDecoration(
                      color: color.withOpacity(
                        0.18,
                      ), // Increased opacity for background color
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: iconSize, color: color),
                  ),
                  const SizedBox(height: 12), // Increased spacing
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800, // Bolder title font
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6), // Increased spacing
                  Expanded(
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: subtitleFontSize,
                        color:
                            Colors
                                .grey
                                .shade700, // Darker grey for better readability
                        height: 1.3, // Slightly increased line height
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildWelcomeHeader(ColorScheme colorScheme) {
    // This widget is now placed inside FlexibleSpaceBar, its styles adapt to that context.
    return FadeInAnimation(
      delay: 0.1, // Animasi muncul setelah 0.1 detik
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16.0,
          50.0,
          16.0,
          16.0,
        ), // Padding to keep content from edge and below app bar title
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              MainAxisAlignment
                  .end, // Align content to the bottom of the flexible space
          children: [
            Text(
              'Halo,',
              style: GoogleFonts.lato(
                fontSize: 24, // Larger font for "Halo,"
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(
                  0.9,
                ), // White with slight transparency for header text
              ),
            ),
            Text(
              _userData?['nama']?.toString().capitalize() ?? 'Pelanggan',
              style: GoogleFonts.lato(
                fontSize: 32, // More prominent name
                fontWeight: FontWeight.bold,
                color: Colors.white, // Pure white for the name
                height: 1.2,
              ),
            ),
            if (_userData?['email'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Ionicons.mail_outline, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    _userData!['email'],
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLaporTemuanButton(ColorScheme colorScheme) {
    return Center(
      child: FadeInAnimation(
        delay:
            0.5 +
            (_menuItems.length * 0.08), // Animasi muncul setelah semua kartu
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.tertiary.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4), // Shadow for depth
              ),
            ],
            gradient: LinearGradient(
              // Subtle gradient for a modern look
              colors: [
                colorScheme.tertiary,
                _darkenColor(colorScheme.tertiary, 0.15),
              ], // Use the helper to darken
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Material(
            color: Colors.transparent, // Important for InkWell ripple effect
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/temuan_kebocoran');
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 16,
                ), // More generous padding
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Make row wrap its content
                  children: [
                    Icon(
                      Ionicons.warning_outline,
                      color: Colors.white,
                      size: 24, // Larger icon
                    ),
                    const SizedBox(width: 12), // Spacing between icon and text
                    Text(
                      "Lapor Temuan Kebocoran",
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontWeight: FontWeight.w700, // Bolder text
                        fontSize: 16, // Larger text
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

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Ionicons.cloud_offline_outline,
              size: 80, // Larger icon for emphasis
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              "Oops!",
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ??
                  "Terjadi kesalahan tidak diketahui. Silakan coba lagi.", // More descriptive message
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 28), // Increased spacing
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh_outline, size: 20),
              label: Text(
                "Coba Lagi",
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loadUserData,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<Color> menuColors = [
      colorScheme.tertiary, // Buat Laporan
      colorScheme.secondary, // Lacak Laporan
      colorScheme.primary, // Info Tagihan
      Colors.orange.shade700, // Lapor Foto Meter (Warna Baru)
      colorScheme.error, // Hubungi Kami (atau warna lain yang sesuai)
    ];

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                onRefresh: _loadUserData,
                color: colorScheme.primary,
                child: CustomScrollView(
                  // Use CustomScrollView for flexible app bar and slivers
                  slivers: [
                    SliverAppBar(
                      expandedHeight:
                          220.0, // Increased expanded height for more space
                      floating: true,
                      pinned:
                          true, // App bar will pin at the top when scrolled up
                      snap: false,
                      elevation: 4.0, // Add a subtle shadow
                      backgroundColor:
                          colorScheme
                              .primary, // Default background color when collapsed
                      foregroundColor: colorScheme.onPrimary, // Icon/text color
                      actions: [
                        IconButton(
                          icon: Icon(
                            Ionicons.person_circle_outline,
                            color:
                                colorScheme
                                    .onPrimary, // White icon when expanded, adapts on collapse
                            size: 26,
                          ),
                          tooltip: 'Profil Saya',
                          onPressed: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/profil_page',
                            );
                            if (result == true && mounted) {
                              _loadUserData();
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Ionicons.log_out_outline,
                            color:
                                colorScheme
                                    .onErrorContainer, // A more distinct error color for logout
                            size: 26,
                          ),
                          tooltip: 'Logout',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text('Konfirmasi Logout'),
                                    content: const Text(
                                      'Apakah Anda yakin ingin keluar dari akun ini?',
                                    ),
                                    actionsAlignment: MainAxisAlignment.end,
                                    actions: [
                                      TextButton(
                                        child: const Text('Batal'),
                                        onPressed:
                                            () => Navigator.of(ctx).pop(),
                                      ),
                                      TextButton(
                                        child: Text(
                                          'Logout',
                                          style: TextStyle(
                                            color: colorScheme.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          _logout();
                                        },
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        centerTitle: false,
                        titlePadding: const EdgeInsets.only(
                          left: 16.0,
                          bottom: 16.0,
                        ),
                        title: LayoutBuilder(
                          builder: (context, constraints) {
                            // Dynamically change title visibility or style based on collapse
                            // This will make 'Beranda' appear/disappear smoothly
                            return AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity:
                                  constraints.biggest.height <
                                          kToolbarHeight + 40
                                      ? 1.0
                                      : 0.0, // Show 'Beranda' when collapsed
                              child: Text(
                                'Beranda',
                                style: GoogleFonts.lato(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimary,
                                  fontSize: 20,
                                ),
                              ),
                            );
                          },
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Background image or gradient for the header area
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  // Menggunakan fungsi _darkenColor dan _lightenColor
                                  colors: [
                                    _darkenColor(
                                      colorScheme.primary,
                                      0.2,
                                    ), // Lebih gelap dari primary
                                    colorScheme.primary,
                                    _lightenColor(
                                      colorScheme.primary,
                                      0.1,
                                    ), // Sedikit lebih terang dari primary
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            // You can add an image here for more branding
                            // Image.asset(
                            //   'assets/images/water_patterns.png', // Replace with a water-related illustration
                            //   fit: BoxFit.cover,
                            //   opacity: const AlwaysStoppedAnimation(0.2), // Subtle overlay
                            // ),
                            _buildWelcomeHeader(
                              colorScheme,
                            ), // Your welcome header
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16.0,
                        20.0,
                        16.0,
                        16.0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Animasi untuk judul "Menu Layanan Utama"
                          FadeInAnimation(
                            delay: 0.2, // Muncul setelah header
                            slideDistance: 0.05, // Sedikit geser ke atas
                            child: Text(
                              "Menu Layanan Utama",
                              style: GoogleFonts.lato(
                                fontSize: 20, // Slightly larger heading
                                fontWeight: FontWeight.w700, // Bolder
                                color: colorScheme.onSurface, // Main text color
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 600
                                  ? 3
                                  : 2, // Responsive grid: 3 columns on wider screens, 2 on smaller
                          crossAxisSpacing: 16.0, // Increased spacing
                          mainAxisSpacing: 16.0, // Increased spacing
                          childAspectRatio:
                              0.95, // Slightly adjusted for better card height
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = _menuItems[index];
                          return FadeInAnimation(
                            delay:
                                0.25 +
                                (index *
                                    0.08), // Animasi tertunda untuk setiap kartu
                            slideDistance: 0.05, // Setiap kartu geser sedikit
                            child: _buildFeatureCard(
                              icon: item['icon'] as IconData,
                              title: item['title'] as String,
                              subtitle: item['subtitle'] as String,
                              color:
                                  menuColors[index %
                                      menuColors
                                          .length], // Assign color from our list
                              onTap: () {
                                if (item['route'] != null) {
                                  Navigator.pushNamed(
                                    context,
                                    item['route'] as String,
                                  );
                                }
                              },
                            ),
                          );
                        }, childCount: _menuItems.length),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16.0,
                        30.0,
                        16.0,
                        20.0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildLaporTemuanButton(colorScheme),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

// Widget Animasi Sederhana (bisa diletakkan di file terpisah jika sering dipakai)
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final double delay;
  final double slideDistance; // Menambahkan parameter slideDistance

  const FadeInAnimation({
    super.key,
    required this.child,
    this.delay = 0.0,
    this.slideDistance = 0.1, // Default slide distance
  });

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400), // Durasi animasi lebih cepat
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutSine),
    ); // Kurva animasi lebih smooth

    _slideAnimation = Tween<Offset>(
      begin: Offset(
        0,
        widget.slideDistance,
      ), // Menggunakan slideDistance dari widget
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutSine));

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

// Extension untuk capitalize (jika belum ada global)
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
