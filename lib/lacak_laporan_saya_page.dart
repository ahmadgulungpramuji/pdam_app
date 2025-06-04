// lib/lacak_laporan_saya_page.dart
import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:pdam_app/api_service.dart'; // Sesuaikan path jika perlu
import 'package:pdam_app/models/pengaduan_model.dart'; // Sesuaikan path jika perlu
// import 'package:pdam_app/models/petugas_simple_model.dart'; // Jika API mengirim data petugas
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart'; // Untuk format tanggal jika perlu

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

  // State untuk dialog rating
  final _komentarRatingController = TextEditingController();
  double _currentRatingValueForDialog = 0;
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

  // Fungsi untuk mengambil token dari SharedPreferences
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Pastikan 'user_token' adalah key yang benar saat Anda menyimpan token
    return prefs.getString('user_token');
  }

  // Fungsi untuk menghapus token jika tidak valid
  Future<void> _removeAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_token');
    // Anda juga bisa menghapus data user lain yang tersimpan jika ada
    // await prefs.remove('user_data');
  }

  Future<void> _fetchLaporan({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Panggil ApiService.getLaporanPengaduan.
      // Berdasarkan ApiService Anda, method ini MENGAMBIL TOKEN SENDIRI SECARA INTERNAL.
      // Jadi, kita TIDAK PERLU mengirim parameter 'token' di sini.
      print("LacakLaporanPage: Memanggil _apiService.getLaporanPengaduan()");
      final List<dynamic> rawData = await _apiService.getLaporanPengaduan();

      if (mounted) {
        List<Pengaduan> tempList = [];
        int failedItemsCount = 0;

        for (final itemJson in rawData) {
          if (itemJson is Map<String, dynamic>) {
            try {
              tempList.add(Pengaduan.fromJson(itemJson));
            } catch (e) {
              failedItemsCount++;
              print(
                'LacakLaporanPage: Gagal memproses item laporan dari JSON: $itemJson. Error: $e',
              );
            }
          } else {
            failedItemsCount++;
            print(
              'LacakLaporanPage: Item data laporan tidak valid (bukan Map): $itemJson',
            );
          }
        }
        // Urutkan berdasarkan tanggal terbaru (misalnya, updatedAt atau createdAt)
        tempList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        setState(() {
          _laporanList = tempList;
          _isLoading = false;

          if (failedItemsCount > 0) {
            print(
              'LacakLaporanPage: $failedItemsCount item laporan gagal dimuat dan dilewati.',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$failedItemsCount item laporan tidak dapat ditampilkan karena format salah.',
                  ),
                  backgroundColor: Colors.orange.shade800,
                ),
              );
            }
          }
          if (rawData.isNotEmpty && tempList.isEmpty && _errorMessage == null) {
            _errorMessage =
                'Gagal memproses semua data laporan. Format mungkin tidak sesuai.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        String displayError = 'Gagal memuat data laporan.';
        if (e.toString().contains("401") ||
            e.toString().toLowerCase().contains("autentikasi") ||
            e.toString().toLowerCase().contains("sesi")) {
          displayError =
              'Sesi Anda berakhir atau tidak valid. Silakan login kembali.';
          await _removeAuthToken(); // Hapus token yang mungkin sudah tidak valid
        } else if (e.toString().toLowerCase().contains("format")) {
          displayError = 'Format data laporan tidak sesuai.';
        } else if (e.toString().toLowerCase().contains("jaringan") ||
            e.toString().toLowerCase().contains("host") ||
            e.toString().toLowerCase().contains("socket")) {
          displayError =
              'Gagal terhubung ke server. Periksa koneksi internet Anda.';
        }
        print('LacakLaporanPage: Error saat fetch laporan: $e');
        setState(() {
          _errorMessage = displayError;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRatingSubmission(
    Pengaduan laporan,
    double ratingValue,
    String komentar,
    BuildContext dialogContext, // Context dari AlertDialog
    Function(bool isLoading)
    setDialogLoadingState, // Callback untuk update loading di dialog
  ) async {
    setDialogLoadingState(true);
    print(
      "LacakLaporanPage: Memulai _handleRatingSubmission untuk laporan ID: ${laporan.id}",
    );

    // 1. DAPATKAN TOKEN DARI SharedPreferences
    final String? token = await _getAuthToken();
    print(
      "LacakLaporanPage: Token yang didapat dari _getAuthToken: ${token != null ? 'Ada (${token.substring(0, Math.min(10, token.length))}...)' : 'NULL'}",
    );

    // 2. VALIDASI TOKEN
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Autentikasi gagal. Token tidak ditemukan. Silakan login ulang.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        // Tutup dialog jika masih terbuka
        if (Navigator.canPop(dialogContext)) Navigator.of(dialogContext).pop();
      }
      setDialogLoadingState(false);
      return;
    }

    // 3. PANGGIL ApiService.submitRating DENGAN TOKEN
    try {
      // Pastikan method 'submitRating' di ApiService Anda didefinisikan untuk menerima parameter 'token'
      // dan menggunakannya dalam header 'Authorization: Bearer $token'
      final Map<String, dynamic> responseData = await _apiService.submitRating(
        tipeLaporan: 'pengaduan',
        idLaporan: laporan.id,
        rating: ratingValue.toInt(),
        komentar: komentar,
        token: token, // <--- TOKEN DIKIRIMKAN KE ApiService
      );

      // 4. PROSES JIKA SUKSES
      print("LacakLaporanPage: Respons submitRating: $responseData");
      if (mounted && responseData['success'] == true) {
        final index = _laporanList.indexWhere((item) => item.id == laporan.id);
        if (index != -1) {
          // Update item di list lokal agar UI langsung refresh
          // Idealnya, API mengembalikan data laporan yang sudah terupdate
          setState(() {
            // Jika API mengembalikan data laporan yang sudah terupdate di responseData['data']
            if (responseData.containsKey('data') &&
                responseData['data'] is Map<String, dynamic>) {
              _laporanList[index] = Pengaduan.fromJson(
                responseData['data'] as Map<String, dynamic>,
              );
            } else {
              // Jika tidak, update manual field rating dan komentar saja
              _laporanList[index] = Pengaduan(
                // Salin semua field dari laporan lama
                id: _laporanList[index].id,
                idPdam: _laporanList[index].idPdam,
                idPelanggan: _laporanList[index].idPelanggan,
                idCabang: _laporanList[index].idCabang,
                latitude: _laporanList[index].latitude,
                longitude: _laporanList[index].longitude,
                kategori: _laporanList[index].kategori,
                lokasiMaps: _laporanList[index].lokasiMaps,
                deskripsiLokasi: _laporanList[index].deskripsiLokasi,
                deskripsi: _laporanList[index].deskripsi,
                tanggalPengaduan: _laporanList[index].tanggalPengaduan,
                status: _laporanList[index].status, // Status tetap 'selesai'
                fotoBukti: _laporanList[index].fotoBukti,
                idPetugasPelapor: _laporanList[index].idPetugasPelapor,
                fotoRumah: _laporanList[index].fotoRumah,
                fotoSebelum: _laporanList[index].fotoSebelum,
                fotoSesudah: _laporanList[index].fotoSesudah,
                createdAt: _laporanList[index].createdAt,
                updatedAt:
                    DateTime.now(), // Atau gunakan dari respons API jika ada field updatedAt baru
                // Update field rating & komentar
                rating: ratingValue.toInt(),
                komentarRating: komentar.isNotEmpty ? komentar : null,
                petugasDitugaskan: _laporanList[index].petugasDitugaskan,
              );
            }
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penilaian berhasil dikirim!'),
            backgroundColor: Colors.green,
          ),
        );
        if (Navigator.canPop(dialogContext))
          Navigator.of(dialogContext).pop(); // Tutup dialog rating
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message'] ?? 'Gagal mengirim penilaian.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 5. TANGANI ERROR DARI ApiService
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith("Exception: ")) {
          errorMessage = errorMessage.substring("Exception: ".length);
        }
        print(
          "LacakLaporanPage: Error saat _handleRatingSubmission: $errorMessage",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
        // Jika errornya adalah autentikasi, hapus token lokal
        if (e.toString().contains("401") ||
            e.toString().toLowerCase().contains("autentikasi") ||
            e.toString().toLowerCase().contains("sesi")) {
          await _removeAuthToken();
        }
      }
    } finally {
      setDialogLoadingState(false);
    }
  }

  void _showDetailAndRatingDialog(Pengaduan laporan) {
    // Reset state dialog rating untuk laporan yang baru dipilih
    _currentRatingValueForDialog = laporan.rating?.toDouble() ?? 0;
    _komentarRatingController.text = laporan.komentarRating ?? '';
    _isDialogRatingLoading = false; // Pastikan state loading dialog direset

    showDialog(
      context: context,
      barrierDismissible:
          !_isDialogRatingLoading, // Cegah menutup dialog saat loading
      builder: (BuildContext dialogContext) {
        // Menggunakan context yang berbeda untuk dialog
        // StatefulBuilder agar UI di dalam dialog bisa di-update (loading, rating bar, dsb.)
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fungsi callback untuk mengontrol state loading dari dalam dialog
            void updateDialogLoadingState(bool isLoading) {
              setDialogState(() {
                _isDialogRatingLoading = isLoading;
              });
            }

            bool isCommentRequired =
                _currentRatingValueForDialog > 0 &&
                _currentRatingValueForDialog <= 3;
            bool isCommentValid =
                !isCommentRequired ||
                (_komentarRatingController.text.trim().isNotEmpty);

            bool ratingOrCommentChanged =
                (laporan.rating?.toDouble() ?? 0) !=
                    _currentRatingValueForDialog ||
                (laporan.komentarRating ?? '') !=
                    _komentarRatingController.text.trim();

            bool canSubmit =
                _currentRatingValueForDialog > 0 && // Harus ada rating dipilih
                isCommentValid && // Komentar valid jika diperlukan
                ratingOrCommentChanged && // Harus ada perubahan
                !_isDialogRatingLoading; // Tidak sedang loading

            return WillPopScope(
              // Mencegah menutup dialog dengan tombol back HP saat loading
              onWillPop: () async => !_isDialogRatingLoading,
              child: AlertDialog(
                title: Text(
                  'Laporan #${laporan.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRowDialog(
                        'Kategori:',
                        laporan.friendlyKategori,
                      ),
                      _buildDetailRowDialog(
                        'Status:',
                        laporan.friendlyStatus,
                        statusColor: _getStatusColor(laporan.status),
                      ),
                      _buildDetailRowDialog(
                        'Tanggal Lapor:',
                        laporan.tanggalPengaduan,
                      ), // Anda mungkin ingin memformat tanggal ini
                      _buildDetailRowDialog(
                        'Deskripsi Lokasi:',
                        laporan.deskripsiLokasi,
                      ),
                      _buildDetailRowDialog(
                        'Deskripsi Masalah:',
                        laporan.deskripsi,
                        isMultiline: true,
                      ),
                      const SizedBox(height: 8),
                      if (laporan.fotoBukti != null &&
                          laporan.fotoBukti!.isNotEmpty)
                        _buildPhotoDisplay(laporan.fotoBukti!),

                      // --- BAGIAN RATING ---
                      if (laporan.status.toLowerCase() == 'selesai') ...[
                        const Divider(height: 20, thickness: 0.8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                          child: Text(
                            laporan.rating == null
                                ? 'Beri Penilaian:'
                                : 'Penilaian Anda:',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (laporan.petugasDitugaskan != null &&
                            laporan.petugasDitugaskan!.isNotEmpty) ...[
                          Text(
                            "Petugas: ${laporan.petugasDitugaskan!.map((p) => p.nama).join(', ')}",
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Center(
                          child: RatingBar.builder(
                            initialRating: _currentRatingValueForDialog,
                            minRating: 1,
                            direction: Axis.horizontal,
                            allowHalfRating: false,
                            itemCount: 5,
                            itemSize: 36.0,
                            itemPadding: const EdgeInsets.symmetric(
                              horizontal: 3.0,
                            ),
                            itemBuilder:
                                (context, _) => Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber.shade600,
                                ),
                            onRatingUpdate: (rating) {
                              setDialogState(() {
                                _currentRatingValueForDialog = rating;
                              });
                            },
                            ignoreGestures:
                                _isDialogRatingLoading, // Nonaktifkan saat loading
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_currentRatingValueForDialog >
                            0) // Hanya tampilkan field komentar jika sudah ada rating
                          TextField(
                            controller: _komentarRatingController,
                            decoration: InputDecoration(
                              labelText: 'Komentar',
                              hintText:
                                  isCommentRequired
                                      ? 'Komentar (wajib untuk rating ini)'
                                      : 'Komentar (opsional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              errorText:
                                  isCommentRequired &&
                                          _komentarRatingController.text
                                              .trim()
                                              .isEmpty &&
                                          !_isDialogRatingLoading
                                      ? 'Komentar wajib diisi'
                                      : null,
                            ),
                            maxLines: 3,
                            minLines: 2,
                            textInputAction: TextInputAction.done,
                            onChanged:
                                (_) => setDialogState(
                                  () {},
                                ), // Untuk re-validasi errorText
                            readOnly:
                                _isDialogRatingLoading, // Nonaktifkan saat loading
                          ),
                        const SizedBox(height: 16),
                        if (_isDialogRatingLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_currentRatingValueForDialog > 0 &&
                            ratingOrCommentChanged)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(
                                laporan.rating == null
                                    ? Icons.send_rounded
                                    : Icons.edit_note_rounded,
                                size: 20,
                              ),
                              label: Text(
                                laporan.rating == null
                                    ? 'Kirim Penilaian'
                                    : 'Update Penilaian',
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed:
                                  !canSubmit
                                      ? null
                                      : () {
                                        // Tombol disable jika tidak bisa submit
                                        _handleRatingSubmission(
                                          laporan,
                                          _currentRatingValueForDialog,
                                          _komentarRatingController.text.trim(),
                                          dialogContext, // Context dari AlertDialog utama
                                          updateDialogLoadingState, // Callback untuk loading state dialog
                                        );
                                      },
                            ),
                          ),
                        if (laporan.rating != null &&
                            !ratingOrCommentChanged &&
                            !_isDialogRatingLoading &&
                            _currentRatingValueForDialog > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Center(
                              child: Text(
                                "Tidak ada perubahan pada penilaian.",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                actionsAlignment: MainAxisAlignment.center,
                actionsPadding: const EdgeInsets.only(bottom: 12, top: 0),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Tutup', style: TextStyle(fontSize: 16)),
                    onPressed:
                        _isDialogRatingLoading
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRowDialog(
    String label,
    String value, {
    Color? statusColor,
    bool isMultiline = false,
  }) {
    if (value.trim().isEmpty || value.trim() == 'N/A')
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110, // Lebar tetap untuk label
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            ": ",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                color: statusColor ?? Colors.black87,
              ),
              softWrap: true,
              maxLines:
                  isMultiline ? 5 : 3, // Izinkan lebih banyak baris jika perlu
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoDisplay(String fotoBuktiPath) {
    // Menggunakan rootBaseUrl dari ApiService
    String rootUrl =
        _apiService.rootBaseUrl; // Contoh: http://192.168.0.107:8000

    // Pastikan rootUrl tidak memiliki trailing slash
    if (rootUrl.endsWith('/')) {
      rootUrl = rootUrl.substring(0, rootUrl.length - 1);
    }

    // Path dari server, contoh: "pengaduan_bukti/namafile.jpg"
    String cleanedPath =
        fotoBuktiPath.startsWith('/')
            ? fotoBuktiPath.substring(1)
            : fotoBuktiPath;

    // Asumsi umum: path dari server adalah relatif terhadap folder public,
    // dan Laravel Storage Link membuat /storage/ mengarah ke storage/app/public.
    // Jadi, kita tambahkan /storage/ di antara rootUrl dan cleanedPath.
    final imageUrl = '$rootUrl/storage/$cleanedPath';

    print(
      "LacakLaporanPage: Mencoba memuat gambar dari: $imageUrl",
    ); // Untuk debugging

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Foto Bukti:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
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
              borderRadius: BorderRadius.circular(7),
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
                      strokeWidth: 3,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print(
                    "LacakLaporanPage: Error loading image $imageUrl: $error",
                  );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Gagal memuat gambar",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'diproses':
        return Icons.hourglass_bottom_rounded;
      case 'selesai':
        return Icons.check_circle_rounded;
      case 'dibatalkan':
        return Icons.cancel_rounded;
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'menunggu_konfirmasi':
        return Icons.notifications_active_rounded;
      case 'diterima':
        return Icons.thumb_up_alt_rounded;
      case 'dalam_perjalanan':
        return Icons.local_shipping_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Laporan Saya'),
        // Menggunakan warna dari Material 3 theme
        backgroundColor: ElevationOverlay.applySurfaceTint(
          colorScheme.surface,
          colorScheme.surfaceTint,
          2.0,
        ), // Elevation level 2
        elevation: 0, // Set ke 0 jika menggunakan surfaceTint
        // Jika ingin shadow tradisional, gunakan elevation: 1 atau 2
      ),
      body: RefreshIndicator(
        onRefresh:
            () => _fetchLaporan(
              showLoadingIndicator: false,
            ), // Tidak menampilkan loading utama saat refresh
        color: colorScheme.primary,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: _buildBody(colorScheme, textTheme),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _laporanList.isEmpty) {
      return _buildErrorState(_errorMessage!);
    }
    if (_laporanList.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      itemCount: _laporanList.length,
      itemBuilder: (context, index) {
        final Pengaduan laporan = _laporanList[index];
        final Color statusColor = _getStatusColor(laporan.status);
        final IconData statusIcon = _getStatusIcon(laporan.status);

        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(vertical: 7.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showDetailAndRatingDialog(laporan),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          laporan.friendlyKategori,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID Laporan: ${laporan.id}',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Tanggal: ${laporan.tanggalPengaduan}', // Format tanggal jika perlu
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8), // Spacer
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          laporan.friendlyStatus,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (laporan.status.toLowerCase() == 'selesai' &&
                          laporan.rating != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Colors.amber.shade700,
                              size: 17,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${laporan.rating}/5',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 60,
            ),
            const SizedBox(height: 18),
            Text(
              'Oops, Terjadi Kesalahan',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Coba Lagi"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onPressed: () => _fetchLaporan(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 18),
            Text(
              'Belum Ada Laporan',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Semua laporan pengaduan Anda akan muncul di sini.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text("Buat Laporan Baru"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/buat_laporan',
                ) // Pastikan rute '/buat_laporan' ada
                .then(
                  (_) => _fetchLaporan(showLoadingIndicator: false),
                ); // Refresh list setelah kembali
              },
            ),
          ],
        ),
      ),
    );
  }
}
