// lib/pages/home_petugas_page.dart

import 'dart:async'; // Ditambahkan untuk Future.value
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:pdam_app/pages/detail_tugas_page.dart';
import 'package:pdam_app/pages/edit_profile_page.dart';
import 'package:pdam_app/models/petugas_model.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pdam_app/pages/detail_calon_pelanggan_page.dart';
import 'package:pdam_app/models/paginated_response.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <-- DITAMBAHKAN

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
    // Inisialisasi daftar halaman/widget untuk BottomNavigationBar
    _widgetOptions = <Widget>[
      AssignmentsPage(idPetugasLoggedIn: widget.idPetugasLoggedIn),
      const KinerjaPage(),
      HistoryPage(idPetugasLoggedIn: widget.idPetugasLoggedIn),
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
        return 'Kinerja Petugas';
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

  // Widget untuk membuat BottomNavigationBar yang modern
  Widget _buildModernNavBar() {
    return Container(
      margin: const EdgeInsets.all(12).copyWith(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              26,
            ), // Perbaikan: .withOpacity deprecated
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
              label: 'Tugas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Ionicons.stats_chart_outline),
              activeIcon: Icon(Ionicons.stats_chart),
              label: 'Kinerja',
            ),
            BottomNavigationBarItem(
              icon: Icon(Ionicons.time_outline),
              activeIcon: Icon(Ionicons.time),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Ionicons.person_circle_outline),
              activeIcon: Icon(Ionicons.person_circle),
              label: 'Profil',
            ),
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

  // Helper Methods (didefinisikan di dalam State Class)
  IconData _getIconForTugas(Tugas tugas) {
    if (tugas is PengaduanTugas) return Ionicons.document_text_outline;
    if (tugas is TemuanTugas) return Ionicons.warning_outline;
    if (tugas is CalonPelangganTugas) {
      if (tugas.jenisTugasInternal.toLowerCase().contains('survey')) {
        return Ionicons.map_outline;
      }
      return Ionicons.build_outline;
    }
    return Ionicons.help_circle_outline;
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
      case 'terpasang':
      case 'survey selesai':
        return Colors.green.shade700;
      case 'dibatalkan':
        return Colors.red.shade700;
      case 'diproses':
      case 'pemasangan':
      case 'survey':
        return Colors.blue.shade800;
      case 'dalam_perjalanan':
        return Colors.purple.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTugasCard(Tugas tugas) {
    KontakInfo? kontak = tugas.infoKontakPelapor;
    String formattedDate = tugas.tanggalTugas;
    try {
      if (tugas.tanggalTugas.isNotEmpty) {
        formattedDate = _dateFormatter.format(
          DateTime.parse(tugas.tanggalTugas),
        );
      }
    } catch (e) {
      /* Biarkan tanggal asli */
    }

    Color statusColor = _getColorForStatus(tugas.status);

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withAlpha(26), // Perbaikan
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Logika Navigasi yang diperbarui
          if (tugas is CalonPelangganTugas) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailCalonPelangganPage(tugas: tugas),
              ),
            ).then((_) => _loadTugas());
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailTugasPage(tugas: tugas),
              ),
            ).then((_) => _loadTugas());
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26), // Perbaikan
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
                        color: statusColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tugas.isPetugasPelapor)
                    const Icon(
                      Ionicons.megaphone,
                      color: Colors.amber,
                      size: 20,
                    ),
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
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (kontak?.nama != null && kontak!.nama.isNotEmpty)
                    _buildInfoRow(
                      Ionicons.person_outline,
                      '${kontak.nama} (${kontak.nomorHp})',
                    ),
                  _buildInfoRow(
                    Ionicons.calendar_outline,
                    'Tgl Tugas: $formattedDate',
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tugas.friendlyStatus.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'Lihat Detail',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Ionicons.arrow_forward,
                            size: 16,
                            color: Colors.blue[800],
                          ),
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

  Widget _buildErrorUI(
    String message, {
    IconData icon = Ionicons.cloud_offline_outline,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 17, color: Colors.grey[700]),
            ),
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
            return _buildErrorUI(
              'Belum ada tugas untuk Anda saat ini.',
              icon: Ionicons.file_tray_stacked_outline,
            );
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
}

// ===============================================================
// == HALAMAN RIWAYAT (TAB 3) ==
// ===============================================================
class HistoryPage extends StatefulWidget {
  final int idPetugasLoggedIn;
  const HistoryPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ApiService _apiService = ApiService();
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  final ScrollController _scrollController = ScrollController();

  final List<Tugas> _riwayatList = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchRiwayat();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchRiwayat() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      // Panggil method API yang sudah diperbarui
      final response = await _apiService.getRiwayatPetugas(
        widget.idPetugasLoggedIn,
        _currentPage,
      );

      if (!mounted) return;

