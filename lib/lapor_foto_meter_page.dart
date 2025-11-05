import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdam_app/api_service.dart'; // Sesuaikan path
import 'package:pdam_app/models/cabang_model.dart'; // Pastikan Anda punya model ini
import 'package:google_fonts/google_fonts.dart';

// --- DEFINISI TEMA WARNA ELEGAN ---
const Color elegantPrimaryColor = Color(0xFF2C3E50); // Biru Gelap Keabuan
const Color elegantSecondaryColor = Color(0xFF3498DB); // Biru Terang
const Color elegantBackgroundColor = Color(0xFFF8F9FA); // Putih Gading
const Color elegantTextColor = Color(0xFF34495E); // Abu-abu Tua
const Color elegantBorderColor = Color(0xFFEAECEF); // Abu-abu Sangat Terang

class LaporFotoMeterPage extends StatefulWidget {
  const LaporFotoMeterPage({super.key});

  @override
  State<LaporFotoMeterPage> createState() => _LaporFotoMeterPageState();
}

class _LaporFotoMeterPageState extends State<LaporFotoMeterPage> with SingleTickerProviderStateMixin {
  // --- Blok Variabel & Controller (TIDAK BERUBAH) ---
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _komentarController = TextEditingController();
  final _cabangController = TextEditingController();

  List<String> _pdamIds = [];
  List<Cabang> _daftarCabang = [];
  String? _selectedPdamId;
  int? _selectedCabangId;
  File? _imageFile;

  bool _isLoading = false;
  bool _isFetchingInitialData = true;
  String? _fetchError;

  late AnimationController _cameraButtonAnimationController;
  late Animation<double> _scaleAnimation;

