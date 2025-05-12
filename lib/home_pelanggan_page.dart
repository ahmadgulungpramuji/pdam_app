// ignore_for_file: unused_import, unused_element

import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdam_app/login_page.dart';

class HomePelangganPage extends StatefulWidget {
  const HomePelangganPage({super.key});

  @override
  State<HomePelangganPage> createState() => _HomePelangganPageState();
}

class _HomePelangganPageState extends State<HomePelangganPage> {
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
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 24,
                backgroundColor: (iconColor ??
                        Theme.of(context).colorScheme.primary)
                    .withOpacity(0.1),
                child: Icon(
                  icon,
                  size: 28,
                  color: iconColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda Pelanggan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/profil_page');
              if (result == true && mounted) {
                _loadUserData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Konfirmasi Logout'),
                      content: const Text('Apakah Anda yakin ingin keluar?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Batal'),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        TextButton(
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
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
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadUserData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Selamat Datang, ${_userData?['username'] ?? 'Pelanggan'}!',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_userData?['email'] != null)
                        Text(
                          _userData!['email'],
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: <Widget>[
                          _buildFeatureCard(
                            icon: Icons.report_problem_outlined,
                            title: 'Buat Laporan',
                            subtitle: 'Laporkan masalah atau kebocoran air.',
                            iconColor: Colors.orangeAccent,
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/buat_laporan',
                                ),
                          ),
                          _buildFeatureCard(
                            icon: Icons.track_changes_outlined,
                            title: 'Lacak Laporan',
                            subtitle: 'Lihat status progres laporan Anda.',
                            iconColor: Colors.blueAccent,
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/lacak_laporan_saya',
                                ),
                          ),
                          _buildFeatureCard(
                            icon: Icons.receipt_long_outlined,
                            title: 'Info Tagihan',
                            subtitle: 'Cek tunggakan & kelola ID PDAM.',
                            iconColor: Colors.greenAccent,
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/cek_tunggakan',
                                ),
                          ),
                          _buildFeatureCard(
                            icon: Icons.chat_bubble_outline,
                            title: 'Hubungi Admin',
                            subtitle: 'Chat langsung atau via chatbot.',
                            iconColor: Colors.purpleAccent,
                            onTap:
                                () =>
                                    Navigator.pushNamed(context, '/chat_page'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.water_drop_outlined),
                          label: const Text("Lapor Temuan Kebocoran (Umum)"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
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
