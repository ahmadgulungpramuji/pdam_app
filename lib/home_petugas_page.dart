import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdam_app/login_page.dart';
import 'package:pdam_app/pages/petugas_chat_home_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdam_app/models/kinerja_model.dart';
import 'package:pdam_app/services/notification_service.dart';
import 'package:pdam_app/services/chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePetugasPage extends StatefulWidget {
  final int idPetugasLoggedIn;
  const HomePetugasPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<HomePetugasPage> createState() => _HomePetugasPageState();
}

class _HomePetugasPageState extends State<HomePetugasPage> {
  DateTime? _lastPressed;
  int _selectedIndex = 0;

  // HAPUS variabel _widgetOptions yang lama (Kita ganti dengan method _buildBody)
  // late final List<Widget> _widgetOptions;

  StreamSubscription? _newTaskSubscription;
  final GlobalKey<_AssignmentsPageState> _assignmentsPageKey = GlobalKey();

  final ChatService _chatService = ChatService();
  Map<String, dynamic>? _currentUserData;
  Stream<int>? _badgeStream;

  // [TAMBAHAN BARU 1] Variable untuk menyimpan daftar Thread ID dimana saya adalah KETUA
  List<String> _myLeaderThreadIds = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _setupDataAndBadge(); // Gabungan load badge & whitelist

