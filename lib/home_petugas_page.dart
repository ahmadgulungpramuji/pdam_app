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

// ===============================================================
// == MAIN HOME PAGE (INDUK)
// ===============================================================
class HomePetugasPage extends StatefulWidget {
  final int idPetugasLoggedIn;
  const HomePetugasPage({super.key, required this.idPetugasLoggedIn});

  @override
  State<HomePetugasPage> createState() => _HomePetugasPageState();
}

class _HomePetugasPageState extends State<HomePetugasPage> {
  DateTime? _lastPressed;

  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;
  StreamSubscription? _newTaskSubscription;
  final GlobalKey<_AssignmentsPageState> _assignmentsPageKey = GlobalKey();

  // Tambahan untuk Badge Navigasi
  final ChatService _chatService = ChatService();
  Map<String, dynamic>? _currentUserData;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser(); // Load user untuk Nav Bar

    _widgetOptions = <Widget>[
      AssignmentsPage(
        key: _assignmentsPageKey,
        idPetugasLoggedIn: widget.idPetugasLoggedIn,
      ),
      KinerjaPage(idPetugasLoggedIn: widget.idPetugasLoggedIn),
      HistoryPage(idPetugasLoggedIn: widget.idPetugasLoggedIn),
      const PetugasChatHomePage(),
      const ProfilePage(),
    ];

    _newTaskSubscription =
        NotificationService().onNotificationTap.listen((payload) {
      if (mounted && payload['tipe_notifikasi'] == 'penugasan_baru') {
        _onItemTapped(0);
        _assignmentsPageKey.currentState?.refreshTugas();
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
        return 'Dashboard Petugas';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isProfilePage = _selectedIndex == 4;
    final bool isKinerjaPage = _selectedIndex == 1;

    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
            _lastPressed == null ||
                now.difference(_lastPressed!) > const Duration(seconds: 2);

        if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
          _lastPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tekan sekali lagi untuk keluar'),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        } else {
          SystemNavigator.pop();
          return true;
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: isProfilePage || isKinerjaPage
            ? null
            : AppBar(
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
      ),
    );
  }

  Widget _buildModernNavBar() {
    return Container(
      margin: const EdgeInsets.all(12).copyWith(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Ionicons.list_circle_outline),
              activeIcon: Icon(Ionicons.list_circle),
              label: 'Tugas',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Ionicons.stats_chart_outline),
              activeIcon: Icon(Ionicons.stats_chart),
              label: 'Kinerja',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Ionicons.time_outline),
              activeIcon: Icon(Ionicons.time),
              label: 'Riwayat',
            ),
            // Ikon Chat dengan Badge
            BottomNavigationBarItem(
              icon: _buildChatIconWithBadge(active: false),
              activeIcon: _buildChatIconWithBadge(active: true),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
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

  Widget _buildChatIconWithBadge({required bool active}) {
    final iconData =
        active ? Ionicons.chatbubbles : Ionicons.chatbubbles_outline;

    if (_currentUserData == null || _currentUserData!['firebase_uid'] == null) {
      return Icon(iconData);
    }

    return StreamBuilder<int>(
      stream: _chatService.getUnreadCountByPrefix(
          _currentUserData!['firebase_uid'], 'pengaduan_'),
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

// ===============================================================
// == HALAMAN DAFTAR TUGAS (TAB 1)
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
      _tugasFuture =
          _apiService.getPetugasSemuaTugas(widget.idPetugasLoggedIn);
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
      shadowColor: Colors.black.withOpacity(0.05),
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
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
                      const Spacer(),
                      _buildChatBadge(tugas),
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
// == HALAMAN RIWAYAT (TAB 3) - FIXED
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
      final response = await _apiService.getRiwayatPetugas(
        widget.idPetugasLoggedIn,
        _currentPage,
      );
      if (!mounted) return;
      setState(() {
        _riwayatList.addAll(response.tugasList);
        _hasMore = response.hasMorePages;
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
      case 'ditolak':
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
      // Biarkan tanggal asli
    }
    Color statusColor = _getColorForStatus(tugas.status);
    final bool hasRating = (tugas.ratingHasil ?? 0) > 0;
    String tanggalLabel;
    switch (tugas.status.toLowerCase()) {
      case 'survey selesai':
        tanggalLabel = 'Tgl Survey Selesai:';
        break;
      case 'terpasang':
        tanggalLabel = 'Tgl Pemasangan:';
        break;
      case 'dibatalkan':
      case 'ditolak':
        tanggalLabel = 'Tgl Dibatalkan:';
        break;
      default:
        tanggalLabel = 'Tgl Selesai:';
    }
    Color headerBackgroundColor = statusColor.withOpacity(0.1);
    Color headerTextColor = statusColor;
    IconData headerIcon = _getIconForTugas(tugas);
    if (tugas.status.toLowerCase() == 'survey selesai') {
      headerBackgroundColor = Colors.teal.shade50;
      headerTextColor = Colors.teal.shade700;
      headerIcon = Ionicons.map;
    } else if (tugas.status.toLowerCase() == 'terpasang') {
      headerBackgroundColor = Colors.blue.shade50;
      headerTextColor = Colors.blue.shade800;
      headerIcon = Ionicons.build;
    }
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.05),
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
            ).then((_) => _onRefresh());
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailTugasPage(tugas: tugas),
              ),
            ).then((_) => _onRefresh());
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: headerBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(headerIcon, color: headerTextColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tugas.kategoriDisplay,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: headerTextColor,
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
                    '$tanggalLabel $formattedDate',
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
                      if (hasRating)
                        InkWell(
                          onTap: () => _showRatingDialog(context, tugas),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Ionicons.star,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Lihat Rating',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
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

  void _showRatingDialog(BuildContext context, Tugas tugas) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Detail Penilaian'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildRatingRow('Kecepatan', tugas.ratingKecepatan ?? 0),
                _buildRatingRow('Pelayanan', tugas.ratingPelayanan ?? 0),
                _buildRatingRow('Hasil', tugas.ratingHasil ?? 0),
                const Divider(height: 24),
                Text(
                  'Komentar Pelanggan:',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  tugas.komentarRating ?? 'Tidak ada komentar.',
                  style: GoogleFonts.lato(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Tutup'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRatingRow(String label, int rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.lato(fontSize: 15)),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 20,
              );
            }),
          ),
        ],
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
            const Icon(
              Ionicons.cloud_offline_outline,
              size: 60,
              color: Colors.grey,
            ),
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
      child: (_riwayatList.isEmpty && _isLoading)
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
                          child: _hasMore
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

