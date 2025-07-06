// lib/pages/detail_tugas_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';

class DetailTugasPage extends StatefulWidget {
  final Tugas tugas;
  const DetailTugasPage({super.key, required this.tugas});

  @override
  State<DetailTugasPage> createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends State<DetailTugasPage> {
  // --- TIDAK ADA PERUBAHAN PADA LOGIKA DAN STATE ---
  late Tugas _tugasSaatIni;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final DateFormat _dateFormatter = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
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

  Future<void> _updateStatus(String targetNewStatus) async {
    _setLoading(true);
    try {
      final responseData = await _apiService.updateStatusTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        newStatus: targetNewStatus,
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
  // --- AKHIR DARI BAGIAN LOGIKA & STATE ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar dibuat transparan agar menyatu dengan body
      appBar: AppBar(
        title: Text(
          'Detail Tugas',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Latar belakang utama halaman
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[800]!, Colors.blue[600]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animasi untuk header
                  FadeInDown(child: _buildHeader()),
                  const SizedBox(height: 10),
                  
                  // Animasi untuk kartu aksi
                  if (_tugasSaatIni.isPetugasPelapor)
                    FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildActionSection(),
                        )),
                  
                  // Animasi untuk kartu detail laporan
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _buildDetailCard(
                      icon: Ionicons.document_text_outline,
                      title: 'Detail Laporan',
                      children: [
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
                          Ionicons.document_text_outline,
                          'Deskripsi Laporan:',
                          _tugasSaatIni.deskripsi,
                          isMultiline: true,
                        ),
                      ],
                    ),
                  ),
                  
                  // Animasi untuk kartu informasi lokasi
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: _buildDetailCard(
                      icon: Ionicons.map_outline,
                      title: 'Informasi Lokasi',
                      children: [
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
                      ],
                    ),
                  ),

                  // Animasi untuk info kontak
                  if (_tugasSaatIni.infoKontakPelapor != null)
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: _buildDetailCard(
                        icon: Ionicons.person_circle_outline,
                        title: _tugasSaatIni is PengaduanTugas ? 'Informasi Pelanggan' : 'Informasi Pelapor',
                        children: [
                           _buildKontakRow(_tugasSaatIni.infoKontakPelapor!),
                        ]
                      )
                    ),

                  // Animasi untuk dokumentasi awal
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: _buildDetailCard(
                      icon: Ionicons.camera_outline,
                      title: 'Dokumentasi Awal',
                      children: [
                         _buildPhotoViewer('Foto Bukti Awal:', _tugasSaatIni.fotoBuktiUrl),
                         if (_tugasSaatIni is PengaduanTugas)
                           _buildPhotoViewer(
                               'Foto Rumah Pelanggan:',
                               (_tugasSaatIni as PengaduanTugas).fotoRumahUrl,
                           ),
                      ]
                    )
                  ),

                  // Animasi untuk dokumentasi progres
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: _buildFotoProgresSection(),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
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

  // --- WIDGET HELPER BARU DAN YANG DIMODIFIKASI ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tugasSaatIni.kategoriDisplay,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Status: ',
                 style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getColorForStatus(_tugasSaatIni.status).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1)
                ),
                child: Text(
                  _tugasSaatIni.friendlyStatus.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({required IconData icon, required String title, required List<Widget> children}) {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
       child: Card(
         elevation: 4,
         shadowColor: Colors.black.withOpacity(0.2),
         margin: EdgeInsets.zero,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
         child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 children: [
                   Icon(icon, color: Colors.blue[700], size: 22),
                   const SizedBox(width: 10),
                   Text(
                     title,
                     style: GoogleFonts.poppins(
                       fontSize: 17,
                       fontWeight: FontWeight.bold,
                       color: Colors.blue[800],
                     ),
                   ),
                 ],
               ),
               const Divider(height: 24),
               ...children,
             ],
           ),
         ),
       ),
     );
  }

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
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aksi Petugas',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const Divider(height: 20),
            ...actionButtons,
          ],
        ),
      ),
    );
  }

  Widget _buildFotoProgresSection() {
    return _buildDetailCard(
      icon: Ionicons.images_outline,
      title: 'Dokumentasi Progres',
      children: [
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
    );
  }

  // WIDGET HELPER
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String? value, {
    bool isLink = false,
    bool isMultiline = false,
  }) {
    final displayValue = (value == null || value.isEmpty) ? 'Data tidak tersedia' : value;
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
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label\n',
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2),
                  ),
                  isLink
                      ? WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: InkWell(
                            onTap: displayValue == 'Data tidak tersedia'
                                ? null
                                : () => _launchURL(displayValue),
                            child: Text(
                              displayValue,
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.blue.shade800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        )
                      : TextSpan(text: displayValue, style: const TextStyle(height: 1.5, color: Colors.black54, fontSize: 15)),
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
      '${_tugasSaatIni is PengaduanTugas ? 'Pelanggan:' : 'Pelapor:'}',
      '${kontak.nama} (${kontak.nomorHp})',
    );
  }

  Widget _buildPhotoViewer(String title, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
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
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(10),
                    child: InteractiveViewer(
                      panEnabled: false,
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Image.network(imageUrl, fit: BoxFit.contain),
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
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                              height: 220,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            ),
                  errorBuilder: (context, error, stack) => Container(
                    height: 180,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
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
          AspectRatio(
            aspectRatio: 1, // Membuat gambar menjadi persegi
            child: GestureDetector(
                 onTap: (imageUrl != null && imageUrl.isNotEmpty) ? () => showDialog(
                 context: context,
                 builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(10),
                     child: InteractiveViewer(
                       panEnabled: false,
                       child: Image.network(imageUrl),
                     ),
                   ),
               ) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (c, e, s) => Icon(
                            Ionicons.image_outline,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        ),
                      )
                    : Icon(
                        Ionicons.image_outline,
                        size: 40,
                        color: Colors.grey[400],
                      ),
              ),
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
      padding: const EdgeInsets.only(bottom: 6.0),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
        return Colors.indigo.shade600;
      case 'dalam_perjalanan':
        return Colors.purple.shade600;
      default: // menunggu_konfirmasi
        return Colors.orange.shade800;
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
    // URL di-parse dengan lebih aman
    final Uri? targetUri = Uri.tryParse(url);
    if (targetUri == null) {
      _showSnackbar('Format URL tidak valid.');
      return;
    }
    
    try {
      if (await canLaunchUrl(targetUri)) {
        await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackbar('Tidak bisa membuka aplikasi peta untuk: $url');
      }
    } catch (e) {
      _showSnackbar('Error membuka peta: $e');
    }
  }
}