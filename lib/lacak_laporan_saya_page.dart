// lib/lacak_laporan_saya_page.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart'; // Sesuaikan path jika perlu
import 'package:pdam_app/models/pengaduan_model.dart'; // Sesuaikan path dan pastikan model ini sudah benar

class LacakLaporanSayaPage extends StatefulWidget {
  const LacakLaporanSayaPage({super.key});

  @override
  State<LacakLaporanSayaPage> createState() => _LacakLaporanSayaPageState();
}

class _LacakLaporanSayaPageState extends State<LacakLaporanSayaPage> {
  final ApiService _apiService = ApiService();
  List<Pengaduan> _laporanList = [];
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
      final List<dynamic> rawData = await _apiService.getLaporanPengaduan();

      if (mounted) {
        List<Pengaduan> tempList = [];
        int failedItemsCount = 0;

        for (final itemJson in rawData) {
          if (itemJson is Map<String, dynamic>) {
            try {
              tempList.add(Pengaduan.fromJson(itemJson));
            } catch (e) {
              failedItemsCount++;
              print(
                'Gagal memproses satu item laporan (dilewati): $itemJson. Error: $e',
              );
            }
          } else {
            failedItemsCount++;
            print(
              'Item data laporan tidak valid (bukan Map dan dilewati): $itemJson',
            );
          }
        }

        setState(() {
          _laporanList = tempList;
          _isLoading = false;

          if (failedItemsCount > 0) {
            print('$failedItemsCount item laporan gagal dimuat dan dilewati.');
            // Opsional: Tampilkan SnackBar jika ada item yang gagal
            // if (mounted) {
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     SnackBar(
            //       content: Text('$failedItemsCount item laporan tidak dapat ditampilkan karena format salah.'),
            //       duration: Duration(seconds: 3),
            //     ),
            //   );
            // }
          }

          if (rawData.isNotEmpty && tempList.isEmpty && _errorMessage == null) {
            _errorMessage =
                'Gagal memproses semua data laporan. Format mungkin tidak sesuai.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data laporan: Terjadi kesalahan.';
          print('Error saat fetch laporan: $e');
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'diproses':
        return Colors.orangeAccent;
      case 'selesai':
        return Colors.green;
      case 'dibatalkan':
        return Colors.redAccent;
      case 'pending':
      case 'menunggu_konfirmasi':
      case 'diterima':
        return Colors.blueAccent;
      case 'dalam_perjalanan':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'diproses':
        return Icons.hourglass_top_rounded;
      case 'selesai':
        return Icons.check_circle_outline_rounded;
      case 'dibatalkan':
        return Icons.cancel_outlined;
      case 'pending':
      case 'menunggu_konfirmasi':
      case 'diterima':
        return Icons.pending_outlined;
      case 'dalam_perjalanan':
        return Icons.directions_walk_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lacak Laporan Saya')),
      body: RefreshIndicator(onRefresh: _fetchLaporan, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _laporanList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red[700]),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Coba Lagi"),
                onPressed: _fetchLaporan,
              ),
            ],
          ),
        ),
      );
    }

    if (_laporanList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                'Anda belum memiliki laporan pengaduan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Text(
                'Silakan buat laporan baru jika Anda memiliki keluhan atau menemukan masalah layanan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text("Buat Laporan Baru"),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/buat_laporan',
                  ).then((_) => _fetchLaporan());
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: _laporanList.length,
      itemBuilder: (context, index) {
        final Pengaduan laporan = _laporanList[index];
        final String rawStatus = laporan.status;
        final String displayStatus =
            laporan
                .friendlyStatus; // Tetap menggunakan friendlyStatus untuk teks

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(rawStatus).withOpacity(0.15),
              child: Icon(
                _getStatusIcon(rawStatus),
                color: _getStatusColor(rawStatus),
                size: 28,
              ),
              radius: 25,
            ),
            title: Text(
              laporan.friendlyKategori,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ID: ${laporan.id}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  Text(
                    'Tanggal: ${laporan.tanggalPengaduan}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  if (laporan.deskripsiLokasi.isNotEmpty &&
                      laporan.deskripsiLokasi != 'N/A')
                    Text(
                      'Lokasi: ${laporan.deskripsiLokasi}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(rawStatus),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                displayStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: Text('Detail Laporan: ${laporan.id}'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDetailRow(
                              'Kategori:',
                              laporan.friendlyKategori,
                            ),
                            _buildDetailRow('Status:', displayStatus),
                            _buildDetailRow(
                              'Tanggal Lapor:',
                              laporan.tanggalPengaduan,
                            ),
                            _buildDetailRow(
                              'Deskripsi Lokasi:',
                              laporan.deskripsiLokasi,
                            ),
                            _buildDetailRow(
                              'Deskripsi Masalah:',
                              laporan.deskripsi,
                            ),
                          ],
                        ),
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 15),
          children: <TextSpan>[
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value.isNotEmpty ? value : '-'),
          ],
        ),
      ),
    );
  }
}
