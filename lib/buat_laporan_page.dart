// lib/buat_laporan_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdam_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image/image.dart' as img;

class BuatLaporanPage extends StatefulWidget {
  const BuatLaporanPage({super.key});

  @override
  State<BuatLaporanPage> createState() => _BuatLaporanPageState();
}

class _BuatLaporanPageState extends State<BuatLaporanPage> {
  // --- Controllers & Keys ---
  final _pageController = PageController();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  final _deskripsiController = TextEditingController();
  final _deskripsiLokasiManualController = TextEditingController();
  final _kategoriLainnyaController = TextEditingController();
  final ApiService _apiService = ApiService();

  // --- State Variables ---
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Data Laporan
  String? _loggedInPelangganId;
  List<String> _pdamIdNumbersList = [];
  String? _selectedPdamIdNumber;
  int? _selectedCabangId;
  String? _selectedJenisLaporan;
  Position? _currentPosition;
  File? _fotoBuktiFile;
  File? _fotoRumahFile;

  final List<Map<String, String>> _jenisLaporanOptions = [
    {'value': 'air_tidak_mengalir', 'label': 'Air Tidak Mengalir'},
    {'value': 'air_keruh', 'label': 'Air Keruh'},
    {'value': 'water_meter_rusak', 'label': 'Meteran Rusak'},
    {'value': 'angka_meter_tidak_sesuai', 'label': 'Angka Meter Tidak Sesuai'},
    {'value': 'tagihan_membengkak', 'label': 'Tagihan Membengkak'},
    {'value': 'lain_lain', 'label': 'Lain-lain...'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deskripsiController.dispose();
    _deskripsiLokasiManualController.dispose();
    _kategoriLainnyaController.dispose();
    super.dispose();
  }

  // --- Navigation ---
  void _nextPage() {
    bool isStepValid = false;
    if (_currentPage == 0) {
      isStepValid = _step1FormKey.currentState?.validate() ?? false;
    } else if (_currentPage == 1) {
      isStepValid = _step2FormKey.currentState?.validate() ?? false;
    } else if (_currentPage == 2) {
      if (_fotoBuktiFile == null || _fotoRumahFile == null) {
        _showSnackbar('Mohon unggah kedua foto yang diperlukan.',
            isError: true);
        isStepValid = false;
      } else {
        isStepValid = _step3FormKey.currentState?.validate() ?? false;
      }
    }

    if (isStepValid) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  // --- Data Loading and Processing (All features preserved) ---
  Future<void> _loadInitialData() async {
    await _getLoggedInPelangganId();
    await _getCurrentLocationAndAddress();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _getLoggedInPelangganId() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      final pelangganId = userData['id']?.toString();
      if (mounted) {
        _loggedInPelangganId = pelangganId;
        if (pelangganId != null) await _fetchPdamIds(pelangganId);
      }
    } else {
      _showSnackbar('Data pengguna tidak ditemukan. Harap login kembali.',
          isError: true);
    }
  }

  Future<void> _fetchPdamIds(String idPelanggan) async {
    try {
      final pdamNumbers =
          await _apiService.fetchPdamNumbersByPelanggan(idPelanggan);
      if (mounted) setState(() => _pdamIdNumbersList = pdamNumbers);
    } catch (e) {
      _showSnackbar('Gagal mengambil daftar nomor PDAM: $e', isError: true);
    }
  }

  Future<void> _getCurrentLocationAndAddress() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Layanan lokasi tidak aktif.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Izin lokasi ditolak.');
      }
      if (permission == LocationPermission.deniedForever)
        throw Exception('Izin lokasi ditolak permanen.');

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15));
      setState(() => _currentPosition = position);

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude,
          localeIdentifier: 'id_ID');
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        String address =
            "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.subAdministrativeArea ?? ''}"
                .trim();
        setState(() => _deskripsiLokasiManualController.text =
            address.startsWith(',') ? address.substring(2) : address);
      }
    } catch (e) {
      _showSnackbar(
          'Gagal mendapatkan lokasi: ${e.toString().replaceFirst("Exception: ", "")}',
          isError: true);
    }
  }

  void _onPdamNumberChanged(String? value) {
    setState(() {
      _selectedPdamIdNumber = value;
      _selectedCabangId = null;
      if (value != null && value.length >= 2) {
        final duaDigit = value.substring(0, 2);
        const Map<String, int> cabangMapping = {
          '10': 1,
          '12': 2,
          '15': 3,
          '20': 4,
          '30': 5,
          '40': 6,
          '50': 7,
          '60': 8
        };
        _selectedCabangId = cabangMapping[duaDigit];
      }
    });
  }

  Future<File?> _compressAndGetFile(File file) async {
    final imageBytes = await file.readAsBytes();
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) return null;
    img.Image resizedImage =
        (originalImage.width > 1280 || originalImage.height > 1280)
            ? img.copyResize(originalImage, width: 1280)
            : originalImage;
    final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
    final tempDir = Directory.systemTemp;
    final tempFile =
        File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg')
          ..writeAsBytesSync(compressedBytes);
    return tempFile;
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Dialog(
          child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Memproses...")
              ]))),
    );

    try {
      final compressedFile = await _compressAndGetFile(File(pickedFile.path));
      if (compressedFile != null) {
        setState(() {
          if (type == 'bukti')
            _fotoBuktiFile = compressedFile;
          else if (type == 'rumah') _fotoRumahFile = compressedFile;
        });
      } else {
        _showSnackbar('Format gambar tidak didukung.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Gagal memproses gambar: $e', isError: true);
    } finally {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submitLaporan() async {
    setState(() => _isSubmitting = true);
    try {
      Map<String, String> dataLaporan = {
        'id_pelanggan': _loggedInPelangganId!,
        'id_pdam': _selectedPdamIdNumber!,
        'id_cabang': _selectedCabangId.toString(),
        'kategori': _selectedJenisLaporan!,
        'latitude': _currentPosition!.latitude.toString(),
        'longitude': _currentPosition!.longitude.toString(),
        'lokasi_maps':
            'http://maps.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}',
        'deskripsi_lokasi': _deskripsiLokasiManualController.text,
        'deskripsi': _deskripsiController.text,
      };

      if (_selectedJenisLaporan == 'lain_lain') {
        dataLaporan['kategori_lainnya'] = _kategoriLainnyaController.text;
      }

      final response = await _apiService.buatPengaduan(dataLaporan,
          fotoBukti: _fotoBuktiFile, fotoRumah: _fotoRumahFile);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSuccessDialog();
      } else {
        final responseData = jsonDecode(response.body);
        throw Exception(responseData['message'] ?? 'Error tidak diketahui');
      }
    } catch (e) {
      _showSnackbar(
          'Gagal mengirim laporan: ${e.toString().replaceFirst("Exception: ", "")}',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Ionicons.arrow_back), onPressed: _previousPage),
        title: Text('Buat Laporan',
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                _buildStepper(primaryColor),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    children: [
                      _buildStep1InfoDasar(),
                      _buildStep2Lokasi(),
                      _buildStep3DeskripsiFoto(),
                      _buildStep4Konfirmasi(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildNavigationButtons(primaryColor),
    );
  }

  // --- UI HELPER WIDGETS (Styled) ---
  Widget _buildStepper(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Row(
        children: List.generate(4, (index) {
          bool isActive = index <= _currentPage;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      isActive ? primaryColor : Colors.grey.shade300,
                  child: Text('${index + 1}',
                      style: GoogleFonts.manrope(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                if (index < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isActive ? primaryColor : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          if (_currentPage > 0 && !_isSubmitting)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: primaryColor),
                ),
                child: Text('Kembali',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentPage == 0 ? 2 : 1,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : (_currentPage == 3 ? _submitLaporan : _nextPage),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _currentPage == 3 ? Colors.green : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3))
                  : Text(
                      _currentPage == 3 ? 'KIRIM LAPORAN' : 'Selanjutnya',
                      style: GoogleFonts.manrope(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0077B6), size: 28),
          const SizedBox(width: 12),
          Text(title,
              style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF212529))),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: GoogleFonts.manrope(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.manrope(color: Colors.grey.shade600),
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0077B6), width: 2)),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.manrope(color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0077B6), width: 2)),
    );
  }

  // --- Step Widgets (Refactored) ---
  Widget _buildStep1InfoDasar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'Langkah 1: Informasi Dasar', Ionicons.document_text_outline),
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration('Pilih Nomor Pelanggan (NSL)'),
              items: _pdamIdNumbersList
                  .map((pdamNum) => DropdownMenuItem(
                      value: pdamNum,
                      child: Text(pdamNum, style: GoogleFonts.manrope())))
                  .toList(),
              value: _selectedPdamIdNumber,
              onChanged: _onPdamNumberChanged,
              validator: (v) =>
                  v == null ? 'Nomor Pelanggan wajib dipilih' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration('Pilih Jenis Laporan'),
              items: _jenisLaporanOptions
                  .map((opt) => DropdownMenuItem(
                      value: opt['value'],
                      child: Text(opt['label']!, style: GoogleFonts.manrope())))
                  .toList(),
              value: _selectedJenisLaporan,
              onChanged: (v) => setState(() => _selectedJenisLaporan = v),
              validator: (v) =>
                  v == null ? 'Jenis Laporan wajib dipilih' : null,
            ),
            if (_selectedJenisLaporan == 'lain_lain')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: _buildTextField(
                    controller: _kategoriLainnyaController,
                    label: 'Sebutkan Jenis Laporan Anda',
                    hint: 'Contoh: Pipa bocor di depan rumah',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Wajib diisi jika memilih Lain-lain'
                        : null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Lokasi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'Langkah 2: Detail Lokasi', Ionicons.map_outline),
            _buildTextField(
                controller: _deskripsiLokasiManualController,
                label: 'Alamat Detail Lokasi (Otomatis/Manual)',
                hint: 'Pastikan alamat sudah akurat',
                maxLines: 3,
                validator: (v) =>
                    v!.isEmpty ? 'Deskripsi lokasi wajib diisi' : null),
            Container(
              height: 45,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.white,
              ),
              child: TextButton.icon(
                icon: const Icon(Ionicons.navigate_circle_outline,
                    color: Color(0xFF0077B6)),
                label: Text("Perbarui Lokasi GPS Saat Ini",
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0077B6))),
                onPressed: _getCurrentLocationAndAddress,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3DeskripsiFoto() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'Langkah 3: Detail & Bukti', Ionicons.camera_outline),
            _buildTextField(
              controller: _deskripsiController,
              label: 'Deskripsi Lengkap Laporan',
              hint: 'Jelaskan detail keluhan Anda di sini...',
              maxLines: 5,
              validator: (v) => v!.isEmpty ? 'Deskripsi wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            _buildImageUploadCard(
              title: 'Foto Bukti Laporan',
              subtitle: 'Wajib ambil dari kamera langsung',
              imageFile: _fotoBuktiFile,
              onTap: () => _pickImage(
                  ImageSource.camera, 'bukti'), // Logic preserved: Camera only
            ),
            const SizedBox(height: 20),
            _buildImageUploadCard(
              title: 'Foto Rumah (Tampak Depan)',
              subtitle: 'Bisa dari galeri atau kamera',
              imageFile: _fotoRumahFile,
              onTap: () => _showImageSourceActionSheet(
                // Logic preserved: Camera or Gallery
                (source) => _pickImage(source, 'rumah'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Konfirmasi() {
    String jenisLaporanLabel = _jenisLaporanOptions.firstWhere(
        (e) => e['value'] == _selectedJenisLaporan,
        orElse: () => {'label': '-'})['label']!;
    if (_selectedJenisLaporan == 'lain_lain') {
      jenisLaporanLabel = 'Lain-lain: ${_kategoriLainnyaController.text}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'Langkah 4: Konfirmasi Laporan', Ionicons.checkmark_done_outline),
          Text(
            'Mohon periksa kembali semua data yang akan Anda kirim. Pastikan semuanya sudah benar.',
            style: GoogleFonts.manrope(color: Colors.grey.shade700),
          ),
          const Divider(height: 32),
          _buildConfirmationSection("Informasi Laporan", [
            _buildConfirmationRow(
                "Nomor Pelanggan", _selectedPdamIdNumber ?? '-'),
            _buildConfirmationRow("Jenis Laporan", jenisLaporanLabel),
            _buildConfirmationRow("Deskripsi", _deskripsiController.text),
          ]),
          const Divider(height: 32),
          _buildConfirmationSection("Informasi Lokasi", [
            _buildConfirmationRow(
                "Alamat Detail", _deskripsiLokasiManualController.text),
            _buildConfirmationRow("Koordinat GPS",
                "${_currentPosition?.latitude.toStringAsFixed(6)}, ${_currentPosition?.longitude.toStringAsFixed(6)}"),
          ]),
          const Divider(height: 32),
          _buildConfirmationSection("Dokumen Pendukung", [
            _buildConfirmationRow("Foto Bukti",
                _fotoBuktiFile != null ? "Terunggah" : "Tidak ada"),
            _buildConfirmationRow("Foto Rumah",
                _fotoRumahFile != null ? "Terunggah" : "Tidak ada"),
          ]),
        ],
      ),
    );
  }

  // Refactored & New UI Helper Widgets
  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required File? imageFile,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            image: imageFile != null
                ? DecorationImage(
                    image: FileImage(imageFile), fit: BoxFit.cover)
                : null,
          ),
          child: imageFile == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Ionicons.camera_outline,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(title,
                        style: GoogleFonts.manrope(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        textAlign: TextAlign.center,
                        style:
                            GoogleFonts.manrope(color: Colors.grey.shade600)),
                  ],
                )
              : Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(title,
                        style: GoogleFonts.manrope(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
        ),
      ),
    );
  }

  void _showImageSourceActionSheet(Function(ImageSource) onSelected) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Ionicons.camera_outline),
            title: Text('Kamera', style: GoogleFonts.manrope()),
            onTap: () {
              Navigator.pop(ctx);
              onSelected(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Ionicons.image_outline),
            title: Text('Galeri', style: GoogleFonts.manrope()),
            onTap: () {
              Navigator.pop(ctx);
              onSelected(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildConfirmationSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: GoogleFonts.manrope(color: Colors.grey.shade600))),
          Expanded(
              flex: 3,
              child: Text(value,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Laporan Terkirim!',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(
            'Terima kasih. Laporan Anda telah kami terima dan akan segera diproses.',
            style: GoogleFonts.manrope()),
        actions: [
          TextButton(
            child: Text('OK',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
