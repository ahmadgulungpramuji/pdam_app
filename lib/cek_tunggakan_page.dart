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
  // == BAGIAN BUILD WIDGET (UI) YANG DIDESAIN ULANG (TEMA BIRU & PUTIH) ==
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang putih
      appBar: AppBar(
        title: Text(
          'Cek Tagihan PDAM',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.blue.shade800,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoadingApiPdamIds
          ? Center(child: CircularProgressIndicator(color: Colors.blue.shade700))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(
                    delay: const Duration(milliseconds: 100),
                    child: _buildIdManagementSection(),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _buildArrearsInfoSection(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }

  Widget _buildIdManagementSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Kelola ID Pelanggan'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pdamIdController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Masukkan ID PDAM baru...',
              prefixIcon: const Icon(Ionicons.person_outline, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.blue.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              label: const Text("TAMBAH ID"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_pdamIdsFromApi.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Pilih ID Tersimpan',
                prefixIcon: const Icon(Ionicons.bookmark_outline, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.blue.shade50,
              ),
              value: _pdamIdsFromApi.any((item) => item['nomor'].toString() == _selectedPdamId)
                  ? _selectedPdamId
                  : null,
              items: _pdamIdsFromApi.map((item) {
                final id = item['nomor']?.toString() ?? '';
                return DropdownMenuItem(
                  value: id,
                  child: Text(id, style: GoogleFonts.lato()),
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
      ),
    );
  }

  Widget _buildArrearsInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informasi Tagihan'),
          const Divider(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _isLoadingTunggakan
                ? Center(
                    key: const ValueKey('loading'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: Colors.blue.shade700),
                    ),
                  )
                : _buildArrearsContent(),
          ),
        ],
      ),
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
                isSuccessMessage ? Ionicons.checkmark_circle_outline : Ionicons.information_circle_outline,
                size: 50,
                color: isSuccessMessage ? Colors.green.shade600 : Colors.orange.shade600,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(fontSize: 16, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }
    if (_tunggakanData != null && _tunggakanData!.isNotEmpty) {
      return FadeIn(
        key: const ValueKey('data'),
        duration: const Duration(milliseconds: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoRow('ID Pelanggan', _tunggakanData!['id_pdam']?.toString() ?? '-'),
            _buildInfoRow('Nama', _tunggakanData!['nama']?.toString() ?? '-'),
            _buildInfoRow('Periode', _tunggakanData!['bulan']?.toString() ?? '-'),
            _buildInfoRow('Jatuh Tempo', _tunggakanData!['jatuh_tempo']?.toString() ?? '-'),
            const SizedBox(height: 20),
            _buildTotalAmountRow(),
            const SizedBox(height: 20),
            if ((_tunggakanData!['jumlah'] ?? 0) > 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showSnackbar(
                      "Fitur pembayaran akan segera tersedia.",
                      isError: false),
                  icon: const Icon(Ionicons.wallet_outline, size: 20),
                  label: Text(
                    'BAYAR SEKARANG',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
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
          style: GoogleFonts.lato(fontSize: 16, color: Colors.grey.shade700),
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
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAmountRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Tagihan',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'Rp ${(_tunggakanData!['jumlah'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade200,
            ),
          ),
        ],
      ),
    );
  }
}