    // Event listener notifikasi
    _newTaskSubscription =
        NotificationService().onNotificationTap.listen((payload) {
      if (mounted && payload['tipe_notifikasi'] == 'penugasan_baru') {
        _onItemTapped(0);
        _assignmentsPageKey.currentState?.refreshTugas();
        _setupDataAndBadge();
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_data');
    if (jsonString != null && mounted) {
      setState(() {
        _currentUserData = jsonDecode(jsonString);
      });
    }
  }

  // [PERBAIKAN LOGIKA UTAMA]
  Future<void> _setupDataAndBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_data');
    if (jsonString == null) return;

    final userData = jsonDecode(jsonString);
    final String myUid = userData['firebase_uid'] ?? '';
    final int myIdPetugas = userData['id'];

    if (myUid.isEmpty) return;

    try {
      final ApiService apiService = ApiService();
      // Ambil semua tugas terbaru
      final List<Tugas> semuaTugas =
          await apiService.getPetugasSemuaTugas(myIdPetugas);

      // List untuk menampung ID Chat dimana user adalah KETUA
      List<String> leaderIds = [];

      for (var t in semuaTugas) {
        // Logika: User adalah Petugas Pelapor (Ketua) DAN tipe tugas Pengaduan
        if (t.isPetugasPelapor && t.tipeTugas == 'pengaduan') {
          // Format ID harus sama persis dengan di ChatService
          String threadId = '${t.tipeTugas}_${t.idTugas}';
          leaderIds.add(threadId);
        }
      }

      if (mounted) {
        setState(() {
          // 1. Simpan ke variable state agar bisa dikirim ke Halaman Chat
          _myLeaderThreadIds = leaderIds;

          // 2. Setup Badge Stream (Hanya hitung notif dari tugas Ketua)
          if (leaderIds.isEmpty) {
            _badgeStream = Stream.value(0);
          } else {
            _badgeStream = _chatService.getUnreadCountByPrefix(
              myUid,
              'pengaduan_',
              allowedThreadIds: leaderIds,
            );
          }
        });
      }
    } catch (e) {
      print("Error setup badge/whitelist: $e");
      if (mounted) {
        setState(() {
          _badgeStream = Stream.value(0);
          _myLeaderThreadIds = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _newTaskSubscription?.cancel();
    super.dispose();
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
        return 'Percakapan';
      case 4:
        return 'Profil Petugas';
      default:
        return 'Dashboard';
    }
  }

  // [PERBAIKAN RENDER HALAMAN]
  // Gunakan Switch Case, bukan List, agar _myLeaderThreadIds selalu ter-update
  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return AssignmentsPage(
          key: _assignmentsPageKey,
          idPetugasLoggedIn: widget.idPetugasLoggedIn,
        );
      case 1:
        return KinerjaPage(idPetugasLoggedIn: widget.idPetugasLoggedIn);
      case 2:
        return HistoryPage(idPetugasLoggedIn: widget.idPetugasLoggedIn);
      case 3:
        // [KUNCI PERBAIKAN] Kirim daftar ID Ketua ke halaman Chat
        return PetugasChatHomePage(
          leaderThreadIds: _myLeaderThreadIds,
        );
      case 4:
        return const ProfilePage();
      default:
        return const Center(child: Text("Halaman tidak ditemukan"));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isProfilePage = _selectedIndex == 4;
    final bool isKinerjaPage = _selectedIndex == 1;

    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (_lastPressed == null ||
            now.difference(_lastPressed!) > const Duration(seconds: 2)) {
          _lastPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tekan sekali lagi untuk keluar')));
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: isProfilePage || isKinerjaPage
            ? null
            : AppBar(
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Ionicons.chevron_back,
                      color: Color(0xFF1565C0),
                      size: 24,
                    ),
                    onPressed: () {
                      // Kembali ke halaman sebelumnya jika ada
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
                title: Text(
                  _getAppBarTitle(_selectedIndex),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D47A1),
                elevation: 1.0,
                centerTitle: true,
              ),
        // Panggil method pembangun body
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildBodyContent(),
        ),
        bottomNavigationBar: _buildModernNavBar(),
      ),
    );
  }

  Widget _buildModernNavBar() {
    // Definisi Warna Tema Petugas (Navy Blue & Cool Grey)
    const Color activeColor =
        Color(0xFF1565C0); // Navy Blue: Tegas & Profesional
    const Color inactiveColor = Color(0xFF94A3B8); // Cool Grey: Modern & Netral

    return Container(
      // Margin kiri-kanan-bawah memberikan efek "Floating" (Mengambang)
      // Ini membuat aplikasi terasa lebih premium dibandingkan navbar yang menempel kaku
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(30), // Bentuk Pill / Kapsul (Radius Besar)
        boxShadow: [
          BoxShadow(
            // Shadow berwarna Navy transparan, bukan hitam pekat
            // Memberikan efek "Glow" yang elegan
            color: activeColor.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0, // Hilangkan shadow bawaan

          // Styling Item
          selectedItemColor: activeColor,
          unselectedItemColor: inactiveColor,

          // KONSEP "SIMPLE": Sembunyikan label yang tidak aktif
          showUnselectedLabels: false,
          showSelectedLabels: true,

          // Menggunakan Font Manrope agar selaras dengan aplikasi Pelanggan
          selectedLabelStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            height: 1.5, // Sedikit jarak antara ikon dan teks
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),

          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Ionicons.list_outline),
              activeIcon: Icon(Ionicons.list),
              label: 'Tugas',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Ionicons.bar_chart_outline),
              activeIcon: Icon(Ionicons.bar_chart),
              label: 'Kinerja',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Ionicons.time_outline),
              activeIcon: Icon(Ionicons.time),
              label: 'Riwayat',
            ),
            // Ikon Chat dengan Logika Badge (Tetap dipertahankan)
            BottomNavigationBarItem(
              icon: _buildChatIconWithBadge(active: false),
              activeIcon: _buildChatIconWithBadge(active: true),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Ionicons.person_outline),
              activeIcon: Icon(Ionicons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatIconWithBadge({required bool active}) {
    final iconData =
        active ? Ionicons.chatbubbles : Ionicons.chatbubbles_outline;
    if (_badgeStream == null) {
      return Icon(iconData);
    }
    return StreamBuilder<int>(
      stream: _badgeStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : count.toString()),
          backgroundColor: Colors.red,
          child: Icon(iconData),
        );
      },
    );
  }
}

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

  final ChatService _chatService = ChatService();
  Map<String, dynamic>? _currentUserData;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadTugas();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_data');
    if (jsonString != null && mounted) {
      setState(() {
        _currentUserData = jsonDecode(jsonString);
      });
    }
  }

  void refreshTugas() {
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

  Widget _buildChatBadge(Tugas tugas) {
    // [LOGIKA BARU] 1. Cek Role: Jika bukan Ketua Tim (Petugas Pelapor),
    // langsung kembalikan widget kosong. Anggota tim tidak dapat notif.
    if (!tugas.isPetugasPelapor) {
      return const SizedBox.shrink();
    }

    // 2. Jika Ketua Tim, jalankan logika pengecekan Firebase seperti biasa
    if (_currentUserData == null || _currentUserData!['firebase_uid'] == null) {
      return const SizedBox.shrink();
    }

    final threadId = _chatService.generateTugasThreadId(
      tipeTugas: tugas.tipeTugas,
      idTugas: tugas.idTugas,
    );

    return StreamBuilder<int>(
      stream: _chatService.getUnreadMessageCount(
          threadId, _currentUserData!['firebase_uid']),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Badge(
            label: Text(count > 99 ? '99+' : count.toString()),
            child: const Icon(
              Ionicons.chatbubble_ellipses_outline,
              size: 20,
              color: Color(0xFF0D47A1),
            ),
          ),
        );
      },
    );
  }

 Widget _buildTugasCard(Tugas tugas) {
    // 1. Setup Data & Format Tanggal
    KontakInfo? kontak = tugas.infoKontakPelapor;
    String formattedDate = tugas.tanggalTugas;
    try {
      if (tugas.tanggalTugas.isNotEmpty) {
        formattedDate = DateFormat('dd MMM yyyy', 'id_ID')
            .format(DateTime.parse(tugas.tanggalTugas));
      }
    } catch (e) {}

    // 2. Ambil Warna Berdasarkan Status
    final Color statusColor = _getColorForStatus(tugas.status);

    // 3. Tentukan Peran (Ketua vs Anggota)
    final bool isKetua = tugas.isPetugasPelapor;
    final Color roleColor = isKetua ? const Color(0xFFF59E0B) : const Color(0xFF64748B);
    final Color roleBg = isKetua ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9);
    final IconData roleIcon = isKetua ? Ionicons.star : Ionicons.person;
    final String roleLabel = isKetua ? "Ketua Tim" : "Anggota";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER: Layout Baru (Judul di Atas, Status di Bawah) ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Ikon Kategori (Kiri)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getIconForTugas(tugas),
                          color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 14),

                    // 2. Konten Utama (Kanan)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // A. JUDUL (Full Width, bisa multi-line)
                          Text(
                            tugas.kategoriDisplay,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: const Color(0xFF1E293B),
                              height: 1.3,
                            ),
                            maxLines: 2, // Izinkan judul panjang turun baris
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 12), // Jarak antara Judul dan Info Bawah

                          // B. Baris Info: ID + Role (Kiri) & Status (Kanan)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end, // Rata bawah agar rapi
                            children: [
                              // Kiri: ID & Role
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ID Tugas
                                    Text(
                                      '#${tugas.tipeTugas.toUpperCase()}-${tugas.idTugas}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Role Badge (Ketua/Anggota)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: roleBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: roleColor.withOpacity(0.3), width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(roleIcon, size: 10, color: roleColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            roleLabel,
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: roleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Kanan: Status Badge
                              // Menggunakan Flexible agar tidak overflow jika layar sempit
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: statusColor.withOpacity(0.2), width: 1),
                                  ),
                                  child: Text(
                                    tugas.friendlyStatus,
                                    textAlign: TextAlign.center,
                                    maxLines: 2, // Status panjang aman 2 baris
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),

                if (kontak != null && kontak.nama.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Ionicons.person_outline,
                          size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${kontak.nama} (${kontak.nomorHp})",
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // --- FOOTER: Tanggal & Chat Action (Tidak Berubah) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Ionicons.calendar_outline,
                            size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildChatBadge(tugas),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1565C0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Ionicons.arrow_forward,
                              size: 16, color: Colors.white),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
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
            itemCount: daftarTugas.length + 1,
            itemBuilder: (context, index) {
              // Item pertama adalah greeting
              if (index == 0) {
                final namaPetugas = _currentUserData?['nama'] ?? 'Petugas';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Halo, $namaPetugas",
                        style: GoogleFonts.manrope(
                            fontSize: 14, color: Colors.grey[600]),
                      ),
                      Text(
                        "Siap bertugas hari ini?",
                        style: GoogleFonts.manrope(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1565C0) // Navy
                            ),
                      ),
                    ],
                  ),
                );
              }

              final tugas = daftarTugas[index - 1];
              return FadeInUp(
                from: 20,
                delay: Duration(milliseconds: 100 * (index - 1)),
                child: _buildTugasCard(tugas),
              );
            },
          );
        },
      ),
    );
  }
}

