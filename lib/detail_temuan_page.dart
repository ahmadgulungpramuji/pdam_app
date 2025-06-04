// lib/detail_temuan_page.dart
// ignore: unused_import
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Clipboard
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:pdam_app/models/temuan_kebocoran_model.dart';
import 'package:pdam_app/api_service.dart';
// import 'package:intl/intl.dart'; // Jika ingin format tanggal

class DetailTemuanPage extends StatefulWidget {
  final TemuanKebocoran temuanKebocoran;

  const DetailTemuanPage({super.key, required this.temuanKebocoran});

  @override
  State<DetailTemuanPage> createState() => _DetailTemuanPageState();
}

class _DetailTemuanPageState extends State<DetailTemuanPage> {
  late TemuanKebocoran _currentTemuan;
  final ApiService _apiService = ApiService();

  // State untuk rating
  final _komentarRatingController = TextEditingController();
  double _ratingValueForDialog = 0;
  bool _isSubmittingRating = false;

  @override
  void initState() {
    super.initState();
    _currentTemuan = widget.temuanKebocoran;
    // Inisialisasi nilai rating jika sudah ada
    _ratingValueForDialog = _currentTemuan.rating?.toDouble() ?? 0;
    _komentarRatingController.text = _currentTemuan.komentarRating ?? '';
  }

  @override
  void dispose() {
    _komentarRatingController.dispose();
    super.dispose();
  }

