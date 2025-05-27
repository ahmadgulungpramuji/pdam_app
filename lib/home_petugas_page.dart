import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/api_service.dart';

// --- IMPORTANT: ASSUMED IMPORTS ---
// Make sure these files exist and paths are correct based on your project structure
import 'package:pdam_app/models/pengaduan_model.dart'; // Created in the previous step
// --- END OF ASSUMED IMPORTS ---

// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// MODIFIED AssignmentsPage: Now fetches and displays real data
// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
class AssignmentsPage extends StatefulWidget {
  final int idPetugasLoggedIn;

  const AssignmentsPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  late Future<List<Pengaduan>> _assignmentsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  void _loadAssignments() {
    setState(() {
      _assignmentsFuture = _apiService.getPetugasAssignments(
        widget.idPetugasLoggedIn,
      );
    });
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
    // Using a Scaffold here to provide a consistent background if needed,
    // or remove it if the parent Scaffold's background is preferred.
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD), // Match parent background
      body: Padding(
        // Added Padding to match original structure
        padding: const EdgeInsets.all(24.0), // Applied general padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Ionicons.clipboard_outline, size: 60, color: Colors.blue[300]),
            const SizedBox(height: 15),
            Text(
              'Daftar Penugasan Anda',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Di sini Anda akan melihat penugasan yang diberikan oleh admin cabang.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Pengaduan>>(
                future: _assignmentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Ionicons.alert_circle_outline,
                            color: Colors.red,
                            size: 50,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Gagal memuat data: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.red[700]),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Ionicons.refresh_outline),
                            label: const Text('Coba Lagi'),
                            onPressed: _loadAssignments,
                            style: ElevatedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).primaryColorDark,
                              // backgroundColor: Colors.white
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
                            Ionicons.file_tray_outline,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'Belum ada penugasan untuk Anda saat ini.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  List<Pengaduan> assignments = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: () async {
                      _loadAssignments();
                    },
                    child: ListView.builder(
                      // Removed shrinkWrap and primary: false to let Expanded handle scrolling
                      itemCount: assignments.length,
                      itemBuilder: (context, index) {
                        final assignment = assignments[index];
                        return _buildAssignmentCard(assignment);
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

  Widget _buildAssignmentCard(Pengaduan assignment) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 0,
      ), // horizontal: 0 because parent Padding handles it
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    assignment.friendlyKategori,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _getIconForStatus(assignment.status),
                  color: _getColorForStatus(assignment.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lokasi: ${assignment.deskripsiLokasi}',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[800]),
            ),
            const SizedBox(height: 4),
            Text(
              'Deskripsi: ${assignment.deskripsi}',
              style: GoogleFonts.poppins(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Tanggal: ${assignment.tanggalPengaduan}', // Consider formatting this date
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Status: ',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  assignment.friendlyStatus,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _getColorForStatus(assignment.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Handle view details navigation
                  // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => AssignmentDetailPage(assignmentId: assignment.id)));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lihat Detail untuk ID: ${assignment.id}'),
                    ),
                  );
                },
                icon: const Icon(Ionicons.eye_outline, size: 18),
                label: Text(
                  'Lihat Detail',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
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
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// END OF MODIFIED AssignmentsPage
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

// Placeholder pages for bottom navigation (SelfReport, History, Profile remain unchanged)
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
              'Laporkan temuan baru seperti kebocoran, kerusakan fasilitas, atau masalah lainnya.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            // Placeholder for self-report form
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Jenis Laporan',
                        prefixIcon: Icon(
                          Ionicons.bookmark_outline,
                          color: Colors.teal[700],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Lokasi',
                        prefixIcon: Icon(
                          Ionicons.location_outline,
                          color: Colors.teal[700],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Deskripsi Detail',
                        prefixIcon: Icon(
                          Ionicons.document_text_outline,
                          color: Colors.teal[700],
                        ),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Handle report submission
                      },
                      icon: const Icon(Ionicons.send),
                      label: const Text('Kirim Laporan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            Icon(
              Ionicons.analytics_outline,
              size: 80,
              color: Colors.purple[300],
            ),
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
              'Lihat riwayat pengerjaan tugas dan statistik kinerja Anda di sini.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            // Placeholder for history details
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tugas Selesai: 25',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rata-rata Waktu Penyelesaian: 3 jam',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Terakhir Selesai:',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '- Perbaikan Saluran (20 Mei 2025)',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    Text(
                      '- Inspeksi Jaringan (18 Mei 2025)',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Ionicons.person_circle_outline,
              size: 80,
              color: Colors.blueGrey[300],
            ),
            const SizedBox(height: 20),
            Text(
              'Profil Petugas',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Kelola informasi profil Anda di sini.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            // Placeholder for profile details
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Icon(
                        Ionicons
                            .person_outline, // Changed to outline for consistency
                        color: Colors.blueGrey[700],
                      ),
                      title: Text(
                        'Nama: Petugas A', // TODO: Replace with actual data
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Ionicons.mail_outline,
                        color: Colors.blueGrey[700],
                      ), // Changed
                      title: Text(
                        'Email: petugas.a@pdam.com', // TODO: Replace with actual data
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Ionicons.call_outline,
                        color: Colors.blueGrey[700],
                      ), // Changed
                      title: Text(
                        'Telepon: +62 812 3456 7890', // TODO: Replace with actual data
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Handle edit profile
                      },
                      icon: const Icon(Ionicons.create_outline), // Changed
                      label: const Text('Edit Profil'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Handle logout properly (e.g., clear session, navigate to login)
                        // For now, just navigating to a conceptual login route
                        Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pushReplacementNamed(
                          '/',
                        ); // Assuming '/' is your login/splash page
                      },
                      icon: const Icon(Ionicons.log_out_outline), // Changed
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        side: BorderSide(color: Colors.red[700]!),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePetugasPage extends StatefulWidget {
  final int idPetugasLoggedIn; // Added: Requires logged-in petugas ID

  const HomePetugasPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<HomePetugasPage> createState() => _HomePetugasPageState();
}

class _HomePetugasPageState extends State<HomePetugasPage> {
  int _selectedIndex = 0;
  late List<Widget>
  _widgetOptions; // Made non-final and initialized in initState

  @override
  void initState() {
    super.initState();
    // Initialize _widgetOptions here, passing the idPetugasLoggedIn to AssignmentsPage
    _widgetOptions = <Widget>[
      AssignmentsPage(
        idPetugasLoggedIn: widget.idPetugasLoggedIn,
      ), // Pass the ID
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(_selectedIndex), // Dynamic AppBar Title
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 2, // Added a bit of elevation
        centerTitle: true,
      ),
      body: IndexedStack(
        // Using IndexedStack to preserve state of inactive tabs
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Ionicons.clipboard_outline),
            activeIcon: Icon(Ionicons.clipboard),
            label: 'Penugasan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.add_circle_outline),
            activeIcon: Icon(Ionicons.add_circle),
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
        unselectedItemColor: Colors.grey[600], // Slightly darker grey
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        backgroundColor: Colors.white, // Added background color for navbar
        elevation: 8, // Added elevation to navbar
      ),
    );
  }

  // Helper method to get AppBar title based on selected index
  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Penugasan Petugas';
      case 1:
        return 'Laporan Mandiri';
      case 2:
        return 'Riwayat Pekerjaan';
      case 3:
        return 'Profil Petugas';
      default:
        return 'Dashboard Petugas';
    }
  }
}
