// lib/home_pelanggan_page.dart
// ignore_for_file: unused_element, unused_field, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:pdam_app/models/berita_model.dart';
import 'package:intl/intl.dart';

import 'dart:async';

// --- WIDGET ANIMASI ---

// 1. Animasi Fade-in dan Slide-up.
class FadeInAnimation extends StatefulWidget {
  final int delay;
  final Widget child;

  const FadeInAnimation({super.key, this.delay = 0, required this.child});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _position = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(curve);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
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
      opacity: _opacity,
      child: SlideTransition(
        position: _position,
        child: widget.child,
      ),
    );
  }
}

// 2. Widget untuk animasi staggered pada list/grid.
class StaggeredFadeIn extends StatelessWidget {
  final List<Widget> children;
  final int delay;
  final bool isHorizontal;

  const StaggeredFadeIn({
    super.key,
    required this.children,
    this.delay = 100,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return Row(
        children: List.generate(children.length, (index) {
          return Flexible(
            child: FadeInAnimation(
              delay: delay * index,
              child: children[index],
            ),
          );
        }),
      );
    }
    return Column(
      children: List.generate(children.length, (index) {
        return FadeInAnimation(
          delay: delay * index,
          child: children[index],
        );
      }),
    );
  }
}

// 3. Widget untuk animasi angka (counter).
class AnimatedCounter extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _animation =
          Tween<double>(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _animation.value.toStringAsFixed(1),
          style: widget.style,
        );
      },
    );
  }
}

