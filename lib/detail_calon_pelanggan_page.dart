// Salin dan ganti seluruh isi file: lib/detail_calon_pelanggan_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan import ini benar

class DetailCalonPelangganPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const DetailCalonPelangganPage({super.key, required this.data});

  @override
  State<DetailCalonPelangganPage> createState() =>
      _DetailCalonPelangganPageState();
}

class _DetailCalonPelangganPageState extends State<DetailCalonPelangganPage> {
  final _apiService = ApiService();
  late Map<String, dynamic> _currentData;

  final _komentarRatingController = TextEditingController();
  double _ratingKecepatan = 0;
  double _ratingPelayanan = 0;
  double _ratingHasil = 0;
  bool _isSubmittingRating = false;

  @override
  void initState() {
    super.initState();
    _currentData = widget.data;
    _initializeRatingState();
  }

  void _initializeRatingState() {
    setState(() {
      _ratingKecepatan =
          (_currentData['rating_kecepatan'] as num?)?.toDouble() ?? 0;
      _ratingPelayanan =
          (_currentData['rating_pelayanan'] as num?)?.toDouble() ?? 0;
      _ratingHasil = (_currentData['rating_hasil'] as num?)?.toDouble() ?? 0;
      _komentarRatingController.text = _currentData['komentar_rating'] ?? '';
    });
  }

