// ignore_for_file: unused_import, unused_element

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdam_app/login_page.dart';

class HomePelangganPage extends StatefulWidget {
  const HomePelangganPage({super.key});

  @override
  State<HomePelangganPage> createState() => _HomePelangganPageState();
}

class _HomePelangganPageState extends State<HomePelangganPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getUserProfile();
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoading = false;
      });

      if (_userData == null) {
        _logout();
      }
    }
  }

  Future<void> _logout() async {
    await _apiService.removeToken();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: (iconColor ?? Colors.blue)
                        .withOpacity(0.1),
                    child: Icon(
                      icon,
                      size: 30,
                      color: iconColor ?? Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Beranda Pelanggan'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 6,
        actions: [
          IconButton(
            icon: const Icon(Feather.user),
            tooltip: 'Profil',
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/profil_page');
              if (result == true && mounted) {
                _loadUserData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Feather.log_out),
            tooltip: 'Logout',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      child: const Text('Batal'),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    TextButton(
                      child: const Text('Logout',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _logout();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Datang, ${_userData?['username'] ?? 'Pelanggan'}!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    if (_userData?['email'] != null)
                      Text(
                        _userData!['email'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildFeatureCard(
                          icon: Feather.alert_triangle,
                          title: 'Buat Laporan',
                          subtitle: 'Laporkan masalah atau kebocoran air.',
                          iconColor: Colors.orange,
                          onTap: () => Navigator.pushNamed(context, '/buat_laporan'),
                        ),
                        _buildFeatureCard(
                          icon: Feather.search,
                          title: 'Lacak Laporan',
                          subtitle: 'Lihat status progres laporan Anda.',
                          iconColor: Colors.blue,
                          onTap: () => Navigator.pushNamed(context, '/lacak_laporan_saya'),
                        ),
                        _buildFeatureCard(
                          icon: Feather.file_text,
                          title: 'Info Tagihan',
                          subtitle: 'Cek tunggakan & kelola ID PDAM.',
                          iconColor: Colors.green,
                          onTap: () => Navigator.pushNamed(context, '/cek_tunggakan'),
                        ),
                        _buildFeatureCard(
                          icon: Feather.message_square,
                          title: 'Hubungi Admin',
                          subtitle: 'Chat langsung atau via chatbot.',
                          iconColor: Colors.purple,
                          onTap: () => Navigator.pushNamed(context, '/chat_page'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.water_drop),
                        label: const Text("Lapor Temuan Kebocoran (Umum)"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          elevation: 6,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/temuan_kebocoran');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