  void _showSnackbar(
    String message, {
    bool isError = true,
    Color? backgroundColor,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError
                ? Colors.red.shade600
                : (backgroundColor ?? Colors.green.shade600),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitTemuanRating() async {
    if (_ratingValueForDialog == 0) {
      _showSnackbar(
        'Silakan pilih jumlah bintang rating terlebih dahulu.',
        isError: true,
      );
      return;
    }
    bool isCommentRequired =
        _ratingValueForDialog > 0 && _ratingValueForDialog <= 3;
    if (isCommentRequired && _komentarRatingController.text.trim().isEmpty) {
      _showSnackbar(
        'Komentar wajib diisi untuk rating bintang 3 atau kurang.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmittingRating = true;
    });

    try {
      final Map<String, dynamic> responseData = await _apiService.submitRating(
        tipeLaporan: 'temuan_kebocoran',
        trackingCode:
            _currentTemuan.trackingCode!, // trackingCode pasti ada di sini
        rating: _ratingValueForDialog.toInt(),
        komentar: _komentarRatingController.text.trim(),
        token: null, // PENTING: null untuk pengguna anonim
      );

      if (mounted && responseData['success'] == true) {
        if (responseData.containsKey('data') &&
            responseData['data'] is Map<String, dynamic>) {
          final updatedTemuanData =
              responseData['data'] as Map<String, dynamic>;

          // Cetak data yang diterima dari server untuk debugging
          print(
            '[DETAIL TEMUAN PAGE] Data dari server (updatedTemuanData): $updatedTemuanData',
          );

          setState(() {
            // Gunakan keseluruhan data dari server untuk memperbarui _currentTemuan
            // Ini mengasumsikan `TemuanKebocoran.fromJson` dapat menangani
            // semua field yang dikembalikan oleh `$laporanModel->fresh()` dari Laravel.
            _currentTemuan = TemuanKebocoran.fromJson(updatedTemuanData);

            // Perbarui juga nilai yang digunakan oleh UI RatingBar dan TextField
            _ratingValueForDialog = _currentTemuan.rating?.toDouble() ?? 0;
            _komentarRatingController.text =
                _currentTemuan.komentarRating ?? '';
          });
          _showSnackbar('Penilaian berhasil dikirim!', isError: false);
        } else {
          // Kasus ini idealnya tidak terjadi jika API selalu mengembalikan 'data' saat sukses.
          // Jika API bisa saja tidak mengembalikan 'data', maka fallback ke update manual
          // atau tampilkan pesan error yang lebih spesifik.
          print(
            '[DETAIL TEMUAN PAGE] WARNING: Respons sukses tapi tidak ada field "data" atau formatnya salah.',
          );
          // Opsi: Update manual state ratingnya saja jika server tidak mengembalikan objek penuh
          setState(() {
            // Ini akan membuat objek baru dengan ID lama dan rating/komentar baru
            // Jika 'id' juga tidak ada di _currentTemuan.toJson(), ini akan menyebabkan error yang sama.
            // Lebih aman jika server SELALU mengembalikan objek 'data' yang lengkap.
            var tempDataForManualUpdate = _currentTemuan.toJson();
            tempDataForManualUpdate['rating'] = _ratingValueForDialog.toInt();
            tempDataForManualUpdate['komentar_rating'] =
                _komentarRatingController.text.trim();
            _currentTemuan = TemuanKebocoran.fromJson(tempDataForManualUpdate);

            _ratingValueForDialog = _currentTemuan.rating?.toDouble() ?? 0;
            _komentarRatingController.text =
                _currentTemuan.komentarRating ?? '';
          });
          _showSnackbar(
            'Penilaian berhasil, namun data detail mungkin belum sepenuhnya terbarui.',
            isError: false,
            backgroundColor: Colors.orange,
          );
        }
      } else if (mounted) {
        // Jika responseData['success'] == false atau tidak ada sama sekali
        _showSnackbar(
          responseData['message'] ?? 'Gagal mengirim penilaian.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        // Cek apakah error adalah FormatException karena field 'id' null,
        // ini bisa membantu memberikan pesan yang lebih spesifik jika masih terjadi
        if (e is FormatException && e.message.contains("Field 'id' is null")) {
          errorMessage =
              "Gagal memproses data dari server: ID tidak ditemukan setelah update. Mohon coba lagi atau hubungi support jika masalah berlanjut.\nDetail: $e";
        } else if (errorMessage.startsWith("Exception: ")) {
          errorMessage = errorMessage.substring("Exception: ".length);
        }
        _showSnackbar(errorMessage, isError: true);
        print(
          '[DETAIL TEMUAN PAGE] Error submitting rating: $e',
        ); // Tambahkan log error di Flutter
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }

  Widget _buildDetailItem(
    String label,
    String? value, {
    IconData? icon,
    bool isSelectable = false,
    bool isLink = false,
    Color? valueColor,
  }) {
    if (value == null || value.isEmpty || value == "N/A") {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                isSelectable
                    ? SelectableText(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: valueColor ?? Colors.black87,
                        decoration: isLink ? TextDecoration.underline : null,
                      ),
                    )
                    : Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: valueColor ?? Colors.black87,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    bool isAlreadyRated = _currentTemuan.rating != null;
    bool canUpdateRating =
        _ratingValueForDialog != (_currentTemuan.rating?.toDouble() ?? 0) ||
        _komentarRatingController.text.trim() !=
            (_currentTemuan.komentarRating ?? '');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAlreadyRated
                  ? 'Penilaian Anda:'
                  : 'Beri Penilaian Laporan Ini:',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(
              child: RatingBar.builder(
                initialRating: _ratingValueForDialog,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 40.0,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder:
                    (context, _) =>
                        Icon(Icons.star_rounded, color: Colors.amber.shade700),
                onRatingUpdate: (rating) {
                  setState(() {
                    _ratingValueForDialog = rating;
                  });
                },
                ignoreGestures: _isSubmittingRating,
              ),
            ),
            const SizedBox(height: 16),
            if (_ratingValueForDialog > 0)
              TextField(
                controller: _komentarRatingController,
                decoration: InputDecoration(
                  labelText: 'Komentar Tambahan',
                  hintText:
                      (_ratingValueForDialog > 0 && _ratingValueForDialog <= 3)
                          ? 'Komentar (wajib untuk rating ini)'
                          : 'Komentar (opsional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  errorText:
                      (_ratingValueForDialog > 0 &&
                              _ratingValueForDialog <= 3 &&
                              _komentarRatingController.text.trim().isEmpty &&
                              !_isSubmittingRating) // Jangan tampilkan error saat submit
                          ? 'Komentar wajib diisi untuk rating ini.'
                          : null,
                ),
                maxLines: 3,
                minLines: 2,
                readOnly: _isSubmittingRating,
                onChanged:
                    (_) => setState(() {}), // Untuk memicu rebuild & revalidasi
              ),
            const SizedBox(height: 20),
            if (_isSubmittingRating)
              const Center(child: CircularProgressIndicator())
            else if (_ratingValueForDialog > 0 &&
                (isAlreadyRated
                    ? canUpdateRating
                    : true)) // Hanya tampilkan tombol jika ada rating & ada perubahan (jika sudah dirate)
              ElevatedButton.icon(
                icon: Icon(
                  isAlreadyRated ? Icons.edit_note_rounded : Icons.send_rounded,
                ),
                label: Text(
                  isAlreadyRated ? 'Update Penilaian' : 'Kirim Penilaian',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _submitTemuanRating,
              ),
            if (isAlreadyRated &&
                !canUpdateRating &&
                !_isSubmittingRating &&
                _ratingValueForDialog > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Anda sudah memberikan penilaian ini. Ubah bintang atau komentar untuk update.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoDisplay(String? fotoPath, String label) {
    if (fotoPath == null || fotoPath.isEmpty) return const SizedBox.shrink();

    // Menggunakan rootBaseUrl dari ApiService
    String rootUrl = _apiService.rootBaseUrl; // http://192.168.0.107:8000

    // Pastikan rootUrl tidak memiliki trailing slash jika path akan diawali /storage/
    if (rootUrl.endsWith('/')) {
      rootUrl = rootUrl.substring(0, rootUrl.length - 1);
    }

    // Path dari server biasanya sudah benar, misal: "temuan_bukti/namafile.jpg"
    // atau "storage/temuan_bukti/namafile.jpg".
    // Jika path dari server sudah mengandung "/storage/", maka tidak perlu ditambah lagi.
    // Jika belum, maka perlu ditambahkan.
    // Asumsi umum: path dari server adalah relatif terhadap folder public,
    // dan Laravel Storage Link membuat /storage/ mengarah ke storage/app/public.

    String ScleanedPath =
        fotoPath.startsWith('/') ? fotoPath.substring(1) : fotoPath;

    // Cek apakah ScleanedPath sudah diawali dengan 'storage/'
    // Ini penting karena beberapa API mungkin mengembalikan path lengkap dari public,
    // ada juga yang relatif dari public/storage.
    // Untuk konsistensi dengan kode sebelumnya: '$ScleanedBaseUrl/storage/$ScleanedPath'
    // ini mengasumsikan ScleanedPath adalah path *di dalam* folder storage.

    final imageUrl = '$rootUrl/storage/$ScleanedPath';
    // Contoh jika fotoPath = "temuan_foto/gambar.jpg", maka imageUrl akan menjadi:
    // "http://192.168.0.107:8000/storage/temuan_foto/gambar.jpg"

    print('[DETAIL TEMUAN PAGE] Image URL: $imageUrl'); // Untuk debugging

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7.5),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value:
                          loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print(
                    '[DETAIL TEMUAN PAGE] Error loading image $imageUrl: $error',
                  ); // Debug error load gambar
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 50,
                          color: Colors.grey.shade400,
                        ),
                        Text(
                          "Gagal muat foto",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        // Text(
                        //   "Error: ${error.toString().substring(0,50)}...", // Tampilkan sedikit detail error jika perlu
                        //   style: TextStyle(color: Colors.red.shade300, fontSize: 10),
                        //   textAlign: TextAlign.center,
                        // ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format tanggal (opsional, jika ingin tampilan lebih baik)
    // final DateFormat dateFormat = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');
    // final String tanggalLaporFormatted = dateFormat.format(_currentTemuan.tanggalTemuan);
    final String tanggalLaporFormatted = _currentTemuan.tanggalTemuan
        .toLocal()
        .toString()
        .substring(0, 16); // Format sederhana

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Laporan #${_currentTemuan.trackingCode ?? _currentTemuan.id}',
        ),
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            if (_currentTemuan.trackingCode != null) {
              final updatedTemuan = await _apiService.trackReport(
                _currentTemuan.trackingCode!,
              );
              if (mounted) {
                setState(() {
                  _currentTemuan = updatedTemuan;
                  _ratingValueForDialog =
                      _currentTemuan.rating?.toDouble() ?? 0;
                  _komentarRatingController.text =
                      _currentTemuan.komentarRating ?? '';
                });
                _showSnackbar(
                  "Data laporan diperbarui.",
                  isError: false,
                  backgroundColor: Colors.blue,
                );
              }
            }
          } catch (e) {
            if (mounted) {
              String errorMessage = e.toString();
              if (errorMessage.startsWith("Exception: "))
                errorMessage = errorMessage.substring("Exception: ".length);
              _showSnackbar(errorMessage, isError: true);
            }
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              _currentTemuan.status,
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentTemuan.friendlyStatus
                                .toUpperCase(), // Gunakan friendlyStatus jika ada di model
                            style: TextStyle(
                              color: _getStatusColor(_currentTemuan.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailItem(
                        'Kode Pelacakan:',
                        _currentTemuan.trackingCode,
                        icon: Icons.qr_code_scanner_rounded,
                        isSelectable: true,
                      ),
                      _buildDetailItem(
                        'Dilaporkan oleh:',
                        _currentTemuan.namaPelapor,
                        icon: Icons.person_outline_rounded,
                      ),
                      _buildDetailItem(
                        'Nomor HP Pelapor:',
                        _currentTemuan.nomorHpPelapor,
                        icon: Icons.phone_outlined,
                      ),
                      _buildDetailItem(
                        'Tanggal Laporan:',
                        tanggalLaporFormatted,
                        icon: Icons.calendar_today_outlined,
                      ),
                      _buildDetailItem(
                        'Cabang Dilaporkan:',
                        _currentTemuan.cabang?.namaCabang ?? 'N/A',
                        icon: Icons.business_outlined,
                      ), // Asumsi model TemuanKebocoran ada relasi 'cabang'
                      _buildDetailItem(
                        'Lokasi Maps:',
                        _currentTemuan.lokasiMaps,
                        icon: Icons.map_outlined,
                        isLink: true,
                      ),
                      _buildDetailItem(
                        'Deskripsi Lokasi:',
                        _currentTemuan.deskripsiLokasi,
                        icon: Icons.description_outlined,
                      ),

                      _buildPhotoDisplay(
                        _currentTemuan.fotoBukti,
                        "Foto Bukti Awal:",
                      ),
                      _buildPhotoDisplay(
                        _currentTemuan.fotoSebelum,
                        "Foto Sebelum Perbaikan:",
                      ),
                      _buildPhotoDisplay(
                        _currentTemuan.fotoSesudah,
                        "Foto Sesudah Perbaikan:",
                      ),

                      // Tampilkan rating yang sudah ada jika laporan sudah selesai dan sudah dirating
                      if (_currentTemuan.status.toLowerCase() == 'selesai' &&
                          _currentTemuan.rating != null) ...[
                        const Divider(height: 24, thickness: 1),
                        _buildDetailItem(
                          'Rating Diberikan:',
                          '${_currentTemuan.rating}/5 bintang',
                          icon: Icons.star_rounded,
                          valueColor: Colors.amber.shade800,
                        ),
                        if (_currentTemuan.komentarRating != null &&
                            _currentTemuan.komentarRating!.isNotEmpty)
                          _buildDetailItem(
                            'Komentar Rating:',
                            _currentTemuan.komentarRating,
                            icon: Icons.comment_outlined,
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bagian untuk memberi rating jika status "selesai"
              if (_currentTemuan.status.toLowerCase() == 'selesai')
                _buildRatingSection(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Ambil dari LacakLaporanSayaPage, sesuaikan jika perlu
  Color _getStatusColor(String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status.toLowerCase()) {
      case 'diproses':
        return Colors.orange.shade700;
      case 'selesai':
        return Colors.green.shade700;
      case 'dibatalkan':
        return colorScheme.error;
      case 'pending':
        return Colors.blue.shade700;
      case 'menunggu_konfirmasi':
        return Colors.cyan.shade700;
      case 'diterima':
        return Colors.lightBlue.shade800;
      case 'dalam_perjalanan':
        return Colors.teal.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
