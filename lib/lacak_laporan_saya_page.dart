// lib/lacak_laporan_saya_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/pengaduan_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts
import 'package:animate_do/animate_do.dart'; // Import Animate_Do

class LacakLaporanSayaPage extends StatefulWidget {
  const LacakLaporanSayaPage({super.key});

  @override
  State<LacakLaporanSayaPage> createState() => _LacakLaporanSayaPageState();
}

class _LacakLaporanSayaPageState extends State<LacakLaporanSayaPage> {
  final ApiService _apiService = ApiService();
  List<Pengaduan> _laporanList = [];
  bool _isLoading = true;
  String? _errorMessage;

  final _komentarRatingController = TextEditingController();
  double _dialogRatingKecepatan = 0;
  double _dialogRatingPelayanan = 0;
  double _dialogRatingHasil = 0;
  bool _isDialogRatingLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLaporan();
  }

  @override
  void dispose() {
    _komentarRatingController.dispose();
    super.dispose();
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_token');
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
        final tempList =
            rawData
                .whereType<Map<String, dynamic>>()
                .map((item) => Pengaduan.fromJson(item))
                .toList();
        tempList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        setState(() {
          _laporanList = tempList;
          _isLoading = false;
        });
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

          final index = _laporanList.indexWhere(
            (item) => item.id == laporan.id,
          );
          if (index != -1) {
            setState(() {
              _laporanList[index] = updatedLaporan;
            });
          }
        } else {
          final index = _laporanList.indexWhere(
            (item) => item.id == laporan.id,
          );
          if (index != -1) {
            setState(() {
              _laporanList[index] = _laporanList[index].copyWith(
                ratingKecepatan: ratingKecepatan.toInt(),
                ratingPelayanan: ratingPelayanan.toInt(),
                ratingHasil: ratingHasil.toInt(),
                komentarRating: komentar.isNotEmpty ? komentar : null,
                updatedAt: DateTime.now(),
              );
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penilaian berhasil dikirim!'),
            backgroundColor: Colors.green,
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
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      setDialogLoadingState(false);
    }
  }

  void _showDetailAndRatingDialog(Pengaduan laporan) {
    _dialogRatingKecepatan = laporan.ratingKecepatan?.toDouble() ?? 0;
    _dialogRatingPelayanan = laporan.ratingPelayanan?.toDouble() ?? 0;
    _dialogRatingHasil = laporan.ratingHasil?.toDouble() ?? 0;
    _komentarRatingController.text = laporan.komentarRating ?? '';
    _isDialogRatingLoading = false;

    showDialog(
      context: context,
      barrierDismissible: !_isDialogRatingLoading,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateDialogLoadingState(bool isLoading) {
              setDialogState(() => _isDialogRatingLoading = isLoading);
            }

            bool allRatingsGiven =
                _dialogRatingKecepatan > 0 &&
                _dialogRatingPelayanan > 0 &&
                _dialogRatingHasil > 0;

            bool ratingsChanged =
                (laporan.ratingKecepatan?.toDouble() ?? 0) !=
                    _dialogRatingKecepatan ||
                (laporan.ratingPelayanan?.toDouble() ?? 0) !=
                    _dialogRatingPelayanan ||
                (laporan.ratingHasil?.toDouble() ?? 0) != _dialogRatingHasil ||
                (laporan.komentarRating ?? '') !=
                    _komentarRatingController.text.trim();

            bool canSubmit =
                allRatingsGiven && ratingsChanged && !_isDialogRatingLoading;

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent, // For a cleaner look on newer Flutter versions
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Detail Laporan #${laporan.id}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              content: SingleChildScrollView(
                child: FadeInUp( // <-- Animasi untuk seluruh konten dialog
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRowDialog(
                        'Kategori:',
                        laporan.friendlyKategori,
                      ),
                      _buildDetailRowDialog('Status:', laporan.friendlyStatus,
                          valueColor: _getStatusColor(laporan.status)),
                      _buildDetailRowDialog(
                        'Tanggal Lapor:',
                        laporan.tanggalPengaduan,
                      ),
                      _buildDetailRowDialog(
                        'Deskripsi:',
                        laporan.deskripsi,
                        isMultiline: true,
                      ),

                      if (laporan.status.toLowerCase() == 'selesai') ...[
                        const Divider(height: 24, thickness: 1, color: Colors.grey),
                        FadeIn( // <-- Animasi untuk judul "Beri Penilaian"
                          duration: const Duration(milliseconds: 400),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              laporan.ratingHasil == null
                                  ? 'Beri Penilaian:'
                                  : 'Penilaian Anda:',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ),
                        FadeInUp( // <-- Animasi untuk Rating Kecepatan
                          duration: const Duration(milliseconds: 500),
                          child: _buildRatingBar(
                            title: 'Kecepatan Respon',
                            currentRating: _dialogRatingKecepatan,
                            onRatingUpdate:
                                (rating) => setDialogState(
                                  () => _dialogRatingKecepatan = rating,
                                ),
                            isLoading: _isDialogRatingLoading,
                          ),
                        ),
                        FadeInUp( // <-- Animasi untuk Rating Pelayanan
                          duration: const Duration(milliseconds: 550),
                          child: _buildRatingBar(
                            title: 'Pelayanan Petugas',
                            currentRating: _dialogRatingPelayanan,
                            onRatingUpdate:
                                (rating) => setDialogState(
                                  () => _dialogRatingPelayanan = rating,
                                ),
                            isLoading: _isDialogRatingLoading,
                          ),
                        ),
                        FadeInUp( // <-- Animasi untuk Rating Hasil
                          duration: const Duration(milliseconds: 600),
                          child: _buildRatingBar(
                            title: 'Hasil Penanganan',
                            currentRating: _dialogRatingHasil,
                            onRatingUpdate:
                                (rating) => setDialogState(
                                  () => _dialogRatingHasil = rating,
                                ),
                            isLoading: _isDialogRatingLoading,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeInUp( // <-- Animasi untuk TextField Komentar
                          duration: const Duration(milliseconds: 650),
                          child: TextField(
                            controller: _komentarRatingController,
                            decoration: InputDecoration(
                              labelText: 'Komentar (Opsional)',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                            maxLines: 3,
                            minLines: 2,
                            readOnly: _isDialogRatingLoading,
                            onChanged: (_) => setDialogState(() {}),
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_isDialogRatingLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (allRatingsGiven)
                          FadeInUp( // <-- Animasi untuk tombol Submit
                            duration: const Duration(milliseconds: 700),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Icon(
                                  laporan.ratingHasil == null
                                      ? Icons.send_rounded
                                      : Icons.edit_note_rounded,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  laporan.ratingHasil == null
                                      ? 'Kirim Penilaian'
                                      : 'Update Penilaian',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 5,
                                  shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                                ),
                                onPressed:
                                    !canSubmit
                                        ? null
                                        : () {
                                            _handleRatingSubmission(
                                              laporan,
                                              _dialogRatingKecepatan,
                                              _dialogRatingPelayanan,
                                              _dialogRatingHasil,
                                              _komentarRatingController.text.trim(),
                                              dialogContext,
                                              updateDialogLoadingState,
                                            );
                                          },
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      _isDialogRatingLoading
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Tutup',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Center(
            child: RatingBar.builder(
              initialRating: currentRating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemSize: 36.0,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder:
                  (context, _) =>
                      Icon(Icons.star_rounded, color: Colors.amber.shade600),
              onRatingUpdate: onRatingUpdate,
              ignoreGestures: isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowDialog(
    String label,
    String value, {
    bool isMultiline = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          const Text(": ", style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              value,
              maxLines: isMultiline ? 5 : 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'diproses':
        return Colors.orange.shade700;
      case 'selesai':
        return Colors.green.shade700;
      case 'dibatalkan':
        return Colors.red.shade700;
      case 'pending':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Riwayat Laporan Saya',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade400,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.red.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _fetchLaporan(),
                          icon: const Icon(Icons.refresh),
                          label: Text('Coba Lagi', style: GoogleFonts.poppins()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchLaporan(showLoadingIndicator: false),
                  color: Theme.of(context).primaryColor,
                  child: _laporanList.isEmpty
                      ? Center(
                          child: FadeInUp(
                            duration: const Duration(milliseconds: 500),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_rounded,
                                  color: Colors.grey.shade400,
                                  size: 80,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Belum ada laporan pengaduan.",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _laporanList.length,
                          itemBuilder: (context, index) {
                            final laporan = _laporanList[index];
                            final bool isRated = laporan.ratingHasil != null;
                            final Color statusColor = _getStatusColor(
                              laporan.status,
                            );

                            return FadeInUp(
                              duration: Duration(milliseconds: 300 + index * 50),
                              child: Card(
                                elevation: 5,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                shadowColor: Colors.grey.withOpacity(0.3),
                                child: InkWell(
                                  onTap: () => _showDetailAndRatingDialog(laporan),
                                  borderRadius: BorderRadius.circular(15),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                laporan.friendlyKategori,
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  color: Colors.blueAccent.shade700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isRated)
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.star_rounded,
                                                    color: Colors.amber.shade700,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    (laporan.ratingHasil ?? 0).toStringAsFixed(0),
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'ID Laporan: ${laporan.id}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tanggal: ${laporan.tanggalPengaduan}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: statusColor, width: 1),
                                            ),
                                            child: Text(
                                              laporan.friendlyStatus,
                                              style: GoogleFonts.poppins(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}