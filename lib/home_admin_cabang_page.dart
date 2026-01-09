import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdam_app/api_service.dart';
// Import halaman lain nanti di sini (ChatPage, PengaduanPage, dll)

class HomeAdminCabangPage extends StatefulWidget {
  const HomeAdminCabangPage({super.key});

  @override
  State<HomeAdminCabangPage> createState() => _HomeAdminCabangPageState();
}

class _HomeAdminCabangPageState extends State<HomeAdminCabangPage> {
  final ApiService _apiService = ApiService();
  
  // Variable Data
  Map<String, dynamic>? _stats;
  String? _jabatan;
  String? _namaUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // 1. Ambil data jabatan lokal dulu untuk render kerangka
      final localJabatan = await _apiService.getJabatan();
      
      // 2. Ambil data real-time dari server
      final response = await _apiService.getAdminDashboardStats();
      
      if (mounted) {
        setState(() {
          _stats = response['data'];
          _namaUser = response['user_info']['nama'];
          _jabatan = response['user_info']['jabatan'] ?? localJabatan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Helper boolean untuk logika tampilan
    bool isDistribusi = _jabatan == 'supervisor_distribusi';
    bool isHublang = _jabatan == 'supervisor_hublang';
    bool isAdmin = _jabatan == 'admin_cabang'; // Super Admin Cabang

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dashboard Admin", style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(_jabatan?.replaceAll('_', ' ').toUpperCase() ?? "Loading...", 
              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          // Tombol Chat (Inbox)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
               // Nanti arahkan ke halaman Inbox Chat
               // Navigator.push(context, MaterialPageRoute(builder: (_) => AdminInboxPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sapaan
                  Text(
                    "Halo, $_namaUser 👋",
                    style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  ),
                  const SizedBox(height: 20),

                  // --- GRID STATISTIK (DAPAT DIKLIK) ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      // 1. KARTU PENGADUAN (Semua Role Punya)
                      _buildStatCard(
                        title: "Pengaduan Baru",
                        count: _stats?['pengaduan_baru'] ?? 0,
                        icon: Icons.assignment_late,
                        color: Colors.red,
                        onTap: () {
                          // Navigasi ke List Pengaduan
                        },
                      ),

                      // 2. KARTU KEBOCORAN (Distribusi & Admin)
                      if (!isHublang)
                        _buildStatCard(
                          title: "Temuan Kebocoran",
                          count: _stats?['kebocoran_baru'] ?? 0,
                          icon: Icons.water_damage,
                          color: Colors.orange,
                          onTap: () {
                            // Navigasi ke List Kebocoran
                          },
                        ),

                      // 3. KARTU WATER METER (Hublang & Admin)
                      if (!isDistribusi)
                        _buildStatCard(
                          title: "Verifikasi Meter",
                          count: _stats?['verifikasi_wm'] ?? 0,
                          icon: Icons.camera_alt,
                          color: Colors.blue,
                          onTap: () {
                             // Navigasi ke Verifikasi WM
                          },
                        ),
                      
                      // 4. KARTU CALON PELANGGAN (Hublang & Admin)
                      if (!isDistribusi)
                        _buildStatCard(
                          title: "Calon Pelanggan",
                          count: _stats?['calon_pelanggan'] ?? 0,
                          icon: Icons.person_add,
                          color: Colors.green,
                          onTap: () {
                             // Navigasi ke Verifikasi Pelanggan
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStatCard({
    required String title, 
    required int count, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}