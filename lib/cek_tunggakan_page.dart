// lib/cek_tunggakan_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// --- WIDGET ANIMASI (Disalin dari home_pelanggan_page.dart) ---
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
  // == SEMUA FUNGSI LOGIC (fetch, add, dll) TETAP SAMA (TIDAK DIUBAH)  ==
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
      final response =
          await _apiService.postPdamId(newId, idPelanggan.toString());
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
      content: Text(message, style: GoogleFonts.manrope()),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
    ));
  }

  // =========================================================================
  // == BAGIAN BUILD WIDGET (UI) YANG DIDESAIN ULANG SESUAI GAYA BERANDA  ==
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color backgroundColor = Color(0xFFF8F9FA);
    const Color textColor = Color(0xFF212529);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Cek Tagihan',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoadingApiPdamIds
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                FadeInAnimation(
                  delay: 100,
                  child: _buildCard(
                    child: _buildIdManagementSection(),
                  ),
                ),
                const SizedBox(height: 24),
                FadeInAnimation(
                  delay: 200,
                  child: _buildCard(
                    child: _buildArrearsInfoSection(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF212529)),
    );
  }

  Widget _buildIdManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Kelola ID Pelanggan'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pdamIdController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.manrope(),
          decoration: _inputDecoration(
            hintText: 'Masukkan ID PDAM baru',
            icon: Ionicons.person_add_outline,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isLoadingApiPdamIds || _isLoadingTunggakan)
                ? null
                : _addAndSelectPdamId,
            icon: const Icon(Ionicons.add_circle_outline, size: 20),
            label: const Text("TAMBAH & CARI"),
            style: _buttonStyle(),
          ),
        ),
        if (_pdamIdsFromApi.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: _inputDecoration(
              hintText: 'Pilih ID Tersimpan',
              icon: Ionicons.bookmark_outline,
            ),
            value: _pdamIdsFromApi
                    .any((item) => item['nomor'].toString() == _selectedPdamId)
                ? _selectedPdamId
                : null,
            items: _pdamIdsFromApi.map((item) {
              final id = item['nomor']?.toString() ?? '';
              return DropdownMenuItem(
                value: id,
                child: Text(id, style: GoogleFonts.manrope()),
              );
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
              ? const Center(
                  key: ValueKey('loading'),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Color(0xFF0077B6)),
                  ),
                )
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
              Icon(
                isSuccessMessage
                    ? Ionicons.happy_outline
                    : Ionicons.information_circle_outline,
                size: 50,
                color: isSuccessMessage
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                    fontSize: 15, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }
    if (_tunggakanData != null && _tunggakanData!['jumlah'] > 0) {
      return FadeInAnimation(
        delay: 50,
        key: const ValueKey('data'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoRow(
                'ID Pelanggan', _tunggakanData!['id_pdam']?.toString() ?? '-'),
            _buildInfoRow('Nama', _tunggakanData!['nama']?.toString() ?? '-'),
            _buildInfoRow(
                'Periode', _tunggakanData!['bulan']?.toString() ?? '-'),
            _buildInfoRow('Jatuh Tempo',
                _tunggakanData!['jatuh_tempo']?.toString() ?? '-'),
            const SizedBox(height: 20),
            _buildTotalAmountDisplay(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showSnackbar(
                  "Fitur pembayaran akan segera tersedia.",
                  isError: false),
              icon: const Icon(Ionicons.wallet_outline, size: 20),
              label: Text('BAYAR SEKARANG',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
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
        child: Text(
          'Pilih atau tambahkan ID untuk melihat tagihan.',
          style: GoogleFonts.manrope(fontSize: 15, color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                GoogleFonts.manrope(color: Colors.grey.shade700, fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAmountDisplay() {
    const Color primaryColor = Color(0xFF0077B6);
    const Color secondaryColor = Color(0xFF00B4D8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Tagihan',
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rp ${(_tunggakanData!['jumlah'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')},-',
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total tagihan di atas belum termasuk: Retribusi Kebersihan, PMI, dan biaya admin Bank.',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hintText, required IconData icon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.manrope(color: Colors.grey.shade500),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0077B6), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  ButtonStyle _buttonStyle({bool isPrimary = true}) {
    const Color primaryColor = Color(0xFF0077B6);
    return ElevatedButton.styleFrom(
      backgroundColor: isPrimary ? primaryColor : Colors.green.shade600,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14),
      elevation: 2,
    );
  }
}