// // ===============================================================
// == HALAMAN RIWAYAT (TAB 3) -
// ===============================================================
class HistoryPage extends StatefulWidget {
  final int idPetugasLoggedIn;
  const HistoryPage({super.key, required this.idPetugasLoggedIn});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  // State Data
  final List<Tugas> _riwayatList = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  // State Filter
  DateTimeRange? _selectedDateRange;
  int _limitPerPage = 10; // Default 10 data per load

  // Tema Warna
  final Color _primaryNavy = const Color(0xFF1565C0);
  final Color _slateText = const Color(0xFF1E293B);
  final Color _subText = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    // Default filter: Bulan ini
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );

    _fetchRiwayat();

    // Infinite Scroll Listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _fetchRiwayat();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- LOGIKA FETCH DATA DENGAN FILTER ---
  Future<void> _fetchRiwayat() async {
    // Pengecekan standar
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      // Format tanggal untuk API (YYYY-MM-DD)
      String? startDateStr =
          _selectedDateRange?.start.toIso8601String().split('T')[0];
      String? endDateStr =
          _selectedDateRange?.end.toIso8601String().split('T')[0];

      // --- PERBAIKAN: Hapus tanda komentar (//) pada parameter ---
      final response = await _apiService.getRiwayatPetugas(
        widget.idPetugasLoggedIn,
        _currentPage,
        limit: _limitPerPage, // <--- Pastikan ini aktif
        startDate: startDateStr, // <--- Pastikan ini aktif
        endDate: endDateStr, // <--- Pastikan ini aktif
      );

      if (!mounted) return;

      setState(() {
        // ... (logika setState Anda sudah benar) ...
        if (_currentPage == 1) _riwayatList.clear();

        _riwayatList.addAll(response.tugasList);

        // Cek halaman berikutnya
        if (response.tugasList.length < _limitPerPage) {
          _hasMore = false;
        } else {
          _hasMore = response.hasMorePages;
          if (_hasMore) _currentPage++;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false); // Pastikan loading mati jika error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal memuat: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _applyFilter() {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _riwayatList.clear();
      _isLoading = false;
    });

    // Panggil fetch
    _fetchRiwayat();
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. App Bar & Filter Section
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: const Color(0xFFF8F9FA),
            elevation: 0,
            automaticallyImplyLeading: false,
            toolbarHeight: 100, // Tinggi area filter
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              title: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildFilterControls(),
                  ],
                ),
              ),
            ),
          ),

          // 2. Daftar Riwayat
          if (_riwayatList.isEmpty && !_isLoading)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < _riwayatList.length) {
                      return FadeInUp(
                        from: 20,
                        delay: const Duration(milliseconds: 50),
                        child: _buildHistoryCard(_riwayatList[index]),
                      );
                    } else {
                      return _buildBottomLoader();
                    }
                  },
                  childCount: _riwayatList.length + (_hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Riwayat Pekerjaan",
            style: GoogleFonts.manrope(
                fontSize: 20, fontWeight: FontWeight.w800, color: _slateText)),
        // Indikator Total Data (Opsional)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: _primaryNavy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Text("${_riwayatList.length} Data",
              style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _primaryNavy)),
        )
      ],
    );
  }

  Widget _buildFilterControls() {
    return Row(
      children: [
        // Filter Tanggal
        Expanded(
          flex: 3,
          child: GestureDetector(
            // <--- Ganti InkWell jadi GestureDetector
            onTap: _pickDateRange,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 5)
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Ionicons.calendar_outline, size: 16, color: _subText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedDateRange == null
                          ? "Semua Tanggal"
                          : "${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}",
                      style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _slateText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Ionicons.chevron_down, size: 14, color: _subText),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Filter Limit (Dropdown)
        Expanded(
          flex: 2,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _limitPerPage,
                icon: Icon(Ionicons.options_outline, size: 16, color: _subText),
                isExpanded: true,
                style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _slateText),
                items: [10, 20, 50, 100].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text("$value Data"),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _limitPerPage = newValue;
                    });
                    _applyFilter();
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Tugas tugas) {
    bool isSuccess = ['selesai', 'terpasang', 'survey selesai']
        .contains(tugas.status.toLowerCase());
    Color statusColor = isSuccess ? Colors.green : Colors.red;

    // Format Tanggal
    String dateStr = "-";
    if (tugas.tanggalTugas.isNotEmpty) {
      try {
        dateStr = DateFormat('dd MMM yyyy')
            .format(DateTime.parse(tugas.tanggalTugas));
      } catch (e) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () {
          // Logika navigasi tetap sama
          if (tugas is CalonPelangganTugas) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DetailCalonPelangganPage(tugas: tugas)));
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DetailTugasPage(tugas: tugas)));
          }
        },
        child: Row(
          children: [
            // Status Strip (Garis warna di kiri)
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),

            // Konten Utama
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BARIS JUDUL & TANGGAL (PERBAIKAN DISINI) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Gunakan Expanded pada Judul agar tidak menabrak tanggal
                      Expanded(
                        child: Text(
                          tugas.kategoriDisplay,
                          style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _slateText),
                          maxLines: 2, // Batasi maks 2 baris
                          overflow: TextOverflow
                              .ellipsis, // Tambah "..." jika kepanjangan
                        ),
                      ),
                      const SizedBox(width: 8), // Jarak aman

                      // 2. Tanggal (Ukurannya tetap)
                      Text(
                        dateStr,
                        style:
                            GoogleFonts.manrope(fontSize: 11, color: _subText),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Deskripsi Lokasi
                  Text(
                    tugas.deskripsiLokasi,
                    style: GoogleFonts.manrope(fontSize: 13, color: _subText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Badges (ID & Status)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text("#${tugas.idTugas}",
                            style: GoogleFonts.manrope(
                                fontSize: 10,
                                color: _subText,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),

                      // Bungkus status dengan Flexible untuk keamanan ekstra
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(tugas.friendlyStatus,
                              style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  color: statusColor,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow
                                  .ellipsis, // Jaga-jaga jika status panjang
                              maxLines: 1),
                        ),
                      ),

                      const Spacer(),

                      // Rating Star jika ada
                      if ((tugas.ratingHasil ?? 0) > 0)
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              "${tugas.ratingHasil}",
                              style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _slateText),
                            ),
                          ],
                        )
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(width: 12),
            Icon(Ionicons.chevron_forward,
                size: 18, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Ionicons.file_tray_outline,
              size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Tidak ada riwayat ditemukan",
            style: GoogleFonts.manrope(
                fontSize: 16, fontWeight: FontWeight.bold, color: _subText),
          ),
          const SizedBox(height: 8),
          Text(
            "Coba ubah filter tanggal Anda",
            style:
                GoogleFonts.manrope(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _hasMore
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _primaryNavy))
            : Text("Semua data telah dimuat",
                style: GoogleFonts.manrope(
                    fontSize: 12, color: Colors.grey.shade400)),
      ),
    );
  }

  // Helper Date Picker
  Future<void> _pickDateRange() async {
    // Tentukan lastDate yang aman (minimal sampai akhir bulan ini agar tidak crash)
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    // Gunakan tanggal mana yang lebih jauh: hari ini atau akhir bulan
    final safeLastDate = endOfMonth.isAfter(now) ? endOfMonth : now;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      // UBAH BARIS DI BAWAH INI
      lastDate: safeLastDate, // Jangan gunakan DateTime.now() langsung
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: _primaryNavy,
            colorScheme: ColorScheme.light(primary: _primaryNavy),
            buttonTheme:
                const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _applyFilter();
    }
  }
}

