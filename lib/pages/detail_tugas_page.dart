// lib/pages/detail_tugas_page.dart

// ignore: unused_import
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart'; // Pastikan ini diimpor
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';

class DetailTugasPage extends StatefulWidget {
  final Tugas tugas;
  const DetailTugasPage({super.key, required this.tugas});

  @override
  State<DetailTugasPage> createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends State<DetailTugasPage> {
  late Tugas _tugasSaatIni;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final DateFormat _dateFormatter = DateFormat('EEEE, dd MMMM', 'id_ID');
  final DateFormat _timeFormatter = DateFormat('HH:mm', 'id_ID');

  @override
  void initState() {
    super.initState();
    _tugasSaatIni = widget.tugas;
  }

  void _setLoading(bool loading) {
    if (mounted) setState(() => _isLoading = loading);
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // --- START MODIFIKASI: _updateStatus untuk menangani keterangan ---
  Future<void> _updateStatus(
    String targetNewStatus, {
    String? keterangan,
  }) async {
    _setLoading(true);
    try {
      final responseData = await _apiService.updateStatusTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        newStatus: targetNewStatus,
        keterangan: keterangan, // Teruskan keterangan di sini
      );

      final Map<String, dynamic>? tugasTerbaruJson =
          responseData['tugas_terbaru'] as Map<String, dynamic>?;

      if (mounted && tugasTerbaruJson != null) {
        setState(() {
          _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
        });
        _showSnackbar(
          'Status berhasil diubah ke: ${_tugasSaatIni.friendlyStatus}',
          isError: false,
        );
      } else {
        _showSnackbar(
          'Gagal memperbarui UI: Respons tidak lengkap dari server.',
        );
      }
    } catch (e) {
      _showSnackbar('Gagal mengubah status: $e');
    } finally {
      if (mounted) _setLoading(false);
    }
  }
  // --- END MODIFIKASI: _updateStatus untuk menangani keterangan ---

  Future<void> _pickAndUploadImage(
    String jenisFotoUntukUpload,
    String statusSetelahUpload,
  ) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1080,
    );

    if (pickedFile == null) return;

    _setLoading(true);
    try {
      final responseData = await _apiService.uploadFotoTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        jenisFoto: jenisFotoUntukUpload,
        imagePath: pickedFile.path,
        newStatus: statusSetelahUpload,
      );

      final Map<String, dynamic>? tugasTerbaruJson =
          responseData['tugas_terbaru'] as Map<String, dynamic>?;

