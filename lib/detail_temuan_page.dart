// lib/detail_temuan_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:pdam_app/models/temuan_kebocoran_model.dart';
import 'package:pdam_app/api_service.dart';

class DetailTemuanPage extends StatefulWidget {
  final TemuanKebocoran temuanKebocoran;

  const DetailTemuanPage({super.key, required this.temuanKebocoran});

  @override
  State<DetailTemuanPage> createState() => _DetailTemuanPageState();
}

class _DetailTemuanPageState extends State<DetailTemuanPage> {
  late TemuanKebocoran _currentTemuan;
  final ApiService _apiService = ApiService();

  // DIUBAH: State untuk tiga rating
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
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      ),
    );
  }

  Future<void> _refreshData() async {
    try {
      if (_currentTemuan.trackingCode != null) {
        final updatedTemuan = await _apiService.trackReport(
          _currentTemuan.trackingCode!,
        );
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
        'Harap isi semua aspek penilaian (kecepatan, pelayanan, dan hasil).',
      );
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
        await _refreshData(); // Muat ulang data untuk menampilkan rating terbaru
      } else {
        _showSnackbar(responseData['message'] ?? 'Gagal mengirim penilaian.');
      }
    } catch (e) {
      _showSnackbar(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmittingRating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        'Laporan #${_currentTemuan.trackingCode ?? _currentTemuan.id}',
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _refreshData,
      // TAMBAHKAN AlwaysScrollableScrollPhysics di sini
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // <--- Tambahan
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailCard(),
            if (_currentTemuan.status.toLowerCase() == 'selesai')
              _buildRatingSection(),
            // OPSIONAL: Tambahkan SizedBox kosong untuk memastikan scroll bisa dilakukan
            // const SizedBox(height: 100), 
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDetailCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    _currentTemuan.status,
                  ).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentTemuan.friendlyStatus.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(_currentTemuan.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailItem('Kode Pelacakan:', _currentTemuan.trackingCode),
            _buildDetailItem('Dilaporkan oleh:', _currentTemuan.namaPelapor),
            _buildDetailItem(
              'Deskripsi Lokasi:',
              _currentTemuan.deskripsiLokasi,
              isMultiline: true,
            ),

            // Tampilkan foto-foto jika ada
            _buildPhotoDisplay(_currentTemuan.fotoBukti, "Foto Bukti Awal"),
            _buildPhotoDisplay(
              _currentTemuan.fotoSebelum,
              "Foto Sebelum Perbaikan",
            ),
            _buildPhotoDisplay(
              _currentTemuan.fotoSesudah,
              "Foto Sesudah Perbaikan",
            ),

            // Tampilkan rating yang sudah ada jika laporan selesai dan sudah dirating
            if (_currentTemuan.status.toLowerCase() == 'selesai' &&
                _currentTemuan.ratingHasil != null) ...[
              const Divider(height: 24, thickness: 1),
              Text(
                "Penilaian Anda:",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDetailItem(
                'Kecepatan Respon:',
                '${_currentTemuan.ratingKecepatan}/5 ★',
              ),
              _buildDetailItem(
                'Pelayanan Petugas:',
                '${_currentTemuan.ratingPelayanan}/5 ★',
              ),
              _buildDetailItem(
                'Hasil Penanganan:',
                '${_currentTemuan.ratingHasil}/5 ★',
              ),
              if (_currentTemuan.komentarRating != null &&
                  _currentTemuan.komentarRating!.isNotEmpty)
                _buildDetailItem(
                  'Komentar:',
                  _currentTemuan.komentarRating,
                  isMultiline: true,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    bool isAlreadyRated = _currentTemuan.ratingHasil != null;
    bool ratingsChanged =
        _ratingKecepatan != (_currentTemuan.ratingKecepatan?.toDouble() ?? 0) ||
        _ratingPelayanan != (_currentTemuan.ratingPelayanan?.toDouble() ?? 0) ||
        _ratingHasil != (_currentTemuan.ratingHasil?.toDouble() ?? 0) ||
        _komentarRatingController.text.trim() !=
            (_currentTemuan.komentarRating ?? '');

    bool canSubmit =
        (_ratingKecepatan > 0 && _ratingPelayanan > 0 && _ratingHasil > 0) &&
        (isAlreadyRated ? ratingsChanged : true);

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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            _buildRatingBar(
              title: "Kecepatan Respon",
              currentRating: _ratingKecepatan,
              onRatingUpdate:
                  (rating) => setState(() => _ratingKecepatan = rating),
            ),
            _buildRatingBar(
              title: "Pelayanan Petugas",
              currentRating: _ratingPelayanan,
              onRatingUpdate:
                  (rating) => setState(() => _ratingPelayanan = rating),
            ),
            _buildRatingBar(
              title: "Hasil Penanganan",
              currentRating: _ratingHasil,
              onRatingUpdate: (rating) => setState(() => _ratingHasil = rating),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _komentarRatingController,
              decoration: InputDecoration(
                labelText: 'Komentar Tambahan (Opsional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
              readOnly: _isSubmittingRating,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            if (_isSubmittingRating)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton.icon(
                icon: Icon(
                  isAlreadyRated ? Icons.edit_note_rounded : Icons.send_rounded,
                ),
                label: Text(
                  isAlreadyRated ? 'Update Penilaian' : 'Kirim Penilaian',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: canSubmit ? _submitTemuanRating : null,
              ),
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          RatingBar.builder(
            initialRating: currentRating,
            minRating: 1,
            itemCount: 5,
            itemSize: 36.0,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder:
                (context, _) =>
                    Icon(Icons.star_rounded, color: Colors.amber.shade700),
            onRatingUpdate: onRatingUpdate,
            ignoreGestures: _isSubmittingRating,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String? value, {
    bool isMultiline = false,
  }) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const Text(": "),
          Expanded(
            child: Text(
              value,
              maxLines: isMultiline ? 5 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoDisplay(String? fotoPath, String label) {
    if (fotoPath == null || fotoPath.isEmpty) return const SizedBox.shrink();

    final String imageUrl = '${_apiService.rootBaseUrl}/storage/$fotoPath';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
            ),
            // Opsional: Tambahkan error/loading builder jika perlu
          ),
        ],
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
        return Colors.red.shade700;
      case 'pending':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
