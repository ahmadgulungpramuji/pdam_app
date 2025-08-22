// lib/lacak_laporan_saya_page.dart
// ignore_for_file: unused_element

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart'; // <<<--- FIX 1: MENAMBAHKAN IMPORT YANG HILANG
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/pengaduan_model.dart';
import 'package:pdam_app/models/petugas_simple_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:pdam_app/pages/shared/reusable_chat_page.dart';
import 'package:pdam_app/services/chat_service.dart';

class LacakLaporanSayaPage extends StatefulWidget {
  const LacakLaporanSayaPage({super.key});

  @override
  State<LacakLaporanSayaPage> createState() => _LacakLaporanSayaPageState();
}

class _LacakLaporanSayaPageState extends State<LacakLaporanSayaPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  // --- State untuk Manajemen Data Tab ---
  List<Pengaduan> _masterLaporanList = [];
  List<Pengaduan> _laporanDiproses = [];
  List<Pengaduan> _laporanDikerjakan = [];
  List<Pengaduan> _laporanSelesai = [];
  List<Pengaduan> _laporanDibatalkan = [];
  int _laporanButuhPenilaianCount = 0;
  // --- Akhir State untuk Tab ---

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
  // --- FUNGSI LOGIC (TIDAK BERUBAH) ---
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
          _filterAndCategorizeLaporan(); // Panggil fungsi filter
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi berakhir, silakan login ulang.'),
            backgroundColor: Colors.red,
          ),
        );
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
              _filterAndCategorizeLaporan(); // Re-filter setelah update
            });
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penilaian berhasil dikirim! Terima kasih.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (Navigator.canPop(dialogContext)) {
          Navigator.of(dialogContext).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseData['message'] ?? 'Gagal mengirim penilaian.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setDialogLoadingState(false);
    }
  }


  // ==========================================================
  // --- UI WIDGETS (MODERN & ELEGANT) ---
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text('Lacak Laporan Saya', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                indicator: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                indicatorPadding: const EdgeInsets.symmetric(vertical: 6),
                splashBorderRadius: BorderRadius.circular(30),
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                unselectedLabelStyle: textTheme.bodyMedium,
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
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                    ),
                  ))
                : RefreshIndicator(
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
        return FadeInUp(
          from: 20,
          delay: Duration(milliseconds: 100 * index),
          duration: const Duration(milliseconds: 500),
          child: _buildTimelineCard(laporan, isLast: index == laporanList.length - 1),
        );
      },
    );
  }

  Widget _buildTimelineCard(Pengaduan laporan, {bool isLast = false}) {
    final statusMeta = _getStatusMeta(laporan.status);
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return IntrinsicHeight(
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
                    color: statusMeta.color.withOpacity(0.2),
                  ),
                  child: Icon(statusMeta.icon, color: statusMeta.color, size: 18),
                ),
                Expanded(
                  flex: 5,
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey.shade200,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showDetailAndRatingSheet(laporan),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatusBadge(laporan.friendlyStatus),
                            Text(
                              '#${laporan.id.toString().padLeft(4, '0')}',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          laporan.friendlyKategori,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D2A3A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          laporan.deskripsi,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                             Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('d MMM yyyy, HH:mm').format(laporan.createdAt.toLocal()),
                              style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                            ),
                            const Spacer(),
                            if (laporan.ratingHasil != null)
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    laporan.ratingHasil!.toStringAsFixed(1),
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                             if (laporan.ratingHasil == null)
                               Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
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
    );
  }

  Widget _buildEmptyState({String message = 'Semua laporan pengaduan Anda akan muncul di sini.'}) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
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
                color: Colors.grey.shade100,
              ),
              child: Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Laporan',
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyLarge?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  ({Color color, IconData icon}) _getStatusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return (
          color: Colors.blue.shade700,
          icon: Icons.pending_actions_rounded,
        );
      case 'menunggu_pelanggan':
        return (
          color: Colors.purple.shade700,
          icon: Icons.person_search_rounded,
        );
      case 'diproses':
      case 'diterima':
      case 'menunggu_konfirmasi':
      case 'dalam_perjalanan':
        return (
          color: Colors.orange.shade800,
          icon: Icons.construction_rounded
        );
      case 'selesai':
        return (color: Colors.green.shade700, icon: Icons.check_circle_rounded);
      case 'dibatalkan':
      case 'ditolak':
        return (color: Colors.red.shade700, icon: Icons.cancel_rounded);
      default:
        return (color: Colors.grey.shade600, icon: Icons.help_outline_rounded);
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
            status.replaceAll('_', ' ').toUpperCase(),
            style: GoogleFonts.poppins(
              color: meta.color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
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
        final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            // <<<--- FIX 2: MENDEFINISIKAN KEMBALI FUNGSI YANG HILANG ---
            void updateSheetLoadingState(bool isLoading) {
              setSheetState(() => _isDialogRatingLoading = isLoading);
            }
            // --- -------------------------------------------------- ---

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
                            Center(child: _buildStatusBadge(laporan.friendlyStatus)),
                            const SizedBox(height: 16),
                            Text(
                              'Detail Laporan #${laporan.id}',
                              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            _buildDetailRowSheet('Kategori', laporan.friendlyKategori),
                            _buildDetailRowSheet(
                                  'Tanggal Lapor',
                                  // TAMBAHKAN .toLocal() DI SINI
                                  DateFormat('d MMMM yyyy, HH:mm').format(laporan.createdAt.toLocal())
                                ),
                            _buildDetailRowSheet('Deskripsi', laporan.deskripsi, isMultiline: true),
                            
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
                                        Icon(Icons.info_outline_rounded,
                                            color: Colors.red.shade700,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Alasan Dibatalkan/Ditolak',
                                          style: textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade800,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      laporan.keteranganPenolakan!,
                                      style: textTheme.bodyMedium?.copyWith(
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                             const Divider(height: 32, thickness: 1),
                            _buildContactButtons(laporan),
                            if (laporan.status.toLowerCase() ==
                                'menunggu_pelanggan') ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tindak Lanjut Laporan',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Anda diminta untuk datang ke kantor cabang PDAM untuk diskusi lebih lanjut mengenai laporan tagihan membengkak. Mohon berikan konfirmasi Anda di bawah ini.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (_isDialogRatingLoading)
                                      const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    else ...[
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                          onPressed: () async {
                                            updateSheetLoadingState(true); // SEKARANG VALID
                                            try {
                                              await _apiService
                                                  .respondToComplaint(
                                                laporan.id,
                                                'bersedia',
                                              );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Konfirmasi berhasil dikirim.',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                                Navigator.of(context).pop();
                                              }
                                              _fetchLaporan(
                                                showLoadingIndicator: false,
                                              );
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(e.toString()),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                updateSheetLoadingState(false); // SEKARANG VALID
                                              }
                                            }
                                          },
                                          child: const Text(
                                            'Ya, Saya Bersedia Datang',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: Colors.orange.shade700,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                          onPressed: () async {
                                            updateSheetLoadingState(true); // SEKARANG VALID
                                            try {
                                              await _apiService
                                                  .respondToComplaint(
                                                laporan.id,
                                                'permohonan_cek_kebocoran',
                                              );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Permohonan cek kebocoran berhasil diajukan.',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                                Navigator.of(context).pop();
                                              }
                                              _fetchLaporan(
                                                showLoadingIndicator: false,
                                              );
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(e.toString()),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                updateSheetLoadingState(false); // SEKARANG VALID
                                              }
                                            }
                                          },
                                          child: Text(
                                            'Saya Ingin Ajukan Cek Kebocoran Persil',
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
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
                                      laporan.ratingHasil == null ? 'Beri Penilaian' : 'Penilaian Anda',
                                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildRatingBar(
                                      title: 'Kecepatan Respon',
                                      currentRating: _dialogRatingKecepatan,
                                      onRatingUpdate: (rating) => setSheetState(() => _dialogRatingKecepatan = rating),
                                      isLoading: _isDialogRatingLoading,
                                    ),
                                    _buildRatingBar(
                                      title: 'Pelayanan Petugas',
                                      currentRating: _dialogRatingPelayanan,
                                      onRatingUpdate: (rating) => setSheetState(() => _dialogRatingPelayanan = rating),
                                      isLoading: _isDialogRatingLoading,
                                    ),
                                    _buildRatingBar(
                                      title: 'Hasil Penanganan',
                                      currentRating: _dialogRatingHasil,
                                      onRatingUpdate: (rating) => setSheetState(() => _dialogRatingHasil = rating),
                                      isLoading: _isDialogRatingLoading,
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _komentarRatingController,
                                      style: textTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        hintText: 'Tulis komentar Anda di sini... (Opsional)',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
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
                                    icon: Icon(laporan.ratingHasil == null ? Icons.send_rounded : Icons.edit_note_rounded),
                                    label: Text(laporan.ratingHasil == null ? 'Kirim Penilaian' : 'Update Penilaian'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      textStyle: textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: !canSubmit
                                        ? null
                                        : () => _handleRatingSubmission(
                                              laporan,
                                              _dialogRatingKecepatan,
                                              _dialogRatingPelayanan,
                                              _dialogRatingHasil,
                                              _komentarRatingController.text.trim(),
                                              context,
                                              updateSheetLoadingState, // Menggunakan fungsi yang sudah valid
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
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 16),
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
                  Icon(Icons.star_rounded, color: Colors.amber.shade600),
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
          style: GoogleFonts.poppins( textStyle: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.support_agent),
            label: const Text('Chat dengan Admin Cabang'),
            onPressed: () async {
              try {
                final token = await _apiService.getToken();
                if (token == null || !mounted) return;

                final threadId =
                    await _chatService.getOrCreateAdminChatThreadForPelanggan(
                  userData: _currentUserData!,
                  apiToken: token,
                );

                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReusableChatPage(
                        threadId: threadId!,
                        chatTitle: "Live Chat Admin",
                        currentUser: _currentUserData!,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Gagal memulai chat admin: $e")),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (hasPetugasPelapor && isStatusAktif)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: Text('Chat dengan Petugas ${petugasPelapor.nama}'),
              onPressed: () async {
                try {
                  setState(() => _isDialogRatingLoading = true);
                  final petugasInfo = await _apiService.getChatInfoForPelanggan(
                    'pengaduan',
                    laporan.id,
                  );

                  final threadId =
                      await _chatService.getOrCreateTugasChatThread(
                    tipeTugas: 'pengaduan',
                    idTugas: laporan.id,
                    currentUser: _currentUserData!,
                    otherUser: petugasInfo,
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
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gagal memulai chat petugas: $e")),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isDialogRatingLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
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
          Text(
            label,
            style: GoogleFonts.poppins(
              textStyle: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            )
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.poppins( textStyle:const TextStyle(fontSize: 16, height: 1.5))),
        ],
      ),
    );
  }
}