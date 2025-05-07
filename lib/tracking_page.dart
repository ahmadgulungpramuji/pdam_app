// tracking_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart'; // Import file api_service.dart Anda

class TrackingPage extends StatefulWidget {
  // Halaman ini menerima kode tracking sebagai argumen
  final String trackingCode;

  const TrackingPage({Key? key, required this.trackingCode}) : super(key: key);

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final ApiService _apiService = ApiService(); // Inisialisasi ApiService

  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReportStatus(); // Ambil status laporan saat halaman dimuat
  }

  Future<void> _fetchReportStatus() async {
    setState(() {
      _isLoading = true;
      _reportData = null;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.trackReport(
        widget.trackingCode,
      ); // Panggil API tracking

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _reportData =
              responseData['report']; // Ambil data laporan dari respons
        });
      } else {
        // Handle error (misal kode tracking tidak valid)
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage =
              responseData['message'] ?? 'Gagal memuat status laporan.';
        });
        print(
          'Failed to fetch report status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      });
      print('Error fetching report status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Laporan'),
        // Tombol back otomatis muncul jika ada halaman sebelumnya di stack
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Coba Lagi"),
                        onPressed: _fetchReportStatus, // Tombol untuk retry
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                )
                : _reportData != null
                ? ListView(
                  // Menggunakan ListView agar bisa di-scroll jika konten panjang
                  children: [
                    const Text(
                      'Detail Laporan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      // Tampilkan data dalam Card agar lebih rapi
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kode Tracking: ${widget.trackingCode}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(height: 24),
                            Text(
                              'Status: ${_reportData!['status']}',
                              style: TextStyle(
                                fontSize: 16,
                                color: _getStatusColor(_reportData!['status']),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Deskripsi Lokasi: ${_reportData!['deskripsi_lokasi']}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tanggal Temuan: ${_formatDate(_reportData!['tanggal_temuan'])}',
                              style: const TextStyle(fontSize: 16),
                            ),

                            // Tambahkan detail lain dari _reportData jika ada
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Anda bisa tambahkan tombol kembali atau navigasi lain di sini jika perlu
                    // ElevatedButton(
                    //   onPressed: () {
                    //      Navigator.pop(context); // Kembali ke halaman sebelumnya
                    //   },
                    //   child: const Text('Kembali'),
                    // ),
                  ],
                )
                : const Center(
                  child: Text(
                    'Laporan tidak ditemukan atau terjadi kesalahan.',
                  ),
                ), // Kasus jika _reportData null tanpa error spesifik (jarang)
      ),
    );
  }

  // Fungsi helper untuk menentukan warna status (opsional)
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'menunggu_konfirmasi':
        return Colors.orange;
      case 'diterima':
        return Colors.blue;
      case 'dalam_perjalanan':
        return Colors.cyan;
      case 'diproses':
        return Colors.blueAccent;
      case 'selesai':
        return Colors.green;
      case 'dibatalkan':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  // Fungsi helper untuk format tanggal (opsional)
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    // Asumsi format dari backend adalah string ISO 8601 atau serupa
    try {
      final dateTime = DateTime.parse(date);
      return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
    } catch (e) {
      print("Failed to parse date: $e");
      return date.toString(); // Kembali ke string asli jika gagal parse
    }
  }
}
