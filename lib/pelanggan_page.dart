import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdam_app/pengaduan_form_page.dart';
import 'package:pdam_app/id_pdam_form_page.dart';

class PelangganPage extends StatefulWidget {
  const PelangganPage({super.key});

  @override
  State<PelangganPage> createState() => _PelangganPageState();
}

class _PelangganPageState extends State<PelangganPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadInitial();
  }

  Future<void> loadInitial() async {
    await Future.delayed(const Duration(milliseconds: 300)); // Optional
    setState(() => isLoading = false);
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Dashboard Pelanggan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: logout,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    _buildMenuItem(
                      icon: Icons.badge,
                      title: "Lihat ID PDAM",
                      subtitle:
                          "Daftar ID PDAM yang terhubung dengan akun Anda",
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      icon: Icons.receipt_long,
                      title: "Cek Tunggakan Pembayaran",
                      subtitle: "Lihat status pembayaran Anda",
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      icon: Icons.report_problem,
                      title: "Buat Pengaduan",
                      subtitle: "Laporkan masalah PDAM di sekitar Anda",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PengaduanFormPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.track_changes,
                      title: "Lacak Status Pengaduan",
                      subtitle: "Pantau penanganan pengaduan Anda",
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      icon: Icons.visibility,
                      title: "Laporan Lapangan dari Petugas",
                      subtitle: "Laporan yang ditemukan langsung oleh petugas",
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      icon: Icons.edit,
                      title: "Isi ID PDAM",
                      subtitle: "Masukkan ID PDAM Anda untuk mulai",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const IdPdamFormPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
