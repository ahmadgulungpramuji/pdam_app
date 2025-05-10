// home_page.dart
import 'package:flutter/material.dart';
import 'api_service.dart'; // Import api_service untuk logout (opsional di halaman home)

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Fungsi logout (opsional, tambahkan tombol di UI jika diperlukan)
  Future<void> _logout(BuildContext context) async {
    final apiService = ApiService();
    await apiService.removeToken(); // Hapus token
    // Navigasi kembali ke halaman login dan hapus semua route sebelumnya
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Pelanggan'),
        // Tambahkan tombol logout di AppBar (opsional)
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Selamat Datang!', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            const Text(
              'Ini adalah halaman utama setelah login.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Tombol untuk navigasi ke halaman Temuan Kebocoran
            ElevatedButton(
              onPressed: () {
                // Navigasi ke route Temuan Kebocoran Page
                Navigator.pushNamed(
                  context,
                  '/temuan_kebocoran',
                ); // Ganti dengan route Temuan Kebocoran Page Anda
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Buat Laporan Temuan Kebocoran'),
            ),

            const SizedBox(height: 20),

            // Jika ada fitur lain, tambahkan tombol di sini
          ],
        ),
      ),
    );
  }
}
