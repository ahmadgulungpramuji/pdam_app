// lib/view_profil_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/profil_page.dart'; // Untuk navigasi ke halaman edit

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

  // Helper untuk mendapatkan URL gambar lengkap
  String _getFullImageUrl() {
    final String? profilePhotoPath = _userData?['foto_profil'];
    return (profilePhotoPath != null && profilePhotoPath.isNotEmpty)
        ? '${_apiService.rootBaseUrl}/storage/$profilePhotoPath'
        : '';
  }

  // Fungsi untuk navigasi ke halaman edit dan menunggu hasilnya
  void _navigateToEdit() async {
    // Navigasi ke ProfilPage dan tunggu hasilnya
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilPage()),
    );
    
    // Jika halaman edit mengembalikan 'true', muat ulang data di halaman ini
    if (result == true && mounted) {
      // Mengirimkan 'true' kembali ke halaman home agar header juga di-refresh
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        // **PERUBAHAN 1: Tombol edit di sini dihapus**
        // actions: [ ... ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _fetchUserData,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24), // beri padding bawah
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildInfoCard(),
                    ],
                  ),
                ),
      // **PERUBAHAN 2: Tombol ditambahkan di bawah sini**
      bottomNavigationBar: _userData != null && _errorMessage == null 
        ? _buildEditButton() 
        : null,
    );
  }

  Widget _buildHeader() {
    final fullImageUrl = _getFullImageUrl();

    return Container(
      color: Theme.of(context).colorScheme.primary,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 30),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            backgroundImage: fullImageUrl.isNotEmpty
                ? NetworkImage(fullImageUrl)
                : null,
            child: fullImageUrl.isEmpty
                ? Icon(Ionicons.person, size: 50, color: Colors.grey.shade400)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            _userData?['nama']?.toString() ?? 'Nama Pengguna',
            style: GoogleFonts.lato(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userData?['email'] ?? 'email@example.com',
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informasi Kontak',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              _buildInfoTile(
                icon: Ionicons.call_outline,
                title: 'Nomor HP',
                subtitle: _userData?['nomor_hp'] ?? 'Belum diatur',
              ),
              const SizedBox(height: 16),
              _buildInfoTile(
                icon: Ionicons.mail_outline,
                title: 'Email',
                subtitle: _userData?['email'] ?? 'Belum diatur',
              ),
              const SizedBox(height: 16),
               _buildInfoTile(
                icon: Ionicons.location_outline,
                title: 'Cabang Terdaftar',
                subtitle: _userData?['cabang']?['nama_cabang'] ?? 'Tidak diketahui',
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // **PERUBAHAN 3: Widget baru untuk membuat tombol di bawah**
  Widget _buildEditButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      // Memberi warna latar agar konsisten jika ada tema gelap/terang
      color: Theme.of(context).scaffoldBackgroundColor, 
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
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        )
      ],
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