// --- END WIDGET ANIMASI ---

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
  List<Pengaduan> _laporanTerbaruList = [];
  List<Berita> _beritaList = [];
  bool _isBeritaLoading = true;
  String? _beritaErrorMessage;
  
  // ---> [MODIFIKASI 1] TAMBAHKAN VARIABEL INI <---
  DateTime? _lastPressed;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUserData(),
      _fetchBerita(),
    ]);
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final count = await _apiService.getUnreadNotifikasiCount();
      if (mounted) {
        setState(() {
          _unreadNotifCount = count;
        });
      }
    } catch (e) {
      // Biarkan 0 jika gagal
    }
  }

  Future<void> _fetchLaporanTerbaru() async {
    try {
      final List<dynamic> rawData = await _apiService.getLaporanPengaduan();
      if (mounted) {
        final allLaporan = rawData
            .whereType<Map<String, dynamic>>()
            .map((item) => Pengaduan.fromJson(item))
            .toList();
        allLaporan.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        setState(() {
          _laporanTerbaruList = allLaporan.take(4).toList();
        });
      }
    } catch (e) {
      print("Gagal mengambil laporan terbaru di beranda: $e");
      if (mounted) {
        setState(() {
          _laporanTerbaruList = [];
        });
      }
    }
  }

  Future<void> _fetchBerita() async {
    if (!mounted) return;
    setState(() {
      _isBeritaLoading = true;
      _beritaErrorMessage = null;
    });
    try {
      final berita = await _apiService.getBerita();
      if (mounted) {
        setState(() {
          _beritaList = berita;
          _isBeritaLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _beritaErrorMessage = 'Gagal memuat berita: $e';
          _isBeritaLoading = false;
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
            'Sesi berakhir. Silakan login kembali.',
            isError: true,
          );
          await _logout();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Gagal memuat data. Periksa koneksi internet Anda.";
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
      ),
    );
  }

  void _showBeritaDetailModal(Berita berita) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(berita.judul,
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (berita.fotoBanner != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _apiService.rootBaseUrl +
                          '/storage/' +
                          berita.fotoBanner!,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  DateFormat('d MMMM yyyy').format(berita.tanggalTerbit),
                  style: GoogleFonts.manrope(
                      fontSize: 14, color: Colors.grey.shade600),
                ),
                if (berita.namaAdmin != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Oleh: ${berita.namaAdmin}',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(berita.isi, style: GoogleFonts.manrope(fontSize: 16)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog({required String title, required List<String> steps}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: ListBody(
                children: List.generate(steps.length, (index) {
                  return _buildStepTile(index + 1, steps[index]);
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Mengerti",
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStepTile(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text(
              '$number',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  const Color primaryColor = Color(0xFF0077B6);
  const Color secondaryColor = Color(0xFF00B4D8);
  const Color backgroundColor = Color(0xFFF8F9FA);
  const Color textColor = Color(0xFF212529);
  const Color subtleTextColor = Color(0xFF6C757D);

  return WillPopScope(
    onWillPop: () async {
      final now = DateTime.now();
      // Cek jika tombol kembali belum pernah ditekan atau sudah lebih dari 2 detik
      final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
          _lastPressed == null ||
              now.difference(_lastPressed!) > const Duration(seconds: 2);

      if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
        _lastPressed = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tekan sekali lagi untuk keluar'),
            duration: Duration(seconds: 2),
          ),
        );
        return false; // Mencegah aplikasi keluar pada tekanan pertama
      } else {
        // [INI SOLUSINYA]
        // Memaksa aplikasi untuk keluar sepenuhnya, tidak peduli state navigator.
        SystemNavigator.pop();
        return true; 
      }
    },
    child: Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(textColor, subtleTextColor),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _errorMessage != null
              ? _buildErrorView()
              : _buildHomeContent(
                  primaryColor, secondaryColor, textColor, subtleTextColor),
      bottomNavigationBar: _buildBottomNavBar(primaryColor, subtleTextColor),
    ),
  );
}


  AppBar _buildAppBar(Color textColor, Color subtleTextColor) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: FadeInAnimation(
        delay: 50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat Datang,',
              style: GoogleFonts.manrope(fontSize: 16, color: subtleTextColor),
            ),
            Text(
              _userData?['nama']?.toString().capitalize() ?? 'Pelanggan',
              style: GoogleFonts.manrope(
                  fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
      ),
      actions: [
        FadeInAnimation(
          delay: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Ionicons.notifications_outline,
                    size: 28, color: textColor),
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotifikasiPage()));
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
                        borderRadius: BorderRadius.circular(10)),
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
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNavBar(Color primaryColor, Color subtleTextColor) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: subtleTextColor.withOpacity(0.8),
      selectedLabelStyle:
          GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle: GoogleFonts.manrope(fontSize: 12),
      currentIndex: _currentIndex,
      onTap: (index) {
        switch (index) {
          case 0:
            break;
          case 1:
            Navigator.pushNamed(context, '/lacak_laporan_saya');
            break;
          case 2:
            Navigator.pushNamed(context, '/cek_tunggakan');
            break;
          case 3:
            Navigator.pushNamed(context, '/view_profil');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Ionicons.home_outline),
            activeIcon: Icon(Ionicons.home),
            label: 'Beranda'),
        BottomNavigationBarItem(
            icon: Icon(Ionicons.document_text_outline),
            activeIcon: Icon(Ionicons.document_text),
            label: 'Laporan'),
        BottomNavigationBarItem(
            icon: Icon(Ionicons.receipt_outline),
            activeIcon: Icon(Ionicons.receipt),
            label: 'Tagihan'),
        BottomNavigationBarItem(
            icon: Icon(Ionicons.person_outline),
            activeIcon: Icon(Ionicons.person),
            label: 'Profil'),
      ],
    );
  }

  Widget _buildHomeContent(Color primaryColor, Color secondaryColor,
      Color textColor, Color subtleTextColor) {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          FadeInAnimation(
            delay: 200,
            child: _buildWaterUsageCard(primaryColor, secondaryColor),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader("Layanan Utama", textColor),
          const SizedBox(height: 16),
          FadeInAnimation(
            delay: 300,
            child: _buildMainServicesGrid(primaryColor, textColor),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader("Laporan Terbaru", textColor,
              actionText: _laporanTerbaruList.isNotEmpty ? "Lihat Semua" : null,
              onActionTap: () =>
                  Navigator.pushNamed(context, '/lacak_laporan_saya')),
          const SizedBox(height: 16),
          FadeInAnimation(
            delay: 400,
            child: _buildLaporanTerbaruSection(textColor),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader("Berita & Pengumuman", textColor),
          const SizedBox(height: 16),
          FadeInAnimation(
            delay: 500,
            child: _buildBeritaHorizontalList(textColor, subtleTextColor),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader("Untuk Anda", textColor),
          const SizedBox(height: 16),
          StaggeredFadeIn(
            delay: 150,
            children: [
              _buildInfoCard(
                icon: Ionicons.water_outline,
                iconColor: Colors.green,
                title: "Tips Cerdas Menghemat Air",
                subtitle: "Langkah mudah untuk mengurangi tagihan.",
                onTap: () {
                  final List<String> tips = [
                    "Matikan keran saat menyikat gigi atau mencuci tangan dengan sabun.",
                    "Gunakan pancuran (shower) dengan aliran rendah dan perpendek waktu mandi Anda.",
                    "Segera perbaiki keran atau pipa yang bocor sekecil apapun.",
                    "Gunakan ulang air bekas cucian sayuran atau buah untuk menyiram tanaman.",
                    "Cuci pakaian dengan muatan penuh untuk mengoptimalkan penggunaan air mesin cuci.",
                    "Pasang aerator pada keran untuk mengurangi aliran air tanpa mengurangi tekanan."
                  ];
                  _showInfoDialog(title: "Tips Menghemat Air", steps: tips);
                },
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Ionicons.search_circle_outline,
                iconColor: Colors.teal,
                title: "Cek Kebocoran Mandiri",
                subtitle: "Deteksi dini kebocoran di rumah Anda.",
                onTap: () {
                  final List<String> steps = [
                    "Pastikan semua keran air, shower, dan kloset di dalam rumah dalam keadaan mati total.",
                    "Pergi ke lokasi meteran air Anda. Buka penutupnya dan catat angka yang tertera.",
                    "Jangan gunakan air sama sekali selama 30-60 menit.",
                    "Setelah waktu tunggu selesai, periksa kembali angka pada meteran air.",
                    "Jika angka pada meteran berubah (bertambah), ada kemungkinan besar terjadi kebocoran pada jaringan pipa di rumah Anda. Segera hubungi teknisi."
                  ];
                  _showInfoDialog(
                      title: "Cara Mengecek Kebocoran Persil", steps: steps);
                },
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Ionicons.card_outline,
                iconColor: Colors.blue,
                title: "Cara Pembayaran Tagihan",
                subtitle: "Lihat semua kanal pembayaran yang tersedia.",
                onTap: () {
                  final List<String> steps = [
                    "Pembayaran dapat dilakukan melalui Kantor PDAM terdekat.",
                    "Melalui minimarket seperti Indomaret atau Alfamart dengan menyebutkan ID Pelanggan.",
                    "Melalui E-Wallet (GoPay, OVO, Dana) pada menu PDAM/Air.",
                    "Melalui Mobile Banking (BCA, Mandiri, BRI) pada menu pembayaran PDAM.",
                    "Pastikan Anda menyimpan bukti pembayaran yang sah."
                  ];
                  _showInfoDialog(
                      title: "Kanal Pembayaran Tagihan", steps: steps);
                },
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Ionicons.speedometer_outline,
                iconColor: Colors.indigo,
                title: "Cara Membaca Meter Air",
                subtitle: "Pahami angka pada meteran air Anda.",
                onTap: () {
                  final List<String> steps = [
                    "Lihat angka berwarna hitam pada meteran. Angka ini menunjukkan pemakaian dalam satuan meter kubik (m³).",
                    "Angka berwarna merah (jika ada) menunjukkan pemakaian dalam satuan liter dan biasanya tidak dicatat dalam tagihan.",
                    "Untuk pelaporan, catat semua angka yang tertera di bagian hitam dari kiri ke kanan.",
                    "Contoh: Jika angka hitam menunjukkan '00123', maka pemakaian Anda adalah 123 m³.",
                    "Perhatikan juga jarum kecil/roda gigi. Jika semua keran mati tapi jarum tetap berputar, kemungkinan ada kebocoran."
                  ];
                  _showInfoDialog(title: "Membaca Meter Air", steps: steps);
                },
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Ionicons.home_outline,
                iconColor: Colors.brown,
                title: "Informasi Pasang Baru",
                subtitle: "Syarat dan alur pemasangan sambungan baru.",
                onTap: () {
                  final List<String> steps = [
                    "Datang ke kantor PDAM terdekat dengan membawa fotokopi KTP dan KK.",
                    "Isi formulir pendaftaran yang telah disediakan oleh petugas.",
                    "Petugas akan melakukan survei ke lokasi pemasangan untuk menentukan kelayakan teknis.",
                    "Jika disetujui, lakukan pembayaran biaya pendaftaran dan pemasangan.",
                    "Tim teknis akan datang ke lokasi Anda untuk melakukan pemasangan pipa dan meteran air."
                  ];
                  _showInfoDialog(title: "Alur Pemasangan Baru", steps: steps);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor,
      {String? actionText, VoidCallback? onActionTap}) {
    return FadeInAnimation(
      delay: 300,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.manrope(
                  fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          if (actionText != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(actionText),
            ),
        ],
      ),
    );
  }

  Widget _buildWaterUsageCard(Color primary, Color secondary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Penggunaan Air Bulan Lalu",
                style: GoogleFonts.manrope(color: Colors.white, fontSize: 16),
              ),
              Icon(Ionicons.water,
                  color: Colors.white.withOpacity(0.8), size: 28),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCounter(
                value: 24.5,
                style: GoogleFonts.manrope(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  'm³',
                  style: GoogleFonts.manrope(
                      fontSize: 20,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(color: Colors.white30, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Tagihan Tertunggak",
                  style:
                      GoogleFonts.manrope(color: Colors.white, fontSize: 14)),
              Text("Rp 0",
                  style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainServicesGrid(Color primaryColor, Color textColor) {
    final services = [
      {
        'icon': Ionicons.create_outline,
        'label': 'Buat Laporan',
        'route': '/buat_laporan'
      },
      {
        'icon': Ionicons.headset_outline,
        'label': 'Hubungi Kami',
        'route': '/hubungi_kami'
      },
      {
        'icon': Ionicons.camera_outline,
        'label': 'Baca Meter Mandiri',
        'route': '/lapor_foto_meter'
      },
      {
        'icon': Ionicons.map_outline,
        'label': 'Lacak Laporan',
        'route': '/lacak_laporan_saya'
      },
      {
        'icon': Ionicons.receipt_outline,
        'label': 'Cek Tagihan',
        'route': '/cek_tunggakan'
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return FadeInAnimation(
          delay: 100 * index,
          child: _AnimatedIconButton(
            onTap: () {
              if (service['route'] == '/hubungi_kami') {
                if (_userData != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              ChatPage(userData: _userData!)));
                }
              } else {
                Navigator.pushNamed(context, service['route'] as String);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(service['icon'] as IconData,
                      size: 36, color: primaryColor),
                  const SizedBox(height: 12),
                  Text(
                    service['label'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLaporanTerbaruSection(Color textColor) {
    if (_laporanTerbaruList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16)),
        child: Center(
            child: Text('Anda belum memiliki laporan aktif.',
                style: GoogleFonts.manrope(color: Colors.grey))),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.builder(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: _laporanTerbaruList.length,
        itemBuilder: (context, index) {
          return FadeInAnimation(
              delay: 150 * index,
              child: _buildSingleLaporanCard(
                  _laporanTerbaruList[index], textColor));
        },
      ),
    );
  }

  Widget _buildSingleLaporanCard(Pengaduan laporan, Color textColor) {
    final statusMeta = _getStatusMeta(laporan.status);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pushNamed(context, '/lacak_laporan_saya'),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '#LAP${laporan.id}',
                      style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusMeta.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        laporan.friendlyStatus,
                        style: GoogleFonts.manrope(
                            color: statusMeta.color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  laporan.friendlyKategori,
                  style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(Ionicons.calendar_outline,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('d MMM yyyy').format(laporan.createdAt),
                      style: GoogleFonts.manrope(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({Color color, IconData icon}) _getStatusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'menunggu_konfirmasi':
        return (
          color: Colors.orange.shade700,
          icon: Icons.pending_actions_rounded
        );
      case 'diterima':
      case 'dalam_perjalanan':
      case 'diproses':
        return (color: Colors.blue.shade800, icon: Icons.construction_rounded);
      case 'selesai':
        return (color: Colors.green.shade700, icon: Icons.check_circle_rounded);
      default:
        return (color: Colors.red.shade700, icon: Icons.cancel_rounded);
    }
  }

  Widget _buildBeritaHorizontalList(Color textColor, Color subtleTextColor) {
    if (_isBeritaLoading) {
      return const SizedBox(
          height: 250, child: Center(child: CircularProgressIndicator()));
    }
    if (_beritaList.isEmpty) {
      return const SizedBox(
          height: 250, child: Center(child: Text('Belum ada berita terbaru.')));
    }

    final PageController pageController =
        PageController(viewportFraction: 0.85);

    return SizedBox(
      height: 250,
      child: PageView.builder(
        clipBehavior: Clip.none,
        controller: pageController,
        itemCount: _beritaList.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: pageController,
            builder: (context, child) {
              double value = 1.0;
              if (pageController.position.haveDimensions) {
                value = pageController.page! - index;
                value = (1 - (value.abs() * 0.25)).clamp(0.0, 1.0);
              }
              return Center(
                child: SizedBox(
                  height: Curves.easeOut.transform(value) * 250,
                  child: _buildBeritaCard(
                      _beritaList[index], textColor, subtleTextColor),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBeritaCard(
      Berita berita, Color textColor, Color subtleTextColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showBeritaDetailModal(berita),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (berita.fotoBanner != null)
                  Expanded(
                    flex: 3,
                    child: Image.network(
                      _apiService.rootBaseUrl +
                          '/storage/' +
                          berita.fotoBanner!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          berita.judul,
                          style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (berita.namaAdmin != null)
                          Text(
                            'Oleh: ${berita.namaAdmin}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: subtleTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1.5)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.manrope(
                            color: Colors.grey.shade700, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Ionicons.chevron_forward,
                  color: Colors.grey, size: 20),
            ],
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
            Icon(Ionicons.cloud_offline_outline,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text("Oops!",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_errorMessage ?? "Terjadi kesalahan.",
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh_outline),
              label: const Text("Coba Lagi"),
              onPressed: _loadInitialData,
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET BANTUAN UNTUK ANIMASI TOMBOL ---
class _AnimatedIconButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedIconButton({required this.child, required this.onTap});

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _controller.reverse();
    });
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}