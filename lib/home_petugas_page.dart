// lib/pages/home_petugas_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart'; // Untuk Ionicons
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:pdam_app/pages/detail_tugas_page.dart';
import 'package:pdam_app/pages/edit_profile_page.dart';
import 'package:pdam_app/models/petugas_model.dart';

// Halaman Daftar Tugas (Sebelumnya AssignmentsPage)
// Catatan: Sisa dari kelas AssignmentsPage dan _AssignmentsPageState diasumsikan sama
// seperti versi sebelumnya, kecuali untuk metode _buildTugasCard di bawah ini.

class _AssignmentsPageState extends State<AssignmentsPage> {
  late Future<List<Tugas>> _tugasFuture;
  final ApiService _apiService = ApiService();
  final DateFormat _dateFormatter = DateFormat(
    'dd MMM yyyy',
    'id_ID',
  ); // Format tanggal Indonesia

  @override
  void initState() {
    super.initState();
    _loadTugas();
  }

  void _loadTugas() {
    // print('Memuat tugas untuk petugas ID: ${widget.idPetugasLoggedIn}'); // Untuk debug
    setState(() {
      _tugasFuture = _apiService.getPetugasSemuaTugas(widget.idPetugasLoggedIn);
    });
  }

  IconData _getIconForTugas(Tugas tugas) {
    if (tugas is PengaduanTugas) {
      return Ionicons.document_text_outline;
    } else if (tugas is TemuanTugas) {
      return Ionicons.warning_outline;
    }
    return Ionicons.help_circle_outline;
  }

