// lib/lacak_laporan_saya_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/pengaduan_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      // --- PERBAIKAN UTAMA ADA DI SINI ---
      if (mounted && responseData['success'] == true) {
        // Cek apakah server mengembalikan objek 'data' yang sudah diperbarui
        if (responseData['data'] != null &&
            responseData['data'] is Map<String, dynamic>) {
          // Buat objek Pengaduan baru dari data yang dikembalikan server
          final updatedLaporan = Pengaduan.fromJson(responseData['data']);

          final index = _laporanList.indexWhere(
            (item) => item.id == laporan.id,
          );
          if (index != -1) {
            setState(() {
              // Ganti item lama di list dengan item baru yang datanya paling akurat dari server
              _laporanList[index] = updatedLaporan;
            });
          }
        } else {
          // Fallback jika 'data' tidak ada (seharusnya tidak terjadi)
          // Tetap update UI secara lokal agar responsif
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
              title: Text('Laporan #${laporan.id}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRowDialog(
                      'Kategori:',
                      laporan.friendlyKategori,
                    ),
                    _buildDetailRowDialog('Status:', laporan.friendlyStatus),
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
                      const Divider(height: 24, thickness: 1),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          laporan.ratingHasil == null
                              ? 'Beri Penilaian:'
                              : 'Penilaian Anda:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      _buildRatingBar(
                        title: 'Kecepatan Respon',
                        currentRating: _dialogRatingKecepatan,
                        onRatingUpdate:
                            (rating) => setDialogState(
                              () => _dialogRatingKecepatan = rating,
                            ),
                        isLoading: _isDialogRatingLoading,
                      ),
                      _buildRatingBar(
                        title: 'Pelayanan Petugas',
                        currentRating: _dialogRatingPelayanan,
                        onRatingUpdate:
                            (rating) => setDialogState(
                              () => _dialogRatingPelayanan = rating,
                            ),
                        isLoading: _isDialogRatingLoading,
                      ),
                      _buildRatingBar(
                        title: 'Hasil Penanganan',
                        currentRating: _dialogRatingHasil,
                        onRatingUpdate:
                            (rating) => setDialogState(
                              () => _dialogRatingHasil = rating,
                            ),
                        isLoading: _isDialogRatingLoading,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _komentarRatingController,
                        decoration: InputDecoration(
                          labelText: 'Komentar (Opsional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        maxLines: 3,
                        minLines: 2,
                        readOnly: _isDialogRatingLoading,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 16),
                      if (_isDialogRatingLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (allRatingsGiven)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(
                              laporan.ratingHasil == null
                                  ? Icons.send_rounded
                                  : Icons.edit_note_rounded,
                            ),
                            label: Text(
                              laporan.ratingHasil == null
                                  ? 'Kirim Penilaian'
                                  : 'Update Penilaian',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      _isDialogRatingLoading
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Tutup'),
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Center(
            child: RatingBar.builder(
              initialRating: currentRating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemSize: 34.0,
              itemPadding: const EdgeInsets.symmetric(horizontal: 3.0),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const Text(": "),
          Expanded(
            child: Text(
              value,
              maxLines: isMultiline ? 5 : 2,
              overflow: TextOverflow.ellipsis,
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
      appBar: AppBar(title: const Text('Riwayat Laporan Saya')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                onRefresh: () => _fetchLaporan(showLoadingIndicator: false),
                child:
                    _laporanList.isEmpty
                        ? Center(
                          child: Text(
                            "Belum ada laporan pengaduan.",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _laporanList.length,
                          itemBuilder: (context, index) {
                            final laporan = _laporanList[index];
                            final bool isRated = laporan.ratingHasil != null;
                            final Color statusColor = _getStatusColor(
                              laporan.status,
                            );

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                title: Text(
                                  laporan.friendlyKategori,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${laporan.id} | Tanggal: ${laporan.tanggalPengaduan}',
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        laporan.friendlyStatus,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing:
                                    isRated
                                        ? Icon(
                                          Icons.star_rounded,
                                          color: Colors.amber.shade700,
                                          size: 28,
                                        )
                                        : null,
                                onTap:
                                    () => _showDetailAndRatingDialog(laporan),
                              ),
                            );
                          },
                        ),
              ),
    );
  }
}