/// ===============================================================
// == HALAMAN PROFIL (TAB 4) - DIPERBARUI DENGAN NIK
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
      await _apiService.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Widget _buildProfileHeader(Petugas petugas) {
    final String? profilePhotoPath = petugas.fotoProfil;
    final String fullImageUrl =
        profilePhotoPath != null && profilePhotoPath.isNotEmpty
            ? '${_apiService.rootBaseUrl}/storage/$profilePhotoPath'
            : '';
    return SliverAppBar(
      expandedHeight: 240.0,
      pinned: true,
      backgroundColor: const Color(0xFF0D47A1),
      elevation: 0,
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
                      ? Icon(
                          Ionicons.person,
                          size: 60,
                          color: Colors.blue[800],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              FadeInUp(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  petugas.nama,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
              color: const Color(0xFF0D47A1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0D47A1), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Ionicons.create_outline, size: 20),
              label: const Text('Edit Profil'),
              onPressed: () async {
                final result = await Navigator.push<Petugas>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditProfilePage(currentPetugas: petugas),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    _petugasFuture = Future.value(result);
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Ionicons.log_out_outline),
              label: const Text('Logout'),
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[700],
                side: BorderSide(color: Colors.red[700]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Ionicons.cloud_offline_outline,
              size: 60,
              color: Colors.grey,
            ),
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
              onPressed: _loadProfileData,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _loadProfileData(),
      child: FutureBuilder<Petugas>(
        future: _petugasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    children: [
                      // --- NIK DITAMBAHKAN DI SINI ---
                      FadeInUp(
                        from: 20,
                        delay: const Duration(milliseconds: 200),
                        child: _buildInfoTile(
                          icon: Ionicons.card_outline,
                          title: 'NIK',
                          subtitle: petugas.nik ?? '-',
                        ),
                      ),
                      
                      FadeInUp(
                        from: 20,
                        delay: const Duration(milliseconds: 300),
                        child: _buildInfoTile(
                          icon: Ionicons.call_outline,
                          title: 'Nomor HP',
                          subtitle: petugas.nomorHp,
                        ),
                      ),
                      FadeInUp(
                        from: 20,
                        delay: const Duration(milliseconds: 400),
                        child: _buildInfoTile(
                          icon: Ionicons.mail_outline,
                          title: 'Email',
                          subtitle: petugas.email,
                        ),
                      ),
                      FadeInUp(
                        from: 20,
                        delay: const Duration(milliseconds: 500),
                        child: _buildInfoTile(
                          icon: Ionicons.location_outline,
                          title: 'Cabang Terdaftar',
                          subtitle:
                              petugas.cabang?.namaCabang ?? 'Tidak diketahui',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeInUp(
                        from: 20,
                        delay: const Duration(milliseconds: 600),
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
    );
  }
}

// ===============================================================
// == HALAMAN KINERJA (TAB 2)
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
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: () async => _loadKinerjaData(),
        child: FutureBuilder<KinerjaResponse>(
          future: _kinerjaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
            // Tampilan utama menggunakan CustomScrollView
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  snap: true,
                  backgroundColor: Colors.grey.shade100,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    title: _buildFilterPeriode(),
                  ),
                  toolbarHeight: 80,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      FadeInUp(
                        from: 20,
                        delay: const Duration(milliseconds: 100),
                        child: _buildKpiGrid(kinerjaData.kpiUtama),
                      ),
                      const SizedBox(height: 32),
                      if (kinerjaData.komposisiTugas.isNotEmpty) ...[
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 200),
                          child: _buildChartTitle('Komposisi Pekerjaan'),
                        ),
                        const SizedBox(height: 16),
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 300),
                          child: _buildPieChart(kinerjaData.komposisiTugas),
                        ),
                        const SizedBox(height: 32),
                      ],
                      if (kinerjaData.rincianPerTipe.isNotEmpty) ...[
                        FadeInUp(
                          from: 20,
                          delay: const Duration(milliseconds: 400),
                          child: _buildChartTitle('Rincian per Jenis Tugas'),
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

  Widget _buildFilterPeriode() {
    return SegmentedButton<String>(
      segments: const <ButtonSegment<String>>[
        ButtonSegment(
          value: 'mingguan',
          label: Text('Minggu Ini'),
          icon: Icon(Ionicons.calendar_outline, size: 18),
        ),
        ButtonSegment(
          value: 'bulanan',
          label: Text('Bulan Ini'),
          icon: Icon(Ionicons.calendar, size: 18),
        ),
      ],
      selected: <String>{_selectedPeriode},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _selectedPeriode = newSelection.first;
          _loadKinerjaData();
        });
      },
      style: SegmentedButton.styleFrom(
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[700],
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: const Color(0xFF0D47A1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildKpiGrid(KpiUtama kpi) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        GestureDetector(
          onTap: () => _showRatingDetailsDialog(context, kpi),
          child: _buildKpiCard(
            'Rating Rata-rata',
            kpi.ratingRataRata > 0
                ? kpi.ratingRataRata.toStringAsFixed(1)
                : 'N/A',
            Ionicons.star,
            Colors.amber,
          ),
        ),
        _buildKpiCard(
          'Rata-rata Cepat',
          '${kpi.kecepatanRataRataMenit} mnt',
          Ionicons.timer_outline,
          Colors.blue,
        ),
        _buildKpiCard(
          'Tugas Selesai',
          kpi.totalTugasSelesai.toString(),
          Ionicons.checkmark_circle_outline,
          Colors.green,
        ),
        _buildKpiCard(
          'Tugas Batal',
          kpi.totalTugasDibatalkan.toString(),
          Ionicons.close_circle_outline,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 5,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 28, color: Colors.white),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildPieChart(List<KomposisiTugas> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
    ];
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: data.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final KomposisiTugas item = entry.value;
                      return PieChartSectionData(
                        color: colors[index % colors.length],
                        value: item.total.toDouble(),
                        title: '${item.total}',
                        radius: 50,
                        titleStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors[entry.key % colors.length],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.tipeTugas,
                              style: GoogleFonts.lato(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRincianList(List<RincianPerTipe> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: data.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final item = data[index];
          return ListTile(
            title: Text(
              item.tipeTugas,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Selesai: ${item.totalSelesai} | Cepat: ${item.kecepatanRataRataMenit} mnt ${item.ratingRataRata != null ? "| Rating: ${item.ratingRataRata} ★" : ""}',
              style: GoogleFonts.lato(),
            ),
          );
        },
      ),
    );
  }

  void _showRatingDetailsDialog(BuildContext context, KpiUtama kpi) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Rincian Rata-Rata Rating',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildRatingRowDialog('Kecepatan', kpi.ratingRataRataKecepatan),
                _buildRatingRowDialog('Pelayanan', kpi.ratingRataRataPelayanan),
                _buildRatingRowDialog('Hasil', kpi.ratingRataRataHasil),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Tutup'),
              onPressed: () {
                Navigator.of(context).pop();
              },
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
          Text(label, style: GoogleFonts.lato(fontSize: 16)),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating.round() ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 22,
              );
            }),
          ),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Ionicons.cloud_offline_outline,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Ionicons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              onPressed: _loadKinerjaData,
            ),
          ],
        ),
      ),
    );
  }
}