  @override
  void dispose() {
    _komentarRatingController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      ),
    );
  }

  Future<void> _refreshData() async {
    try {
      if (_currentData['tracking_code'] != null) {
        final updatedData = await _apiService
            .trackCalonPelanggan(_currentData['tracking_code']);
        if (mounted) {
          setState(() => _currentData = updatedData);
          _initializeRatingState();
          _showSnackbar("Data pendaftaran diperbarui.", isError: false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Gagal memperbarui data: ${e.toString()}');
      }
    }
  }

  Future<void> _submitRating() async {
    if (_ratingKecepatan == 0 || _ratingPelayanan == 0 || _ratingHasil == 0) {
      _showSnackbar(
          'Harap isi semua aspek penilaian (kecepatan, pelayanan, dan hasil).');
      return;
    }

    setState(() => _isSubmittingRating = true);

    try {
      await _apiService.submitRating(
        tipeLaporan: 'calon_pelanggan',
        trackingCode: _currentData['tracking_code'],
        ratingKecepatan: _ratingKecepatan.toInt(),
        ratingPelayanan: _ratingPelayanan.toInt(),
        ratingHasil: _ratingHasil.toInt(),
        komentar: _komentarRatingController.text.trim(),
      );

      if (mounted) {
        _showSnackbar('Penilaian berhasil dikirim!', isError: false);
        await _refreshData();
      }
    } catch (e) {
      if (mounted) _showSnackbar(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = _currentData['status'] ?? 'Status Tidak Diketahui';
    final String namaLengkap =
        _currentData['nama_lengkap'] ?? 'Nama Tidak Tersedia';
    final String tglDaftar = _currentData['tanggal_pendaftaran'] ?? '-';
    final String namaCabang = _currentData['nama_cabang'] ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Pendaftaran'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detail Pendaftaran Anda',
                style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                namaLengkap,
                style: GoogleFonts.poppins(
                    fontSize: 18, color: Colors.grey.shade700),
              ),
              const Divider(height: 30),
              _buildStatusCard(status),
              const SizedBox(height: 24),
              _buildInfoRow(
                  icon: Ionicons.calendar_outline,
                  label: 'Tanggal Pendaftaran',
                  value: tglDaftar),
              _buildInfoRow(
                  icon: Ionicons.business_outline,
                  label: 'Cabang Pendaftaran',
                  value: namaCabang),

              // === WIDGET BARU UNTUK FOTO-FOTO ===
              _buildPhotoCard(
                title: '📸 Foto Hasil Survey',
                imageUrl: _currentData['foto_survey'],
              ),
              _buildPhotoCard(
                title: '🛠️ Foto Hasil Pemasangan',
                imageUrl: _currentData['foto_pemasangan'],
              ),
              // === AKHIR WIDGET BARU ===

              if (_currentData['rating_hasil'] != null) ...[
                const Divider(height: 24, thickness: 1),
                Text(
                  "Penilaian Anda:",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                    icon: Ionicons.speedometer_outline,
                    label: 'Kecepatan',
                    value: '${_currentData['rating_kecepatan']}/5 ★'),
                _buildInfoRow(
                    icon: Ionicons.people_outline,
                    label: 'Pelayanan',
                    value: '${_currentData['rating_pelayanan']}/5 ★'),
                _buildInfoRow(
                    icon: Ionicons.checkmark_done_outline,
                    label: 'Hasil',
                    value: '${_currentData['rating_hasil']}/5 ★'),
                if (_currentData['komentar_rating'] != null &&
                    _currentData['komentar_rating'].isNotEmpty)
                  _buildInfoRow(
                      icon: Ionicons.chatbox_ellipses_outline,
                      label: 'Komentar',
                      value: _currentData['komentar_rating']),
              ],
              
              if (status.toLowerCase() == 'terpasang') _buildRatingSection(),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Harap hubungi cabang terkait atau datang langsung ke kantor cabang untuk informasi lebih lanjut mengenai status pendaftaran Anda.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === WIDGET BARU UNTUK MENAMPILKAN KARTU FOTO ===
  Widget _buildPhotoCard({required String title, String? imageUrl}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink(); // Jangan tampilkan apapun jika URL tidak ada
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showImageDialog(context, imageUrl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  alignment: Alignment.center,
                  color: Colors.grey.shade200,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Ionicons.warning_outline, color: Colors.red, size: 40),
                      SizedBox(height: 8),
                      Text('Gagal Memuat Gambar'),
                    ],
                  ),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Ketuk untuk perbesar', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  SizedBox(width: 4),
                  Icon(Ionicons.expand_outline, color: Colors.grey, size: 16),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // === WIDGET BARU UNTUK MENAMPILKAN GAMBAR DALAM DIALOG ===
  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(_getStatusIcon(status),
                size: 70, color: _getStatusColor(status)),
            const SizedBox(height: 16),
            Text('Status Terkini',
                style: GoogleFonts.poppins(
                    fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              status.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    bool isAlreadyRated = _currentData['rating_hasil'] != null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAlreadyRated ? 'Ubah Penilaian Anda:' : 'Beri Penilaian',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildRatingBar(
                title: "Kecepatan Proses",
                currentRating: _ratingKecepatan,
                onRatingUpdate: (rating) =>
                    setState(() => _ratingKecepatan = rating)),
            _buildRatingBar(
                title: "Pelayanan Petugas",
                currentRating: _ratingPelayanan,
                onRatingUpdate: (rating) =>
                    setState(() => _ratingPelayanan = rating)),
            _buildRatingBar(
                title: "Hasil Pemasangan",
                currentRating: _ratingHasil,
                onRatingUpdate: (rating) =>
                    setState(() => _ratingHasil = rating)),
            const SizedBox(height: 16),
            TextField(
              controller: _komentarRatingController,
              decoration: InputDecoration(
                labelText: 'Komentar Tambahan (Opsional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
              readOnly: _isSubmittingRating,
            ),
            const SizedBox(height: 20),
            if (_isSubmittingRating)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton.icon(
                icon: Icon(isAlreadyRated
                    ? Icons.edit_note_rounded
                    : Icons.send_rounded),
                label: Text(
                    isAlreadyRated ? 'Update Penilaian' : 'Kirim Penilaian'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _isSubmittingRating ? null : _submitRating,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(
      {required String title,
      required double currentRating,
      required Function(double) onRatingUpdate}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          RatingBar.builder(
            initialRating: currentRating,
            minRating: 1,
            itemCount: 5,
            itemSize: 36.0,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) =>
                Icon(Icons.star_rounded, color: Colors.amber.shade700),
            onRatingUpdate: onRatingUpdate,
            ignoreGestures: _isSubmittingRating,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    status = status.toLowerCase();
    if (status.contains('terpasang')) return Colors.green.shade700;
    if (status.contains('pemasangan') || status.contains('survey'))
      return Colors.blue.shade700;
    if (status.contains('menunggu')) return Colors.orange.shade700;
    if (status.contains('diterima')) return Colors.lightBlue.shade600;
    if (status.contains('ditolak') || status.contains('dibatalkan'))
      return Colors.red.shade700;
    return Colors.grey.shade600;
  }

  IconData _getStatusIcon(String? status) {
    if (status == null) return Ionicons.help_circle_outline;
    status = status.toLowerCase();
    if (status.contains('terpasang')) return Ionicons.checkmark_circle_outline;
    if (status.contains('pemasangan')) return Ionicons.construct_outline;
    if (status.contains('survey')) return Ionicons.search_circle_outline;
    if (status.contains('menunggu')) return Ionicons.time_outline;
    if (status.contains('diterima')) return Ionicons.shield_checkmark_outline;
    if (status.contains('ditolak') || status.contains('dibatalkan'))
      return Ionicons.close_circle_outline;
    return Ionicons.information_circle_outline;
  }
}