      setState(() {
        // Gunakan data dari respons baru
        _riwayatList.addAll(response.tugasList);
        _hasMore =
            response.hasMorePages; // <- Penentu utama untuk berhenti loading

        // Hanya tambah halaman jika masih ada data berikutnya
        if (_hasMore) {
          _currentPage++;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat riwayat: ${e.toString().replaceAll("Exception: ", "")}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isLoading = false;
      _hasMore = true;
      _currentPage = 1;
      _riwayatList.clear();
    });
    await _fetchRiwayat();
  }

  // Helper Methods (didefinisikan di dalam State Class)
  IconData _getIconForTugas(Tugas tugas) {
    if (tugas is PengaduanTugas) return Ionicons.document_text_outline;
    if (tugas is TemuanTugas) return Ionicons.warning_outline;
    if (tugas is CalonPelangganTugas) {
      if (tugas.jenisTugasInternal.toLowerCase().contains('survey')) {
        return Ionicons.map_outline;
      }
      return Ionicons.build_outline;
    }
    return Ionicons.help_circle_outline;
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
      case 'terpasang':
      case 'survey selesai':
        return Colors.green.shade700;
      case 'dibatalkan':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTugasCard(Tugas tugas) {
    KontakInfo? kontak = tugas.infoKontakPelapor;
    String formattedDate = tugas.tanggalTugas;
    try {
      if (tugas.tanggalTugas.isNotEmpty) {
        formattedDate = _dateFormatter.format(
          DateTime.parse(tugas.tanggalTugas),
        );
      }
    } catch (e) {
      /* Biarkan tanggal asli */
    }

    Color statusColor = _getColorForStatus(tugas.status);

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withAlpha(26), // Perbaikan
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (tugas is CalonPelangganTugas) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailCalonPelangganPage(tugas: tugas),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailTugasPage(tugas: tugas),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26), // Perbaikan
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
                        color: statusColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (kontak?.nama != null && kontak!.nama.isNotEmpty)
                    _buildInfoRow(
                      Ionicons.person_outline,
                      '${kontak.nama} (${kontak.nomorHp})',
                    ),
                  _buildInfoRow(
                    Ionicons.calendar_outline,
                    'Tgl Selesai: $formattedDate',
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tugas.friendlyStatus.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'Lihat Detail',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Ionicons.arrow_forward,
                            size: 16,
                            color: Colors.blue[800],
                          ),
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

  Widget _buildErrorUI(
    String message, {
    IconData icon = Ionicons.cloud_offline_outline,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 17, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              onPressed: _onRefresh,
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child:
          (_riwayatList.isEmpty && _isLoading)
              ? const Center(child: CircularProgressIndicator())
              : (_riwayatList.isEmpty && !_hasMore)
              ? _buildErrorUI(
                'Riwayat pekerjaan Anda masih kosong.',
                icon: Ionicons.archive_outline,
              )
              : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _riwayatList.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _riwayatList.length) {
                    final tugas = _riwayatList[index];
                    return FadeInUp(
                      from: 20,
                      delay: const Duration(milliseconds: 50),
                      child: _buildTugasCard(tugas),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child:
                            _hasMore
                                ? const CircularProgressIndicator()
                                : Text(
                                  '-- Anda telah mencapai akhir riwayat --',
                                  style: GoogleFonts.lato(
                                    color: Colors.grey[500],
                                  ),
                                ),
                      ),
                    );
                  }
                },
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

  Widget _buildProfileHeader(Petugas petugas) {
    final String? profilePhotoPath = petugas.fotoProfil;
    final String fullImageUrl = profilePhotoPath != null && profilePhotoPath.isNotEmpty
        ? '${_apiService.rootBaseUrl}/storage/$profilePhotoPath'
        : '';
        
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
                  backgroundImage: fullImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(fullImageUrl)
                      : null,
                  child: fullImageUrl.isEmpty
                      ? Icon(Ionicons.person, size: 60, color: Colors.blue[800])
                      : null,
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
  
  Widget _buildActionButtons(Petugas petugas) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Ionicons.create_outline, size: 20),
            label: const Text('Edit Profil'),
            onPressed: () async {
              final result = await Navigator.push<Petugas>(
                context,
                MaterialPageRoute(builder: (context) => EditProfilePage(currentPetugas: petugas)),
              );
              if (result != null && mounted) {
                setState(() {
                  _petugasFuture = Future.value(result);
                });
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
                Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
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
              return Text("Gagal memuat profil. Error: ${snapshot.error}");
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
                        // ... Card Info ...
                        const SizedBox(height: 24),
                        _buildActionButtons(petugas),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ===============================================================
// == HALAMAN KINERJA (TAB 2) - PLACEHOLDER ==
// ===============================================================
class KinerjaPage extends StatelessWidget {
  const KinerjaPage({super.key});
  @override
  Widget build(BuildContext context) {
    return _buildComingSoonPage(
      'Kinerja Petugas',
      Ionicons.stats_chart_outline,
    );
  }
}

// Widget helper untuk halaman "Coming Soon"
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
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
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