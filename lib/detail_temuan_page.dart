// lib/detail_temuan_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdam_app/models/temuan_kebocoran_model.dart';
import 'package:pdam_app/api_service.dart';

// --- WIDGET ANIMASI (Disalin dari halaman lain) ---

class FadeInAnimation extends StatefulWidget {
  final int delay;
  final Widget child;
  const FadeInAnimation({super.key, this.delay = 0, required this.child});
  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _position = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(curve);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _position, child: widget.child));
  }
}

class StaggeredFadeIn extends StatelessWidget {
  final List<Widget> children;
  final int delay;
  const StaggeredFadeIn({super.key, required this.children, this.delay = 100});
  @override
  Widget build(BuildContext context) {
    return Column(
        children: List.generate(children.length, (index) {
      return FadeInAnimation(delay: delay * index, child: children[index]);
    }));
  }
}
// --- END WIDGET ANIMASI ---

class DetailTemuanPage extends StatefulWidget {
  final TemuanKebocoran temuanKebocoran;

  const DetailTemuanPage({super.key, required this.temuanKebocoran});

  @override
  State<DetailTemuanPage> createState() => _DetailTemuanPageState();
}

class _DetailTemuanPageState extends State<DetailTemuanPage> {
  late TemuanKebocoran _currentTemuan;
  final ApiService _apiService = ApiService();

  final _komentarRatingController = TextEditingController();
  double _ratingKecepatan = 0;
  double _ratingPelayanan = 0;
  double _ratingHasil = 0;
  bool _isSubmittingRating = false;

  @override
  void initState() {
    super.initState();
    _currentTemuan = widget.temuanKebocoran;
    _initializeRatingState();
  }

