// lib/pages/home_petugas_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:pdam_app/pages/detail_tugas_page.dart';
import 'package:pdam_app/pages/edit_profile_page.dart';
import 'package:pdam_app/models/petugas_model.dart';
import 'package:animate_do/animate_do.dart'; // Import package animasi

// ===============================================================
// == HALAMAN UTAMA (FRAME) UNTUK PETUGAS ==
// ===============================================================
class HomePetugasPage extends StatefulWidget {
  final int idPetugasLoggedIn;
  const HomePetugasPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<HomePetugasPage> createState() => _HomePetugasPageState();
}

class _HomePetugasPageState extends State<HomePetugasPage> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      AssignmentsPage(idPetugasLoggedIn: widget.idPetugasLoggedIn),
      const SelfReportPage(),
      const HistoryPage(),
      const ProfilePage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Daftar Tugas';
      case 1:
        return 'Lapor Mandiri';
      case 2:
        return 'Riwayat Pekerjaan';
      case 3:
        return 'Profil Petugas';
      default:
        return 'Dashboard Petugas';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(_selectedIndex),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        elevation: 1.0,
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: _buildModernNavBar(),
    );
  }

  // --- WIDGET BARU: Bottom Navigation Bar dengan Desain Modern ---
  Widget _buildModernNavBar() {
    return Container(
      margin: const EdgeInsets.all(12).copyWith(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Icon(Ionicons.list_circle_outline),
                activeIcon: Icon(Ionicons.list_circle),
                label: 'Tugas'),
            BottomNavigationBarItem(
                icon: Icon(Ionicons.create_outline),
                activeIcon: Icon(Ionicons.create),
                label: 'Lapor'),
            BottomNavigationBarItem(
                icon: Icon(Ionicons.time_outline),
                activeIcon: Icon(Ionicons.time),
                label: 'Riwayat'),
            BottomNavigationBarItem(
                icon: Icon(Ionicons.person_circle_outline),
                activeIcon: Icon(Ionicons.person_circle),
                label: 'Profil'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF0D47A1),
          unselectedItemColor: Colors.grey[500],
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
        ),
      ),
    );
  }
}

