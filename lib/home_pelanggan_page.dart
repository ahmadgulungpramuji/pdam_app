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
import 'package:pdam_app/services/chat_service.dart';

import 'dart:async';
import 'dart:ui';

// --- WIDGET ANIMASI (TETAP SAMA) ---
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
  final ChatService _chatService = ChatService();
  
  // Stream untuk badge notifikasi
  Stream<int>? _unreadLaporanStream;
  Stream<int>? _unreadAdminStream;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _usageAmount = "0"; // Untuk menampung data liter
  String _usagePeriod = "";
  int _billAmount = 0;       // Untuk menampung total rupiah
  bool _isBillLoading = true; // Indikator loading khusus kartu biru
  String? _errorMessage;
  int _unreadNotifCount = 0;
  int _currentIndex = 0;
  List<Pengaduan> _laporanTerbaruList = [];
  List<Berita> _beritaList = [];
  bool _isBeritaLoading = true;
  String? _beritaErrorMessage;
  List<dynamic> _riwayatMeterList = [];
  String _detailNamaPelanggan = "";
  String _detailIdPelanggan = "";
  
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
      _fetchHomeBillInfo(),
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
      if (mounted) {
        setState(() {
          _laporanTerbaruList = [];
        });
      }
    }
  }

  Future<void> _fetchHomeBillInfo() async {
    if (!mounted) return;
    
    setState(() {
      _isBillLoading = true;
    });

    try {
      String targetIdPdam = '';

      // 1. Ambil Profil Terbaru
      final userProfile = await _apiService.getUserProfile();
      
      if (userProfile != null) {
        if (userProfile['id_pdam'] != null && userProfile['id_pdam'].toString() != 'null') {
          targetIdPdam = userProfile['id_pdam'].toString().trim();
        } else if (userProfile['nomor_sambungan'] != null) {
          targetIdPdam = userProfile['nomor_sambungan'].toString().trim();
        } else if (userProfile['username'] != null) {
           String username = userProfile['username'].toString().trim();
           if (RegExp(r'^[0-9]+$').hasMatch(username) && username.length > 3) {
             targetIdPdam = username;
           }
        }
      }

      // 2. FALLBACK: Jika di Profil Kosong, Ambil dari List API
      if (targetIdPdam.isEmpty) {
        final ids = await _apiService.getAllUserPdamIds();
        if (ids.isNotEmpty) {
          targetIdPdam = ids.last['nomor']?.toString() ?? ids.last['id_pdam']?.toString() ?? ''; 
        }
      }

      // 3. EKSEKUSI CEK TAGIHAN
      if (targetIdPdam.isNotEmpty) {
        final billData = await _apiService.getTunggakan(targetIdPdam);
        
        if (mounted) {
          setState(() {
            // Data Kartu Biru
            _usageAmount = billData['pemakaian']?.toString() ?? "0";
            _usagePeriod = billData['periode_pemakaian']?.toString() ?? ""; 
            _billAmount = int.tryParse(billData['jumlah'].toString()) ?? 0;

            // [PERBAIKAN PENTING] Simpan Data Detail untuk Popup
            _detailNamaPelanggan = billData['nama'] ?? 'Pelanggan';
            _detailIdPelanggan = billData['id_pdam']?.toString() ?? targetIdPdam;
            _riwayatMeterList = billData['riwayat_meter'] ?? []; // List ini dipakai di _showDetailPemakaianDialog
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _usageAmount = "0";
            _usagePeriod = "-";
            _billAmount = 0;
            _riwayatMeterList = [];
          });
        }
      }
    } catch (e) {
      print("Error fetching home bill info: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isBillLoading = false;
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
        // --- PERBAIKAN LOGIKA DISINI ---
        // Kita sort manual lagi di Flutter untuk memastikan 100% akurat
        // Sort: Tanggal terbaru di atas (b.compareTo(a))
        berita.sort((a, b) {
           int compareDate = b.tanggalTerbit.compareTo(a.tanggalTerbit);
           if (compareDate == 0) {
             // Jika tanggal sama persis, bandingkan ID (ID besar = lebih baru)
             return b.id.compareTo(a.id);
           }
           return compareDate;
        });
        // -------------------------------

        setState(() {
          _beritaList = berita;
          _isBeritaLoading = false;
        });

        if (_beritaList.isNotEmpty) {
          final beritaTerbaru = _beritaList.first; 
          
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _showPopupBerita(beritaTerbaru);
            }
          });
        }
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
          // 1. SIMPAN DATA USER
          setState(() {
            _userData = data;
          });

          if (_userData != null && _userData!['firebase_uid'] != null) {
            final String uid = _userData!['firebase_uid'].toString();
            final int? laravelId = _userData!['id'] as int?;

            // 2. AMBIL SEMUA LAPORAN USER UTK BIKIN WHITELIST
            List<String> myReportThreadIds = [];
            try {
              final List<dynamic> rawLaporan = await _apiService.getLaporanPengaduan();
              myReportThreadIds = rawLaporan
                  .whereType<Map<String, dynamic>>()
                  .map((item) => 'pengaduan_${item['id']}') // Format: pengaduan_123
                  .toList();
            } catch (e) {
              print("Gagal load daftar ID laporan: $e");
            }

            // 3. SETUP STREAM DENGAN FILTER
            setState(() {
              _isLoading = false;
              
              _unreadLaporanStream = null;
              _unreadAdminStream = null;

              // Filter 1: Lacak Laporan (Hanya hitung thread yg ada di myReportThreadIds)
              _unreadLaporanStream = _chatService.getUnreadCountByPrefix(
                uid, 
                'pengaduan_',
                allowedThreadIds: myReportThreadIds // <--- INI KUNCINYA
              );

              // Filter 2: Chat Admin (Hanya hitung thread milik userLaravelId ini)
              _unreadAdminStream = _chatService.getUnreadCountByPrefix(
                uid, 
                'cabang_',
                userLaravelId: laravelId // <--- INI KUNCINYA
              );
            });
          }
          
          // 4. LOAD SISANYA
          _fetchUnreadCount();
          _fetchLaporanTerbaru();
        } else {
          _showSnackbar('Sesi berakhir. Silakan login kembali.', isError: true);
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

  void _showDetailPemakaianDialog() {
    // Warna tema untuk dialog ini
    const Color primaryBlue = Color(0xFF0077B6);
    const Color lightBlueBg = Color(0xFFF0F8FF);

    showDialog(
      context: context,
      barrierDismissible: true, // Bisa ditutup dengan klik di luar
      builder: (BuildContext context) {
        // Gunakan Dialog kustom, bukan AlertDialog standar agar lebih fleksibel
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Sudut lebih membulat
          ),
          elevation: 10,
          backgroundColor: Colors.transparent, // Transparan agar kita bisa atur containernya
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400), // Batasi lebar di tablet
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- 1. HEADER DIALOG ---
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: lightBlueBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Ionicons.water, color: primaryBlue, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Detail Pemakaian Air',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: const Color(0xFF2B2B2B),
                        ),
                      ),
                    ),
                    // Tombol Close kecil di pojok kanan atas
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Icon(Icons.close_rounded, color: Colors.grey[400]),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // --- 2. KARTU INFO PELANGGAN (Dengan Gradien Elegant) ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // Gradien yang senada tapi lebih terang dari kartu utama
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Ionicons.person, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _detailNamaPelanggan.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID Pelanggan: $_detailIdPelanggan',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  "Riwayat Stand Meter (2 Bulan Terakhir)",
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700]
                  ),
                ),
                const SizedBox(height: 12),

                // --- 3. KONTEN TABEL (Kustom agar lebih elegan) ---
                Flexible(
                  child: _riwayatMeterList.isEmpty
                      ? _buildEmptyState() // Tampilan jika kosong
                      : _buildCustomTable(lightBlueBg, primaryBlue), // Tampilan tabel
                ),

                const SizedBox(height: 24),

                // --- 4. TOMBOL TUTUP (Full Width) ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightBlueBg,
                      foregroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Tutup",
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 16
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildCustomTable(Color headerBg, Color highlightColor) {
  // Gaya text header
  final headerStyle = GoogleFonts.manrope(
      fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey[700]);
  // Gaya text isi
  final cellStyle = GoogleFonts.manrope(
      fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87);

  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade200),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          // Header Tabel
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: headerBg,
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Periode', style: headerStyle)),
                Expanded(flex: 1, child: Text('Awal', style: headerStyle, textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Akhir', style: headerStyle, textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Pakai', style: headerStyle, textAlign: TextAlign.end)),
              ],
            ),
          ),
          // Isi Tabel
          ListView.separated(
            shrinkWrap: true, // Agar tidak error di dalam Column
            physics: const NeverScrollableScrollPhysics(), // Scroll ikut parent
            itemCount: _riwayatMeterList.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final item = _riwayatMeterList[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(item['periode'] ?? '-', style: cellStyle.copyWith(fontWeight: FontWeight.w600))),
                    Expanded(flex: 1, child: Text(item['stand_awal'] ?? '0', style: cellStyle, textAlign: TextAlign.center)),
                    Expanded(flex: 1, child: Text(item['stand_akhir'] ?? '0', style: cellStyle, textAlign: TextAlign.center)),
                    Expanded(
                      flex: 1,
                      child: Text(
                        item['pemakaian'] ?? '0',
                        style: cellStyle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: highlightColor // Highlight warna biru untuk pemakaian
                        ),
                        textAlign: TextAlign.end
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Ionicons.document_text_outline, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            "Data riwayat tidak tersedia saat ini.",
            style: GoogleFonts.manrope(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
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

  // ... (Sisa method helper seperti _showBeritaDetailModal, _showInfoDialog, _buildStepTile TETAP SAMA) ...
  // ... COPY PASTE DARI FILE LAMA ANDA JIKA INGIN MENGHEMAT RUANG, ATAU GUNAKAN FILE ASLI ...
  // ... UNTUK KELENGKAPAN SAYA TULIS ULANG DI BAWAH ...

  // --- UPDATE: DETAIL BERITA (DESAIN MENYESUAIKAN POPUP) ---
  void _showBeritaDetailModal(Berita berita) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Konstanta desain (Samakan dengan Popup)
        const double dialogRadius = 24.0;
        const double imageHeight = 250.0; // Sedikit lebih pendek dari popup agar teks muat banyak

        return Dialog(
          // KUNCI UTAMA: Inset padding ini membuat dialog lebar seperti popup
          insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dialogRadius)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              // Pastikan dialog tidak melebihi tinggi layar (agar bisa di-scroll)
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(dialogRadius),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. BAGIAN GAMBAR HEADER (FIXED)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(dialogRadius),
                        topRight: Radius.circular(dialogRadius),
                      ),
                      child: berita.fotoBanner != null
                        ? Image.network(
                            '${_apiService.rootBaseUrl}/storage/${berita.fotoBanner!}',
                            height: imageHeight,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(height: imageHeight, color: Colors.grey.shade300, child: Icon(Icons.broken_image, size: 60, color: Colors.grey.shade400)),
                          )
                        : Container(height: imageHeight, color: const Color(0xFF0077B6)),
                    ),
                    
                    // Overlay Gradient
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(dialogRadius),
                            topRight: Radius.circular(dialogRadius),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.4), // Gelap di atas agar tombol close terlihat
                              Colors.transparent,
                              Colors.black.withOpacity(0.6), // Gelap di bawah untuk teks judul (opsional)
                            ],
                            stops: const [0.0, 0.4, 1.0]
                          ),
                        ),
                      ),
                    ),

                    // Tombol Close (X) di Pojok Kanan Atas
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ),
                    ),

                     // Label Kategori/Info
                    Positioned(
                      top: 16,
                      left: 16,
                       child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0077B6).withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.info_outline, size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Detail Berita",
                                    style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                       ),
                    ),
                  ],
                ),

                // 2. BAGIAN KONTEN (SCROLLABLE)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tanggal & Penulis
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('d MMMM yyyy').format(berita.tanggalTerbit),
                              style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            if (berita.namaAdmin != null) ...[
                              Icon(Icons.person_outline_rounded, size: 16, color: const Color(0xFF0077B6)),
                              const SizedBox(width: 4),
                              Text(
                                berita.namaAdmin!,
                                style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF0077B6), fontWeight: FontWeight.bold),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Judul Besar
                        Text(
                          berita.judul,
                          style: GoogleFonts.manrope(
                            fontSize: 24, // Lebih besar
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(thickness: 1, height: 30),
                        
                        // Isi Berita Lengkap
                        Text(
                          berita.isi,
                          style: GoogleFonts.manrope(
                            fontSize: 16, // Lebih nyaman dibaca
                            color: Colors.grey.shade800,
                            height: 1.8, // Spasi antar baris lebih lega
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. BAGIAN BAWAH (TOMBOL TUTUP BESAR)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(dialogRadius),
                      bottomRight: Radius.circular(dialogRadius),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("Tutup", style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// --- FITUR BARU: POPUP BERITA TERBARU (UKURAN LEBIH BESAR) ---
  
  // --- UPDATE: POPUP LEBIH TINGGI & BESAR ---
  void _showPopupBerita(Berita berita) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          // Inset padding diatur agar tidak terlalu mepet tepi layar HP
          insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), // Padding bawah sedikit ditambah
                margin: const EdgeInsets.only(top: 16, right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Akan mengikuti konten, tapi karena gambar besar dia jadi tinggi
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label KABAR TERBARU
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.new_releases_rounded, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            "KABAR TERBARU",
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // GAMBAR (DIPERBESAR TINGGINYA JADI 300)
                    if (berita.fotoBanner != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          '${_apiService.rootBaseUrl}/storage/${berita.fotoBanner!}',
                          // --- UPDATE DISINI: Tinggi jadi 300 agar popup memanjang ---
                          height: 300, 
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(height: 300, color: Colors.grey.shade200, child: Icon(Icons.broken_image, size: 60)),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Judul Berita
                    Text(
                      berita.judul,
                      style: GoogleFonts.manrope(
                        fontSize: 22, // Font judul diperbesar sedikit
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Isi Singkat
                    Text(
                      berita.isi,
                      style: GoogleFonts.manrope(fontSize: 15, color: Colors.grey.shade700, height: 1.6),
                      maxLines: 4, // Baris teks ditambah agar mengisi ruang vertikal
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 32),

                    // Tombol
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                              padding: EdgeInsets.symmetric(vertical: 16), // Tombol lebih tinggi
                            ),
                            child: Text("Tutup", style: GoogleFonts.manrope(color: Colors.grey.shade800, fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(); 
                              _showBeritaDetailModal(berita); 
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0077B6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: EdgeInsets.symmetric(vertical: 16), // Tombol lebih tinggi
                              elevation: 4,
                              shadowColor: Color(0xFF0077B6).withOpacity(0.4),
                            ),
                            child: Text("Baca Detail", style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Tombol Close Bulat
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))]
                    ),
                    child: Icon(Icons.close, color: Colors.black87, size: 26),
                  ),
                ),
              ),
            ],
          ),
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
          return false;
        } else {
          SystemNavigator.pop();
          return true;
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(textColor, subtleTextColor),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor))
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
          
          // --- BAGIAN INI YANG SAYA KEMBALIKAN LENGKAP ---
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
                    "Instal Aplikasi Banyu Digital.",
                    "Milih menu 'Daftar Sambungan Baru' ",
                    "Isi semua formulir pendaftaran yg ada di Aplikasi.",
                    "Unggah dokumen persyaratan KTP dan Foto Rumah.",
                    "Petugas akan melakukan survei ke lokasi pemasangan untuk menentukan kelayakan teknis.",
                    "Jika disetujui, lakukan pembayaran biaya pendaftaran dan pemasangan.",
                    "Tim teknis akan datang ke lokasi Anda untuk melakukan pemasangan pipa dan meteran air."
                  ];
                  _showInfoDialog(title: "Alur Pemasangan Baru", steps: steps);
                },
              ),
            ],
          ),
          // --- AKHIR BAGIAN YANG DIKEMBALIKAN ---
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor, {String? actionText, VoidCallback? onActionTap}) {
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
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID', 
      symbol: 'Rp ', 
      decimalDigits: 0
    );

    // [MODIFIKASI] Bungkus dengan GestureDetector/InkWell
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isBillLoading ? null : _showDetailPemakaianDialog, // <--- Panggil Dialog Di Sini
        borderRadius: BorderRadius.circular(24),
        child: Container(
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
          child: _isBillLoading
              ? const Center(
                  child: SizedBox(
                    height: 30, 
                    width: 30, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                  )
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Penggunaan Air Terakhir", 
                          style: GoogleFonts.manrope(color: Colors.white, fontSize: 16),
                        ),
                        // Tambahkan ikon info kecil agar user tahu bisa diklik
                        Icon(Ionicons.information_circle_outline,
                            color: Colors.white.withOpacity(0.8), size: 24),
                      ],
                    ),
                    
                    if (_usagePeriod.isNotEmpty && _usagePeriod != "-")
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "Periode: $_usagePeriod", 
                          style: GoogleFonts.manrope(
                            color: Colors.white.withOpacity(0.9), 
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic
                          ),
                        ),
                      )
                    else
                       const SizedBox(height: 8),
    
                    const SizedBox(height: 4),
    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _usageAmount, 
                          style: GoogleFonts.manrope(
                              fontSize: 40, 
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            'Liter', 
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
                            style: GoogleFonts.manrope(color: Colors.white, fontSize: 14)),
                        Text(
                          currencyFormatter.format(_billAmount), 
                          style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
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
      {
        'icon': Ionicons.warning_outline,
        'label': 'Lapor Kebocoran',
        'route': '/temuan_kebocoran'
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
        final String route = service['route'] as String;

        Stream<int>? badgeStream;
        if (route == '/lacak_laporan_saya') {
          badgeStream = _unreadLaporanStream;
        } else if (route == '/hubungi_kami') {
          badgeStream = _unreadAdminStream;
        }

        // Widget Konten Ikon (Putih, Kotak)
        Widget iconContent = Container(
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
        );

        // Widget dasar yang bisa diklik
        Widget baseIcon = _AnimatedIconButton(
          onTap: () async { // WAJIB ASYNC AGAR BISA MENUNGGU NAVIGASI SELESAI
            if (route == '/hubungi_kami') {
              if (_userData != null) {
                await Navigator.push( 
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ChatPage(userData: _userData!)));
                _loadUserData(); // Refresh saat kembali
              }
            } else if (route == '/lacak_laporan_saya') {
               await Navigator.pushNamed(context, route);
               _loadUserData(); // Refresh saat kembali
            } else {
              Navigator.pushNamed(context, route);
            }
          },
          child: iconContent,
        );

        // Jika memiliki stream badge
        if (badgeStream != null) {
          return StreamBuilder<int>(
            stream: badgeStream,
            initialData: 0, 
            builder: (context, snapshot) {
              final int count = snapshot.data ?? 0;
              
              // Jika 0, tampilkan ikon polos
              if (count == 0) {
                return FadeInAnimation(delay: 100 * index, child: baseIcon);
              }

              Widget badgeWidget;

              // LOGIKA TAMPILAN BADGE
              if (route == '/lacak_laporan_saya') {
                // Lacak Laporan: Hanya Titik Merah (DOT)
                badgeWidget = Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                );
              } else {
                // Hubungi Kami (Admin): Angka (NUMBER)
                badgeWidget = Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              // Bungkus dengan Stack agar Badge mengambang di atas ikon
              return FadeInAnimation(
                delay: 100 * index,
                child: Stack(
                  fit: StackFit.expand, 
                  clipBehavior: Clip.none, 
                  children: [
                    baseIcon, 
                    Positioned(
                      top: -5,    
                      right: -5,  
                      child: IgnorePointer(child: badgeWidget),
                    ),
                  ],
                ),
              );
            },
          );
        }

        return FadeInAnimation(
          delay: 100 * index,
          child: baseIcon,
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