// lib/pages/petugas/detail_calon_pelanggan_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
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

  @override
  void initState() {
    super.initState();
    _currentTugas = widget.tugas;
  }

  void _setLoading(bool loading) {
    if (mounted) setState(() => _isLoading = loading);
  }

  // Fungsi untuk menampilkan pilihan status
  void _showUpdateStatusDialog() {
    String? nextStatus;
    String title = '';
    bool photoRequired = false;

    // Tentukan status berikutnya yang valid
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
        return; // Tidak ada aksi untuk status lain
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

  // Fungsi untuk menangani update, termasuk ambil foto
  Future<void> _handleStatusUpdate(String newStatus, bool photoRequired) async {
    String? imagePath;

    if (photoRequired) {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (image == null) {
        _showSnackbar('Pengambilan foto dibatalkan.', isError: true);
        return;
      }
      imagePath = image.path;
    }

    _setLoading(true);

    try {
      final result = await _apiService.updateStatusCalonPelanggan(
        idCalon: _currentTugas.idTugas,
        newStatus: newStatus,
        imagePath: imagePath,
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
        _showSnackbar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      _setLoading(false);
    }
  }

  // Fungsi untuk menampilkan dialog pembatalan
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
                  Navigator.pop(dialogContext); // Tutup dialog
                  _handleCancellation(reason); // Panggil fungsi pembatalan
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

  // Fungsi untuk menangani logika pembatalan ke API
  Future<void> _handleCancellation(String alasan) async {
    _setLoading(true);
    try {
      await _apiService.batalkanPenugasanMandiri(
        idTugas: _currentTugas.idTugas,
        tipeTugas: 'calon_pelanggan', // Tipe tugas yang benar
        alasan: alasan,
      );

      if (mounted) {
        await _showSuccessAndNavigateHome();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(e.toString().replaceAll('Exception: ', ''),
            isError: true);
      }
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // Dialog sukses dan navigasi kembali
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
          content:
              Text('Tugas telah berhasil dibatalkan.', style: GoogleFonts.lato()),
          actions: <Widget>[
            TextButton(
              child: Text('OK',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Tutup dialog
                Navigator.of(context).pop(); // Kembali dari halaman detail
              },
            ),
          ],
        );
      },
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
    final Uri mapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    try {
      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $mapsUrl';
      }
    } catch (e) {
      _showSnackbar('Tidak dapat membuka Google Maps.', isError: true);
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
              crossAxisAlignment: CrossAxisAlignment.stretch, // Agar tombol bisa full-width
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

                // -- PERUBAHAN BARU DIMULAI: KUMPULAN TOMBOL AKSI --
                _buildActionButtons(),
                // -- PERUBAHAN BARU SELESAI --

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
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
      // -- PERUBAHAN: FloatingActionButton DIHAPUS dari sini --
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

  // Widget helpers
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

  // -- PERUBAHAN BARU DIMULAI: WIDGET UNTUK KELOMPOK TOMBOL AKSI --
  Widget _buildActionButtons() {
    // Tombol hanya akan muncul jika statusnya aktif
    if (!_canUpdateStatus()) {
      return const SizedBox.shrink(); // return widget kosong jika tidak aktif
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tombol Ubah Status (hanya untuk petugas pelapor)
        if (_currentTugas.isPetugasPelapor)
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
        
        // Beri jarak jika kedua tombol muncul
        if (_currentTugas.isPetugasPelapor)
          const SizedBox(height: 10),

        // Tombol Pembatalan Tugas (untuk semua petugas yang ditugaskan)
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
  // -- PERUBAHAN BARU SELESAI --

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
      'Foto Rumah': _currentTugas.fotoRumahUrl,
      'Foto Hasil Survey': _currentTugas.fotoSebelumUrl,
      'Foto Pemasangan': _currentTugas.fotoSesudahUrl,
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

  Widget _buildPhotoItem(String title, String? url) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Expanded(
            child: Container(
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
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              style: GoogleFonts.lato(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}