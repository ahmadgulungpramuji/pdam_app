// tracking_page.dart
import 'package:flutter/material.dart';
// import 'package:pdam_app/api_service.dart'; // Jika perlu fetch detail tracking

class TrackingPage extends StatefulWidget {
  final String? kodeTracking; // Terima kode tracking dari argumen navigasi

  const TrackingPage({super.key, this.kodeTracking});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final TextEditingController _kodeController = TextEditingController();
  // final ApiService _apiService = ApiService(); // Jika perlu API
  bool _isLoading = false;
  Map<String, dynamic>? _trackingData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.kodeTracking != null && widget.kodeTracking!.isNotEmpty) {
      _kodeController.text = widget.kodeTracking!;
      _searchTracking(widget.kodeTracking!);
    }
  }

  Future<void> _searchTracking(String kode) async {
    if (kode.isEmpty) {
      setState(() {
        _errorMessage = "Kode tracking tidak boleh kosong.";
        _trackingData = null;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _trackingData = null;
    });

    // Simulasi API call
    await Future.delayed(const Duration(seconds: 1));

    // Ganti dengan implementasi API call yang sesungguhnya
    // final response = await _apiService.getTrackingLaporanByKode(kode);
    // if (response.success) {
    //   _trackingData = response.data;
    // } else {
    //   _errorMessage = response.message;
    // }

    // Contoh data dummy
    if (kode.toUpperCase() == "LP202405A1") {
      _trackingData = {
        'kode': kode.toUpperCase(),
        'jenis': 'Kebocoran Pipa Utama',
        'lokasi': 'Jl. Sudirman No. 123, Jakarta',
        'tanggal_lapor': '2024-05-01 10:00',
        'status': 'Sedang Ditangani Petugas',
        'estimasi_selesai': '2024-05-01 15:00',
        'catatan_petugas': 'Tim sedang menuju lokasi, harap bersabar.',
        'history': [
          {
            'timestamp': '2024-05-01 10:05',
            'status': 'Laporan Diterima dan Diverifikasi',
          },
          {'timestamp': '2024-05-01 10:30', 'status': 'Petugas Ditugaskan'},
          {'timestamp': '2024-05-01 11:00', 'status': 'Petugas Menuju Lokasi'},
        ],
      };
    } else if (kode.toUpperCase() == "ERROR123") {
      _errorMessage = "Terjadi kesalahan pada server saat mencari kode Anda.";
    } else {
      _errorMessage = "Kode tracking tidak ditemukan atau tidak valid.";
    }

    setState(() {
      _isLoading = false;
    });
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    status = status.toLowerCase();
    if (status.contains('selesai') || status.contains('teratasi')) {
      return Colors.green;
    }
    if (status.contains('ditangani') ||
        status.contains('proses') ||
        status.contains('menuju')) {
      return Colors.orangeAccent;
    }
    if (status.contains('diterima') || status.contains('verifikasi')) {
      return Colors.blueAccent;
    }
    if (status.contains('ditolak')) return Colors.redAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lacak Laporan (Anonim)'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Jika datang dari login page dan mau kembali, gunakan pushReplacementNamed
            // Jika dari tempat lain, cukup Navigator.pop(context)
            if (ModalRoute.of(context)?.settings.name == '/tracking_page') {
              Navigator.pushReplacementNamed(context, '/login');
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Masukkan Kode Tracking Laporan Anda',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _kodeController,
              decoration: InputDecoration(
                labelText: 'Kode Tracking',
                hintText: 'Contoh: LP202405A1',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                prefixIcon: const Icon(Icons.qr_code_scanner),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _kodeController.clear();
                    setState(() {
                      _trackingData = null;
                      _errorMessage = null;
                    });
                  },
                ),
              ),
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (value) => _searchTracking(value),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon:
                  _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.search),
              label:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text('Lacak Sekarang'),
              onPressed:
                  _isLoading
                      ? null
                      : () => _searchTracking(_kodeController.text.trim()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!_isLoading && _errorMessage != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[700], fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (!_isLoading && _trackingData != null)
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Laporan: ${_trackingData!['kode']}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20),
                      _buildInfoRow(
                        Icons.label_outline,
                        'Jenis Laporan:',
                        _trackingData!['jenis'] ?? '-',
                      ),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        'Lokasi:',
                        _trackingData!['lokasi'] ?? '-',
                      ),
                      _buildInfoRow(
                        Icons.calendar_today_outlined,
                        'Tanggal Lapor:',
                        _trackingData!['tanggal_lapor'] ?? '-',
                      ),
                      _buildInfoRow(
                        Icons.hourglass_empty_outlined,
                        'Estimasi Selesai:',
                        _trackingData!['estimasi_selesai'] ?? '-',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Status Terkini: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Expanded(
                              child: Chip(
                                label: Text(
                                  _trackingData!['status'] ?? '-',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: _getStatusColor(
                                  _trackingData!['status'],
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildInfoRow(
                        Icons.notes_outlined,
                        'Catatan Petugas:',
                        _trackingData!['catatan_petugas'] ??
                            'Tidak ada catatan.',
                      ),
                      if (_trackingData!['history'] != null &&
                          (_trackingData!['history'] as List).isNotEmpty) ...[
                        const Divider(height: 30),
                        Text(
                          'Riwayat Status:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...(_trackingData!['history'] as List).map((hist) {
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.check_circle_outline,
                              color: _getStatusColor(hist['status']),
                              size: 20,
                            ),
                            title: Text(
                              hist['status'],
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              hist['timestamp'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }
}
