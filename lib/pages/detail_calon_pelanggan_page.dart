// lib/pages/petugas/detail_calon_pelanggan_page.dart
import 'dart:async'; // <-- TAMBAHKAN INI
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:pdam_app/services/watermark_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailCalonPelangganPage extends StatefulWidget {
  final CalonPelangganTugas tugas;
  const DetailCalonPelangganPage({super.key, required this.tugas});

  @override
  State<DetailCalonPelangganPage> createState() =>
      _DetailCalonPelangganPageState();
}

class _DetailCalonPelangganPageState extends State<DetailCalonPelangganPage> {
  late CalonPelangganTugas _currentTugas;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _loadingText = '';

  @override
  void initState() {
    super.initState();
    _currentTugas = widget.tugas;
  }

  void _setLoading(bool loading, {String text = ''}) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        _loadingText = text;
      });
    }
  }

  void _showUpdateStatusDialog() {
    String? nextStatus;
    String title = '';
    bool photoRequired = false;

    switch (_currentTugas.status) {
      case 'menunggu survey':
        nextStatus = 'survey';
        title = 'Mulai Survey';
        break;
      case 'survey':
        nextStatus = 'survey selesai';
        title = 'Selesaikan Survey';
        photoRequired = true;
        break;
      case 'menunggu jadwal pemasangan':
        nextStatus = 'pemasangan';
        title = 'Mulai Pemasangan';
        break;
      case 'pemasangan':
        nextStatus = 'terpasang';
        title = 'Selesaikan Pemasangan';
        photoRequired = true;
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          'Anda akan mengubah status menjadi "$nextStatus". ${photoRequired ? "\nAnda WAJIB mengunggah foto bukti." : ""} Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleStatusUpdate(nextStatus!, photoRequired);
            },
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _showRecommendationDialog() async {
    String? rekomendasi;
    final catatanController = TextEditingController();

    return showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Gunakan StatefulWidget dan Builder agar bisa update state di dalam dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rekomendasi Survey'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                        'Apakah lokasi calon pelanggan direkomendasikan untuk pemasangan?'),
                    const SizedBox(height: 16),
                    RadioListTile<String>(
                      title: const Text('Direkomendasikan'),
                      value: 'direkomendasikan',
                      groupValue: rekomendasi,
                      onChanged: (value) {
                        setDialogState(() {
                          rekomendasi = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Tidak Direkomendasikan'),
                      value: 'tidak_direkomendasikan',
                      groupValue: rekomendasi,
                      onChanged: (value) {
                        setDialogState(() {
                          rekomendasi = value;
                        });
                      },
                    ),
                    // Tampilkan field catatan jika tidak direkomendasikan
                    if (rekomendasi == 'tidak_direkomendasikan')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextField(
                          controller: catatanController,
                          decoration: const InputDecoration(
                            labelText: 'Alasan (Wajib diisi)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Kirim'),
                  onPressed: () {
                    // Validasi sebelum menutup dialog
                    if (rekomendasi == null) {
                      _showSnackbar('Silakan pilih salah satu rekomendasi.',
                          isError: true);
                      return;
                    }
                    if (rekomendasi == 'tidak_direkomendasikan' &&
                        catatanController.text.trim().isEmpty) {
                      _showSnackbar(
                          'Alasan wajib diisi jika tidak merekomendasikan.',
                          isError: true);
                      return;
                    }
                    // Tutup dialog dan kirimkan data kembali
                    Navigator.of(context).pop({
                      'rekomendasi': rekomendasi!,
                      'catatan': catatanController.text.trim(),
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleStatusUpdate(String newStatus, bool photoRequired) async {
    String? imagePath;
    Map<String, String>? recommendationData; // Untuk menyimpan hasil dialog

    if (photoRequired) {
      final picker = ImagePicker();
      final XFile? originalImage = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1080,
      );

      if (originalImage == null) {
        _showSnackbar('Pengambilan foto dibatalkan.', isError: true);
        return;
      }

      if (newStatus == 'survey selesai') {
        _setLoading(true, text: 'Menambahkan info lokasi & waktu...');
        try {
          final WatermarkService watermarkService = WatermarkService();
          final XFile watermarkedImage =
              await watermarkService.addWatermark(originalImage);
          imagePath = watermarkedImage.path;

          // --- PANGGIL DIALOG REKOMENDASI SETELAH FOTO SIAP ---
          _setLoading(false); // Matikan loading sementara dialog muncul
          recommendationData = await _showRecommendationDialog();
          if (recommendationData == null) {
            _showSnackbar('Pemberian rekomendasi dibatalkan.', isError: true);
            return; // User membatalkan dialog
          }
        } catch (e) {
          _setLoading(false);
          // --- AWAL PERUBAHAN ---
          String errorMessage;
          if (e is SocketException) {
            errorMessage = 'Periksa koneksi internet Anda. Gagal mengambil data lokasi untuk watermark.';
          } else if (e is TimeoutException) {
            errorMessage = 'Koneksi timeout. Gagal mengambil data lokasi.';
          } else {
            errorMessage = "Gagal menambahkan watermark: ${e.toString().replaceFirst("Exception: ", "")}";
          }
          _showSnackbar(errorMessage, isError: true);
          // --- AKHIR PERUBAHAN ---
          return;
        }
      } else {
        imagePath = originalImage.path;
      }
    }

    _setLoading(true, text: 'Mengunggah data...');
    try {
      final result = await _apiService.updateStatusCalonPelanggan(
        idCalon: _currentTugas.idTugas,
        newStatus: newStatus,
        imagePath: imagePath,
        // --- KIRIM DATA REKOMENDASI KE API SERVICE ---
        rekomendasi: recommendationData?['rekomendasi'],
        catatan: recommendationData?['catatan'],
      );

      final updatedTugasJson = result['tugas_terbaru'];
      if (mounted) {
        setState(() {
          _currentTugas = CalonPelangganTugas.fromJson(updatedTugasJson);
        });
        _showSnackbar('Status berhasil diperbarui!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        // --- AWAL PERUBAHAN ---
        String errorMessage;
        if (e is SocketException) {
          errorMessage = 'Periksa koneksi internet Anda. Gagal memperbarui status.';
        } else if (e is TimeoutException) {
          errorMessage = 'Koneksi timeout. Gagal memperbarui status.';
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        _showSnackbar(errorMessage, isError: true);
        // --- AKHIR PERUBAHAN ---
      }
    } finally {
      _setLoading(false);
    }
  }

  void _showCancelDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Ionicons.warning_outline, color: Colors.orange),
              const SizedBox(width: 10),
              Text(
                'Batalkan Tugas',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: 'Masukkan alasan pembatalan...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
            minLines: 1,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Tutup',
                  style: GoogleFonts.poppins(color: Colors.grey[700])),
            ),
            ElevatedButton(
              onPressed: () {
                final String reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  _showSnackbar('Alasan pembatalan wajib diisi!',
                      isError: true);
                } else {
                  Navigator.pop(dialogContext);
                  _handleCancellation(reason);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: Text('Konfirmasi Batal', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCancellation(String alasan) async {
    _setLoading(true);

    // --- PERUBAHAN LOGIKA DI SINI ---
    // Tentukan 'jenis_tugas_spesifik' berdasarkan status saat ini,
    // bukan dari 'kategoriDisplay'.
    String? jenisTugasSpesifik;
    if (_currentTugas.status == 'menunggu survey') {
      jenisTugasSpesifik = 'survey';
    } else if (_currentTugas.status == 'menunggu jadwal pemasangan') {
      jenisTugasSpesifik = 'pemasangan';
    } else {
      // Jika status tidak sesuai, hentikan proses dan beri tahu pengguna.
      _setLoading(false);
      _showSnackbar('Tugas ini tidak dapat dibatalkan pada status saat ini.',
          isError: true);
      return;
    }
    // --- AKHIR PERUBAHAN LOGIKA ---

    try {
      // Panggil ApiService dengan parameter yang sudah benar
      await _apiService.batalkanPenugasanMandiri(
        idTugas: _currentTugas.idTugas,
        tipeTugas: 'calon_pelanggan',
        alasan: alasan,
        jenisTugasSpesifik:
            jenisTugasSpesifik, // <-- GUNAKAN VARIABEL YANG BENAR
      );

      if (mounted) {
        await _showSuccessAndNavigateHome();
      }
    } catch (e) {
      if (mounted) {
        // --- AWAL PERUBAHAN ---
        String errorMessage;
        if (e is SocketException) {
          errorMessage = 'Periksa koneksi internet Anda. Gagal memperbarui status.';
        } else if (e is TimeoutException) {
          errorMessage = 'Koneksi timeout. Gagal memperbarui status.';
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        _showSnackbar(errorMessage, isError: true);
        // --- AKHIR PERUBAHAN ---
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _showSuccessAndNavigateHome() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Ionicons.checkmark_circle, color: Colors.green[600]),
              const SizedBox(width: 10),
              Text('Berhasil',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Tugas telah berhasil dibatalkan.',
              style: GoogleFonts.lato()),
          actions: <Widget>[
            TextButton(
              child: Text('OK',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPhotoViewer(String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, error, stack) => const Icon(
                  Ionicons.warning_outline,
                  color: Colors.red,
                  size: 60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    String formattedPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '62${formattedPhone.substring(1)}';
    }
    final Uri whatsappUrl = Uri.parse('https://wa.me/$formattedPhone');
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $whatsappUrl';
      }
    } catch (e) {
      _showSnackbar('Tidak dapat membuka WhatsApp.', isError: true);
    }
  }

  Future<void> _launchMaps(String address) async {
    // Memastikan format alamat adalah "latitude,longitude"
    if (!address.contains(',') || address.split(',').length != 2) {
      _showSnackbar('Format koordinat tidak valid.', isError: true);
      return;
    }

    // --- FORMAT URL GOOGLE MAPS YANG BENAR DAN UNIVERSAL ---
    // Ini akan membuka Google Maps di browser atau aplikasi jika terinstal
    final Uri mapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');

    try {
      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $mapsUrl';
      }
    } catch (e) {
      _showSnackbar('Tidak dapat membuka Google Maps: ${e.toString()}',
          isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Pendaftaran',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('Informasi Pemohon'),
                _buildInfoCard([
                  _buildInfoRow(
                    Ionicons.person_outline,
                    'Nama',
                    _currentTugas.pelanggan.nama,
                  ),
                  _buildInfoRow(
                    Ionicons.call_outline,
                    'Nomor WA',
                    _currentTugas.pelanggan.nomorHp,
                    onTap: () =>
                        _launchWhatsApp(_currentTugas.pelanggan.nomorHp),
                  ),
                  _buildInfoRow(
                    Ionicons.location_outline,
                    'Alamat',
                    _currentTugas.deskripsiLokasi,
                    onTap: () => _launchMaps(_currentTugas.deskripsiLokasi),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionTitle('Status Pekerjaan'),
                _buildInfoCard([
                  _buildInfoRow(
                    Ionicons.flag_outline,
                    'Jenis Tugas',
                    _currentTugas.kategoriDisplay,
                  ),
                  _buildInfoRow(
                    Ionicons.pulse_outline,
                    'Status Saat Ini',
                    _currentTugas.status.toUpperCase(),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildActionButtons(),
                const SizedBox(height: 20),
                _buildSectionTitle('Galeri Foto'),
                _buildPhotoGallery(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    if (_loadingText.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _loadingText,
                        style: GoogleFonts.poppins(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _canUpdateStatus() {
    const activeStatus = [
      'menunggu survey',
      'survey',
      'menunggu jadwal pemasangan',
      'pemasangan',
    ];
    return activeStatus.contains(_currentTugas.status);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool canUpdate = _currentTugas.isPetugasPelapor && _canUpdateStatus();
    final bool canCancel = _currentTugas.status == 'menunggu survey' ||
        _currentTugas.status == 'menunggu jadwal pemasangan';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tombol "Ubah Status" hanya muncul untuk Pelapor (Ketua Tim)
        // dan jika statusnya memang bisa diubah.
        if (canUpdate)
          ElevatedButton.icon(
            icon: const Icon(Ionicons.sync_outline),
            label: const Text('Ubah Status'),
            onPressed: _isLoading ? null : _showUpdateStatusDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        // Beri jarak jika tombol "Ubah Status" muncul
        if (canUpdate) const SizedBox(height: 10),

        // Tombol "Pembatalan Tugas" hanya muncul untuk SEMUA petugas
        // jika statusnya masih dalam tahap menunggu (belum dikerjakan).
        if (canCancel)
          ElevatedButton.icon(
            icon: const Icon(Ionicons.close_circle_outline),
            label: const Text('Pembatalan Tugas'),
            onPressed: _isLoading ? null : _showCancelDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    final bool isClickable = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.lato(color: Colors.grey[600])),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isClickable ? Colors.blue.shade800 : null,
                        decoration:
                            isClickable ? TextDecoration.underline : null,
                        decorationColor:
                            isClickable ? Colors.blue.shade800 : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (isClickable)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Ionicons.open_outline,
                    size: 18,
                    color: Colors.blue.shade800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGallery() {
    final photos = {
      // "Foto KTP" dihilangkan sesuai permintaan.
      'Foto Rumah': _currentTugas.fotoRumahUrl,
      'Foto Hasil Survey': _currentTugas.fotoSebelumUrl, // INI PERBAIKANNYA
      'Foto Pemasangan': _currentTugas.fotoSesudahUrl, // INI PERBAIKANNYA
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final title = photos.keys.elementAt(index);
        final url = photos.values.elementAt(index);
        return _buildPhotoItem(title, url);
      },
    );
  }

  // -- KODE YANG DIPERBAIKI: HANYA ADA SATU FUNGSI _buildPhotoItem --
  Widget _buildPhotoItem(String title, String? url) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gambar
          Container(
            color: Colors.grey[200],
            child: url != null
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Ionicons.image_outline,
                      size: 40,
                      color: Colors.grey,
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  )
                : const Center(
                    child: Icon(
                      Ionicons.image_outline,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
          ),
          // Gradient agar teks terbaca
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Text(
                title,
                style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Widget agar bisa ditekan
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: url != null ? () => _showPhotoViewer(url, title) : null,
              splashColor: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}
