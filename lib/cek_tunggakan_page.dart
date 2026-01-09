// lib/cek_tunggakan_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';

// --- WIDGET ANIMASI ---
class FadeInAnimation extends StatefulWidget {
  final int delay;
  final Widget child;

  const FadeInAnimation({super.key, this.delay = 0, required this.child});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _position = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(curve);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _position,
        child: widget.child,
      ),
    );
  }
}
// --- END WIDGET ANIMASI ---

class CekTunggakanPage extends StatefulWidget {
  const CekTunggakanPage({super.key});

  @override
  State<CekTunggakanPage> createState() => _CekTunggakanPageState();
}

class _CekTunggakanPageState extends State<CekTunggakanPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _pdamIdController = TextEditingController();

  List<dynamic> _pdamIdsFromApi = [];
  String? _selectedPdamId;
  String? _mainPdamId; // Variabel ID Utama
  Map<String, dynamic>? _tunggakanData;
  bool _isLoadingApiPdamIds = true;
  bool _isLoadingTunggakan = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 1. Coba update profil user dari server
    try {
      await _apiService.getUserProfile(); 
    } catch (e) {
      // Abaikan error jaringan
    }
    
    // 2. Deteksi Main ID (Dari Profil)
    await _loadMainIdFromProfile();

    // 3. Load List ID Pelanggan dan terapkan logika Fallback jika perlu
    await _fetchUserPdamIdsFromApi();
  }

  @override
  void dispose() {
    _pdamIdController.dispose();
    super.dispose();
  }

  // --- LOGIKA 1: CARI DI PROFIL USER ---
  Future<void> _loadMainIdFromProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      setState(() {
        if (userData['id_pdam'] != null) {
          _mainPdamId = userData['id_pdam'].toString().trim();
        } else if (userData['nomor_sambungan'] != null) {
          _mainPdamId = userData['nomor_sambungan'].toString().trim();
        } else if (userData['username'] != null) {
           String username = userData['username'].toString().trim();
           if (RegExp(r'^[0-9]+$').hasMatch(username) && username.length > 3) {
             _mainPdamId = username;
           }
        }
      });
    }
  }

  Future<void> _fetchUserPdamIdsFromApi() async {
    if (!mounted) return;
    setState(() {
      _isLoadingApiPdamIds = true;
      _pdamIdsFromApi = [];
      _selectedPdamId = null;
      _tunggakanData = null;
      _errorMessage = null;
    });

    try {
      // API mengembalikan data urut DESC (Terbaru di atas, Terlama di bawah)
      final rawIds = await _apiService.getAllUserPdamIds();
      
      if (!mounted) return;

      // --- LOGIKA 2: FALLBACK (JIKA PROFIL KOSONG, AMBIL YANG TERLAMA) ---
      // Jika _mainPdamId masih null setelah cek profil, ambil ID paling bawah (terlama) dari list API
      if (_mainPdamId == null && rawIds.isNotEmpty) {
        // Karena API sort by created_at DESC, maka elemen TERAKHIR adalah yang PERTAMA dibuat
        _mainPdamId = rawIds.last['nomor']?.toString();
        print("DEBUG: Menggunakan Fallback ID Utama (Terlama) = $_mainPdamId");
      }

      // --- LOGIKA 3: PENGURUTAN (Main ID Paling Atas) ---
      List<dynamic> sortedList = List.from(rawIds);

      if (_mainPdamId != null) {
        // Cari ID Utama di dalam list
        final mainIdIndex = sortedList.indexWhere(
          (item) => item['nomor'].toString().trim() == _mainPdamId
        );

        if (mainIdIndex != -1) {
          // Pindahkan ke indeks 0
          final mainItem = sortedList.removeAt(mainIdIndex);
          sortedList.insert(0, mainItem);
        }
      }

      setState(() {
        _pdamIdsFromApi = sortedList;
        _isLoadingApiPdamIds = false;
        
        if (_pdamIdsFromApi.isNotEmpty) {
          // Auto-Select yang paling atas (Indeks 0 = ID Utama)
          _selectedPdamId = _pdamIdsFromApi.first['nomor']?.toString();

          if (_selectedPdamId != null) {
            _fetchTunggakan(_selectedPdamId!);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingApiPdamIds = false;
        _errorMessage = "Gagal memuat daftar ID: ${e.toString()}";
      });
    }
  }

  // Helper Kuat untuk Cek Main ID
  bool _isMainId(String? idToCheck) {
    if (idToCheck == null) return false;
    if (_mainPdamId != null && idToCheck.trim() == _mainPdamId!.trim()) {
      return true;
    }
    return false;
  }

  Future<void> _deleteCurrentId() async {
    if (_selectedPdamId == null) return;

    // --- PROTEKSI ID UTAMA ---
    if (_isMainId(_selectedPdamId)) {
      _showSnackbar("ID Utama akun Anda tidak dapat dihapus!", isError: true);
      return;
    }

    final selectedItem = _pdamIdsFromApi.firstWhere(
      (item) => item['nomor'].toString() == _selectedPdamId,
      orElse: () => null,
    );

    if (selectedItem == null) return;
    
    if (selectedItem['id'] == null) {
       _showSnackbar("Gagal: ID Database tidak ditemukan.", isError: true);
       return;
    }

    final int dbId = selectedItem['id']; 

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ID?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus ID $_selectedPdamId dari daftar tersimpan?',
            style: GoogleFonts.manrope()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.manrope(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: GoogleFonts.manrope(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoadingApiPdamIds = true);
      
      try {
        // PERBAIKAN DI SINI:
        // Kita tidak lagi mengandalkan return boolean semata, tapi menunggu eksekusi selesai
        await _apiService.deleteUserPdamId(dbId);
        
        // Jika kode sampai sini, berarti sukses (tidak ada Exception)
        _showSnackbar('ID berhasil dihapus.', isError: false);
        
        // Reset pilihan agar tidak error karena ID yang dipilih sudah hilang
        setState(() {
          _selectedPdamId = null;
          _tunggakanData = null;
        });

        // Refresh list
        await _fetchUserPdamIdsFromApi(); 
        
      } catch (e) {
        // TANGKAP ERROR ASLI DARI API SERVICE
        // Hapus tulisan "Exception: " agar pesan lebih bersih
        String cleanError = e.toString().replaceAll("Exception: ", "");
        _showSnackbar('Gagal: $cleanError', isError: true);
      } finally {
        // Pastikan loading berhenti apa pun yang terjadi
        if (mounted) setState(() => _isLoadingApiPdamIds = false);
      }
    }
  }

  Future<void> _fetchTunggakan(String pdamId) async {
    if (pdamId.isEmpty) {
      _showSnackbar('ID PDAM tidak boleh kosong.', isError: true);
      return;
    }
    if (!mounted) return;

    setState(() {
      _isLoadingTunggakan = true;
      _errorMessage = null;
      _tunggakanData = null;
    });

    try {
      final data = await _apiService.getTunggakan(pdamId);
      if (!mounted) return;
      setState(() {
        _tunggakanData = data;
        if (data.containsKey('error') && data['error'] != null) {
          _errorMessage = data['error'].toString();
        } else if (data['jumlah'] == 0) {
          _errorMessage = "Selamat! Tidak ada tagihan untuk ID $pdamId.";
        } else if (data.isEmpty) {
          _errorMessage = "Data tunggakan tidak ditemukan untuk ID $pdamId.";
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mengambil data tunggakan: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoadingTunggakan = false);
    }
  }

  Future<void> _addAndSelectPdamId() async {
    if (_pdamIdController.text.trim().isEmpty) {
      _showSnackbar('Masukkan ID PDAM yang valid.', isError: true);
      return;
    }
    final newId = _pdamIdController.text.trim();
    
    // 1. Cek Duplikasi Lokal
    if (_pdamIdsFromApi.any((item) => item['nomor'].toString() == newId)) {
      _showSnackbar('ID PDAM "$newId" sudah ada di daftar Anda.', isError: false);
      _pdamIdController.clear();
      if (_selectedPdamId != newId) {
        setState(() => _selectedPdamId = newId);
        _fetchTunggakan(newId);
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null) {
      _showSnackbar('Gagal mendapatkan info pengguna. Silakan login kembali.', isError: true);
      return;
    }
    final userData = jsonDecode(userDataString) as Map<String, dynamic>;
    final int? idPelanggan = userData['id'];
    if (idPelanggan == null) {
      _showSnackbar('ID Pengguna tidak ditemukan. Silakan login kembali.', isError: true);
      return;
    }

    setState(() => _isLoadingTunggakan = true);
    _pdamIdController.clear();
    
    try {
      // 2. Post ke Backend
      final response = await _apiService.postPdamId(newId, idPelanggan.toString());
      if (!mounted) return;

      if (response.containsKey('success') && response['success'] == true) {
         if (response.containsKey('is_existing') && response['is_existing'] == true) {
             _showSnackbar('ID PDAM sudah terdaftar, menampilkan data...', isError: false);
         } else {
             _showSnackbar('ID PDAM berhasil ditambahkan.', isError: false);
         }
         
         await _fetchUserPdamIdsFromApi();
         // Cek apakah ID baru ini menjadi Main ID atau tidak (tergantung logika)
         // Tapi biasanya kita ingin langsung melihat yg baru ditambahkan
         setState(() {
           _selectedPdamId = newId;
         });
         _fetchTunggakan(newId);

      } else if (response.containsKey('errors')) {
        String errorMsg = 'Gagal menyimpan ID: ';
        (response['errors'] as Map).forEach((key, value) {
          if (value is List) errorMsg += value.join(", ");
        });
        _showSnackbar(errorMsg.trim(), isError: true);
        setState(() => _isLoadingTunggakan = false);
      } else {
        _showSnackbar(response['message'] ?? 'Gagal menyimpan ID PDAM.', isError: true);
        setState(() => _isLoadingTunggakan = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Terjadi kesalahan: $e', isError: true);
      setState(() => _isLoadingTunggakan = false);
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.manrope()),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
    ));
  }

  void _showDetailBottomSheet() {
    if (_tunggakanData == null || _tunggakanData!['rincian'] == null) return;
    final List<dynamic> rincian = _tunggakanData!['rincian'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(height: 20),
                  Text("Rincian Tunggakan", style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: rincian.isEmpty 
                      ? Center(child: Text("Tidak ada rincian tersedia", style: GoogleFonts.manrope()))
                      : ListView.separated(
                        controller: controller,
                        itemCount: rincian.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = rincian[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['periode'] ?? '-', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text(item['total'] ?? '0', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0077B6))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Tagihan: ${item['tagihan']}", style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[600])),
                                    Text("Denda: ${item['denda']}", style: GoogleFonts.manrope(fontSize: 13, color: Colors.red[400])),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200], foregroundColor: Colors.black, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: Text("Tutup", style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color backgroundColor = Color(0xFFF8F9FA);
    const Color textColor = Color(0xFF212529);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Cek Tagihan', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoadingApiPdamIds
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                FadeInAnimation(delay: 100, child: _buildCard(child: _buildIdManagementSection())),
                const SizedBox(height: 24),
                FadeInAnimation(delay: 200, child: _buildCard(child: _buildArrearsInfoSection())),
              ],
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF212529)));
  }

  Widget _buildIdManagementSection() {
    // Logika Proteksi UI: Gunakan fungsi helper _isMainId
    bool isProtected = _isMainId(_selectedPdamId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Kelola ID Pelanggan'),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _pdamIdController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.manrope(),
          decoration: _inputDecoration(hintText: 'Masukkan ID PDAM baru', icon: Ionicons.person_add_outline),
        ),
        const SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isLoadingApiPdamIds || _isLoadingTunggakan) ? null : _addAndSelectPdamId,
            icon: const Icon(Ionicons.add_circle_outline, size: 20),
            label: const Text("TAMBAH & CARI"),
            style: _buttonStyle(),
          ),
        ),

        if (_pdamIdsFromApi.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _inputDecoration(hintText: 'Pilih ID Tersimpan', icon: Ionicons.bookmark_outline),
                  value: _pdamIdsFromApi.any((item) => item['nomor'].toString() == _selectedPdamId) ? _selectedPdamId : null,
                  items: _pdamIdsFromApi.map((item) {
                    final id = item['nomor']?.toString() ?? '';
                    // Tanda visual ID Utama
                    bool isItemMain = _isMainId(id);

                    return DropdownMenuItem(
                      value: id,
                      child: Row(
                        children: [
                          Text(id, style: GoogleFonts.manrope(fontWeight: isItemMain ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis),
                          if (isItemMain) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text("Utama", style: GoogleFonts.manrope(fontSize: 10, color: Colors.blue)),
                            )
                          ]
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (_isLoadingTunggakan) ? null : (value) {
                    if (value != null) {
                      setState(() => _selectedPdamId = value);
                      _fetchTunggakan(value);
                    }
                  },
                ),
              ),
              
              const SizedBox(width: 8),

              // Tombol Hapus (Dilindungi)
              Container(
                height: 58, width: 58,
                decoration: BoxDecoration(
                  color: isProtected ? Colors.grey.shade100 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isProtected ? Colors.grey.shade300 : Colors.red.shade200),
                ),
                child: IconButton(
                  icon: Icon(Ionicons.trash_outline, color: isProtected ? Colors.grey.shade400 : Colors.red.shade600),
                  // Disable tombol jika isProtected == true
                  onPressed: (_isLoadingApiPdamIds || _selectedPdamId == null || isProtected) ? null : _deleteCurrentId,
                  tooltip: isProtected ? 'ID Utama tidak dapat dihapus' : 'Hapus ID Terpilih',
                ),
              ),
            ],
          ),
          
          if (isProtected)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 4),
              child: Text("* ID Utama tidak dapat dihapus.", style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
            )
        ],
      ],
    );
  }

  Widget _buildArrearsInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Informasi Tagihan'),
        const Divider(height: 24, thickness: 0.5),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _isLoadingTunggakan
              ? const Center(key: ValueKey('loading'), child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: CircularProgressIndicator(color: Color(0xFF0077B6))))
              : _buildArrearsContent(),
        ),
      ],
    );
  }

  Widget _buildArrearsContent() {
    if (_errorMessage != null) {
      bool isSuccessMessage = _errorMessage!.contains("Selamat!");
      return Center(
        key: const ValueKey('message'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(isSuccessMessage ? Ionicons.happy_outline : Ionicons.information_circle_outline, size: 50, color: isSuccessMessage ? Colors.green.shade600 : Colors.orange.shade600),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 15, color: Colors.grey.shade700)),
            ],
          ),
        ),
      );
    }
    
    if (_tunggakanData != null && _tunggakanData!['jumlah'] > 0) {
      int jumlahBulan = _tunggakanData!['jumlah_bulan'] ?? 0;

      return FadeInAnimation(
        delay: 50, key: const ValueKey('data'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoRow('ID Pelanggan', _tunggakanData!['id_pdam']?.toString() ?? '-'),
            _buildInfoRow('Nama', _tunggakanData!['nama']?.toString() ?? '-'),
            _buildInfoRow('Alamat', _tunggakanData!['alamat']?.toString() ?? '-'),
            _buildInfoRow('Jumlah Bulan Tertunggak', '$jumlahBulan Bulan'),
            const SizedBox(height: 20),
            InkWell(
              onTap: _showDetailBottomSheet, borderRadius: BorderRadius.circular(16),
              child: _buildTotalAmountDisplay(canClick: true),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showSnackbar("Fitur pembayaran akan segera tersedia.", isError: false),
              icon: const Icon(Ionicons.wallet_outline, size: 20),
              label: Text('BAYAR SEKARANG', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              style: _buttonStyle(isPrimary: false),
            ),
          ],
        ),
      );
    }
    return Center(
      key: const ValueKey('empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text('Pilih atau tambahkan ID untuk melihat tagihan.', style: GoogleFonts.manrope(fontSize: 15, color: Colors.grey.shade700), textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: GoogleFonts.manrope(color: Colors.grey.shade700, fontSize: 14))),
          Expanded(flex: 6, child: Text(value, textAlign: TextAlign.right, style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 15))),
        ],
      ),
    );
  }

  Widget _buildTotalAmountDisplay({bool canClick = false}) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color secondaryColor = Color(0xFF00B4D8);
    String formattedAmount = (_tunggakanData!['jumlah'] ?? 0).toString();
    try {
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
      formattedAmount = formatter.format(_tunggakanData!['jumlah']);
    } catch (e) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [primaryColor, secondaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: canClick ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Tagihan', style: GoogleFonts.manrope(fontSize: 16, color: Colors.white)),
              if (canClick)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Text("Lihat Rincian", style: GoogleFonts.manrope(fontSize: 10, color: Colors.white)),
                      const SizedBox(width: 4),
                      const Icon(Ionicons.chevron_forward, color: Colors.white, size: 10)
                    ],
                  ),
                )
            ],
          ),
          const SizedBox(height: 4),
          Text('Rp $formattedAmount,-', style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Segera lakukan pembayaran untuk menghindari denda tambahan.', style: GoogleFonts.manrope(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText, required IconData icon}) {
    return InputDecoration(
      hintText: hintText, hintStyle: GoogleFonts.manrope(color: Colors.grey.shade500),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0077B6), width: 1.5)),
      filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  ButtonStyle _buttonStyle({bool isPrimary = true}) {
    const Color primaryColor = Color(0xFF0077B6);
    return ElevatedButton.styleFrom(
      backgroundColor: isPrimary ? primaryColor : Colors.green.shade600, foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14), elevation: 2,
    );
  }
}