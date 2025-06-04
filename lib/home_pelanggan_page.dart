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
      'color': Colors.orange.shade700,
    },
    {
      'icon': Ionicons.search_circle_outline,
      'title': 'Lacak Laporan',
      'subtitle': 'Lihat progres laporan',
      'route': '/lacak_laporan_saya',
      'color': Colors.blue.shade700,
    },
    {
      'icon': Ionicons.receipt_outline,
      'title': 'Info Tagihan',
      'subtitle': 'Cek tunggakan & ID',
      'route': '/cek_tunggakan',
      'color': Colors.green.shade700,
    },
    {
      'icon': Ionicons.chatbubbles_outline,
      'title': 'Hubungi Kami',
      'subtitle': 'Admin & info PDAM',
      'route': '/chat_page',
      'color': Colors.purple.shade600,
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
          // Untuk Debug: Lihat struktur data yang diterima
          // print("HomePelangganPage DEBUG: User data loaded: $data");
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
        // print("HomePelangganPage: Error loading user data: $e");
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

        iconSize = iconSize.clamp(24.0, 32.0);
        titleFontSize = titleFontSize.clamp(13.0, 16.0);
        subtitleFontSize = subtitleFontSize.clamp(10.0, 12.5);

        return Card(
          elevation: 2.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(iconSize * 0.35),
                    decoration: BoxDecoration(
                      color: color.withAlpha((0.12 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: iconSize, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: subtitleFontSize,
                        color: Colors.grey.shade600,
                        height: 1.2,
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

  // ... (kode sebelumnya tetap sama)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'Beranda',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: ElevationOverlay.applySurfaceTint(
          colorScheme.surface,
          colorScheme.surfaceTint,
          3.0,
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Ionicons.person_circle_outline,
              color: colorScheme.primary,
              size: 26,
            ),
            tooltip: 'Profil Saya',
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/profil_page');
              if (result == true && mounted) {
                _loadUserData();
              }
            },
          ),
          IconButton(
            icon: Icon(
              Ionicons.log_out_outline,
              color: colorScheme.error,
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
                          onPressed: () => Navigator.of(ctx).pop(),
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
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                onRefresh: _loadUserData,
                color: colorScheme.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 16.0),
                  children: [
                    _buildWelcomeHeader(colorScheme),
                    const SizedBox(height: 28),
                    Text(
                      "Menu Layanan Utama",
                      style: GoogleFonts.lato(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14.0,
                        mainAxisSpacing: 14.0,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: _menuItems.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        return FadeInAnimation(
                          delay: 0.2 + (index * 0.08),
                          child: _buildFeatureCard(
                            icon: item['icon'] as IconData,
                            title: item['title'] as String,
                            subtitle: item['subtitle'] as String,
                            color: item['color'] as Color,
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
                      },
                    ),
                    const SizedBox(height: 30),
                    _buildLaporTemuanButton(colorScheme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }

  Widget _buildWelcomeHeader(ColorScheme colorScheme) {


    return FadeInAnimation(
      delay: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo,',
            style: GoogleFonts.lato(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            // Menggunakan key 'nama' karena itu yang dikembalikan oleh AuthController@me
            // atau UnifiedAuthController@login untuk pelanggan (username disimpan sebagai 'nama' di respons 'me')
            _userData?['nama']?.toString().capitalize() ?? 'Pelanggan',
            style: GoogleFonts.lato(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              height: 1.2,
            ),
          ),
          if (_userData?['email'] != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Ionicons.mail_outline,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  _userData!['email'], // Aman menggunakan ! karena sudah dicek _userData?['email'] != null
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLaporTemuanButton(ColorScheme colorScheme) {
    return Center(
      child: FadeInAnimation(
        delay: 0.5 + (_menuItems.length * 0.08),
        child: ElevatedButton.icon(
          icon: Icon(
            Ionicons.warning_outline,
            color: Colors.white.withAlpha((0.9 * 255).round()),
            size: 20,
          ),
          label: Text(
            "Lapor Temuan Kebocoran",
            style: TextStyle(
              color: Colors.white.withAlpha((0.9 * 255).round()),
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.tertiary,
            foregroundColor: colorScheme.onTertiary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            elevation: 2,
          ),
          onPressed: () {
            Navigator.pushNamed(context, '/temuan_kebocoran');
          },
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
              size: 70,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              "Oops!",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "Terjadi kesalahan tidak diketahui.",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh_outline),
              label: const Text("Coba Lagi"),
              onPressed: _loadUserData,
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

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutSine));

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

// Extension untuk capitalize (jika belum ada global)
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
