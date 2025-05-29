// lib/pages/home_petugas_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart'; // Untuk Ionicons
import 'package:intl/intl.dart'; // Untuk format tanggal

// Import model dan service Anda
import 'package:pdam_app/models/tugas_model.dart'; // Pastikan path ini benar
import 'package:pdam_app/api_service.dart';

// Halaman Daftar Tugas (Sebelumnya AssignmentsPage)
class AssignmentsPage extends StatefulWidget {
  final int idPetugasLoggedIn;

  const AssignmentsPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  late Future<List<Tugas>> _tugasFuture;
  final ApiService _apiService = ApiService();
  // Format tanggal Indonesia, pastikan initializeDateFormatting('id_ID', null) sudah dipanggil di main.dart
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD), // Latar belakang seragam
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
                            // 'Detail: ${snapshot.error}', // Uncomment untuk debug detail error
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
                        return _buildTugasCard(tugas);
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

  Widget _buildTugasCard(Tugas tugas) {
    KontakInfo? kontak = tugas.infoKontakPelapor;
    String formattedDate = tugas.tanggalTugas;
    try {
      if (tugas.tanggalTugas.isNotEmpty) {
        DateTime parsedDate = DateTime.parse(tugas.tanggalTugas);
        formattedDate = _dateFormatter.format(parsedDate);
      }
    } catch (e) {
      // print("Error parsing tanggal_tugas di card: ${tugas.tanggalTugas} - $e");
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.withOpacity(0.15)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconForTugas(tugas),
                        color: Colors.blue[700],
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tugas.kategoriDisplay,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _getIconForStatus(tugas.status),
                  color: _getColorForStatus(tugas.status),
                  size: 24,
                ),
              ],
            ),
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
                  labelPadding: const EdgeInsets.only(left: 4.0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Lokasi: ${tugas.deskripsiLokasi}',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (kontak?.nama != null && kontak!.nama!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    Icon(
                      Ionicons.person_outline,
                      size: 14,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
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
                const SizedBox(width: 8),
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
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Navigasi ke halaman detail tugas
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Lihat Detail untuk ID Penugasan: ${tugas.idPenugasanInternal} (ID Tugas Asli: ${tugas.idTugas}, Tipe: ${tugas.tipeTugas})',
                      ),
                    ),
                  );
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
}

// -----------------------------------------------------------------------------
// PLACEHOLDER PAGES (Pastikan definisi ini ada di file atau diimpor dengan benar)
// -----------------------------------------------------------------------------

class SelfReportPage extends StatelessWidget {
  const SelfReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Ionicons.create_outline, size: 80, color: Colors.teal[300]),
            const SizedBox(height: 20),
            Text(
              'Laporkan Temuan Mandiri',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal[900],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Fitur ini akan datang.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Ionicons.time_outline, size: 80, color: Colors.purple[300]),
            const SizedBox(height: 20),
            Text(
              'Riwayat Kinerja Anda',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.purple[900],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Fitur riwayat pekerjaan akan segera hadir.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ApiService apiService = ApiService(); // Instance ApiService

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Ionicons.person_circle_outline,
              size: 80,
              color: Colors.blueGrey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Profil Petugas',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Informasi akun Anda akan ditampilkan di sini.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.log_out_outline),
              label: const Text('Logout'),
              onPressed: () async {
                // === PERBAIKAN DI SINI ===
                await apiService.removeToken(); // Menggunakan removeToken()

                if (context.mounted) {
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushReplacementNamed('/');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// KELAS UTAMA HOME PETUGAS PAGE
// -----------------------------------------------------------------------------
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
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(_selectedIndex),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 2,
        centerTitle: true,
      ),
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Ionicons.list_outline),
            activeIcon: Icon(Ionicons.list_sharp),
            label: 'Tugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.create_outline),
            activeIcon: Icon(Ionicons.create),
            label: 'Lapor Mandiri',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.time_outline),
            activeIcon: Icon(Ionicons.time),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.person_outline),
            activeIcon: Icon(Ionicons.person),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