  // --- Blok Logika & State Management (TIDAK BERUBAH) ---
  @override
  void initState() {
    super.initState();
    _fetchInitialData();

    _cameraButtonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _cameraButtonAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _komentarController.dispose();
    _cabangController.dispose();
    _cameraButtonAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isFetchingInitialData = true);
    try {
      final responses = await Future.wait([
        _apiService.getAllUserPdamIds(),
        _apiService.getCabangList(),
      ]);

      final pdamData = responses[0];
      final cabangData = responses[1] as List<Cabang>;

      if (mounted) {
        setState(() {
          _pdamIds = pdamData.map((item) => item['nomor'].toString()).toList();
          _daftarCabang = cabangData;
          _isFetchingInitialData = false;
        });
      }
   } catch (e) {
      if (mounted) {
        // --- AWAL PERUBAHAN ---
        String errorMessage;
        if (e is SocketException) {
          errorMessage = 'Periksa koneksi internet Anda. Gagal memuat data awal.';
        } else if (e is TimeoutException) {
          errorMessage = 'Koneksi timeout. Gagal memuat data awal.';
        } else {
          errorMessage = 'Gagal memuat data awal: ${e.toString().replaceFirst("Exception: ", "")}';
        }
        setState(() {
          _fetchError = errorMessage;
          _isFetchingInitialData = false;
        });
        // --- AKHIR PERUBAHAN ---
      }
    }
  }

  void _updateCabangOtomatis(String? nomorPdam) {
    if (nomorPdam == null || nomorPdam.length < 2) {
      setState(() {
        _selectedPdamId = null;
        _selectedCabangId = null;
        _cabangController.clear();
      });
      return;
    }

    final duaDigit = nomorPdam.substring(0, 2);
    int? idCabang;

    switch (duaDigit) {
      case '10': idCabang = 1; break;
      case '12': idCabang = 2; break;
      case '15': idCabang = 3; break;
      case '20': idCabang = 4; break;
      case '30': idCabang = 5; break;
      case '40': idCabang = 6; break;
      case '50': idCabang = 7; break;
      case '60': idCabang = 8; break;
      default: idCabang = null;
    }

    setState(() {
      _selectedPdamId = nomorPdam;
      _selectedCabangId = idCabang;
      if (idCabang != null) {
        final cabangTerpilih = _daftarCabang.firstWhere(
          (c) => c.id == idCabang,
          orElse: () => Cabang(id: 0, namaCabang: 'Cabang Tidak Dikenali'),
        );
        _cabangController.text = cabangTerpilih.namaCabang;
      } else {
        _cabangController.text = 'Cabang tidak terpetakan';
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackbar('Gagal mengambil gambar: $e', isError: true);
    }
  }

  Future<void> _submitLaporan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      _showSnackbar('Mohon unggah foto water meter.', isError: true);
      return;
    }
    if (_selectedCabangId == null) {
      _showSnackbar('Cabang tidak valid atau tidak terpilih.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.submitLaporanFotoWaterMeter(
        idPdam: _selectedPdamId!,
        idCabang: _selectedCabangId!,
        imagePath: _imageFile!.path,
        komentar: _komentarController.text,
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        _showSnackbar('Laporan berhasil dikirim!', isError: false);
        if (mounted) Navigator.of(context).pop();
      } else {
        final message = responseBody['message'] ?? 'Terjadi kesalahan.';
        _showSnackbar('Gagal: $message', isError: true);
      }
    } catch (e) {
      // --- AWAL PERUBAHAN ---
      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'Periksa koneksi internet Anda. Laporan gagal dikirim.';
      } else if (e is TimeoutException) {
        errorMessage = 'Koneksi timeout. Laporan gagal dikirim.';
      } else {
        errorMessage = 'Terjadi kesalahan: ${e.toString().replaceFirst("Exception: ", "")}';
      }
      _showSnackbar(errorMessage, isError: true);
      // --- AKHIR PERUBAHAN ---
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  // --- Blok UI (YANG DIMODIFIKASI LEBIH ELEGAN) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: elegantBackgroundColor,
      appBar: _buildElegantAppBar(),
      body: _isFetchingInitialData
          ? const Center(child: CircularProgressIndicator(color: elegantPrimaryColor))
          : _fetchError != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    _fetchError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.red.shade800),
                  ),
                ))
              : _buildForm(),
    );
  }

  AppBar _buildElegantAppBar() {
    return AppBar(
      title: Text(
        'Lapor Foto Meter',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: elegantTextColor,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0, // Desain flat
      iconTheme: const IconThemeData(color: elegantTextColor),
      // Garis bawah tipis sebagai pemisah
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: elegantBorderColor,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Grup 1: Informasi Pelanggan
          _buildSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'Informasi Pelanggan',
          ),
          _buildDropdownPdamId(),
          const SizedBox(height: 16),
          _buildCabangDisplayField(),
          const SizedBox(height: 32),

          // Grup 2: Unggah Foto
          _buildSectionHeader(
            icon: Icons.camera_alt_outlined,
            title: 'Foto Water Meter',
          ),
          _buildImageUploadSection(),
          const SizedBox(height: 32),

          // Grup 3: Catatan
          _buildSectionHeader(
            icon: Icons.edit_outlined,
            title: 'Catatan Tambahan',
            subtitle: '(Opsional)',
          ),
          _buildKomentarField(),
          const SizedBox(height: 40),

          // Tombol Submit
          _buildSubmitButton(),
        ],
      ),
    );
  }
  
  // Widget baru untuk header seksi, lebih ringan dari Card
  Widget _buildSectionHeader({required IconData icon, required String title, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: elegantPrimaryColor, size: 22),
          const SizedBox(width: 12),
          Text(title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: elegantTextColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
              ),
            ),
          ]
        ],
      ),
    );
  }

  // --- Widget Builders untuk Form dengan Style Elegan ---

  Widget _buildDropdownPdamId() {
    return DropdownButtonFormField<String>(
      value: _selectedPdamId,
      hint: Text('Pilih Nomor ID Pelanggan Anda', style: GoogleFonts.poppins()),
      items: _pdamIds.map((id) => DropdownMenuItem(value: id, child: Text(id, style: GoogleFonts.poppins()))).toList(),
      onChanged: _updateCabangOtomatis,
      validator: (value) => value == null ? 'Mohon pilih ID PDAM' : null,
      decoration: _elegantInputDecoration(
        labelText: 'Nomor ID Pelanggan PDAM',
        prefixIcon: Icons.person_search_outlined,
      ),
      isExpanded: true,
    );
  }

  Widget _buildCabangDisplayField() {
    return TextFormField(
      controller: _cabangController,
      readOnly: true,
      decoration: _elegantInputDecoration(
        labelText: 'Cabang Terdeteksi',
        prefixIcon: Icons.location_on_outlined,
      ).copyWith(
        fillColor: Colors.grey.shade100, // Sedikit berbeda untuk status read-only
      ),
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: elegantPrimaryColor,
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          clipBehavior: Clip.antiAlias, // Penting untuk border radius pada child
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: elegantBorderColor, width: 1.5),
          ),
          child: _imageFile != null
              ? Image.file(_imageFile!, fit: BoxFit.cover)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera_back_outlined, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('Belum ada foto yang diunggah', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: OutlinedButton.icon(
              onPressed: () {
                _cameraButtonAnimationController.forward().then((_) => _cameraButtonAnimationController.reverse());
                _pickImage(ImageSource.camera);
              },
              icon: Icon(_imageFile == null ? Icons.camera_alt_outlined : Icons.sync_outlined),
              label: Text(
                _imageFile == null ? 'Buka Kamera' : 'Ambil Foto Ulang',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: elegantPrimaryColor,
                side: const BorderSide(color: elegantPrimaryColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildKomentarField() {
    return TextFormField(
      controller: _komentarController,
      decoration: _elegantInputDecoration(
        hintText: 'Tulis catatan jika ada...',
        prefixIcon: Icons.notes_outlined,
      ).copyWith(
        alignLabelWithHint: true,
      ),
      maxLines: 4,
      keyboardType: TextInputType.multiline,
      style: GoogleFonts.poppins(),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [elegantSecondaryColor, elegantPrimaryColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: elegantSecondaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitLaporan,
        icon: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
        label: Text(
          _isLoading ? 'Mengirim...' : 'Kirim Laporan',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
  
  // Helper untuk standardisasi decoration input field
  InputDecoration _elegantInputDecoration({String? labelText, String? hintText, IconData? prefixIcon}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade500) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // Hilangkan border default
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: elegantBorderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: elegantPrimaryColor, width: 2),
      ),
    );
  }
}