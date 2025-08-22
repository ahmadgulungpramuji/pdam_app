// Salin dan ganti seluruh isi file: lib/detail_calon_pelanggan_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
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
    const Color primaryColor = Color(0xFF0077B6);
    const Color backgroundColor = Color(0xFFF8F9FA);

    final String status = _currentData['status'] ?? 'Status Tidak Diketahui';
    final String namaLengkap =
        _currentData['nama_lengkap'] ?? 'Nama Tidak Tersedia';
    final String tglDaftar = _currentData['tanggal_pendaftaran'] ?? '-';
    final String namaCabang = _currentData['nama_cabang'] ?? '-';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Status Pendaftaran',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
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
              Text(
                'Detail Pendaftaran Anda',
                style: GoogleFonts.manrope(
                    fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                namaLengkap,
                style: GoogleFonts.manrope(
                    fontSize: 18, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              _buildStatusCard(status),
              if ((_currentData['status'] ?? '')
                      .toLowerCase()
                      .contains('ditolak') &&
                  _currentData['alasan_penolakan'] != null &&
                  _currentData['alasan_penolakan'].isNotEmpty)
                _buildAlasanPenolakanCard(_currentData['alasan_penolakan']),
              const SizedBox(height: 16),
              _buildInfoCard([
                _buildInfoRow(
                    icon: Ionicons.calendar_outline,
                    label: 'Tanggal Pendaftaran',
                    value: tglDaftar),
                _buildInfoRow(
                    icon: Ionicons.business_outline,
                    label: 'Cabang Pendaftaran',
                    value: namaCabang),
              ]),
              _buildPhotoCard(
                title: '📸 Foto Hasil Survey',
                imageUrl: _currentData['foto_survey'],
              ),
              _buildPhotoCard(
                title: '🛠️ Foto Hasil Pemasangan',
                imageUrl: _currentData['foto_pemasangan'],
              ),
              if (_currentData['rating_hasil'] != null) ...[
                const SizedBox(height: 16),
                Text("Penilaian Anda:",
                    style: GoogleFonts.manrope(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildInfoCard([
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
                ]),
              ],
              if (status.toLowerCase() == 'terpasang') _buildRatingSection(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'Harap hubungi cabang terkait atau datang langsung ke kantor cabang untuk informasi lebih lanjut mengenai status pendaftaran Anda.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.blue.shade800,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard({required String title, String? imageUrl}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showImageDialog(context, imageUrl),
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
              imageUrl,
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
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Ketuk untuk perbesar',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
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

  Widget _buildAlasanPenolakanCard(String alasan) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
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
                Text("Pendaftaran Ditolak",
                    style: GoogleFonts.manrope(
                        fontSize: 18,
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

  Widget _buildStatusCard(String status) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color secondaryColor = Color(0xFF00B4D8);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            _getStatusColor(status).withOpacity(0.8),
            _getStatusColor(status)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(_getStatusIcon(status), size: 60, color: Colors.white),
          const SizedBox(height: 16),
          Text('Status Terkini',
              style: GoogleFonts.manrope(
                  fontSize: 16, color: Colors.white.withOpacity(0.9))),
          const SizedBox(height: 4),
          Text(status.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    bool isAlreadyRated = _currentData['rating_hasil'] != null;
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
            const SizedBox(height: 20),
            TextField(
              controller: _komentarRatingController,
              decoration: _inputDecoration("Komentar Tambahan (Opsional)",
                  Ionicons.chatbox_ellipses_outline),
              maxLines: 3,
              readOnly: _isSubmittingRating,
            ),
            const SizedBox(height: 24),
            _GradientButton(
              onPressed: _isSubmittingRating ? null : _submitRating,
              text: isAlreadyRated ? 'Update Penilaian' : 'Kirim Penilaian',
              isLoading: _isSubmittingRating,
            )
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
        padding: const EdgeInsets.all(16.0),
        child: Column(children: children),
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
