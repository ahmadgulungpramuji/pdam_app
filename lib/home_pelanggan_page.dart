// lib/home_pelanggan_page.dart
// ignore_for_file: unused_element, unused_field, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/chat_page.dart';
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/pages/notifikasi_page.dart';
import 'package:pdam_app/view_profil_page.dart';
import 'package:pdam_app/lacak_laporan_saya_page.dart';
import 'package:pdam_app/cek_tunggakan_page.dart';
import 'package:pdam_app/lapor_foto_meter_page.dart';

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
  int _unreadNotifCount = 0;
  int _currentIndex = 0;

  Future<void> _fetchUnreadCount() async {
    try {
      final count = await _apiService.getUnreadNotifikasiCount();
      if (mounted) {
        setState(() {
          _unreadNotifCount = count;
        });
      }
    } catch (e) {
      // Biarkan 0 jika gagal, tidak perlu menampilkan error
    }
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
          _fetchUnreadCount();
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
          _errorMessage = "Tidak dapat memuat data Anda. Periksa koneksi internet dan coba lagi.";
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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Widget _buildHomeContent(ColorScheme colorScheme) {
    final List<Map<String, dynamic>> primaryMenuItems = [
      {
        'icon': Ionicons.document_text_outline,
        'title': 'Buat Laporan',
        'subtitle': 'Keluhan & masalah layanan',
        'route': '/buat_laporan',
        'color': Colors.blue.shade400,
      },
      {
        'icon': Ionicons.chatbubbles_outline,
        'title': 'Hubungi Kami',
        'subtitle': 'Admin & info PDAM',
        'route': '/chat_page',
        'color': Colors.green.shade400,
      },
    ];
    
    return RefreshIndicator(
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
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Ionicons.notifications_outline, size: 28),
                    tooltip: 'Notifikasi',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotifikasiPage(),
                        ),
                      );
                      _fetchUnreadCount();
                    },
                  ),
                  if (_unreadNotifCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$_unreadNotifCount',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: Icon(Ionicons.log_out_outline, color: colorScheme.onErrorContainer, size: 26),
                tooltip: 'Logout',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Konfirmasi Logout'),
                      content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
                      actionsAlignment: MainAxisAlignment.end,
                      actions: [
                        TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop()),
                        TextButton(
                          child: Text('Logout', style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
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
              titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
              title: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: constraints.biggest.height < kToolbarHeight + 40 ? 1.0 : 0.0,
                    child: Text(
                      'Beranda',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: colorScheme.onPrimary, fontSize: 20),
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
                        colors: [_darkenColor(colorScheme.primary, 0.2), colorScheme.primary, _lightenColor(colorScheme.primary, 0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  _buildWelcomeHeader(colorScheme),
                ],
              ),
            ),
          ),
          
          // Bagian Konten Beranda yang baru dan lebih elegan
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // KARTU FITUR MENONJOL (Opsi 1)
                FadeInAnimation(
                  delay: 0.2,
                  slideDistance: 0.05,
                  child: Text(
                    "Layanan Utama",
                    style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: 0.3,
                  slideDistance: 0.05,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: primaryMenuItems.length,
                    itemBuilder: (context, index) {
                      final item = primaryMenuItems[index];
                      return _buildFeatureCard(
                        icon: item['icon'] as IconData,
                        title: item['title'] as String,
                        subtitle: item['subtitle'] as String,
                        color: item['color'] as Color,
                        onTap: () {
                          if (item['title'] == 'Hubungi Kami') {
                            if (_userData != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ChatPage(userData: _userData!)),
                              );
                            } else {
                              _showSnackbar('Data pengguna belum siap, coba lagi.');
                            }
                          } else if (item['route'] != null) {
                            Navigator.pushNamed(context, item['route'] as String);
                          }
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 30),

                // TOMBOL LAPOR TEMUAN KEbOCORAN
                FadeInAnimation(
                  delay: 0.4,
                  child: _buildLaporTemuanButton(colorScheme),
                ),

                const SizedBox(height: 30),

                // KONTEN REKOMENDASI: INFO & PENGUMUMAN
                FadeInAnimation(
                  delay: 0.5,
                  child: Text(
                    "Info & Pengumuman",
                    style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: 0.6,
                  child: _buildInfoCard(
                    title: 'Pemeliharaan Jaringan Air',
                    description: 'Akan ada pemadaman air sementara di area A dan B pada tanggal 10-12 Agustus 2025. Mohon maaf atas ketidaknyamanannya.',
                    icon: Ionicons.construct_outline,
                    color: Colors.orange,
                  ),
                ),
                FadeInAnimation(
                  delay: 0.7,
                  child: _buildInfoCard(
                    title: 'Layanan Pembayaran Online',
                    description: 'Bayar tagihan air Anda sekarang lebih mudah melalui aplikasi mobile banking atau e-wallet.',
                    icon: Ionicons.wallet_outline,
                    color: Colors.purple,
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // KONTEN REKOMENDASI: TIPS HEMAT AIR
                FadeInAnimation(
                  delay: 0.8,
                  child: Text(
                    "Tips Hemat Air",
                    style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: 0.9,
                  child: _buildTipsCard(
                    title: 'Periksa Kebocoran Pipa',
                    description: 'Pastikan tidak ada kebocoran pada pipa atau keran air di rumah Anda.',
                    icon: Ionicons.checkmark_circle_outline,
                  ),
                ),
                FadeInAnimation(
                  delay: 1.0,
                  child: _buildTipsCard(
                    title: 'Gunakan Air Secukupnya',
                    description: 'Tutup keran saat menyikat gigi atau mencuci piring untuk menghemat air.',
                    icon: Ionicons.leaf_outline,
                  ),
                ),
                
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildHomeContent(colorScheme),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigasi ke halaman Lapor Foto Meter
          Navigator.pushNamed(context, '/lapor_foto_meter');
        },
        tooltip: 'Lapor Foto Meter',
        backgroundColor: colorScheme.tertiary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        child: const Icon(Ionicons.camera_outline, size: 28),
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Logika navigasi yang sudah benar
          switch(index) {
            case 0:
              // Sudah di halaman beranda, tidak perlu navigasi
              break;
            case 1:
              Navigator.pushNamed(context, '/cek_tunggakan');
              break;
            case 2:
              Navigator.pushNamed(context, '/lacak_laporan_saya');
              break;
            case 3:
              Navigator.pushNamed(context, '/view_profil');
              break;
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Ionicons.home_outline),
            label: 'Beranda',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Ionicons.receipt_outline),
            label: 'Tagihan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Ionicons.search_circle_outline),
            label: 'Lacak',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Ionicons.person_circle_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(ColorScheme colorScheme) {
    return FadeInAnimation(
      delay: 0.1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 50.0, 16.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Halo,',
              style: GoogleFonts.lato(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
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
        titleFontSize = titleFontSize.clamp(15.0, 18.0);
        subtitleFontSize = subtitleFontSize.clamp(12.0, 14.0);

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(iconSize * 0.3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.18),
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
                        color: Colors.grey.shade700,
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

  Widget _buildLaporTemuanButton(ColorScheme colorScheme) {
    return Center(
      child: FadeInAnimation(
        delay: 0.5,
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

  Widget _buildInfoCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
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
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ??
                  "Terjadi kesalahan tidak diketahui. Silakan coba lagi.",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}