// ===============================================================
// == HALAMAN DAFTAR TUGAS (TAB 1) ==
// ===============================================================
class AssignmentsPage extends StatefulWidget {
  final int idPetugasLoggedIn;
  const AssignmentsPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  late Future<List<Tugas>> _tugasFuture;
  final ApiService _apiService = ApiService();
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadTugas();
  }

  void _loadTugas() {
    setState(() {
      _tugasFuture = _apiService.getPetugasSemuaTugas(widget.idPetugasLoggedIn);
    });
  }

  IconData _getIconForTugas(Tugas tugas) {
    if (tugas is PengaduanTugas) return Ionicons.document_text_outline;
    if (tugas is TemuanTugas) return Ionicons.warning_outline;
    return Ionicons.help_circle_outline;
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'selesai': return Colors.green.shade700;
      case 'dibatalkan': return Colors.red.shade700;
      case 'diproses': return Colors.blue.shade800;
      case 'dalam_perjalanan': return Colors.purple.shade700;
      default: return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _loadTugas(),
      child: FutureBuilder<List<Tugas>>(
        future: _tugasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorUI('Gagal memuat data tugas.');
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildErrorUI('Belum ada tugas untuk Anda saat ini.', icon: Ionicons.file_tray_stacked_outline);
          }

          List<Tugas> daftarTugas = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: daftarTugas.length,
            itemBuilder: (context, index) {
              final tugas = daftarTugas[index];
              return FadeInUp(
                from: 20,
                delay: Duration(milliseconds: 100 * index),
                child: _buildTugasCard(tugas),
              );
            },
          );
        },
      ),
    );
  }

  // --- WIDGET BARU: Kartu Tugas dengan Desain Modern ---
  Widget _buildTugasCard(Tugas tugas) {
    KontakInfo? kontak = tugas.infoKontakPelapor;
    String formattedDate = tugas.tanggalTugas;
    try {
      if (tugas.tanggalTugas.isNotEmpty) {
        formattedDate = _dateFormatter.format(DateTime.parse(tugas.tanggalTugas));
      }
    } catch (e) { /* Biarkan tanggal asli */ }

    Color statusColor = _getColorForStatus(tugas.status);

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DetailTugasPage(tugas: tugas)),
          ).then((_) => _loadTugas());
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(_getIconForTugas(tugas), color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tugas.kategoriDisplay,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: statusColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tugas.isPetugasPelapor)
                    const Icon(Ionicons.megaphone, color: Colors.amber, size: 20),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tugas.deskripsiLokasi,
                    style: GoogleFonts.lato(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (kontak?.nama != null && kontak!.nama!.isNotEmpty)
                    _buildInfoRow(Ionicons.person_outline, '${kontak.nama} (${kontak.nomorHp ?? 'No HP'})'),
                  _buildInfoRow(Ionicons.calendar_outline, 'Tgl Tugas: $formattedDate'),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tugas.friendlyStatus.toUpperCase(),
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                      Row(
                        children: [
                          Text('Lihat Detail', style: GoogleFonts.poppins(fontSize: 13, color: Colors.blue[800], fontWeight: FontWeight.w500)),
                          const SizedBox(width: 4),
                          Icon(Ionicons.arrow_forward, size: 16, color: Colors.blue[800]),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
  
  Widget _buildErrorUI(String message, {IconData icon = Ionicons.cloud_offline_outline}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 17, color: Colors.grey[700])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              onPressed: _loadTugas,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.blue[800],
                backgroundColor: Colors.blue[50],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================================================
// == HALAMAN PROFIL (TAB 4) ==
// ===============================================================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService();
  Future<Petugas>? _petugasFuture;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    setState(() {
      _petugasFuture = _apiService.getPetugasProfile();
    });
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: () async => _loadProfileData(),
        child: FutureBuilder<Petugas>(
          future: _petugasFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _buildErrorUI('Gagal memuat profil.');
            }
            
            final petugas = snapshot.data!;
            return CustomScrollView(
              slivers: [
                _buildProfileHeader(petugas),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 100),
                          child: _buildProfileInfoCard(petugas),
                        ),
                        const SizedBox(height: 24),
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 200),
                          child: _buildActionButtons(petugas),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET BARU: Header Halaman Profil ---
  Widget _buildProfileHeader(Petugas petugas) {
    return SliverAppBar(
      expandedHeight: 240.0,
      pinned: true,
      backgroundColor: const Color(0xFF0D47A1),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Ionicons.person, size: 60, color: Colors.blue[800]),
                ),
              ),
              const SizedBox(height: 12),
              FadeInUp(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  petugas.nama,
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  petugas.email,
                  style: GoogleFonts.lato(fontSize: 15, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // --- WIDGET BARU: Kartu Informasi Profil ---
  Widget _buildProfileInfoCard(Petugas petugas) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileInfoTile(Ionicons.call_outline, 'Nomor HP', petugas.nomorHp),
            const Divider(),
            _buildProfileInfoTile(Ionicons.business_outline, 'Cabang', petugas.cabang?.namaCabang ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoTile(IconData icon, String title, String? subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[800]),
      title: Text(title, style: GoogleFonts.poppins(color: Colors.grey[600])),
      subtitle: Text(subtitle ?? 'Tidak ada data', style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600)),
    );
  }

  // --- WIDGET BARU: Tombol Aksi ---
  Widget _buildActionButtons(Petugas petugas) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Ionicons.create_outline, size: 20),
            label: const Text('Edit Profil'),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => EditProfilePage(currentPetugas: petugas)),
              );
              if (result == true && mounted) {
                _loadProfileData();
                _showSnackbar('Profil berhasil diperbarui!', isError: false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Ionicons.log_out_outline),
            label: const Text('Logout'),
            onPressed: () async {
              await _apiService.logout();
              if (mounted) {
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              side: BorderSide(color: Colors.red[700]!),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildErrorUI(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Ionicons.cloud_offline_outline, size: 60, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text('Gagal memuat profil', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700]), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh_outline),
              label: const Text('Coba Lagi'),
              onPressed: _loadProfileData,
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================================================
// == HALAMAN PLACEHOLDER (TAB 2 & 3) ==
// ===============================================================
class SelfReportPage extends StatelessWidget {
  const SelfReportPage({super.key});
  @override
  Widget build(BuildContext context) {
    return _buildComingSoonPage('Lapor Mandiri', Ionicons.create_outline);
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return _buildComingSoonPage('Riwayat Pekerjaan', Ionicons.time_outline);
  }
}

Widget _buildComingSoonPage(String title, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeIn(
          delay: const Duration(milliseconds: 200),
          child: Icon(icon, size: 80, color: Colors.grey[300]),
        ),
        const SizedBox(height: 20),
        FadeInUp(
          from: 20,
          delay: const Duration(milliseconds: 300),
          child: Text(
            title,
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
        ),
        const SizedBox(height: 8),
        FadeInUp(
          from: 20,
          delay: const Duration(milliseconds: 400),
          child: Text(
            'Fitur ini sedang dalam pengembangan.',
            style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[500]),
          ),
        ),
      ],
    ),
  );
}
