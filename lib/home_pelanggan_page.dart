// lib/home_pelanggan_page.dart
// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/login_page.dart'; 
import 'package:pdam_app/view_profil_page.dart'; // **IMPORT HALAMAN BARU**

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
    {
      'icon': Ionicons.camera_outline,
      'title': 'Lapor Foto Meter',
      'subtitle': 'Kirim foto meteran Anda',
      'route': '/lapor_foto_meter',
    },
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

  Color _darkenColor(Color color, [double amount = .15]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

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
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double iconSize = constraints.maxWidth * 0.22;
        double titleFontSize = constraints.maxWidth * 0.1;
        double subtitleFontSize = constraints.maxWidth * 0.08;

        iconSize = iconSize.clamp(32.0, 40.0);
        titleFontSize = titleFontSize.clamp(
          15.0,
          18.0,
        );
        subtitleFontSize = subtitleFontSize.clamp(
          12.0,
          14.0,
        );

        return Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      iconSize * 0.3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(
                        0.18,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: iconSize, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: subtitleFontSize,
                        color:
                            Colors.grey.shade700,
                        height: 1.3,
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
    return FadeInAnimation(
      delay: 0.1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16.0,
          50.0,
          16.0,
          16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Halo,',
              style: GoogleFonts.lato(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(
                  0.9,
                ),
              ),
            ),
            Text(
              _userData?['nama']?.toString().capitalize() ?? 'Pelanggan',
              style: GoogleFonts.lato(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
        delay: 0.5 + (_menuItems.length * 0.08),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.tertiary.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            gradient: LinearGradient(
              colors: [
                colorScheme.tertiary,
                _darkenColor(colorScheme.tertiary, 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/temuan_kebocoran');
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Ionicons.warning_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Lapor Temuan Kebocoran",
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
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
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              "Oops!",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ??
                  "Terjadi kesalahan tidak diketahui. Silakan coba lagi.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 28),
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
      colorScheme.tertiary,
      colorScheme.secondary,
      colorScheme.primary,
      Colors.orange.shade700,
      colorScheme.error,
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
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 220.0,
                      floating: true,
                      pinned: true,
                      snap: false,
                      elevation: 4.0,
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      actions: [
                        // **INI PERUBAHAN UTAMANYA**
                        IconButton(
                          icon: Icon(
                            Ionicons.person_circle_outline,
                            color: colorScheme.onPrimary,
                            size: 26,
                          ),
                          tooltip: 'Profil Saya',
                          onPressed: () async {
                            // Navigasi ke halaman ViewProfilPage dan tunggu hasilnya
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ViewProfilPage()),
                            );

                            // Jika ViewProfilPage atau ProfilPage mengembalikan true,
                            // itu artinya ada update, maka refresh data di sini
                            if (result == true && mounted) {
                              _loadUserData();
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Ionicons.log_out_outline,
                            color: colorScheme.onErrorContainer,
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
                            return AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity:
                                  constraints.biggest.height <
                                          kToolbarHeight + 40
                                      ? 1.0
                                      : 0.0,
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
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _darkenColor(
                                      colorScheme.primary,
                                      0.2,
                                    ),
                                    colorScheme.primary,
                                    _lightenColor(
                                      colorScheme.primary,
                                      0.1,
                                    ),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            _buildWelcomeHeader(
                              colorScheme,
                            ),
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
                          FadeInAnimation(
                            delay: 0.2,
                            slideDistance: 0.05,
                            child: Text(
                              "Menu Layanan Utama",
                              style: GoogleFonts.lato(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
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
                                  : 2,
                          crossAxisSpacing: 16.0,
                          mainAxisSpacing: 16.0,
                          childAspectRatio: 0.95,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = _menuItems[index];
                          return FadeInAnimation(
                            delay: 0.25 + (index * 0.08),
                            slideDistance: 0.05,
                            child: _buildFeatureCard(
                              icon: item['icon'] as IconData,
                              title: item['title'] as String,
                              subtitle: item['subtitle'] as String,
                              color: menuColors[index % menuColors.length],
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

class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final double delay;
  final double slideDistance;

  const FadeInAnimation({
    super.key,
    required this.child,
    this.delay = 0.0,
    this.slideDistance = 0.1,
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
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutSine),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideDistance),
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}