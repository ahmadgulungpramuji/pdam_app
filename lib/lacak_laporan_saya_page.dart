// lacak_laporan_saya_page.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';

class LacakLaporanSayaPage extends StatefulWidget {
  const LacakLaporanSayaPage({super.key});

  @override
  State<LacakLaporanSayaPage> createState() => _LacakLaporanSayaPageState();
}

class _LacakLaporanSayaPageState extends State<LacakLaporanSayaPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _laporanList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLaporan();
  }

  Future<void> _fetchLaporan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data =
          await _apiService
              .getLaporanPengaduan(); // Ini perlu diimplementasikan di ApiService
      if (mounted) {
        setState(() {
          _laporanList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data laporan: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'sedang diproses':
        return Colors.orangeAccent;
      case 'selesai':
        return Colors.green;
      case 'ditolak':
        return Colors.redAccent;
      case 'menunggu verifikasi':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'sedang diproses':
        return Icons.hourglass_top_rounded;
      case 'selesai':
        return Icons.check_circle_outline_rounded;
      case 'ditolak':
        return Icons.cancel_outlined;
      case 'menunggu verifikasi':
        return Icons.pending_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lacak Laporan Saya')),
      body: RefreshIndicator(
        onRefresh: _fetchLaporan,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _fetchLaporan,
                          child: Text("Coba Lagi"),
                        ),
                      ],
                    ),
                  ),
                )
                : _laporanList.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Anda belum memiliki laporan.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add_circle_outline),
                        label: Text("Buat Laporan Baru"),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/buat_laporan',
                          ).then((_) => _fetchLaporan());
                        },
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                  padding: const EdgeInsets.all(10.0),
                  itemCount: _laporanList.length,
                  itemBuilder: (context, index) {
                    final laporan = _laporanList[index];
                    final status = laporan['status'] ?? 'Tidak diketahui';
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(
                            status,
                          ).withOpacity(0.15),
                          child: Icon(
                            _getStatusIcon(status),
                            color: _getStatusColor(status),
                          ),
                        ),
                        title: Text(
                          laporan['judul'] ?? 'Tanpa Judul',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${laporan['id'] ?? '-'}'),
                            Text('Tanggal: ${laporan['tanggal'] ?? '-'}'),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          // TODO: Navigasi ke detail laporan jika ada
                          showDialog(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: Text(
                                    'Detail Laporan: ${laporan['id']}',
                                  ),
                                  content: Text(
                                    'Judul: ${laporan['judul']}\n'
                                    'Status: $status\n'
                                    'Tanggal: ${laporan['tanggal']}\n\n'
                                    'Deskripsi Lengkap: (Implementasi detail lebih lanjut)',
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('Tutup'),
                                      onPressed: () => Navigator.of(ctx).pop(),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
