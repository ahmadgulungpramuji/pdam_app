// lib/pages/detail_calon_pelanggan_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
// PERUBAHAN 1: Menambahkan import untuk url_launcher
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
      builder:
          (context) => AlertDialog(
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

    setState(() => _isLoading = true);

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
          _isLoading = false;
        });
        _showSnackbar('Status berhasil diperbarui!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  // PERUBAHAN 2: Menambahkan fungsi untuk membuka WhatsApp dan Google Maps
  Future<void> _launchWhatsApp(String phoneNumber) async {
    // Format nomor HP (hapus karakter selain angka, asumsikan +62)
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
  // --- Akhir Perubahan 2 ---

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Informasi Pemohon'),
                _buildInfoCard([
                  _buildInfoRow(
                    Ionicons.person_outline,
                    'Nama',
                    _currentTugas.pelanggan.nama,
                  ),
                  // PERUBAHAN 4: Menambahkan parameter onTap untuk membuka WhatsApp
                  _buildInfoRow(
                    Ionicons.call_outline,
                    'Nomor WA',
                    _currentTugas.pelanggan.nomorHp,
                    onTap: () => _launchWhatsApp(_currentTugas.pelanggan.nomorHp),
                  ),
                  // PERUBAHAN 5: Menambahkan parameter onTap untuk membuka Google Maps
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
                _buildSectionTitle('Galeri Foto'),
                _buildPhotoGallery(),
                const SizedBox(height: 100), // Spacer for FAB
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton:
          _currentTugas.isPetugasPelapor && _canUpdateStatus()
              ? FloatingActionButton.extended(
                onPressed: _showUpdateStatusDialog,
                icon: const Icon(Ionicons.sync_outline),
                label: const Text('Ubah Status'),
                backgroundColor: Theme.of(context).primaryColor,
              )
              : null,
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

  // PERUBAHAN 3: Memodifikasi _buildInfoRow untuk menerima onTap dan mengubah style
  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
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
                    Text(label, style: GoogleFonts.lato(color: Colors.grey[600])),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        // Beri warna berbeda jika bisa diklik
                        color: isClickable ? Colors.blue.shade800 : null,
                        decoration: isClickable ? TextDecoration.underline : null,
                        decorationColor: isClickable ? Colors.blue.shade800 : null,
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
              child:
                  url != null
                      ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
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