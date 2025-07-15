// lib/view_profil_page.dart

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
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Tidak'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ya, Keluar'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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
          MaterialPageRoute(builder: (context) => const LoginPage()), // Diubah dari Placeholder
          (Route<dynamic> route) => false,
        );

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghubungi server, token lokal dihapus. Error: ${e.toString()}')),
        );
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
      appBar: _isLoading ? null : AppBar(
        leading: BackButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      backgroundColor: Colors.grey[100],
      body: WillPopScope(
        onWillPop: () async {
          Navigator.of(context).pop(true);
          return true;
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : CustomScrollView(
                    slivers: [
                      _buildSliverAppBar(),
                      SliverToBoxAdapter(child: const SizedBox(height: 16)),
                      _buildAnimatedInfoList(),
                    ],
                  ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    final String? profilePhotoPath = _userData?['foto_profil'];
    final fullImageUrl = (profilePhotoPath != null && profilePhotoPath.isNotEmpty)
        ? '${_apiService.rootBaseUrl}/storage/$profilePhotoPath'
        : '';
    final userName = _userData?['nama']?.toString() ?? 'Nama Pengguna';

    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 250.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          userName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    Theme.of(context).colorScheme.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: FadeInDown(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white24,
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: Colors.white,
                        backgroundImage: fullImageUrl.isNotEmpty
                            ? CachedNetworkImageProvider(fullImageUrl)
                            : null,
                        child: fullImageUrl.isEmpty
                            ? Icon(Ionicons.person, size: 50, color: Colors.grey.shade400)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userData?['email'] ?? 'email@example.com',
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedInfoList() {
    return SliverList(
      delegate: SliverChildListDelegate(
        [
          FadeInUp(
            from: 20,
            delay: const Duration(milliseconds: 300),
            child: _buildInfoTile(
              icon: Ionicons.call_outline,
              title: 'Nomor HP',
              subtitle: _userData?['nomor_hp'] ?? 'Belum diatur',
            ),
          ),
          FadeInUp(
            from: 20,
            delay: const Duration(milliseconds: 400),
            child: _buildInfoTile(
              icon: Ionicons.mail_outline,
              title: 'Email',
              subtitle: _userData?['email'] ?? 'Belum diatur',
            ),
          ),
          FadeInUp(
            from: 20,
            delay: const Duration(milliseconds: 500),
            child: _buildInfoTile(
              icon: Ionicons.location_outline,
              title: 'Cabang Terdaftar',
              subtitle: _userData?['cabang']?['nama_cabang'] ?? 'Tidak diketahui',
            ),
          ),
          const SizedBox(height: 32),
          FadeInUp(
            from: 20,
            delay: const Duration(milliseconds: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Ionicons.create_outline, size: 18),
                label: const Text('Edit Profil'),
                onPressed: _navigateToEdit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            from: 20,
            delay: const Duration(milliseconds: 700),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: const Icon(Ionicons.log_out_outline, size: 18),
                label: const Text('Logout'),
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 4),
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