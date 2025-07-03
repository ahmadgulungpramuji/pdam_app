// lib/cek_tunggakan_page.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:animate_do/animate_do.dart';

class CekTunggakanPage extends StatefulWidget {
  const CekTunggakanPage({super.key});

  @override
  State<CekTunggakanPage> createState() => _CekTunggakanPageState();
}

class _CekTunggakanPageState extends State<CekTunggakanPage> {
  // =========================================================================
  // == SEMUA LOGIKA STATE DAN CONTROLLER TETAP SAMA (TIDAK DIUBAH) ==
  // =========================================================================
  final ApiService _apiService = ApiService();
  final TextEditingController _pdamIdController = TextEditingController();

  List<dynamic> _pdamIdsFromApi = [];
  String? _selectedPdamId;
  Map<String, dynamic>? _tunggakanData;
  bool _isLoadingApiPdamIds = true;
  bool _isLoadingTunggakan = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserPdamIdsFromApi();
  }

  @override
  void dispose() {
    _pdamIdController.dispose();
    super.dispose();
  }

  // ========================================================================
  // == SEMUA FUNGSI LOGIC (fetch, add, dll) TETAP SAMA (TIDAK DIUBAH)  ==
  // ========================================================================
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
      final idsFromApi = await _apiService.getAllUserPdamIds();
      if (!mounted) return;

      setState(() {
        _pdamIdsFromApi = idsFromApi;
        _isLoadingApiPdamIds = false;
        if (_pdamIdsFromApi.isNotEmpty) {
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
    if (_pdamIdsFromApi.any((item) => item['nomor'].toString() == newId)) {
      _showSnackbar('ID PDAM "$newId" sudah terdaftar.', isError: false);
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
      _showSnackbar('Gagal mendapatkan info pengguna. Silakan login kembali.',
          isError: true);
      return;
    }
    final userData = jsonDecode(userDataString) as Map<String, dynamic>;
    final int? idPelanggan = userData['id'];
    if (idPelanggan == null) {
      _showSnackbar('ID Pengguna tidak ditemukan. Silakan login kembali.',
          isError: true);
      return;
    }
    setState(() => _isLoadingTunggakan = true);
    _pdamIdController.clear();
    try {
      final response = await _apiService.postPdamId(newId, idPelanggan.toString());
      if (!mounted) return;
      if (response.containsKey('data') && response['data'] != null) {
        _showSnackbar('ID PDAM berhasil disimpan.', isError: false);
        _fetchUserPdamIdsFromApi();
      } else if (response.containsKey('errors')) {
        String errorMsg = 'Gagal menyimpan ID: ';
        (response['errors'] as Map).forEach((key, value) {
          errorMsg += (value as List).join(", ");
        });
        _showSnackbar(errorMsg.trim(), isError: true);
        setState(() => _isLoadingTunggakan = false);
      } else {
        _showSnackbar(response['message'] ?? 'Gagal menyimpan ID PDAM.',
            isError: true);
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
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(10),
    ));
  }
  
  // =========================================================================
  // == BAGIAN BUILD WIDGET (UI) YANG DIDESAIN ULANG ==
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoadingApiPdamIds
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildHeader(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildIdManagementSection(),
                        const SizedBox(height: 24),
                        _buildArrearsInfoSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 180.0,
      pinned: true,
      backgroundColor: const Color(0xFF004D40),
      foregroundColor: Colors.white,
      elevation: 2,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text('Cek Tagihan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF004D40)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Opacity(
            opacity: 0.1,
            child: Icon(Ionicons.receipt_outline,
                size: 150, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title,
      required IconData icon,
      required Widget child,
      required int delay}) {
    return FadeInUp(
      from: 20,
      duration: const Duration(milliseconds: 500),
      delay: Duration(milliseconds: delay),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF00695C), size: 22),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildIdManagementSection() {
    return _buildSectionCard(
      title: 'Kelola ID Pelanggan',
      icon: Ionicons.person_add_outline,
      delay: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tambahkan atau pilih ID Pelanggan yang terdaftar di akun Anda.',
              style: GoogleFonts.lato(color: Colors.grey[600])),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pdamIdController,
                  decoration: InputDecoration(
                    labelText: 'ID PDAM Baru',
                    hintText: 'Masukkan ID...',
                    prefixIcon: const Icon(Ionicons.person_circle_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (_isLoadingApiPdamIds || _isLoadingTunggakan)
                    ? null
                    : _addAndSelectPdamId,
                style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: const Color(0xFF00695C)),
                child: const Icon(Ionicons.add, color: Colors.white),
              ),
            ],
          ),
          if (_pdamIdsFromApi.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Pilih ID Tersimpan',
                prefixIcon: const Icon(Ionicons.bookmark_outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              value: _pdamIdsFromApi.any((item) => item['nomor'].toString() == _selectedPdamId)
                  ? _selectedPdamId
                  : null,
              items: _pdamIdsFromApi.map((item) {
                final id = item['nomor']?.toString() ?? '';
                return DropdownMenuItem(value: id, child: Text(id));
              }).toList(),
              onChanged: (_isLoadingTunggakan)
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedPdamId = value);
                        _fetchTunggakan(value);
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArrearsInfoSection() {
    return _buildSectionCard(
      title: 'Informasi Tagihan',
      icon: Ionicons.receipt_outline,
      delay: 200,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _isLoadingTunggakan
            ? const Center(heightFactor: 3, child: CircularProgressIndicator())
            : _buildArrearsContent(),
      ),
    );
  }

  Widget _buildArrearsContent() {
    if (_errorMessage != null) {
      bool isSuccessMessage = _errorMessage!.contains("Selamat!");
      return Center(
        heightFactor: 2.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSuccessMessage ? Ionicons.checkmark_circle_outline : Ionicons.information_circle_outline,
                size: 40, color: isSuccessMessage ? Colors.green : Colors.orange),
            const SizedBox(height: 8),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[700])),
          ],
        ),
      );
    }
    if (_tunggakanData != null && _tunggakanData!.isNotEmpty) {
      return FadeIn(
        duration: const Duration(milliseconds: 400),
        child: Column(
          children: [
            _buildInfoRow(Ionicons.person_circle_outline, 'ID Pelanggan',
                _tunggakanData!['id_pdam']?.toString() ?? '-'),
            _buildInfoRow(Ionicons.calendar_outline, 'Periode Tagihan',
                _tunggakanData!['bulan']?.toString() ?? '-'),
            _buildInfoRow(Ionicons.alarm_outline, 'Jatuh Tempo',
                _tunggakanData!['jatuh_tempo']?.toString() ?? '-'),
            const Divider(height: 24),
            _buildTotalAmountRow(),
            const SizedBox(height: 16),
            if ((_tunggakanData!['jumlah'] ?? 0) > 0)
              ElevatedButton.icon(
                onPressed: () => _showSnackbar(
                    "Fitur pembayaran akan segera tersedia.",
                    isError: false),
                icon: const Icon(Ionicons.wallet_outline, color: Colors.white),
                label: const Text("BAYAR SEKARANG"),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      );
    }
    return Center(
      heightFactor: 3,
      child: Text('Pilih atau tambahkan ID untuk melihat tagihan.',
          style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[700])),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text('$label:', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.lato(fontSize: 15, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTotalAmountRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF00695C).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Tagihan',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          Text(
              'Rp ${(_tunggakanData!['jumlah'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00695C))),
        ],
      ),
    );
  }
}