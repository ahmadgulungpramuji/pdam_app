// lib/pages/petugas/detail_calon_pelanggan_page.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:pdam_app/services/watermark_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart'; // Pastikan package ini ada

class DetailCalonPelangganPage extends StatefulWidget {
  final CalonPelangganTugas tugas;
  const DetailCalonPelangganPage({super.key, required this.tugas});

  @override
  State<DetailCalonPelangganPage> createState() =>
      _DetailCalonPelangganPageState();
}

class _DetailCalonPelangganPageState extends State<DetailCalonPelangganPage> {
  // --- WARNA TEMA (Konsisten dengan Home Petugas) ---
  final Color _primaryNavy = const Color(0xFF1565C0);
  final Color _slateText = const Color(0xFF1E293B);
  final Color _subText = const Color(0xFF64748B);
  final Color _bgGrey = const Color(0xFFF8F9FA);

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

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- LOGIKA UTAMA (API & DIALOG) ---

  void _confirmStatusChange(String nextStatus, String title, {bool photoRequired = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(
          'Status akan diubah menjadi "${nextStatus.toUpperCase()}". ${photoRequired ? "\n\nAnda WAJIB mengambil foto bukti di lokasi." : ""}',
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.manrope(color: _subText)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleStatusUpdate(nextStatus, photoRequired);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Lanjutkan', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Hasil Survey', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Apakah lokasi ini layak untuk pemasangan?',
                      style: GoogleFonts.manrope(color: _slateText),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<String>(
                      title: Text('Layak / Direkomendasikan', style: GoogleFonts.manrope()),
                      value: 'direkomendasikan',
                      groupValue: rekomendasi,
                      activeColor: Colors.green,
                      onChanged: (value) => setDialogState(() => rekomendasi = value),
                    ),
                    RadioListTile<String>(
                      title: Text('Tidak Layak', style: GoogleFonts.manrope()),
                      value: 'tidak_direkomendasikan',
                      groupValue: rekomendasi,
                      activeColor: Colors.red,
                      onChanged: (value) => setDialogState(() => rekomendasi = value),
                    ),
                    if (rekomendasi == 'tidak_direkomendasikan')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextField(
                          controller: catatanController,
                          decoration: InputDecoration(
                            labelText: 'Alasan Penolakan (Wajib)',
                            labelStyle: GoogleFonts.manrope(),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          maxLines: 2,
                        ),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    if (rekomendasi == null) {
                      _showSnackbar('Pilih salah satu hasil survey.', isError: true);
                      return;
                    }
                    if (rekomendasi == 'tidak_direkomendasikan' && catatanController.text.trim().isEmpty) {
                      _showSnackbar('Alasan wajib diisi.', isError: true);
                      return;
                    }
                    Navigator.of(context).pop({
                      'rekomendasi': rekomendasi!,
                      'catatan': catatanController.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Simpan Hasil', style: GoogleFonts.manrope(color: Colors.white)),
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
    Map<String, String>? recommendationData;

    if (photoRequired) {
      final picker = ImagePicker();
      final XFile? originalImage = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1080,
      );

      if (originalImage == null) return;

      if (newStatus == 'survey selesai') {
        _setLoading(true, text: 'Menambahkan lokasi & waktu...');
        try {
          final WatermarkService watermarkService = WatermarkService();
          final XFile watermarkedImage = await watermarkService.addWatermark(originalImage);
          imagePath = watermarkedImage.path;

          _setLoading(false); 
          recommendationData = await _showRecommendationDialog();
          if (recommendationData == null) return;
          
        } catch (e) {
          _setLoading(false);
          _showSnackbar('Gagal memproses foto: $e', isError: true);
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
        rekomendasi: recommendationData?['rekomendasi'],
        catatan: recommendationData?['catatan'],
      );

      final updatedTugasJson = result['tugas_terbaru'];
      if (mounted) {
        setState(() {
          _currentTugas = CalonPelangganTugas.fromJson(updatedTugasJson);
        });
        _showSnackbar('Status diperbarui!', isError: false);
      }
    } catch (e) {
      if (mounted) _showSnackbar('Gagal update: ${e.toString()}', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  void _showCancelDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Batalkan Tugas?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: 'Masukkan alasan pembatalan...',
              hintStyle: GoogleFonts.manrope(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Kembali', style: GoogleFonts.manrope(color: _subText)),
            ),
            ElevatedButton(
              onPressed: () {
                final String reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  _showSnackbar('Alasan wajib diisi!', isError: true);
                } else {
                  Navigator.pop(context);
                  _handleCancellation(reason);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Konfirmasi Batal', style: GoogleFonts.manrope(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCancellation(String alasan) async {
    _setLoading(true, text: "Membatalkan tugas...");
    
    String? jenisTugasSpesifik;
    if (_currentTugas.status == 'menunggu survey') {
      jenisTugasSpesifik = 'survey';
    } else if (_currentTugas.status == 'menunggu jadwal pemasangan') {
      jenisTugasSpesifik = 'pemasangan';
    } else {
      _setLoading(false);
      _showSnackbar('Status tidak valid untuk pembatalan.', isError: true);
      return;
    }

    try {
      await _apiService.batalkanPenugasanMandiri(
        idTugas: _currentTugas.idTugas,
        tipeTugas: 'calon_pelanggan',
        alasan: alasan,
        jenisTugasSpesifik: jenisTugasSpesifik,
      );
      if (mounted) await _showSuccessDialog();
    } catch (e) {
      if (mounted) _showSnackbar('Gagal membatalkan: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Ionicons.checkmark_circle, size: 60, color: Colors.green),
            const SizedBox(height: 16),
            Text("Berhasil Dibatalkan", style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primaryNavy),
                child: Text("Kembali", style: GoogleFonts.manrope(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- UI UTAMA ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        title: Text(
          'Detail Pendaftaran',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Ionicons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInDown(child: _buildHeaderCard()),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 100), child: _buildLocationCard()),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 200), child: _buildApplicantInfoCard()),
                const SizedBox(height: 24),
                
                // Bagian Action (Hanya jika user adalah petugas pelapor/ketua)
                if (_currentTugas.isPetugasPelapor) ...[
                   FadeInUp(delay: const Duration(milliseconds: 300), child: _buildActionSection()),
                   const SizedBox(height: 24),
                ],

                FadeInUp(delay: const Duration(milliseconds: 400), child: _buildPhotoGallerySection()),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    if (_loadingText.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(_loadingText, style: GoogleFonts.manrope(color: Colors.white)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 1. Header Card
  Widget _buildHeaderCard() {
    Color statusColor = _getColorForStatus(_currentTugas.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryNavy.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Text(
                  _currentTugas.status.toUpperCase(),
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
              Text(
                '#REG-${_currentTugas.idTugas}',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: _subText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentTugas.kategoriDisplay, // "Pasang Baru"
            style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: _slateText),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
           Row(
            children: [
              Icon(Ionicons.calendar_outline, size: 16, color: _subText),
              const SizedBox(width: 8),
              // Jika ada tanggal pendaftaran di model, pakai itu. Jika tidak, pakai placeholder.
              Text(
                "Tanggal Daftar: -", 
                style: GoogleFonts.manrope(fontSize: 13, color: _subText, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Location Card (Peta Modern)
  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryNavy.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Ionicons.location, color: _primaryNavy, size: 20),
              const SizedBox(width: 10),
              Text('Lokasi Pemasangan', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: _slateText)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentTugas.deskripsiLokasi,
            style: GoogleFonts.manrope(fontSize: 14, color: _slateText, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _launchMaps(_currentTugas.deskripsiLokasi),
              icon: const Icon(Ionicons.map_outline, size: 18),
              label: Text("Buka Google Maps", style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryNavy,
                side: BorderSide(color: _primaryNavy.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.blue.shade50.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Applicant Info Card
  Widget _buildApplicantInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryNavy.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Data Pemohon", style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: _slateText)),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _primaryNavy.withOpacity(0.1),
                child: Icon(Ionicons.person, color: _primaryNavy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentTugas.pelanggan.nama, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: _slateText)),
                    Text(_currentTugas.pelanggan.nomorHp, style: GoogleFonts.manrope(fontSize: 13, color: _subText)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildContactAction(
                  icon: Ionicons.call,
                  color: Colors.blue.shade600,
                  label: "Telp",
                  onTap: () => _launchUrl('tel:${_currentTugas.pelanggan.nomorHp}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildContactAction(
                  icon: Ionicons.logo_whatsapp,
                  color: Colors.green.shade600,
                  label: "WA",
                  onTap: () => _launchWhatsApp(_currentTugas.pelanggan.nomorHp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Action Section (Logic Berat disini)
  Widget _buildActionSection() {
    List<Widget> buttons = [];
    final status = _currentTugas.status.toLowerCase();

    // -- LOGIKA TOMBOL BERDASARKAN STATUS --
    if (status == 'menunggu survey') {
      buttons.add(_buildBigButton("Mulai Survey", Ionicons.play_circle, _primaryNavy, 
        () => _confirmStatusChange('survey', 'Mulai Survey')));
      buttons.add(const SizedBox(height: 12));
      buttons.add(_buildBigButton("Batalkan Tugas", Ionicons.close_circle, Colors.red, _showCancelDialog, isOutline: true));
    
    } else if (status == 'survey') {
      buttons.add(_buildBigButton("Selesaikan Survey", Ionicons.checkmark_done_circle, Colors.teal, 
        () => _confirmStatusChange('survey selesai', 'Selesaikan Survey', photoRequired: true)));
    
    } else if (status == 'menunggu jadwal pemasangan') {
      buttons.add(_buildBigButton("Mulai Pemasangan", Ionicons.construct, Colors.orange.shade800, 
        () => _confirmStatusChange('pemasangan', 'Mulai Pemasangan')));
      buttons.add(const SizedBox(height: 12));
      buttons.add(_buildBigButton("Batalkan Tugas", Ionicons.close_circle, Colors.red, _showCancelDialog, isOutline: true));
    
    } else if (status == 'pemasangan') {
      buttons.add(_buildBigButton("Selesaikan Pemasangan", Ionicons.checkmark_done_circle, Colors.green, 
        () => _confirmStatusChange('terpasang', 'Selesaikan Pemasangan', photoRequired: true)));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Tindakan Diperlukan", style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: _subText)),
        const SizedBox(height: 12),
        ...buttons,
      ],
    );
  }

  // 5. Gallery Section
  Widget _buildPhotoGallerySection() {
    final photos = {
      'Rumah Pelanggan': _currentTugas.fotoRumahUrl,
      'Hasil Survey': _currentTugas.fotoSebelumUrl,
      'Hasil Pemasangan': _currentTugas.fotoSesudahUrl,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Galeri Foto", style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: _slateText)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final title = photos.keys.elementAt(index);
            final url = photos.values.elementAt(index);
            return _buildPhotoItem(title, url);
          },
        ),
      ],
    );
  }

  // --- WIDGET HELPERS (Reused from DetailTugasPage for consistency) ---

  Widget _buildContactAction({required IconData icon, required Color color, required String label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton(String label, IconData icon, Color color, VoidCallback onTap, {bool isOutline = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onTap,
        icon: Icon(icon, color: isOutline ? color : Colors.white),
        label: Text(label, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15, color: isOutline ? color : Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutline ? Colors.white : color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: isOutline ? 0 : 4,
          side: isOutline ? BorderSide(color: color, width: 2) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: color.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildPhotoItem(String title, String? url) {
    bool hasImage = url != null && url.isNotEmpty;
    return GestureDetector(
      onTap: hasImage ? () => _showPhotoViewer(url, title) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: hasImage
                    ? Image.network(url, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey.shade100,
                        child: Icon(Ionicons.image_outline, color: Colors.grey.shade400, size: 30),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: _subText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoViewer(String url, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(url),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FUNCTION HELPERS ---

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'terpasang': return Colors.green;
      case 'survey selesai': return Colors.teal;
      case 'survey': return Colors.orange;
      case 'pemasangan': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    String formattedPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.startsWith('0')) formattedPhone = '62${formattedPhone.substring(1)}';
    final Uri url = Uri.parse('https://wa.me/$formattedPhone');
    _launchUrl(url.toString());
  }

  Future<void> _launchMaps(String address) async {
    // Format query maps yang universal
    final Uri mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    _launchUrl(mapsUrl.toString());
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _showSnackbar('Tidak dapat membuka link', isError: true);
    }
  }
}