  IconData _getIconForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'menunggu_konfirmasi':
        return Ionicons.hourglass_outline;
      case 'diterima':
        return Ionicons.documents_outline;
      case 'dalam_perjalanan':
        return Ionicons.paper_plane_outline;
      case 'diproses':
        return Ionicons.build_outline;
      case 'selesai':
        return Ionicons.checkmark_circle_outline;
      case 'dibatalkan':
        return Ionicons.close_circle_outline;
      default:
        return Ionicons.help_circle_outline;
    }
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'menunggu_konfirmasi':
        return Colors.orange;
      case 'diterima':
        return Colors.blue;
      case 'dalam_perjalanan':
        return Colors.lightBlue;
      case 'diproses':
        return Colors.green;
      case 'selesai':
        return Colors.teal;
      case 'dibatalkan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // --- METODE _buildTugasCard DENGAN PERBAIKAN ---
  Widget _buildTugasCard(Tugas tugas) {
    KontakInfo? kontak = tugas.infoKontakPelapor;
    String formattedDate = tugas.tanggalTugas; // Default jika parsing gagal
    try {
      // Asumsi API mengirim tanggal_tugas sebagai String "YYYY-MM-DD"
      if (tugas.tanggalTugas.isNotEmpty) {
        DateTime parsedDate = DateTime.parse(tugas.tanggalTugas);
        formattedDate = _dateFormatter.format(parsedDate);
      }
    } catch (e) {
      // print("Error parsing tanggal_tugas di card: ${tugas.tanggalTugas} - $e");
      // Biarkan formattedDate menggunakan nilai asli jika parsing gagal
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.blueGrey.withOpacity(0.15),
        ), // Sedikit border
      ),
      margin: const EdgeInsets.symmetric(
        vertical: 7,
        horizontal: 0,
      ), // horizontal: 0 karena parent Padding
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris untuk ikon kategori, nama kategori, dan ikon status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start, // Align ke atas jika teks kategori panjang
              children: [
                // Bagian kiri: Ikon tugas dan Kategori
                Expanded(
                  // Penting untuk membatasi lebar Row internal
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .center, // Icon dan teks align tengah vertikal
                    children: [
                      Icon(
                        _getIconForTugas(tugas),
                        color: Colors.blue[700],
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        // Agar teks kategori tidak menyebabkan overflow
                        child: Text(
                          tugas.kategoriDisplay,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                          overflow:
                              TextOverflow
                                  .ellipsis, // Jika terlalu panjang, tampilkan ...
                          maxLines: 2, // Maksimal 2 baris untuk kategori
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 8,
                ), // Jarak antara kategori dan ikon status
                // Bagian kanan: Ikon Status
                Icon(
                  _getIconForStatus(tugas.status),
                  color: _getColorForStatus(tugas.status),
                  size: 24,
                ),
              ],
            ),

            // Chip "Anda Pelapor Progres" (jika isPetugasPelapor true)
            if (tugas.isPetugasPelapor)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Chip(
                  avatar: Icon(
                    Ionicons.megaphone_outline,
                    size: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  label: Text(
                    'Anda Pelapor Progres',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: Colors.orange[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  labelPadding: const EdgeInsets.only(
                    left: 4.0,
                  ), // Mengurangi padding internal chip
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity:
                      VisualDensity.compact, // Membuat chip lebih kecil
                ),
              ),
            const SizedBox(height: 10),

            // Deskripsi Lokasi
            Text(
              'Lokasi: ${tugas.deskripsiLokasi}',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4), // Jarak kecil sebelum info pelapor
            // Informasi Pelapor (jika ada)
            if (kontak?.nama != null && kontak!.nama!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Ionicons.person_outline,
                      size: 14,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      // Agar teks pelapor tidak overflow
                      child: Text(
                        '${kontak.nama}${kontak.nomorHp != null && kontak.nomorHp!.isNotEmpty ? " (${kontak.nomorHp})" : ""}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // Baris untuk Status Teks dan Tanggal Tugas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  // Agar teks status tidak overflow
                  child: Text(
                    'Status: ${tugas.friendlyStatus}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _getColorForStatus(tugas.status),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8), // Jarak antara status dan tanggal
                Text(
                  'Tgl: $formattedDate',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tombol Lihat Detail
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailTugasPage(tugas: tugas),
                    ),
                  ).then((_) {
                    // Muat ulang daftar tugas setelah kembali dari halaman detail
                    // untuk merefleksikan perubahan status (jika ada).
                    _loadTugas();
                  });
                },
                icon: const Icon(
                  Ionicons.arrow_forward_circle_outline,
                  size: 20,
                ),
                label: Text(
                  'Lihat Detail',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Metode build dari _AssignmentsPageState tetap sama seperti sebelumnya
  // yang memanggil FutureBuilder dan ListView.builder
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Ionicons.list_outline, size: 40, color: Colors.blue[700]),
                const SizedBox(width: 10),
                Text(
                  'Daftar Tugas Anda',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Berikut adalah semua penugasan dan temuan yang perlu Anda tindaklanjuti.',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Tugas>>(
                future: _tugasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Ionicons.cloud_offline_outline,
                            color: Colors.red[600],
                            size: 50,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Gagal memuat data tugas.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.red[700],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Pastikan koneksi internet Anda stabil.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.red[700],
                              fontSize: 12,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            icon: const Icon(Ionicons.refresh_outline),
                            label: const Text('Coba Lagi'),
                            onPressed: _loadTugas,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[50],
                              foregroundColor: Colors.blueGrey[800],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Ionicons.file_tray_stacked_outline,
                            size: 60,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'Belum ada tugas untuk Anda saat ini.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  List<Tugas> daftarTugas = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: () async => _loadTugas(),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
                      itemCount: daftarTugas.length,
                      itemBuilder: (context, index) {
                        final tugas = daftarTugas[index];
                        return _buildTugasCard(
                          tugas,
                        ); // Memanggil metode yang diperbarui
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

  Widget _buildProfileInfoTile(IconData icon, String title, String? subtitle) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue[700], size: 26),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        subtitle: Text(
          subtitle ?? 'Tidak ada data',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey[100], // Sedikit beda latar untuk halaman profil
      body: RefreshIndicator(
        onRefresh: () async {
          _loadProfileData();
        },
        child: FutureBuilder<Petugas>(
          future: _petugasFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Ionicons.cloud_offline_outline,
                        size: 60,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Gagal memuat profil',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
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
            if (!snapshot.hasData) {
              return Center(
                child: Text(
                  'Tidak ada data profil.',
                  style: GoogleFonts.poppins(),
                ),
              );
            }

            final petugas = snapshot.data!;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.blue[700],
                          child: Icon(
                            Ionicons.person_outline,
                            size: 70,
                            color: Colors.white,
                          ),
                          // TODO: Ganti dengan Image.network jika sudah ada foto profil
                          // backgroundImage: petugas.fotoProfilUrl != null
                          //     ? NetworkImage(petugas.fotoProfilUrl!)
                          //     : null,
                        ),
                        // Positioned( // Untuk tombol edit foto profil nanti
                        //   bottom: 0,
                        //   right: 0,
                        //   child: CircleAvatar(
                        //     radius: 20,
                        //     backgroundColor: Colors.white,
                        //     child: IconButton(
                        //       icon: Icon(Ionicons.camera_outline, size: 20, color: Colors.blue[700]),
                        //       onPressed: () { /* TODO: Edit foto profil */ },
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      petugas.nama,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      petugas.email,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProfileInfoTile(
                    Ionicons.call_outline,
                    'Nomor HP',
                    petugas.nomorHp,
                  ),
                  _buildProfileInfoTile(
                    Ionicons.business_outline,
                    'Cabang',
                    petugas.cabang?.namaCabang ?? 'N/A',
                  ),

                  // Tambahkan info lain jika perlu
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: const Icon(Ionicons.create_outline, size: 20),
                    label: Text(
                      'Edit Profil',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final result = await Navigator.push<Petugas>(
                        // Tunggu hasil dari EditProfilePage
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  EditProfilePage(currentPetugas: petugas),
                        ),
                      );
                      if (result != null && mounted) {
                        // Jika ada data yang dikembalikan (profil diupdate), refresh data
                        _loadProfileData();
                        _showSnackbar(
                          'Profil berhasil diperbarui dari halaman edit!',
                          isError: false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Ionicons.log_out_outline),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await _apiService.removeToken();
                      if (mounted) {
                        Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Definisi kelas AssignmentsPage, HomePetugasPage, _HomePetugasPageState,
// SelfReportPage, HistoryPage, dan ProfilePage diasumsikan ada
// di file ini atau diimpor dengan benar, sesuai dengan versi sebelumnya.
// Saya hanya fokus pada _AssignmentsPageState dan _buildTugasCard sesuai permintaan.

// Contoh kerangka AssignmentsPage (jika belum ada):
class AssignmentsPage extends StatefulWidget {
  final int idPetugasLoggedIn;
  const AssignmentsPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

// Placeholder Pages (jika belum ada di file ini)
class SelfReportPage extends StatelessWidget {
  const SelfReportPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Halaman Lapor Mandiri'));
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Halaman Riwayat Pekerjaan'));
  }
}

// Kelas Utama HomePetugasPage (jika belum ada di file ini)
class HomePetugasPage extends StatefulWidget {
  final int idPetugasLoggedIn;
  const HomePetugasPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<HomePetugasPage> createState() => _HomePetugasPageState();
}

class _HomePetugasPageState extends State<HomePetugasPage> {
  int _selectedIndex = 0;
  late List<Widget> _widgetOptions;

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
      appBar: AppBar(title: Text(_getAppBarTitle(_selectedIndex))),
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Ionicons.list_outline),
            label: 'Tugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.create_outline),
            label: 'Lapor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.time_outline),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.person_outline),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