      if (mounted && tugasTerbaruJson != null) {
        setState(() {
          _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
        });
        _showSnackbar(
          'Foto berhasil diupload & status diperbarui!',
          isError: false,
        );
      } else {
        _showSnackbar(
          'Gagal memperbarui UI: Respons tidak lengkap dari server.',
        );
      }
    } catch (e) {
      _showSnackbar('Gagal upload foto: $e');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Tugas',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInDown(child: _buildInfoSection()),
                const SizedBox(height: 20),
                if (_tugasSaatIni.isPetugasPelapor)
                  FadeInUp(
                    delay: const Duration(milliseconds: 100),
                    child: _buildActionSection(),
                  ),
                const SizedBox(height: 20),
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: _buildFotoProgresSection(),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tugasSaatIni.kategoriDisplay,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Ionicons.calendar_outline,
              'Tgl Kejadian:',
              _formatDate(_tugasSaatIni.tanggalTugas),
            ),
            _buildInfoRow(
              Ionicons.time_outline,
              'Ditugaskan:',
              '${_formatDate(_tugasSaatIni.tanggalDibuatPenugasan.toIso8601String())}, ${_timeFormatter.format(_tugasSaatIni.tanggalDibuatPenugasan)}',
            ),
            _buildInfoRow(
              Ionicons.locate_outline,
              'Deskripsi Lokasi:',
              _tugasSaatIni.deskripsiLokasi,
              isMultiline: true,
            ),
            _buildInfoRow(
              Ionicons.map_outline,
              'Link Peta:',
              _tugasSaatIni.lokasiMaps,
              isLink: true,
            ),
            _buildInfoRow(
              Ionicons.document_text_outline,
              'Deskripsi Laporan:',
              _tugasSaatIni.deskripsi,
              isMultiline: true,
            ),
            if (_tugasSaatIni.infoKontakPelapor != null)
              _buildKontakRow(_tugasSaatIni.infoKontakPelapor!),
            const SizedBox(height: 12),
            _buildStatusRow(),
            // --- START MODIFIKASI: Tampilkan Alasan Pembatalan ---
            if (_tugasSaatIni.status == 'dibatalkan' &&
                (_tugasSaatIni.alasanPembatalan ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alasan Pembatalan:',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tugasSaatIni.alasanPembatalan!,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            // --- END MODIFIKASI: Tampilkan Alasan Pembatalan ---
            _buildPhotoViewer('Foto Bukti Awal:', _tugasSaatIni.fotoBuktiUrl),
            if (_tugasSaatIni is PengaduanTugas)
              _buildPhotoViewer(
                'Foto Rumah Pelanggan:',
                (_tugasSaatIni as PengaduanTugas)
                    .fotoRumahUrl, // Cast untuk akses fotoRumahUrl
              ),
          ],
        ),
      ),
    );
  }

  // --- START MODIFIKASI: _buildActionSection untuk tombol 'Batalkan Laporan' ---
  Widget _buildActionSection() {
    if (!_tugasSaatIni.isPetugasPelapor) return const SizedBox.shrink();

    List<Widget> actionButtons = [];
    switch (_tugasSaatIni.status) {
      case 'menunggu_konfirmasi':
        actionButtons.add(
          _buildActionButton(
            label: 'Terima Laporan',
            icon: Ionicons.checkmark_circle_outline,
            onPressed: () => _updateStatus('diterima'),
            color: Colors.green[600],
          ),
        );
        actionButtons.add(
          const SizedBox(height: 8), // Spasi antar tombol
        );
        actionButtons.add(
          _buildActionButton(
            label: 'Batalkan Laporan',
            icon: Ionicons.close_circle_outline,
            onPressed: _showCancelDialog, // Panggil dialog pembatalan
            color: Colors.red[600],
          ),
        );
        break;
      case 'diterima':
        actionButtons.add(
          _buildActionButton(
            label: 'Mulai Perjalanan',
            icon: Ionicons.paper_plane_outline,
            onPressed: () => _updateStatus('dalam_perjalanan'),
            color: Colors.blue[600],
          ),
        );
        break;
      case 'dalam_perjalanan':
        actionButtons.add(
          _buildActionButton(
            label: 'Ambil Foto Sebelum & Proses',
            icon: Ionicons.camera_outline,
            onPressed: () => _pickAndUploadImage('foto_sebelum', 'diproses'),
            color: Colors.orange[700],
          ),
        );
        break;
      case 'diproses':
        actionButtons.add(
          _buildActionButton(
            label: 'Ambil Foto Sesudah & Selesaikan',
            icon: Ionicons.cloud_upload_outline,
            onPressed: () => _pickAndUploadImage('foto_sesudah', 'selesai'),
            color: Colors.teal[600],
          ),
        );
        break;
      case 'selesai':
        actionButtons.add(
          _buildStatusDisplay(
            'Pekerjaan Telah Selesai',
            Ionicons.checkmark_done_circle,
            Colors.teal[600]!,
          ),
        );
        break;
      case 'dibatalkan':
        actionButtons.add(
          _buildStatusDisplay(
            'Tugas Dibatalkan',
            Ionicons.close_circle,
            Colors.red[700]!,
          ),
        );
        break;
    }

    if (actionButtons.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aksi Petugas',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const Divider(height: 24),
            ...actionButtons,
          ],
        ),
      ),
    );
  }

  // --- Fungsi untuk menampilkan dialog pembatalan ---
  void _showCancelDialog() {
    final TextEditingController _reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Batalkan Laporan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _reasonController,
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
              onPressed: () {
                Navigator.pop(dialogContext); // Tutup dialog
              },
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final String reason = _reasonController.text.trim();
                if (reason.isEmpty) {
                  _showSnackbar(
                    'Alasan pembatalan wajib diisi!',
                    isError: true,
                  );
                } else {
                  Navigator.pop(dialogContext); // Tutup dialog
                  _updateStatus(
                    'dibatalkan',
                    keterangan: reason,
                  ); // Panggil updateStatus dengan alasan
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: Text('Konfirmasi Batalkan', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }
  // --- END MODIFIKASI: _buildActionSection dan _showCancelDialog ---

  Widget _buildFotoProgresSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dokumentasi Progres',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressImage(
                  'Foto Sebelum',
                  _tugasSaatIni.fotoSebelumUrl,
                ),
                const SizedBox(width: 16),
                _buildProgressImage(
                  'Foto Sesudah',
                  _tugasSaatIni.fotoSesudahUrl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET HELPER
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
    bool isMultiline = false,
  }) {
    final displayValue = value.isEmpty ? 'Data tidak tersedia' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.lato(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  isLink
                      ? WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: InkWell(
                          onTap:
                              displayValue == 'Data tidak tersedia'
                                  ? null
                                  : () => _launchURL(displayValue),
                          child: Text(
                            displayValue,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      )
                      : TextSpan(text: displayValue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKontakRow(KontakInfo kontak) {
    return _buildInfoRow(
      Ionicons.person_outline,
      _tugasSaatIni is PengaduanTugas ? 'Pelanggan:' : 'Pelapor:',
      '${kontak.nama} (${kontak.nomorHp})',
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Icon(Ionicons.cellular_outline, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Text(
          'Status: ',
          style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getColorForStatus(_tugasSaatIni.status),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _tugasSaatIni.friendlyStatus.toUpperCase(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoViewer(String title, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap:
                  () => showDialog(
                    context: context,
                    builder:
                        (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(imageUrl),
                          ),
                        ),
                  ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 220,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder:
                      (context, child, progress) =>
                          progress == null
                              ? child
                              : Container(
                                height: 220,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(),
                              ),
                  errorBuilder:
                      (context, error, stack) => Container(
                        height: 180,
                        alignment: Alignment.center,
                        color: Colors.grey[200],
                        child: Icon(
                          Ionicons.warning_outline,
                          color: Colors.grey[400],
                          size: 40,
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

  Widget _buildProgressImage(String title, String? imageUrl) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child:
                (imageUrl != null && imageUrl.isNotEmpty)
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 160,
                        errorBuilder:
                            (c, e, s) => Icon(
                              Ionicons.image_outline,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                      ),
                    )
                    : Icon(
                      Ionicons.image_outline,
                      size: 50,
                      color: Colors.grey[400],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDisplay(String label, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
        return Colors.teal.shade600;
      case 'dibatalkan':
        return Colors.red.shade700;
      case 'diproses':
        return Colors.green.shade700;
      case 'diterima':
        return Colors.blue.shade700;
      case 'dalam_perjalanan':
        return Colors.purple.shade600;
      default:
        return Colors.orange.shade700;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      return _dateFormatter.format(DateTime.parse(dateString));
    } catch (e) {
      return dateString;
    }
  }

  void _launchURL(String url) async {
    final Uri targetUri;
    if (url.startsWith('http')) {
      targetUri = Uri.parse(url);
    } else {
      // Fallback for coordinate-like strings
      targetUri = Uri.parse('http://googleusercontent.com/maps.google.com/5');
    }
    try {
      if (await canLaunchUrl(targetUri)) {
        await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackbar('Tidak bisa membuka aplikasi peta.');
      }
    } catch (e) {
      _showSnackbar('Error membuka peta: $e');
    }
  }
}