// ===============================================================
// == HALAMAN PROFIL (TAB 4) -
// ===============================================================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService();
  Future<Petugas>? _petugasFuture;

  // Tema Warna Konsisten (Petugas Theme)
  final Color _primaryNavy = const Color(0xFF1565C0);
  final Color _slateText = const Color(0xFF1E293B);
  final Color _subText = const Color(0xFF64748B);
  final Color _bgGrey = const Color(0xFFF8F9FA);

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

  Future<void> _logout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Konfirmasi Logout',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin keluar dari akun Anda?',
              style: GoogleFonts.manrope()),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Batal', style: GoogleFonts.manrope(color: _subText)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Ya, Keluar',
                  style: GoogleFonts.manrope(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (shouldLogout == true && mounted) {
      await _apiService.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      body: RefreshIndicator(
        color: _primaryNavy,
        onRefresh: () async => _loadProfileData(),
        child: FutureBuilder<Petugas>(
          future: _petugasFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: _primaryNavy));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _buildErrorUI("Gagal memuat profil. Silakan coba lagi.");
            }
            final petugas = snapshot.data!;

            return CustomScrollView(
              slivers: [
                _buildProfileHeader(petugas),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label Section
                        Text(
                          "Informasi Pribadi",
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _slateText,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // List Informasi
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 200),
                          child: _buildInfoCard(petugas),
                        ),

                        const SizedBox(height: 32),

                        // Tombol Aksi
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 300),
                          child: _buildActionButtons(petugas),
                        ),
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

  Widget _buildProfileHeader(Petugas petugas) {
    final String? profilePhotoPath = petugas.fotoProfil;
    final String fullImageUrl =
        profilePhotoPath != null && profilePhotoPath.isNotEmpty
            ? '${_apiService.rootBaseUrl}/storage/$profilePhotoPath'
            : '';

    return SliverAppBar(
      expandedHeight: 260.0,
      pinned: true,
      backgroundColor: _primaryNavy,
      elevation: 0,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryNavy, const Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Dekorasi Lingkaran Pudar (Opsional, untuk estetika)
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Konten Profil
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20), // Spacer untuk status bar
                // Avatar dengan Border Putih & Shadow
                FadeInDown(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white,
                      backgroundImage: fullImageUrl.isNotEmpty
                          ? CachedNetworkImageProvider(fullImageUrl)
                          : null,
                      child: fullImageUrl.isEmpty
                          ? Icon(Ionicons.person,
                              size: 60, color: Colors.grey.shade300)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Nama
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    petugas.nama,
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Email
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      petugas.email ?? 'Tidak ada email',
                      style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(Petugas petugas) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: _primaryNavy.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Ionicons.card_outline, 'NIK', petugas.nik ?? '-'),
          const Divider(
              height: 1, indent: 60, endIndent: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
              Ionicons.call_outline, 'Nomor HP', petugas.nomorHp ?? '-'),
          const Divider(
              height: 1, indent: 60, endIndent: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow(Ionicons.business_outline, 'Cabang',
              petugas.cabang?.namaCabang ?? 'Pusat'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryNavy.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primaryNavy, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: _subText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _slateText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Petugas petugas) {
    return Column(
      children: [
        // Tombol Edit Profil
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Ionicons.create_outline,
                size: 20, color: Colors.white),
            label: Text('Edit Profil',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white)),
            onPressed: () async {
              final result = await Navigator.push<Petugas>(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        EditProfilePage(currentPetugas: petugas)),
              );
              if (result != null && mounted) {
                setState(() {
                  _petugasFuture = Future.value(result);
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shadowColor: _primaryNavy.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Tombol Logout
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(Ionicons.log_out_outline,
                size: 20, color: Colors.red.shade600),
            label: Text('Logout',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red.shade600)),
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.red.shade200, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.red.shade50.withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorUI(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Ionicons.cloud_offline_outline,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 16, color: _subText),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh, size: 18, color: Colors.white),
              label: Text('Coba Lagi',
                  style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: _loadProfileData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryNavy,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================================================
// == HALAMAN KINERJA (TAB 2) - RE-DESIGNED MODERN
// ===============================================================
class KinerjaPage extends StatefulWidget {
  final int idPetugasLoggedIn;
  const KinerjaPage({super.key, required this.idPetugasLoggedIn});
  @override
  State<KinerjaPage> createState() => _KinerjaPageState();
}

class _KinerjaPageState extends State<KinerjaPage> {
  final ApiService _apiService = ApiService();
  late Future<KinerjaResponse> _kinerjaFuture;
  String _selectedPeriode = 'bulanan';

  // Tema Warna Konsisten
  final Color _primaryNavy = const Color(0xFF1565C0);
  final Color _slateText = const Color(0xFF1E293B);
  final Color _subText = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadKinerjaData();
  }

  void _loadKinerjaData() {
    setState(() {
      _kinerjaFuture = _apiService.getKinerja(
        widget.idPetugasLoggedIn,
        _selectedPeriode,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Background bersih
      body: RefreshIndicator(
        color: _primaryNavy,
        onRefresh: () async => _loadKinerjaData(),
        child: FutureBuilder<KinerjaResponse>(
          future: _kinerjaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: _primaryNavy));
            }
            if (snapshot.hasError) {
              return _buildErrorUI(
                'Gagal memuat data kinerja: ${snapshot.error.toString().replaceAll("Exception: ", "")}',
              );
            }
            if (!snapshot.hasData) {
              return _buildErrorUI('Data kinerja tidak tersedia.');
            }
            final kinerjaData = snapshot.data!;

            return CustomScrollView(
              slivers: [
                // 1. Header & Filter Sticky
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  backgroundColor: const Color(0xFFF8F9FA),
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 90,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: EdgeInsets.zero,
                    title: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Statistik Kinerja",
                              style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _slateText)),
                          const SizedBox(height: 12),
                          _buildFilterPeriode(),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Konten Scrollable
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      const SizedBox(height: 10),
                      // KPI Utama Grid
                      FadeInUp(
                        from: 20,
                        delay: const Duration(milliseconds: 100),
                        child: _buildKpiGrid(kinerjaData.kpiUtama),
                      ),

                      const SizedBox(height: 32),

                      // Grafik Komposisi
                      if (kinerjaData.komposisiTugas.isNotEmpty) ...[
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 200),
                          child: _buildSectionHeader("Komposisi Pekerjaan"),
                        ),
                        const SizedBox(height: 16),
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 300),
                          child: _buildPieChartCard(kinerjaData.komposisiTugas),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // List Rincian
                      if (kinerjaData.rincianPerTipe.isNotEmpty) ...[
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 400),
                          child: _buildSectionHeader("Detail Per Kategori"),
                        ),
                        const SizedBox(height: 16),
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 500),
                          child: _buildRincianList(kinerjaData.rincianPerTipe),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildFilterPeriode() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          _buildFilterButton('mingguan', 'Minggu Ini'),
          _buildFilterButton('bulanan', 'Bulan Ini'),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String value, String label) {
    final bool isSelected = _selectedPeriode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriode = value;
            _loadKinerjaData();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _primaryNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : _subText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                color: _primaryNavy, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.manrope(
                fontSize: 16, fontWeight: FontWeight.w700, color: _slateText)),
      ],
    );
  }

  Widget _buildKpiGrid(KpiUtama kpi) {
    return Column(
      children: [
        // Baris 1: Rating (Full Width untuk Highlight)
        GestureDetector(
          onTap: () => _showRatingDetailsDialog(context, kpi),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [_primaryNavy, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _primaryNavy.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Rating Rata-rata",
                        style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          kpi.ratingRataRata > 0
                              ? kpi.ratingRataRata.toStringAsFixed(1)
                              : "0.0",
                          style: GoogleFonts.manrope(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6, left: 4),
                          child:
                              Icon(Icons.star, color: Colors.amber, size: 20),
                        )
                      ],
                    )
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Ionicons.trophy,
                      color: Colors.white, size: 28),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Baris 2: Grid 3 Item (Selesai, Batal, Kecepatan)
        Row(
          children: [
            Expanded(
                child: _buildMiniStatCard(
                    "Selesai",
                    kpi.totalTugasSelesai.toString(),
                    Colors.green.shade600,
                    Ionicons.checkmark_circle)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildMiniStatCard(
                    "Dibatalkan",
                    kpi.totalTugasDibatalkan.toString(),
                    Colors.red.shade600,
                    Ionicons.close_circle)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildMiniStatCard(
                    "Kecepatan",
                    "${kpi.kecepatanRataRataMenit}m",
                    Colors.orange.shade700,
                    Ionicons.timer)),
          ],
        )
      ],
    );
  }

  Widget _buildMiniStatCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _slateText)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.manrope(
                  fontSize: 11, color: _subText, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(List<KomposisiTugas> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    // Warna Palette Modern
    final colors = [
      const Color(0xFF1565C0), // Navy
      const Color(0xFF00BFA5), // Teal
      const Color(0xFFFFB300), // Amber
      const Color(0xFFE53935), // Red
      const Color(0xFF7E57C2), // Purple
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: data.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final KomposisiTugas item = entry.value;
                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: item.total.toDouble(),
                    title: '${item.total}',
                    radius: 50,
                    titleStyle: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: data.asMap().entries.map((entry) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors[entry.key % colors.length])),
                  const SizedBox(width: 6),
                  Text(entry.value.tipeTugas,
                      style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: _subText,
                          fontWeight: FontWeight.w500)),
                ],
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildRincianList(List<RincianPerTipe> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 5))
        ],
      ),
      child: ListView.separated(
        itemCount: data.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (context, index) => Divider(
            height: 1, indent: 20, endIndent: 20, color: Colors.grey.shade100),
        itemBuilder: (context, index) {
          final item = data[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.tipeTugas,
                          style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _slateText)),
                      const SizedBox(height: 4),
                      Text("Kecepatan: ${item.kecepatanRataRataMenit} mnt",
                          style: GoogleFonts.manrope(
                              fontSize: 12, color: _subText)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text("${item.totalSelesai} Selesai",
                      style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700)),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // --- DIALOGS ---

  void _showRatingDetailsDialog(BuildContext context, KpiUtama kpi) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Detail Rating',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRatingRowDialog('Kecepatan', kpi.ratingRataRataKecepatan),
              _buildRatingRowDialog('Pelayanan', kpi.ratingRataRataPelayanan),
              _buildRatingRowDialog('Hasil Kerja', kpi.ratingRataRataHasil),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tutup',
                  style: GoogleFonts.manrope(
                      color: _primaryNavy, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRatingRowDialog(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.manrope(fontSize: 14, color: _slateText)),
          Row(
            children: [
              Text(rating.toStringAsFixed(1),
                  style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold, color: _slateText)),
              const SizedBox(width: 4),
              const Icon(Icons.star, color: Colors.amber, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Ionicons.stats_chart_outline,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 15, color: _subText)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadKinerjaData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('Muat Ulang',
                  style: GoogleFonts.manrope(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