  void _initializeRatingState() {
    _ratingKecepatan = _currentTemuan.ratingKecepatan?.toDouble() ?? 0;
    _ratingPelayanan = _currentTemuan.ratingPelayanan?.toDouble() ?? 0;
    _ratingHasil = _currentTemuan.ratingHasil?.toDouble() ?? 0;
    _komentarRatingController.text = _currentTemuan.komentarRating ?? '';
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
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _refreshData() async {
    try {
      if (_currentTemuan.trackingCode != null) {
        final updatedTemuan =
            await _apiService.trackReport(_currentTemuan.trackingCode!);
        if (mounted) {
          setState(() {
            _currentTemuan = updatedTemuan;
            _initializeRatingState();
          });
          _showSnackbar("Data laporan diperbarui.", isError: false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Gagal memperbarui data: ${e.toString()}');
      }
    }
  }

  Future<void> _submitTemuanRating() async {
    if (_ratingKecepatan == 0 || _ratingPelayanan == 0 || _ratingHasil == 0) {
      _showSnackbar(
          'Harap isi semua aspek penilaian (kecepatan, pelayanan, dan hasil).');
      return;
    }
    setState(() => _isSubmittingRating = true);
    try {
      final responseData = await _apiService.submitRating(
        tipeLaporan: 'temuan_kebocoran',
        trackingCode: _currentTemuan.trackingCode!,
        ratingKecepatan: _ratingKecepatan.toInt(),
        ratingPelayanan: _ratingPelayanan.toInt(),
        ratingHasil: _ratingHasil.toInt(),
        komentar: _komentarRatingController.text.trim(),
        token: null,
      );
      if (mounted && responseData['success'] == true) {
        _showSnackbar('Penilaian berhasil dikirim!', isError: false);
        await _refreshData();
      } else {
        _showSnackbar(responseData['message'] ?? 'Gagal mengirim penilaian.');
      }
    } catch (e) {
      if (mounted) _showSnackbar(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Detail Laporan',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: StaggeredFadeIn(
            delay: 100,
            children: [
              _buildStatusHeader(),
              const SizedBox(height: 24),
              _buildInfoCard([
                _buildInfoRow(
                    icon: Ionicons.barcode_outline,
                    label: 'Kode Pelacakan',
                    value: _currentTemuan.trackingCode ?? '-'),
                _buildInfoRow(
                    icon: Ionicons.person_outline,
                    label: 'Dilaporkan oleh',
                    value: _currentTemuan.namaPelapor),
                _buildInfoRow( // <-- Perubahan: Menampilkan Deskripsi Laporan
                    icon: Ionicons.document_text_outline,
                    label: 'Deskripsi Laporan',
                    value: _currentTemuan.deskripsi,
                    isMultiline: true),
                _buildInfoRow(
                    icon: Ionicons.map_outline,
                    label: 'Deskripsi Lokasi',
                    value: _currentTemuan.deskripsiLokasi,
                    isMultiline: true),
              ]),
              if ((_currentTemuan.status.toLowerCase() == 'dibatalkan' ||
                      _currentTemuan.status.toLowerCase() == 'ditolak') &&
                  _currentTemuan.keteranganPenolakan != null &&
                  _currentTemuan.keteranganPenolakan!.isNotEmpty)
                _buildAlasanDitolakCard(_currentTemuan.keteranganPenolakan!),
              _buildPhotoCard(
                  title: "📸 Foto Bukti Awal",
                  imageUrl: _currentTemuan.fotoBukti),
              _buildPhotoCard(
                  title: "🛠️ Foto Sebelum Perbaikan",
                  imageUrl: _currentTemuan.fotoSebelum),
              _buildPhotoCard(
                  title: "✅ Foto Sesudah Perbaikan",
                  imageUrl: _currentTemuan.fotoSesudah),
              if (_currentTemuan.status.toLowerCase() == 'selesai' &&
                  _currentTemuan.ratingHasil != null) ...[
                const SizedBox(height: 16),
                Text("Penilaian Anda:",
                    style: GoogleFonts.manrope(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildInfoCard([
                  _buildInfoRow(
                      icon: Ionicons.speedometer_outline,
                      label: 'Kecepatan Respon',
                      value: '${_currentTemuan.ratingKecepatan}/5 ★'),
                  _buildInfoRow(
                      icon: Ionicons.people_outline,
                      label: 'Pelayanan Petugas',
                      value: '${_currentTemuan.ratingPelayanan}/5 ★'),
                  _buildInfoRow(
                      icon: Ionicons.checkmark_done_outline,
                      label: 'Hasil Penanganan',
                      value: '${_currentTemuan.ratingHasil}/5 ★'),
                  if (_currentTemuan.komentarRating != null &&
                      _currentTemuan.komentarRating!.isNotEmpty)
                    _buildInfoRow(
                        icon: Ionicons.chatbox_ellipses_outline,
                        label: 'Komentar',
                        value: _currentTemuan.komentarRating,
                        isMultiline: true),
                ]),
              ],
              if (_currentTemuan.status.toLowerCase() == 'selesai')
                _buildRatingSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
          color: _getStatusColor(_currentTemuan.status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text('Status Laporan',
              style: GoogleFonts.manrope(
                  fontSize: 14, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(
            _currentTemuan.friendlyStatus.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(_currentTemuan.status)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlasanDitolakCard(String alasan) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Ionicons.close_circle_outline,
                    color: Colors.red.shade700, size: 24),
                const SizedBox(width: 12),
                Text("Laporan Dibatalkan/Ditolak",
                    style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800)),
              ],
            ),
            const Divider(height: 20),
            Text("Alasan:",
                style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(alasan,
                style:
                    GoogleFonts.manrope(fontSize: 15, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard({required String title, String? imageUrl}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final String fullImageUrl = '${_apiService.rootBaseUrl}/storage/$imageUrl';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showImageDialog(context, fullImageUrl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(title,
                  style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Image.network(
              fullImageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  alignment: Alignment.center,
                  color: Colors.grey.shade200,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Ionicons.warning_outline,
                          color: Colors.red, size: 40),
                      SizedBox(height: 8),
                      Text('Gagal Memuat Gambar'),
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Ketuk untuk perbesar',
                      style: GoogleFonts.manrope(
                          color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Ionicons.expand_outline,
                      color: Colors.grey, size: 16),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(child: Image.network(imageUrl)),
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    bool isAlreadyRated = _currentTemuan.ratingHasil != null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300)),
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAlreadyRated ? 'Ubah Penilaian Anda' : 'Beri Penilaian',
              style: GoogleFonts.manrope(
                  fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildRatingBar(
                title: "Kecepatan Respon",
                currentRating: _ratingKecepatan,
                onRatingUpdate: (rating) =>
                    setState(() => _ratingKecepatan = rating)),
            _buildRatingBar(
                title: "Pelayanan Petugas",
                currentRating: _ratingPelayanan,
                onRatingUpdate: (rating) =>
                    setState(() => _ratingPelayanan = rating)),
            _buildRatingBar(
                title: "Hasil Penanganan",
                currentRating: _ratingHasil,
                onRatingUpdate: (rating) =>
                    setState(() => _ratingHasil = rating)),
            const SizedBox(height: 20),
            TextField(
              controller: _komentarRatingController,
              decoration: _inputDecoration("Komentar Tambahan (Opsional)",
                  Ionicons.chatbox_ellipses_outline),
              maxLines: 3,
              readOnly: _isSubmittingRating,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            _GradientButton(
              onPressed: _isSubmittingRating ? null : _submitTemuanRating,
              text: isAlreadyRated ? 'Update Penilaian' : 'Kirim Penilaian',
              isLoading: _isSubmittingRating,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar({
    required String title,
    required double currentRating,
    required Function(double) onRatingUpdate,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Text(title,
              style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: currentRating,
            minRating: 1,
            itemCount: 5,
            itemSize: 40.0,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) =>
                Icon(Ionicons.star, color: Colors.amber.shade700),
            onRatingUpdate: onRatingUpdate,
            ignoreGestures: _isSubmittingRating,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(
      {required IconData icon,
      required String label,
      required String? value,
      bool isMultiline = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.manrope(
                        fontSize: 14, color: Colors.grey.shade700)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    const Color primaryColor = Color(0xFF0077B6);
    return InputDecoration(
      hintText: label,
      hintStyle: GoogleFonts.manrope(color: Colors.grey.shade600, fontSize: 15),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 18.0, right: 12.0),
        child: Icon(icon, color: primaryColor, size: 22),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'diproses':
        return Colors.orange.shade700;
      case 'selesai':
        return Colors.green.shade700;
      case 'dibatalkan':
      case 'ditolak':
        return Colors.red.shade700;
      case 'pending':
      case 'menunggu_konfirmasi':
      case 'diterima':
      case 'dalam_perjalanan':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}

// Widget Bantuan untuk Tombol Gradien
class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;

  const _GradientButton(
      {required this.onPressed, required this.text, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color secondaryColor = Color(0xFF00B4D8);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      text,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}