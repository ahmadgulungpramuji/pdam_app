// lib/view_profil_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/profil_page.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ==========================================================
// == 1. PASTIKAN ANDA MENGIMPOR HALAMAN LOGIN ANDA DI SINI ==
// ==========================================================
import 'package:pdam_app/login_page.dart'; // Ganti jika nama file Anda berbeda

class ViewProfilPage extends StatefulWidget {
  const ViewProfilPage({super.key});

  @override
  State<ViewProfilPage> createState() => _ViewProfilPageState();
}

class _ViewProfilPageState extends State<ViewProfilPage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.getUserProfile();
      if (mounted) {
        if (data != null) {
          setState(() {
            _userData = data;
          });
        } else {
          setState(() {
            _errorMessage = 'Gagal memuat data profil. Sesi mungkin berakhir.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilPage()),
    );
    
    if (result == true && mounted) {
      _fetchUserData();
    }
  }

  Future<void> _logout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ya, Keluar'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _apiService.logout();
        
        // ==================================================================
        // == 2. UBAH BAGIAN INI UNTUK MENGARAH KE HALAMAN LOGIN ANDA ==
        // ==================================================================
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );

      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghubungi server, token lokal dihapus. Error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : CustomScrollView(
                  slivers: [
                    _buildStylishSliverAppBar(),
                    SliverToBoxAdapter(child: const SizedBox(height: 20)),
                    _buildUserInfoSection(),
                    _buildActionsSection(),
                  ],
                ),
    );
  }

  SliverAppBar _buildStylishSliverAppBar() {
    final String? profilePhotoPath = _userData?['foto_profil'];
    final fullImageUrl = (profilePhotoPath != null && profilePhotoPath.isNotEmpty)
        ? '${_apiService.rootBaseUrl}/storage/$profilePhotoPath'
        : '';
    final userName = _userData?['nama']?.toString() ?? 'Nama Pengguna';
    final userEmail = _userData?['email'] ?? 'email@example.com';

    return SliverAppBar(
      expandedHeight: 300.0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 0,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: ClipPath(
          clipper: AppBarClipper(),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.7)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Efek Blur di Latar Belakang
                if(fullImageUrl.isNotEmpty)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: CachedNetworkImage(
                    imageUrl: fullImageUrl,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.3),
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
                // Konten Profil
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white.withOpacity(0.8),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white,
                          backgroundImage: fullImageUrl.isNotEmpty
                              ? CachedNetworkImageProvider(fullImageUrl)
                              : null,
                          child: fullImageUrl.isEmpty
                              ? Icon(Ionicons.person, size: 50, color: Colors.grey.shade400)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        userName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                       const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return SliverToBoxAdapter(
      child: FadeInUp(
        duration: const Duration(milliseconds: 500),
        delay: const Duration(milliseconds: 100),
        child: _buildInfoCard(
          title: 'INFORMASI AKUN',
          children: [
            _buildInfoRow(
              icon: Ionicons.call_outline,
              title: 'Nomor HP',
              subtitle: _userData?['nomor_hp'] ?? 'Belum diatur',
            ),
            const Divider(height: 1, indent: 50, endIndent: 16),
             _buildInfoRow(
              icon: Ionicons.mail_outline,
              title: 'Email',
              subtitle: _userData?['email'] ?? 'Belum diatur',
            ),
            const Divider(height: 1, indent: 50, endIndent: 16),
            _buildInfoRow(
              icon: Ionicons.location_outline,
              title: 'Cabang Terdaftar',
              subtitle: _userData?['cabang']?['nama_cabang'] ?? 'Tidak diketahui',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return SliverToBoxAdapter(
      child: FadeInUp(
        duration: const Duration(milliseconds: 500),
        delay: const Duration(milliseconds: 200),
        child: _buildInfoCard(
          title: 'PENGATURAN',
          children: [
            _buildActionRow(
              icon: Ionicons.create_outline,
              title: 'Edit Profil',
              onTap: _navigateToEdit,
              color: Theme.of(context).colorScheme.primary,
            ),
            const Divider(height: 1, indent: 50, endIndent: 16),
            _buildActionRow(
              icon: Ionicons.log_out_outline,
              title: 'Logout',
              onTap: _logout,
              color: Colors.red.shade700,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

   Widget _buildActionRow({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ),
              Icon(Ionicons.chevron_forward, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Ionicons.cloud_offline_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Terjadi kesalahan', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh),
              label: const Text('Coba Lagi'),
              onPressed: _fetchUserData,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Clipper untuk membuat bentuk kurva pada AppBar
class AppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}