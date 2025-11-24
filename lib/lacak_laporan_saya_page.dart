// lib/lacak_laporan_saya_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/pengaduan_model.dart';
import 'package:pdam_app/models/petugas_simple_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:pdam_app/pages/shared/reusable_chat_page.dart';
import 'package:pdam_app/services/chat_service.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// ... (Bagian FadeInAnimation, StaggeredAnimation dll TETAP SAMA) ...
// ... (Untuk menghemat ruang, saya mulai dari class utama. Pastikan Widget Animasi tetap ada di atas) ...

// --- WIDGET ANIMASI ---
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
// --- END WIDGET ANIMASI ---

class LacakLaporanSayaPage extends StatefulWidget {
  const LacakLaporanSayaPage({super.key});

  @override
  State<LacakLaporanSayaPage> createState() => _LacakLaporanSayaPageState();
}

class _LacakLaporanSayaPageState extends State<LacakLaporanSayaPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<Pengaduan> _masterLaporanList = [];
  List<Pengaduan> _laporanDiproses = [];
  List<Pengaduan> _laporanDikerjakan = [];
  List<Pengaduan> _laporanSelesai = [];
  List<Pengaduan> _laporanDibatalkan = [];
  int _laporanButuhPenilaianCount = 0;

  bool _isLoading = true;
  String? _errorMessage;

  final _komentarRatingController = TextEditingController();
  double _dialogRatingKecepatan = 0;
  double _dialogRatingPelayanan = 0;
  double _dialogRatingHasil = 0;
  bool _isDialogRatingLoading = false;
  final ChatService _chatService = ChatService();
  Map<String, dynamic>? _currentUserData;

  int? _targetPengaduanId;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('pengaduan_id')) {
      if (_targetPengaduanId == null) {
        setState(() {
          _targetPengaduanId = arguments['pengaduan_id'];
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id_ID';

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn);

    _fetchLaporan();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _komentarRatingController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _filterAndCategorizeLaporan() {
    _laporanDiproses.clear();
    _laporanDikerjakan.clear();
    _laporanSelesai.clear();
    _laporanDibatalkan.clear();
    int needRatingCount = 0;

    for (var laporan in _masterLaporanList) {
      final status = laporan.status.toLowerCase();

      if (status == 'pending' ||
          status == 'menunggu_konfirmasi' ||
          status == 'menunggu_pelanggan') {
        _laporanDiproses.add(laporan);
      } else if (status == 'diterima' ||
          status == 'dalam_perjalanan' ||
          status == 'diproses') {
        _laporanDikerjakan.add(laporan);
      } else if (status == 'selesai') {
        _laporanSelesai.add(laporan);
        if (laporan.ratingHasil == null) {
          needRatingCount++;
        }
      } else if (status == 'ditolak' || status == 'dibatalkan') {
        _laporanDibatalkan.add(laporan);
      }
    }

    if (mounted) {
      setState(() {
        _laporanButuhPenilaianCount = needRatingCount;
      });
    }
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_token');
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_data');
    if (jsonString != null && mounted) {
      setState(() {
        _currentUserData = jsonDecode(jsonString);
      });
    }
  }

  Future<void> _fetchLaporan({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<dynamic> rawData = await _apiService.getLaporanPengaduan();
      if (mounted) {
        final tempList = rawData
            .whereType<Map<String, dynamic>>()
            .map((item) => Pengaduan.fromJson(item))
            .toList();
        tempList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        setState(() {
          _masterLaporanList = tempList;
          _filterAndCategorizeLaporan(); 
          _isLoading = false;
        });

        _animationController.forward(from: 0.0);

        if (_targetPengaduanId != null) {
          final targetLaporan = _masterLaporanList.firstWhere(
            (l) => l.id == _targetPengaduanId,
            orElse: () => Pengaduan.fallback(),
          );

          if (targetLaporan.id != 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showDetailAndRatingSheet(targetLaporan);
              }
            });
          }
          _targetPengaduanId = null;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRatingSubmission(
    Pengaduan laporan,
    double ratingKecepatan,
    double ratingPelayanan,
    double ratingHasil,
    String komentar,
    BuildContext dialogContext,
    Function(bool isLoading) setDialogLoadingState,
  ) async {
    setDialogLoadingState(true);
    final String? token = await _getAuthToken();
    if (token == null) {
      if (mounted) {
        _showSnackbar('Sesi berakhir, silakan login ulang.', isError: true);
      }
      setDialogLoadingState(false);
      return;
    }

    try {
      final Map<String, dynamic> responseData = await _apiService.submitRating(
        tipeLaporan: 'pengaduan',
        idLaporan: laporan.id,
        ratingKecepatan: ratingKecepatan.toInt(),
        ratingPelayanan: ratingPelayanan.toInt(),
        ratingHasil: ratingHasil.toInt(),
        komentar: komentar,
        token: token,
      );

      if (mounted && responseData['success'] == true) {
        if (responseData['data'] != null &&
            responseData['data'] is Map<String, dynamic>) {
          final updatedLaporan = Pengaduan.fromJson(responseData['data']);
          final index = _masterLaporanList.indexWhere(
            (item) => item.id == laporan.id,
          );
          if (index != -1) {
            setState(() {
              _masterLaporanList[index] = updatedLaporan;
              _filterAndCategorizeLaporan(); 
            });
          }
        }
        _showSnackbar('Penilaian berhasil dikirim! Terima kasih.',
            isError: false);

        if (Navigator.canPop(dialogContext)) {
          Navigator.of(dialogContext).pop();
        }
      } else {
        _showSnackbar(
          responseData['message'] ?? 'Gagal mengirim penilaian.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar('Terjadi kesalahan: ${e.toString()}', isError: true);
    } finally {
      setDialogLoadingState(false);
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.manrope()),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color backgroundColor = Color(0xFFF8F9FA);
    const Color textColor = Color(0xFF212529);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(
            'Lacak Laporan Saya',
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold, color: textColor),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: backgroundColor,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: textColor),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                indicator: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                indicatorPadding: const EdgeInsets.symmetric(vertical: 6),
                splashBorderRadius: BorderRadius.circular(30),
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.manrope(),
                tabs: [
                  const Tab(text: 'Diproses'),
                  const Tab(text: 'Dikerjakan'),
                  Tab(
                    child: Badge(
                      label: Text(_laporanButuhPenilaianCount.toString()),
                      isLabelVisible: _laporanButuhPenilaianCount > 0,
                      backgroundColor: Colors.redAccent,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('Selesai'),
                      ),
                    ),
                  ),
                  const Tab(text: 'Dibatalkan'),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : _errorMessage != null
                ? _buildErrorView()
                : RefreshIndicator(
                    color: primaryColor,
                    onRefresh: () => _fetchLaporan(showLoadingIndicator: false),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: TabBarView(
                        children: [
                          _buildLaporanListView(
                            _laporanDiproses,
                            'Tidak ada laporan yang sedang menunggu diproses.',
                          ),
                          _buildLaporanListView(
                            _laporanDikerjakan,
                            'Tidak ada laporan yang sedang dalam pengerjaan.',
                          ),
                          _buildLaporanListView(
                            _laporanSelesai,
                            'Belum ada laporan yang selesai ditangani.',
                          ),
                          _buildLaporanListView(
                            _laporanDibatalkan,
                            'Tidak ada laporan yang dibatalkan atau ditolak.',
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildLaporanListView(
      List<Pengaduan> laporanList, String emptyMessage) {
    if (laporanList.isEmpty) {
      return _buildEmptyState(message: emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      itemCount: laporanList.length,
      itemBuilder: (context, index) {
        final laporan = laporanList[index];
        return FadeInAnimation(
          delay: 100 * index,
          child: TimelineCardWithUnreadBadge(
            laporan: laporan,
            isLast: index == laporanList.length - 1,
            currentUserData: _currentUserData,
            chatService: _chatService,
            onTap: () => _showDetailAndRatingSheet(laporan),
            getStatusMeta: _getStatusMeta,
            buildStatusBadge: _buildStatusBadge,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
      {String message = 'Semua laporan Anda akan muncul di sini.'}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: Icon(Ionicons.file_tray_stacked_outline,
                  size: 60, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Laporan',
              style: GoogleFonts.manrope(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.manrope(
                  fontSize: 15, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
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
            Icon(Ionicons.cloud_offline_outline,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text("Oops!",
                style: GoogleFonts.manrope(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_errorMessage ?? "Terjadi kesalahan.",
                textAlign: TextAlign.center, style: GoogleFonts.manrope()),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh_outline),
              label: const Text("Coba Lagi"),
              onPressed: _fetchLaporan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0077B6),
                foregroundColor: Colors.white,
                textStyle: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({Color color, IconData icon}) _getStatusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return (color: Colors.blue.shade700, icon: Ionicons.time_outline);
      case 'menunggu_pelanggan':
        return (
          color: Colors.purple.shade700,
          icon: Ionicons.person_circle_outline
        );
      case 'diproses':
      case 'diterima':
      case 'menunggu_konfirmasi':
      case 'dalam_perjalanan':
        return (color: Colors.orange.shade800, icon: Ionicons.build_outline);
      case 'selesai':
        return (
          color: Colors.green.shade700,
          icon: Ionicons.checkmark_circle_outline
        );
      case 'dibatalkan':
      case 'ditolak':
        return (
          color: Colors.red.shade700,
          icon: Ionicons.close_circle_outline
        );
      default:
        return (
          color: Colors.grey.shade600,
          icon: Ionicons.help_circle_outline
        );
    }
  }

  Widget _buildStatusBadge(String status) {
    final meta = _getStatusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: meta.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, color: meta.color, size: 14),
          const SizedBox(width: 6),
          Text(
            status,
            style: GoogleFonts.manrope(
              color: meta.color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailAndRatingSheet(Pengaduan laporan) {
    _dialogRatingKecepatan = laporan.ratingKecepatan?.toDouble() ?? 0;
    _dialogRatingPelayanan = laporan.ratingPelayanan?.toDouble() ?? 0;
    _dialogRatingHasil = laporan.ratingHasil?.toDouble() ?? 0;
    _komentarRatingController.text = laporan.komentarRating ?? '';
    _isDialogRatingLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            void updateSheetLoadingState(bool isLoading) {
              setSheetState(() => _isDialogRatingLoading = isLoading);
            }

            bool allRatingsGiven = _dialogRatingKecepatan > 0 &&
                _dialogRatingPelayanan > 0 &&
                _dialogRatingHasil > 0;
            bool ratingsChanged = (laporan.ratingKecepatan?.toDouble() ?? 0) !=
                    _dialogRatingKecepatan ||
                (laporan.ratingPelayanan?.toDouble() ?? 0) !=
                    _dialogRatingPelayanan ||
                (laporan.ratingHasil?.toDouble() ?? 0) != _dialogRatingHasil ||
                (laporan.komentarRating ?? '') !=
                    _komentarRatingController.text.trim();
            bool canSubmit =
                allRatingsGiven && ratingsChanged && !_isDialogRatingLoading;

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                          children: [
                            Center(
                                child:
                                    _buildStatusBadge(laporan.friendlyStatus)),
                            const SizedBox(height: 16),
                            Text(
                              'Detail Laporan #${laporan.id}',
                              style: GoogleFonts.manrope(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            _buildDetailRowSheet(
                                'Kategori', laporan.friendlyKategori),
                            _buildDetailRowSheet(
                                'Tanggal Lapor',
                                DateFormat('d MMMM yyyy, HH:mm')
                                    .format(laporan.createdAt.toLocal())),
                            _buildDetailRowSheet('Deskripsi', laporan.deskripsi,
                                isMultiline: true),
                            if ((laporan.status.toLowerCase() == 'dibatalkan' ||
                                    laporan.status.toLowerCase() ==
                                        'ditolak') &&
                                laporan.keteranganPenolakan != null &&
                                laporan.keteranganPenolakan!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                            Ionicons.information_circle_outline,
                                            color: Colors.red.shade700,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Alasan Dibatalkan/Ditolak',
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      laporan.keteranganPenolakan!,
                                      style: GoogleFonts.manrope(height: 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Divider(height: 32, thickness: 0.5),
                            if (laporan.status.toLowerCase() ==
                                'menunggu_pelanggan') ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tindak Lanjut Laporan',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Anda diminta untuk datang ke kantor cabang PDAM untuk diskusi lebih lanjut mengenai laporan tagihan membengkak. Mohon berikan konfirmasi Anda di bawah ini.',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (_isDialogRatingLoading)
                                      const Center(
                                          child: CircularProgressIndicator())
                                    else ...[
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: _buttonStyle().copyWith(
                                              backgroundColor:
                                                  MaterialStateProperty.all(
                                                      Colors.green.shade600)),
                                          onPressed: () async {
                                            updateSheetLoadingState(true);
                                            try {
                                              await _apiService
                                                  .respondToComplaint(
                                                      laporan.id, 'bersedia');
                                              _showSnackbar(
                                                  'Konfirmasi berhasil dikirim.',
                                                  isError: false);
                                              Navigator.of(context).pop();
                                              _fetchLaporan(
                                                  showLoadingIndicator: false);
                                            } catch (e) {
                                              _showSnackbar(e.toString(),
                                                  isError: true);
                                            } finally {
                                              if (mounted)
                                                updateSheetLoadingState(false);
                                            }
                                          },
                                          child: const Text(
                                              'Ya, Saya Bersedia Datang'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          style: _buttonStyle(isOutlined: true)
                                              .copyWith(
                                            foregroundColor:
                                                MaterialStateProperty.all(
                                                    Colors.orange.shade800),
                                            side: MaterialStateProperty.all(
                                                BorderSide(
                                                    color: Colors
                                                        .orange.shade700)),
                                          ),
                                          onPressed: () async {
                                            updateSheetLoadingState(true);
                                            try {
                                              await _apiService
                                                  .respondToComplaint(
                                                      laporan.id,
                                                      'permohonan_cek_kebocoran');
                                              _showSnackbar(
                                                  'Permohonan cek kebocoran berhasil diajukan.',
                                                  isError: false);
                                              Navigator.of(context).pop();
                                              _fetchLaporan(
                                                  showLoadingIndicator: false);
                                            } catch (e) {
                                              _showSnackbar(e.toString(),
                                                  isError: true);
                                            } finally {
                                              if (mounted)
                                                updateSheetLoadingState(false);
                                            }
                                          },
                                          child: const Text(
                                              'Saya Ingin Ajukan Cek Kebocoran Persil'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Divider(height: 32, thickness: 0.5),
                            ],
                            _buildContactButtons(laporan),
                            if (laporan.status.toLowerCase() == 'selesai') ...[
                              const Divider(height: 32),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      laporan.ratingHasil == null
                                          ? 'Beri Penilaian'
                                          : 'Penilaian Anda',
                                      style: GoogleFonts.manrope(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildRatingBar(
                                      title: 'Kecepatan Respon',
                                      currentRating: _dialogRatingKecepatan,
                                      onRatingUpdate: (rating) => setSheetState(
                                          () =>
                                              _dialogRatingKecepatan = rating),
                                      isLoading: _isDialogRatingLoading,
                                    ),
                                    _buildRatingBar(
                                      title: 'Pelayanan Petugas',
                                      currentRating: _dialogRatingPelayanan,
                                      onRatingUpdate: (rating) => setSheetState(
                                          () =>
                                              _dialogRatingPelayanan = rating),
                                      isLoading: _isDialogRatingLoading,
                                    ),
                                    _buildRatingBar(
                                      title: 'Hasil Penanganan',
                                      currentRating: _dialogRatingHasil,
                                      onRatingUpdate: (rating) => setSheetState(
                                          () => _dialogRatingHasil = rating),
                                      isLoading: _isDialogRatingLoading,
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _komentarRatingController,
                                      style: GoogleFonts.manrope(),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Tulis komentar Anda... (Opsional)',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      maxLines: 4,
                                      minLines: 2,
                                      readOnly: _isDialogRatingLoading,
                                      onChanged: (_) => setSheetState(() {}),
                                      textInputAction: TextInputAction.done,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (_isDialogRatingLoading)
                                const Center(child: CircularProgressIndicator())
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: Icon(laporan.ratingHasil == null
                                        ? Ionicons.send_outline
                                        : Ionicons.create_outline),
                                    label: Text(laporan.ratingHasil == null
                                        ? 'Kirim Penilaian'
                                        : 'Update Penilaian'),
                                    style: _buttonStyle(),
                                    onPressed: !canSubmit
                                        ? null
                                        : () => _handleRatingSubmission(
                                              laporan,
                                              _dialogRatingKecepatan,
                                              _dialogRatingPelayanan,
                                              _dialogRatingHasil,
                                              _komentarRatingController.text
                                                  .trim(),
                                              context,
                                              updateSheetLoadingState,
                                            ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRatingBar({
    required String title,
    required double currentRating,
    required Function(double) onRatingUpdate,
    required bool isLoading,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Center(
            child: RatingBar.builder(
              initialRating: currentRating,
              minRating: 1,
              itemCount: 5,
              itemSize: 40.0,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) =>
                  const Icon(Ionicons.star, color: Colors.amber),
              onRatingUpdate: onRatingUpdate,
              ignoreGestures: isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButtons(Pengaduan laporan) {
    if (_currentUserData == null) return const SizedBox.shrink();

    final petugasPelapor =
        (laporan.petugasDitugaskan != null && laporan.idPetugasPelapor != null)
            ? laporan.petugasDitugaskan!.firstWhere(
                (p) => p.id == laporan.idPetugasPelapor,
                orElse: () => PetugasSimple(id: 0, nama: ''),
              )
            : null;

    final bool hasPetugasPelapor =
        petugasPelapor != null && petugasPelapor.id != 0;

    final List<String> statusAktifUntukChat = [
      'diterima',
      'dalam_perjalanan',
      'diproses',
    ];
    final bool isStatusAktif = statusAktifUntukChat.contains(laporan.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Butuh Bantuan?',
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Ionicons.headset_outline),
            label: const Text('Chat dengan Admin Cabang'),
            onPressed: () async {
              try {
                setState(() => _isDialogRatingLoading = true);
                final adminInfoList =
                    await _apiService.getBranchAdminInfoByCabangId(
                  laporan.idCabang.toString(),
                );
                if (adminInfoList.isEmpty) {
                  throw Exception(
                      "Tidak ada admin yang dapat dihubungi untuk cabang ini.");
                }

                // Logic Chat Admin - Sesuai File Anda
                final threadId = 'cabang_${laporan.idCabang}_pelanggan_${_currentUserData!['id']}';

                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReusableChatPage(
                        threadId: threadId,
                        chatTitle: "Chat Admin: #${laporan.id}",
                        currentUser: _currentUserData!,
                      ),
                    ),
                  );
                }
              } catch (e) {
                _showSnackbar("Gagal memulai chat admin: ${e.toString()}",
                    isError: true);
              } finally {
                if (mounted) {
                  setState(() => _isDialogRatingLoading = false);
                }
              }
            },
            style: _buttonStyle(isOutlined: true),
          ),
        ),
        const SizedBox(height: 8),
        if (hasPetugasPelapor && isStatusAktif)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Ionicons.person_outline),
              label: Text('Chat dengan Petugas ${petugasPelapor.nama}'),
              onPressed: () async {
                try {
                  setState(() => _isDialogRatingLoading = true);
                  final petugasInfo = await _apiService.getChatInfoForPelanggan(
                    'pengaduan',
                    laporan.id,
                  );
                  
                  // PERUBAHAN DISINI: Menggunakan fungsi yang sudah pakai generateTugasThreadId
                  final threadId =
                      await _chatService.getOrCreateTugasChatThread(
                    tipeTugas: 'pengaduan',
                    idTugas: laporan.id,
                    currentUser: _currentUserData!,
                    otherUsers: [petugasInfo],
                    cabangId: laporan.idCabang,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReusableChatPage(
                          threadId: threadId,
                          chatTitle: "Chat Petugas: #${laporan.id}",
                          currentUser: _currentUserData!,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  _showSnackbar("Gagal memulai chat petugas: $e",
                      isError: true);
                } finally {
                  if (mounted) {
                    setState(() => _isDialogRatingLoading = false);
                  }
                }
              },
              style: _buttonStyle(),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailRowSheet(
    String label,
    String value, {
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.manrope(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.manrope(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }

  ButtonStyle _buttonStyle({bool isOutlined = false}) {
    const Color primaryColor = Color(0xFF0077B6);
    return isOutlined
        ? OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: primaryColor),
            foregroundColor: primaryColor,
            textStyle: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            elevation: 2,
          );
  }
}

// ==========================================================
// --- WIDGET CARD DENGAN BADGE STREAM ---
// ==========================================================

class TimelineCardWithUnreadBadge extends StatefulWidget {
  final Pengaduan laporan;
  final bool isLast;
  final Map<String, dynamic>? currentUserData;
  final VoidCallback onTap;
  final ChatService chatService;
  final Function(String) getStatusMeta;
  final Function(String) buildStatusBadge;

  const TimelineCardWithUnreadBadge({
    super.key,
    required this.laporan,
    required this.isLast,
    required this.currentUserData,
    required this.onTap,
    required this.chatService,
    required this.getStatusMeta,
    required this.buildStatusBadge,
  });

  @override
  State<TimelineCardWithUnreadBadge> createState() =>
      _TimelineCardWithUnreadBadgeState();
}

class _TimelineCardWithUnreadBadgeState
    extends State<TimelineCardWithUnreadBadge> {
  Stream<int>? _unreadPetugasChatCountStream;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  @override
  void didUpdateWidget(covariant TimelineCardWithUnreadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.laporan.id != widget.laporan.id) {
      _setupStream();
    }
  }

  void _setupStream() {
    if (widget.currentUserData != null && widget.currentUserData!['firebase_uid'] != null) {
      
      // GUNAKAN HELPER YANG SAMA PERSIS DENGAN CHAT SERVICE
      // Ini memastikan ID-nya sinkron (misal: pengaduan_2 vs pengaduan_02)
      final String petugasThreadId = widget.chatService.generateTugasThreadId(
        tipeTugas: 'pengaduan',
        idTugas: widget.laporan.id,
      );

      // Debug (Opsional, bisa dihapus nanti)
      // print("Badge Monitoring ID: $petugasThreadId");

      setState(() {
        _unreadPetugasChatCountStream = widget.chatService.getUnreadMessageCount(
          petugasThreadId,
          widget.currentUserData!['firebase_uid'],
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadPetugasChatCountStream,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Badge(
          label: Text(unreadCount.toString()),
          isLabelVisible: unreadCount > 0,
          alignment: const AlignmentDirectional(1.0, -0.45),
          largeSize: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6),

          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          width: 2,
                          color: Colors.grey.shade200,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (widget.getStatusMeta(widget.laporan.status)
                                  as ({Color color, IconData icon}))
                              .color
                              .withOpacity(0.2),
                        ),
                        child: Icon(
                            (widget.getStatusMeta(widget.laporan.status)
                                    as ({Color color, IconData icon}))
                                .icon,
                            color: (widget.getStatusMeta(widget.laporan.status)
                                    as ({Color color, IconData icon}))
                                .color,
                            size: 18),
                      ),
                      Expanded(
                        flex: 5,
                        child: Container(
                          width: 2,
                          color: widget.isLast
                              ? Colors.transparent
                              : Colors.grey.shade200,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
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
                        onTap: widget.onTap,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  widget.buildStatusBadge(
                                      widget.laporan.friendlyStatus),
                                  Text(
                                    '#LAP${widget.laporan.id}',
                                    style: GoogleFonts.manrope(
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.laporan.friendlyKategori,
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: const Color(0xFF212529),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.laporan.deskripsi,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                    color: Colors.grey.shade600, height: 1.5),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Ionicons.calendar_outline,
                                      size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('d MMM yyyy, HH:mm').format(
                                        widget.laporan.createdAt.toLocal()),
                                    style: GoogleFonts.manrope(
                                        color: Colors.grey.shade600,
                                        fontSize: 12),
                                  ),
                                  const Spacer(),
                                  if (widget.laporan.ratingHasil != null)
                                    Row(
                                      children: [
                                        Icon(Ionicons.star,
                                            color: Colors.amber.shade700,
                                            size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.laporan.ratingHasil!
                                              .toStringAsFixed(1),
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade800,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Icon(Ionicons.chevron_forward,
                                        size: 16, color: Colors.grey.shade400),
                                ],
                              ),
                            ],
                          ),
                        ),
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
}