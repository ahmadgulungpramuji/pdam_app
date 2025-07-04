// lib/lacak_laporan_saya_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/pengaduan_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
    Intl.defaultLocale = 'id_ID';
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
        final tempList = rawData
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
          final index = _laporanList.indexWhere((item) => item.id == laporan.id);
          if (index != -1) {
            setState(() {
              _laporanList[index] = updatedLaporan;
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
            
            bool allRatingsGiven = _dialogRatingKecepatan > 0 && _dialogRatingPelayanan > 0 && _dialogRatingHasil > 0;
            bool ratingsChanged = (laporan.ratingKecepatan?.toDouble() ?? 0) != _dialogRatingKecepatan ||
                                  (laporan.ratingPelayanan?.toDouble() ?? 0) != _dialogRatingPelayanan ||
                                  (laporan.ratingHasil?.toDouble() ?? 0) != _dialogRatingHasil ||
                                  (laporan.komentarRating ?? '') != _komentarRatingController.text.trim();
            bool canSubmit = allRatingsGiven && ratingsChanged && !_isDialogRatingLoading;

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            Text(
                              'Detail Laporan #${laporan.id}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Center(child: _buildStatusBadge(laporan.status)),
                            const SizedBox(height: 16),
                            _buildDetailRowSheet('Kategori', laporan.friendlyKategori),
                            _buildDetailRowSheet('Tanggal Lapor', DateFormat('d MMMM yyyy, HH:mm').format(laporan.createdAt)),
                            _buildDetailRowSheet('Deskripsi', laporan.deskripsi, isMultiline: true),
                            
                            // Menggunakan fotoSesudah dari model Anda
                            if (laporan.status.toLowerCase() == 'selesai' &&
                                laporan.fotoSesudah != null &&
                                laporan.fotoSesudah!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildFotoHasil(laporan.fotoSesudah!),
                            ],

                            if (laporan.status.toLowerCase() == 'selesai') ...[
                              const Divider(height: 32, thickness: 1),
                              Text(
                                laporan.ratingHasil == null ? 'Beri Penilaian' : 'Penilaian Anda',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
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
                                decoration: InputDecoration(
                                  labelText: 'Komentar (Opsional)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                                maxLines: 4,
                                minLines: 2,
                                readOnly: _isDialogRatingLoading,
                                onChanged: (_) => setSheetState(() {}),
                                textInputAction: TextInputAction.done,
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          const SizedBox(height: 8),
          Center(
            child: RatingBar.builder(
              initialRating: currentRating,
              minRating: 1,
              itemCount: 5,
              itemSize: 40.0,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => Icon(Icons.star_rounded, color: Colors.amber.shade600),
              onRatingUpdate: onRatingUpdate,
              ignoreGestures: isLoading,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildDetailRowSheet(String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildFotoHasil(String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto Hasil Pengerjaan',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showFullScreenImage(context, imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey, size: 40),
                        SizedBox(height: 8),
                        Text('Gagal memuat gambar'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  ({Color color, IconData icon}) _getStatusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return (color: Colors.blue.shade700, icon: Icons.pending_actions_rounded);
      case 'diproses':
        return (color: Colors.orange.shade700, icon: Icons.sync_rounded);
      case 'selesai':
        return (color: Colors.green.shade700, icon: Icons.check_circle_rounded);
      case 'dibatalkan':
        return (color: Colors.red.shade700, icon: Icons.cancel_rounded);
      default:
        return (color: Colors.grey.shade600, icon: Icons.help_outline_rounded);
    }
  }

  Widget _buildStatusBadge(String status) {
    final meta = _getStatusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: meta.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, color: meta.color, size: 16),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(color: meta.color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLaporanCard(Pengaduan laporan) {
    final statusMeta = _getStatusMeta(laporan.status);
    final bool isRated = laporan.ratingHasil != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusMeta.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(statusMeta.icon, color: statusMeta.color, size: 24),
            ),
            Container(
              width: 2,
              height: 100,
              color: Colors.grey.shade300,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showDetailAndRatingSheet(laporan),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: _buildStatusBadge(laporan.friendlyStatus)),
                        if (isRated)
                          Icon(
                            Icons.star_rate_rounded,
                            color: Colors.amber.shade700,
                            size: 28,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      laporan.friendlyKategori,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ID: ${laporan.id}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d MMMM yyyy, HH:mm').format(laporan.createdAt),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const Divider(height: 24),
                    Text(
                      laporan.deskripsi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Riwayat Laporan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua laporan pengaduan Anda akan muncul di sini.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lacak Laporan Saya'),
        backgroundColor: Theme.of(context).canvasColor,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: () => _fetchLaporan(showLoadingIndicator: false),
                  child: _laporanList.isEmpty
                      ? _buildEmptyState()
                      : AnimationLimiter(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _laporanList.length,
                            itemBuilder: (context, index) {
                              final laporan = _laporanList[index];
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 400),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: _buildLaporanCard(laporan),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
    );
  }
}