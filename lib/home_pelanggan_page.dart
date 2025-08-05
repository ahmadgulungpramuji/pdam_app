// lib/home_pelanggan_page.dart
// ignore_for_file: unused_element, unused_field, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/chat_page.dart';
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/models/pengaduan_model.dart';
import 'package:pdam_app/pages/notifikasi_page.dart';
import 'package:pdam_app/view_profil_page.dart';
import 'package:pdam_app/lacak_laporan_saya_page.dart';
import 'package:pdam_app/cek_tunggakan_page.dart';
import 'package:pdam_app/lapor_foto_meter_page.dart';
import 'package:intl/intl.dart';

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
  Pengaduan? _laporanTerbaru;

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

  Future<void> _fetchLaporanTerbaru() async {
    try {
      final List<dynamic> rawData = await _apiService.getLaporanPengaduan();
      if (mounted && rawData.isNotEmpty) {
        final allLaporan = rawData
            .whereType<Map<String, dynamic>>()
            .map((item) => Pengaduan.fromJson(item))
            .toList();
        allLaporan.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        setState(() {
          _laporanTerbaru = allLaporan.first;
        });
      } else if (mounted) {
        setState(() {
          _laporanTerbaru = null;
        });
      }
    } catch (e) {
      print("Gagal mengambil laporan terbaru di beranda: $e");
      if (mounted) {
        setState(() {
          _laporanTerbaru = null;
        });
      }
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
          _fetchLaporanTerbaru();
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

  void _showTipsDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Widget _buildHomeContent(ColorScheme colorScheme) {
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
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$_unreadNotifCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
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
                    opacity: constraints.biggest.height < kToolbarHeight + 40
                        ? 1.0
                        : 0.0,
                    child: Text(
                      'Beranda',
                      style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary,
                          fontSize: 20),
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
                          _darkenColor(colorScheme.primary, 0.2),
                          colorScheme.primary,
                          _lightenColor(colorScheme.primary, 0.1)
                        ],
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Bagian baru untuk Akses Cepat (Opsi 2)
                FadeInAnimation(
                  delay: 0.2,
                  slideDistance: 0.05,
                  child: Text(
                    "Akses Cepat",
                    style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: 0.3,
                  slideDistance: 0.05,
                  child: _buildQuickAccessCard(colorScheme),
                ),

                const SizedBox(height: 30),

                // Laporan Terbaru
                FadeInAnimation(
                  delay: 0.4,
                  slideDistance: 0.05,
                  child: Text(
                    "Laporan Terbaru",
                    style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: 0.5,
                  child: _buildLaporanTerbaruCard(colorScheme),
                ),

                const SizedBox(height: 30),

                // KONTEN REKOMENDASI: INFO & PENGUMUMAN
                FadeInAnimation(
                  delay: 0.6,
                  child: Text(
                    "Info & Pengumuman",
                    style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: 0.7,
                  child: _buildInfoCard(
                    title: 'Pemeliharaan Jaringan Air',
                    description:
                        'Akan ada pemadaman air sementara di area Kecamatan Indramayu dan Jatibarang pada tanggal 10-12 Agustus 2025. Mohon maaf atas ketidaknyamanannya.',
                    icon: Ionicons.construct_outline,
                    color: Colors.orange,
                  ),
                ),
                FadeInAnimation(
                  delay: 0.8,
                  child: _buildInfoCard(
                    title: 'Layanan Pembayaran Online',
                    description:
                        'Bayar tagihan air Anda sekarang lebih mudah melalui aplikasi mobile banking atau e-wallet.',
                    icon: Ionicons.wallet_outline,
                    color: Colors.purple,
                  ),
                ),

                const SizedBox(height: 30),

                // KONTEN REKOMENDASI: TIPS HEMAT AIR
                FadeInAnimation(
                  delay: 0.9,
                  child: Text(
                    "Tips Hemat Air",
                    style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: 1.0,
                  child: _buildTipsCard(
                    title: 'Periksa Kebocoran Pipa',
                    description:
                        'Pastikan tidak ada kebocoran pada pipa atau keran air di rumah Anda.',
                    icon: Ionicons.checkmark_circle_outline,
                    onTap: () => _showTipsDialog(
                      'Cara Memeriksa Kebocoran Pipa',
                      '1. Tutup semua keran air di rumah Anda.\n'
                          '2. Catat angka pada meteran air.\n'
                          '3. Tunggu selama 1-2 jam tanpa menggunakan air.\n'
                          '4. Periksa kembali meteran air. Jika angkanya berubah, kemungkinan ada kebocoran.',
                    ),
                  ),
                ),
                FadeInAnimation(
                  delay: 1.1,
                  child: _buildTipsCard(
                    title: 'Gunakan Air Secukupnya',
                    description:
                        'Tutup keran saat menyikat gigi atau mencuci piring untuk menghemat air.',
                    icon: Ionicons.leaf_outline,
                    onTap: () => _showTipsDialog(
                      'Cara Menggunakan Air Secukupnya',
                      '1. Mandi dengan shower lebih hemat daripada berendam di bak mandi.\n'
                          '2. Gunakan sikat gigi dan pasta gigi, lalu nyalakan keran hanya saat membilas.\n'
                          '3. Cuci piring dengan air yang mengalir, tapi jangan terlalu deras.\n'
                          '4. Gunakan mesin cuci hanya jika pakaian kotor sudah cukup banyak.',
                    ),
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
          switch (index) {
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Ionicons.home_outline),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.receipt_outline),
            label: 'Tagihan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.search_circle_outline),
            label: 'Lacak',
          ),
          BottomNavigationBarItem(
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
                  const Icon(Ionicons.mail_outline,
                      size: 16, color: Colors.white70),
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

  Widget _buildQuickAccessCard(ColorScheme colorScheme) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade400.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Ionicons.document_text_outline,
                  color: Colors.blue.shade400, size: 24),
            ),
            title: Text(
              'Buat Laporan',
              style: GoogleFonts.lato(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Keluhan & masalah layanan'),
            trailing: const Icon(Ionicons.chevron_forward_outline,
                color: Colors.grey),
            onTap: () {
              Navigator.pushNamed(context, '/buat_laporan');
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade400.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Ionicons.chatbubbles_outline,
                  color: Colors.green.shade400, size: 24),
            ),
            title: Text(
              'Hubungi Kami',
              style: GoogleFonts.lato(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Admin & info PDAM'),
            trailing: const Icon(Ionicons.chevron_forward_outline,
                color: Colors.grey),
            onTap: () {
              if (_userData != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ChatPage(userData: _userData!)),
                );
              } else {
                _showSnackbar('Data pengguna belum siap, coba lagi.');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLaporanTerbaruCard(ColorScheme colorScheme) {
    // Jika state _laporanTerbaru masih loading atau kosong
    if (_laporanTerbaru == null) {
      return Card(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Anda belum memiliki laporan.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Jika data laporan ada, bangun kartu dengan data tersebut
    final laporan = _laporanTerbaru!;
    final statusMeta =
        _getStatusMeta(laporan.status); // Helper untuk warna & ikon

    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigasi tetap ke halaman lacak laporan
          Navigator.pushNamed(context, '/lacak_laporan_saya');
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Laporan #${laporan.id}', // Data dinamis
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusMeta.color.withOpacity(0.2), // Warna dinamis
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      laporan.friendlyStatus, // Status dinamis
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusMeta.color, // Warna dinamis
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Masalah: ${laporan.friendlyKategori}', // Kategori dinamis
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                // Format tanggal dinamis
                'Tanggal: ${DateFormat('d MMMM yyyy').format(laporan.createdAt)}',
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Lihat Detail >',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAMBAHKAN FUNGSI HELPER INI ---
  // Fungsi ini bisa Anda salin dari lacak_laporan_saya_page.dart untuk konsistensi
  ({Color color, IconData icon}) _getStatusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'menunggu_konfirmasi':
        return (
          color: Colors.blue.shade700,
          icon: Icons.pending_actions_rounded,
        );
      case 'diterima':
      case 'dalam_perjalanan':
      case 'diproses':
        return (
          color: Colors.orange.shade800,
          icon: Icons.construction_rounded
        );
      case 'selesai':
        return (color: Colors.green.shade700, icon: Icons.check_circle_rounded);
      case 'ditolak':
      case 'dibatalkan':
        return (color: Colors.red.shade700, icon: Icons.cancel_rounded);
      default:
        return (color: Colors.grey.shade600, icon: Icons.help_outline_rounded);
    }
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
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
