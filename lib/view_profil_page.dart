// lib/view_profil_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/profil_page.dart';
import 'package:animate_do/animate_do.dart'; // **IMPORT UNTUK ANIMASI**
import 'package:cached_network_image/cached_network_image.dart'; // Import untuk gambar

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
      if(mounted){
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
      // Panggil _fetchUserData lagi untuk refresh halaman ini
      _fetchUserData();
      
      // Kirim sinyal 'true' juga ke halaman home
      // agar header di sana ikut refresh saat halaman ini ditutup.
      Navigator.of(context).pop(true);
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
              : CustomScrollView( // Menggunakan CustomScrollView untuk efek Sliver
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(child: const SizedBox(height: 16)),
                    _buildAnimatedInfoList(),
                  ],
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
            // Gradient Background
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
            // Foto Profil dengan Animasi
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
                    const SizedBox(height: 40), // Spacer untuk title
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
          // Setiap item dibungkus dengan widget animasi
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
          // Tombol Edit dengan Animasi
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
        ],
      ),
    );
  }
  
  // Desain baru untuk setiap item info
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