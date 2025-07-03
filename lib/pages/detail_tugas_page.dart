// lib/pages/detail_tugas_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdam_app/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:animate_do/animate_do.dart'; // Import package animasi

class DetailTugasPage extends StatefulWidget {
  final Tugas tugas;
  const DetailTugasPage({super.key, required this.tugas});

  @override
  State<DetailTugasPage> createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends State<DetailTugasPage> {
  // =========================================================================
  // == SEMUA LOGIKA STATE DAN CONTROLLER TETAP SAMA (TIDAK DIUBAH) ==
  // =========================================================================
  late Tugas _tugasSaatIni;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  File? _pickedFotoSebelum;
  File? _pickedFotoSesudah;

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
      if (mounted) {
        setState(() {
          final Map<String, dynamic>? tugasTerbaruJson =
              responseData['tugas_terbaru'] as Map<String, dynamic>?;
          if (tugasTerbaruJson != null) {
            _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
          }
        });
        _showSnackbar(
          'Status berhasil diubah ke: ${_tugasSaatIni.friendlyStatus}',
          isError: false,
        );
      }
    } catch (e) {
      _showSnackbar('Gagal mengubah status: $e');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _pickAndUploadImage(
      String jenisFotoUntukUpload, String statusSetelahUpload) async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (pickedFile == null) {
      _showSnackbar('Pemilihan gambar dibatalkan.', isError: true);
      return;
    }

    File imageFile = File(pickedFile.path);
    if (jenisFotoUntukUpload == 'foto_sebelum') {
      setState(() => _pickedFotoSebelum = imageFile);
    } else if (jenisFotoUntukUpload == 'foto_sesudah') {
      setState(() => _pickedFotoSesudah = imageFile);
    }

    _setLoading(true);
    try {
      final responseData = await _apiService.uploadFotoTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        jenisFoto: jenisFotoUntukUpload,
        imagePath: pickedFile.path,
        newStatus: statusSetelahUpload,
      );
      if (mounted) {
        setState(() {
          final Map<String, dynamic>? tugasTerbaruJson =
              responseData['tugas_terbaru'] as Map<String, dynamic>?;
          if (tugasTerbaruJson != null) {
            _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
          }
          if (jenisFotoUntukUpload == 'foto_sebelum') _pickedFotoSebelum = null;
          if (jenisFotoUntukUpload == 'foto_sesudah') _pickedFotoSesudah = null;
        });
        _showSnackbar(
          'Foto ${jenisFotoUntukUpload.replaceAll("_", " ")} berhasil diupload!',
          isError: false,
        );
      }
    } catch (e) {
      _showSnackbar('Gagal upload: $e');
      if (mounted) {
        setState(() {
          if (jenisFotoUntukUpload == 'foto_sebelum') _pickedFotoSebelum = null;
          if (jenisFotoUntukUpload == 'foto_sesudah') _pickedFotoSesudah = null;
        });
      }
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  // =========================================================================
  // == BAGIAN BUILD WIDGET (UI) YANG DIDESAIN ULANG ==
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 100),
                          child: _buildInfoSection()),
                      const SizedBox(height: 24),
                      if (_tugasSaatIni.isPetugasPelapor)
                        FadeInUp(
                            from: 20,
                            delay: const Duration(milliseconds: 200),
                            child: _buildActionSection()),
                      const SizedBox(height: 24),
                      FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 300),
                          child: _buildFotoProgresSection()),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
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

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'selesai': return Colors.green.shade700;
      case 'dibatalkan': return Colors.red.shade700;
      case 'diproses': return Colors.blue.shade800;
      case 'dalam_perjalanan': return Colors.purple.shade700;
      default: return Colors.orange.shade800;
    }
  }

  Widget _buildHeader() {
    Color statusColor = _getColorForStatus(_tugasSaatIni.status);
    return SliverAppBar(
      expandedHeight: 160.0,
      pinned: true,
      stretch: true,
      backgroundColor: statusColor,
      foregroundColor: Colors.white,
      elevation: 2,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          _tugasSaatIni.kategoriDisplay,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor.withOpacity(0.8), statusColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: Icon(Ionicons.water, size: 150, color: Colors.white),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Chip(
                    label: Text(_tugasSaatIni.friendlyStatus.toUpperCase()),
                    backgroundColor: Colors.white.withOpacity(0.9),
                    labelStyle: GoogleFonts.poppins(
                        color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue[800], size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    KontakInfo? kontak = _tugasSaatIni.infoKontakPelapor;
    return _buildSectionCard(
      title: 'Detail Laporan',
      icon: Ionicons.document_text_outline,
      child: Column(
        children: [
          _buildInfoRow(Ionicons.calendar_outline, 'Tanggal Kejadian',
              _dateFormatter.format(DateTime.parse(_tugasSaatIni.tanggalTugas))),
          _buildInfoRow(Ionicons.time_outline, 'Ditugaskan pada',
              '${_dateFormatter.format(_tugasSaatIni.tanggalDibuatPenugasan)}, ${_timeFormatter.format(_tugasSaatIni.tanggalDibuatPenugasan)}'),
          if (kontak != null)
            _buildInfoRow(
                Ionicons.person_outline,
                _tugasSaatIni is PengaduanTugas ? 'Pelanggan' : 'Pelapor',
                '${kontak.nama ?? "N/A"} (${kontak.nomorHp ?? "No HP"})',
                isContact: true,
                phoneNumber: kontak.nomorHp),
          _buildInfoRow(Ionicons.locate_outline, 'Deskripsi Lokasi',
              _tugasSaatIni.deskripsiLokasi,
              isMultiline: true),
          _buildInfoRow(Ionicons.map_outline, 'Link Peta',
              _tugasSaatIni.lokasiMaps,
              isLink: true),
          _buildInfoRow(Ionicons.chatbox_ellipses_outline, 'Deskripsi Laporan',
              _tugasSaatIni.deskripsi,
              isMultiline: true),
          if (_tugasSaatIni.fotoBukti != null && _tugasSaatIni.fotoBukti!.isNotEmpty)
            _buildPhotoDisplay('Foto Bukti Awal', _tugasSaatIni.fotoBukti!),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    List<Widget> actionButtons = [];
    switch (_tugasSaatIni.status) {
      case 'menunggu_konfirmasi':
        actionButtons.add(_buildActionButton(
          label: 'Terima Laporan', icon: Ionicons.checkmark_circle_outline,
          onPressed: () => _updateStatus('diterima'), color: Colors.green[600]));
        break;
      case 'diterima':
        actionButtons.add(_buildActionButton(
          label: 'Mulai Perjalanan', icon: Ionicons.paper_plane_outline,
          onPressed: () => _updateStatus('dalam_perjalanan'), color: Colors.blue[600]));
        break;
      case 'dalam_perjalanan':
        actionButtons.add(_buildActionButton(
          label: 'Ambil Foto Sebelum & Proses', icon: Ionicons.camera_outline,
          onPressed: () => _pickAndUploadImage('foto_sebelum', 'diproses'), color: Colors.orange[700]));
        break;
      case 'diproses':
        actionButtons.add(_buildActionButton(
          label: 'Ambil Foto Sesudah & Selesaikan', icon: Ionicons.camera_reverse_outline,
          onPressed: () => _pickAndUploadImage('foto_sesudah', 'selesai'), color: Colors.teal[600]));
        break;
      default:
        actionButtons.add(Center(child: Text('Tidak ada aksi yang tersedia.', style: GoogleFonts.lato(fontStyle: FontStyle.italic))));
    }

    return _buildSectionCard(
      title: 'Aksi Petugas',
      icon: Ionicons.flash_outline,
      child: Column(children: actionButtons),
    );
  }

  Widget _buildFotoProgresSection() {
    String? fotoSebelumUrl = _tugasSaatIni.detailTugasLengkap?['foto_sebelum_url'] as String?;
    String? fotoSesudahUrl = _tugasSaatIni.detailTugasLengkap?['foto_sesudah_url'] as String?;

    return _buildSectionCard(
      title: 'Dokumentasi Progres',
      icon: Ionicons.images_outline,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _buildPhotoDisplay('Foto Sebelum', fotoSebelumUrl, localFile: _pickedFotoSebelum)),
          const SizedBox(width: 16),
          Expanded(child: _buildPhotoDisplay('Foto Sesudah', fotoSesudahUrl, localFile: _pickedFotoSesudah)),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required VoidCallback onPressed, Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isLink = false, bool isMultiline = false, bool isContact = false, String? phoneNumber}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 2),
                isLink
                    ? InkWell(
                        onTap: () => _launchURL(value),
                        child: Text(value, style: GoogleFonts.lato(fontSize: 15, color: Colors.blue.shade800, decoration: TextDecoration.underline)),
                      )
                    : Text(value, style: GoogleFonts.lato(fontSize: 15, color: Colors.black87, height: isMultiline ? 1.5 : 1.2)),
              ],
            ),
          ),
          if (isContact && phoneNumber != null && phoneNumber.isNotEmpty)
            IconButton(
              icon: Icon(Ionicons.logo_whatsapp, color: Colors.green.shade700),
              onPressed: () => _launchURL('https://wa.me/${phoneNumber.replaceAll(RegExp(r'[^0-9]'), '')}'),
              tooltip: 'Chat via WhatsApp',
            )
        ],
      ),
    );
  }

  Widget _buildPhotoDisplay(String title, String? imageUrl, {File? localFile}) {
    Widget content;
    if (localFile != null) {
      content = Image.file(localFile, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      content = Image.network(imageUrl, fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (context, error, stack) => const Icon(Ionicons.alert_circle_outline, color: Colors.red, size: 40),
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Ionicons.image_outline, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 4),
          Text('Kosong', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600])),
        ],
      );
    }
    return Column(
      children: [
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: content),
          ),
        ),
      ],
    );
  }

  Future<void> _launchURL(String urlString) async {
    String url = urlString;
    if (!url.startsWith('http') && !url.startsWith('https')) {
      url = 'https://maps.google.com/?q=$url';
    }
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackbar('Tidak bisa membuka: $url');
    }
  }
}
