// lib/calon_pelanggan_register_page.dart
// ignore_for_file: unused_field, use_build_context_synchronously

import 'dart:async';
import 'dart:developer' show log;
import 'dart:math' show cos, sqrt, asin, pi, sin;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/cabang_model.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image/image.dart' as img;

class CalonPelangganRegisterPage extends StatefulWidget {
  const CalonPelangganRegisterPage({super.key});

  @override
  State<CalonPelangganRegisterPage> createState() =>
      _CalonPelangganRegisterPageState();
}

class _CalonPelangganRegisterPageState
    extends State<CalonPelangganRegisterPage> {
  // --- Keys & Controllers ---
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  // Step 1 Controllers
  final _namaController = TextEditingController();
  final _noKtpController = TextEditingController();
  final _alamatKtpController = TextEditingController();
  final _noWaController = TextEditingController();
  final _pekerjaanController = TextEditingController();
  final _jumlahJiwaController = TextEditingController();

  // Step 2 Controllers
  final _provinsiController = TextEditingController(text: 'JAWA BARAT');
  final _kabupatenKotaController = TextEditingController(text: 'INDRAMAYU');
  final _deskripsiAlamatController = TextEditingController();
  final _cabangController = TextEditingController();

  // State Variables
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Location & Dropdown Data
  List<dynamic> _kecamatanOptions = [];
  List<dynamic> _desaOptions = [];
  String? _selectedKecamatanCode;
  String? _selectedKecamatanName;
  String? _selectedDesaName;
  bool _isKecamatanLoading = true;
  bool _isDesaLoading = false;

  // Cabang (Branch) Logic
  List<Cabang> _allCabangs = [];
  int? _selectedCabangId;
  String? _cabangByKecamatanName;
  String? _cabangByGpsName;
  String? _nearestBranchError;

  // GPS & Address
  bool _isLocationLoading = false;
  String? _gpsCoordinates;
  String? _detectedKabupatenKota;

  // Image Files for Step 3
  File? _imageFileKtp;
  File? _imageFileRumah;
  final _picker = ImagePicker();

  // --- KECAMATAN TO CABANG MAPPING (LOGIC IS PRESERVED) ---
  final Map<String, int> _kecamatanToCabangMapping = {
    'ANJATAN': 13,
    'ARAHAN': 12,
    'BALONGAN': 14,
    'BANGODUA': 9,
    'BONGAS': 11,
    'CANTIGI': 12,
    'CIKEDUNG': 7,
    'GABUSWETAN': 11,
    'GANTAR': 13,
    'HAURGEULIS': 11,
    'INDRAMAYU': 1,
    'JATIBARANG': 4,
    'JUNTINYUAT': 8,
    'KANDANGHAUR': 6,
    'KARANGAMPEL': 8,
    'KEDOKAN BUNDER': 5,
    'KERTASEMAYA': 5,
    'KRANGKENG': 8,
    'KROYA': 11,
    'LELEA': 7,
    'LOHBENER': 7,
    'LOSARANG': 2,
    'PASEKAN': 1,
    'PATROL': 6,
    'SINDANG': 3,
    'SLIYEG': 10,
    'SUKAGUMIWANG': 10,
    'SUKRA': 6,
    'TERISI': 7,
    'TUKDANA': 9,
    'WIDASARI': 4,
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
    _pageController.dispose();
    _namaController.dispose();
    _noKtpController.dispose();
    _alamatKtpController.dispose();
    _noWaController.dispose();
    _pekerjaanController.dispose();
    _jumlahJiwaController.dispose();
    _provinsiController.dispose();
    _kabupatenKotaController.dispose();
    _deskripsiAlamatController.dispose();
    _cabangController.dispose();
    super.dispose();
  }

  // --- DATA LOADING ---
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchKecamatan(),
      _fetchCabangOptions(),
      _getCurrentLocationAndAddress(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- NAVIGATION LOGIC ---
  void _nextPage() {
    bool isStepValid = false;
    switch (_currentPage) {
      case 0:
        isStepValid = _formKeyStep1.currentState?.validate() ?? false;
        break;
      case 1:
        isStepValid = _formKeyStep2.currentState?.validate() ?? false;
        if (isStepValid && _gpsCoordinates == null) {
          _showSnackbar(
              'Lokasi GPS belum didapatkan. Mohon aktifkan GPS dan coba lagi.',
              isError: true);
          isStepValid = false;
        }
        break;
      case 2:
        if (_imageFileKtp == null || _imageFileRumah == null) {
          _showSnackbar('Harap unggah kedua dokumen yang diperlukan.',
              isError: true);
        } else {
          isStepValid = true;
        }
        break;
    }

    if (isStepValid) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // --- All original feature methods are preserved below ---
  // (e.g., _fetchKecamatan, _fetchCabangOptions, _getCurrentLocationAndAddress, _pickImage, etc.)

  Future<void> _fetchCabangOptions() async {
    try {
      final options = await _apiService.getCabangList();
      if (mounted) setState(() => _allCabangs = options);
    } catch (e) {
      log('Error fetching cabang options: $e');
      _showSnackbar('Gagal memuat daftar cabang: $e', isError: true);
    }
  }

  Future<void> _fetchKecamatan() async {
    setState(() => _isKecamatanLoading = true);
    try {
      final List<dynamic> kecamatanData =
          await _apiService.getKecamatanIndramayu();
      if (mounted) setState(() => _kecamatanOptions = kecamatanData);
    } catch (e) {
      log('Error tertangkap di _fetchKecamatan: $e');
      _showSnackbar('Gagal memuat data kecamatan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isKecamatanLoading = false);
    }
  }

  Future<void> _fetchDesa(String kecamatanCode) async {
    setState(() {
      _isDesaLoading = true;
      _desaOptions = [];
      _selectedDesaName = null;
    });
    try {
      final List<dynamic> desaData = await _apiService.getDesa(kecamatanCode);
      if (mounted) setState(() => _desaOptions = desaData);
    } catch (e) {
      _showSnackbar('Gagal memuat data desa: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDesaLoading = false);
    }
  }

  Future<void> _getCurrentLocationAndAddress() async {
    setState(() {
      _isLocationLoading = true;
      _deskripsiAlamatController.text = 'Mencari lokasi...';
      _nearestBranchError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled)
        throw Exception('Layanan lokasi tidak aktif. Mohon aktifkan GPS Anda.');

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
        timeLimit: const Duration(seconds: 15),
      );

      setState(
          () => _gpsCoordinates = '${position.latitude},${position.longitude}');

      final String fullAddressString = await _apiService
          .getAddressFromCoordinates(position.latitude, position.longitude);
      _detectedKabupatenKota = _extractKabupatenKota(fullAddressString);

      if (mounted) {
        setState(() => _deskripsiAlamatController.text = fullAddressString);
        _showSnackbar('Lokasi dan Alamat berhasil didapatkan.', isError: false);
      }
      _findNearestBranch(
          position.latitude, position.longitude, _detectedKabupatenKota);
    } catch (e) {
      final errorMessage = e.toString().replaceFirst("Exception: ", "");
      if (mounted) {
        log('Error getting location: $e');
        _showSnackbar('Gagal mendapatkan lokasi: $errorMessage', isError: true);
        setState(() {
          _deskripsiAlamatController.text = 'Gagal mendapatkan lokasi.';
          _nearestBranchError = 'Kesalahan sistem lokasi.';
          _gpsCoordinates = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  String _extractKabupatenKota(String fullAddress) {
    final regex = RegExp(r'Kab\.?\s*([A-Za-z\s]+)', caseSensitive: false);
    final match = regex.firstMatch(fullAddress);
    if (match != null && match.groupCount >= 1) return match.group(1)!.trim();
    return fullAddress.toLowerCase().contains('indramayu')
        ? 'Indramayu'
        : 'Tidak Diketahui';
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * (2 * asin(sqrt(a)));
  }

  void _findNearestBranch(
      double currentLat, double currentLon, String? detectedKabupatenKota) {
    if (_allCabangs.isEmpty) {
      setState(() => _nearestBranchError = 'Tidak ada data cabang.');
      return;
    }
    if (detectedKabupatenKota == null ||
        !detectedKabupatenKota.toUpperCase().contains('INDRAMAYU')) {
      setState(() => _nearestBranchError =
          'Pendaftaran hanya di wilayah Kabupaten Indramayu.');
      return;
    }

    Cabang? nearestBranch;
    double minDistance = double.infinity;
    for (var cabang in _allCabangs) {
      if (cabang.latitude != null && cabang.longitude != null) {
        double distance = _calculateDistance(
            currentLat, currentLon, cabang.latitude!, cabang.longitude!);
        if (distance < minDistance) {
          minDistance = distance;
          nearestBranch = cabang;
        }
      }
    }

    if (mounted) setState(() => _cabangByGpsName = nearestBranch?.namaCabang);
  }

  void _updateCabangBasedOnKecamatan(String kecamatanName) {
    final cabangId = _kecamatanToCabangMapping[kecamatanName.toUpperCase()];
    if (cabangId != null) {
      final selectedCabang = _allCabangs.firstWhere((c) => c.id == cabangId,
          orElse: () => Cabang(id: 0, namaCabang: ''));
      setState(() {
        _cabangByKecamatanName = selectedCabang.namaCabang;
        _selectedCabangId = selectedCabang.id;
        _cabangController.text = selectedCabang.namaCabang;
        _nearestBranchError = null;
      });
    } else {
      setState(() {
        _cabangByKecamatanName = null;
        _selectedCabangId = null;
        _cabangController.text = '';
        _nearestBranchError = 'Wilayah kerja cabang tidak ditemukan.';
      });
    }
  }

  Future<void> _pickImage(ImageSource source, {required bool isKtp}) async {
    final pickedFile = await _picker.pickImage(source: source);
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
            Text("Memproses gambar..."),
          ]),
        ),
      ),
    );

    try {
      File file = File(pickedFile.path);
      final imageBytes = await file.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null)
        throw Exception('Format gambar tidak didukung.');

      img.Image resizedImage =
          (originalImage.width > 1280 || originalImage.height > 1280)
              ? img.copyResize(originalImage,
                  width: 1280, interpolation: img.Interpolation.average)
              : originalImage;

      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      final tempFile = File(
          '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}.jpg')
        ..writeAsBytesSync(compressedBytes);

      setState(() {
        if (isKtp)
          _imageFileKtp = tempFile;
        else
          _imageFileRumah = tempFile;
      });
    } catch (e) {
      _showSnackbar('Gagal memproses gambar: $e');
    } finally {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submitRegistration() async {
    // Final validation before submitting
    if (_imageFileKtp == null ||
        _imageFileRumah == null ||
        _gpsCoordinates == null ||
        _selectedCabangId == null) {
      _showSnackbar('Data belum lengkap. Harap periksa kembali semua langkah.',
          isError: true);
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final data = {
        'id_cabang': _selectedCabangId.toString(),
        'nama_lengkap': _namaController.text,
        'no_ktp': _noKtpController.text,
        'provinsi': _provinsiController.text,
        'kabupaten_kota': _kabupatenKotaController.text,
        'kecamatan': _selectedKecamatanName ?? '',
        'desa_kelurahan': _selectedDesaName ?? '',
        'alamat': _gpsCoordinates!,
        'alamat_ktp': _alamatKtpController.text,
        'deskripsi_alamat': _deskripsiAlamatController.text,
        'no_wa': _noWaController.text,
        'pekerjaan': _pekerjaanController.text,
        'jumlah_jiwa': _jumlahJiwaController.text,
      };

      final responseData = await _apiService.registerCalonPelanggan(
        data: data,
        imagePathKtp: _imageFileKtp!.path,
        imagePathRumah: _imageFileRumah!.path,
      );
      _showSuccessDialog(responseData['data']?['tracking_code']);
    } catch (e) {
      _showSnackbar(
          'Pendaftaran Gagal: ${e.toString().replaceFirst("Exception: ", "")}',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- UI WIDGETS ---
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0077B6);
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Pendaftaran Pelanggan Baru',
          style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    children: [
                      _buildStep1PersonalData(),
                      _buildStep2Address(),
                      _buildStep3Documents(),
                      _buildStep4Confirmation(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildNavigationButtons(primaryColor),
    );
  }

  // UPDATED WIDGET: Stepper is now clickable
  Widget _buildStepper(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          bool isActive = index <= _currentPage;
          bool isClickable = index < _currentPage;

          return Expanded(
            child: GestureDetector(
              onTap:
                  isClickable ? () => _pageController.jumpToPage(index) : null,
              child: MouseRegion(
                cursor: isClickable
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          isActive ? primaryColor : Colors.grey.shade300,
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
              ),
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
                  : (_currentPage == 3 ? _submitRegistration : _nextPage),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
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
                      _currentPage == 3 ? 'Daftar Sekarang' : 'Selanjutnya',
                      style: GoogleFonts.manrope(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 1: PERSONAL DATA ---
  Widget _buildStep1PersonalData() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'Langkah 1: Data Pribadi', Ionicons.person_outline),
            _buildTextField(
                controller: _namaController,
                label: 'Nama Lengkap (sesuai KTP)',
                hint: 'Masukkan nama lengkap',
                validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null),
            _buildTextField(
                controller: _noKtpController,
                label: 'Nomor KTP (16 digit)',
                hint: 'Masukkan 16 digit NIK',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16)
                ],
                validator: (v) =>
                    v!.length != 16 ? 'NIK harus 16 digit' : null),
            _buildTextField(
                controller: _noWaController,
                label: 'Nomor WhatsApp Aktif',
                hint: 'Contoh: 08123456789',
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Nomor WA wajib diisi' : null),
            _buildTextField(
                controller: _pekerjaanController,
                label: 'Pekerjaan',
                hint: 'Contoh: Karyawan Swasta',
                validator: (v) => v!.isEmpty ? 'Pekerjaan wajib diisi' : null),
            _buildTextField(
                controller: _jumlahJiwaController,
                label: 'Jumlah Jiwa dalam Satu Rumah',
                hint: 'Contoh: 4',
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v!.isEmpty ? 'Jumlah Jiwa wajib diisi' : null),
            _buildTextField(
                controller: _alamatKtpController,
                label: 'Alamat Sesuai KTP',
                hint: 'Masukkan alamat lengkap KTP',
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Alamat KTP wajib diisi' : null),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: ADDRESS ---
  Widget _buildStep2Address() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKeyStep2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'Langkah 2: Alamat Pemasangan', Ionicons.location_outline),
            _buildGpsStatusCard(),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _provinsiController,
                label: 'Provinsi',
                readOnly: true),
            _buildTextField(
                controller: _kabupatenKotaController,
                label: 'Kabupaten/Kota',
                readOnly: true),
            _buildKecamatanDropdown(),
            const SizedBox(height: 16),
            _buildDesaDropdown(),
            const SizedBox(height: 16),
            _buildCabangSelectionField(),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _deskripsiAlamatController,
                label: 'Alamat Lengkap Pemasangan',
                hint: 'Jalan, No. Rumah, RT/RW',
                maxLines: 3,
                validator: (v) =>
                    v!.isEmpty ? 'Alamat pemasangan wajib diisi' : null),
          ],
        ),
      ),
    );
  }

  // --- STEP 3: DOCUMENTS ---
  Widget _buildStep3Documents() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'Langkah 3: Unggah Dokumen', Ionicons.document_attach_outline),
          _buildImageUploadCard(
            title: 'Foto KTP',
            subtitle: 'Pastikan foto jelas dan tidak buram.',
            imageFile: _imageFileKtp,
            onTap: () => _showImageSourceActionSheet(context, isKtp: true),
          ),
          const SizedBox(height: 20),
          _buildImageUploadCard(
            title: 'Foto Tampak Depan Lokasi',
            subtitle: 'Sertakan nomor rumah jika ada.',
            imageFile: _imageFileRumah,
            onTap: () => _showImageSourceActionSheet(context, isKtp: false),
          ),
        ],
      ),
    );
  }

  // --- STEP 4: CONFIRMATION ---
  Widget _buildStep4Confirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Langkah 4: Konfirmasi Data Anda',
              Ionicons.checkmark_done_outline),
          Text(
            'Mohon periksa kembali semua data yang telah Anda masukkan sebelum mengirim pendaftaran. Pastikan semuanya sudah benar.',
            style: GoogleFonts.manrope(color: Colors.grey.shade700),
          ),
          const Divider(height: 32),
          _buildConfirmationSection("Data Pribadi", [
            _buildConfirmationRow("Nama Lengkap", _namaController.text),
            _buildConfirmationRow("No. KTP", _noKtpController.text),
            _buildConfirmationRow("No. WhatsApp", _noWaController.text),
            _buildConfirmationRow("Pekerjaan", _pekerjaanController.text),
            _buildConfirmationRow("Jumlah Jiwa", _jumlahJiwaController.text),
            _buildConfirmationRow("Alamat KTP", _alamatKtpController.text),
          ]),
          const Divider(height: 32),
          _buildConfirmationSection("Alamat Pemasangan", [
            _buildConfirmationRow("Kecamatan", _selectedKecamatanName ?? '-'),
            _buildConfirmationRow("Desa/Kelurahan", _selectedDesaName ?? '-'),
            _buildConfirmationRow(
                "Alamat Lengkap", _deskripsiAlamatController.text),
            _buildConfirmationRow("Koordinat GPS", _gpsCoordinates ?? '-'),
            _buildConfirmationRow("Cabang Dipilih", _cabangController.text),
          ]),
          const Divider(height: 32),
          _buildConfirmationSection("Dokumen", [
            _buildConfirmationRow("Foto KTP",
                _imageFileKtp != null ? "Terunggah" : "Belum diunggah",
                isFile: true, file: _imageFileKtp),
            _buildConfirmationRow("Foto Lokasi",
                _imageFileRumah != null ? "Terunggah" : "Belum diunggah",
                isFile: true, file: _imageFileRumah),
          ]),
        ],
      ),
    );
  }

  // --- UI HELPER WIDGETS (Styled like home_pelanggan_page) ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0077B6), size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF212529),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        readOnly: readOnly,
        validator: validator,
        style: GoogleFonts.manrope(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.manrope(color: Colors.grey.shade600),
          hintText: hint,
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
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
            borderSide: const BorderSide(color: Color(0xFF0077B6), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildKecamatanDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedKecamatanCode,
      hint: Text(_isKecamatanLoading ? 'Memuat...' : 'Pilih Kecamatan'),
      isExpanded: true,
      decoration: _dropdownDecoration('Kecamatan'),
      style: GoogleFonts.manrope(),
      onChanged: _isKecamatanLoading
          ? null
          : (value) {
              if (value != null) {
                final selectedItem = _kecamatanOptions
                    .firstWhere((k) => k['code'] == value, orElse: () => {});
                if (selectedItem.isNotEmpty) {
                  setState(() {
                    _selectedKecamatanCode = selectedItem['code'];
                    _selectedKecamatanName = selectedItem['name'];
                    _updateCabangBasedOnKecamatan(selectedItem['name']);
                  });
                  _fetchDesa(value);
                }
              }
            },
      items: _kecamatanOptions
          .map((kec) => DropdownMenuItem<String>(
                value: kec['code'].toString(),
                child: Text(kec['name'],
                    style: GoogleFonts.manrope(color: Colors.black87)),
              ))
          .toList(),
      validator: (v) => v == null ? 'Kecamatan wajib dipilih' : null,
    );
  }

  Widget _buildDesaDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDesaName,
      hint: Text(_isDesaLoading ? 'Memuat...' : 'Pilih Desa/Kelurahan'),
      isExpanded: true,
      decoration: _dropdownDecoration('Desa/Kelurahan'),
      style: GoogleFonts.manrope(),
      onChanged: _selectedKecamatanCode == null || _isDesaLoading
          ? null
          : (value) {
              if (value != null) setState(() => _selectedDesaName = value);
            },
      items: _desaOptions
          .map((desa) => DropdownMenuItem<String>(
                value: desa['name'],
                child: Text(desa['name'],
                    style: GoogleFonts.manrope(color: Colors.black87)),
              ))
          .toList(),
      validator: (v) => v == null ? 'Desa wajib dipilih' : null,
    );
  }

  Widget _buildCabangSelectionField() {
    return TextFormField(
      controller: _cabangController,
      readOnly: true,
      style: GoogleFonts.manrope(),
      decoration: _dropdownDecoration('Cabang Pemasangan').copyWith(
          hintText: 'Pilih Kecamatan dulu',
          suffixIcon: const Icon(Icons.arrow_drop_down)),
      onTap: () {
        if (_allCabangs.isNotEmpty && _selectedKecamatanName != null) {
          _showCabangSelectionDialog();
        } else {
          _showSnackbar(
              'Harap pilih Kecamatan untuk melihat rekomendasi cabang.',
              isError: true);
        }
      },
      validator: (v) => v!.isEmpty ? 'Cabang wajib dipilih' : null,
    );
  }

  Future<void> _showCabangSelectionDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pilih Cabang Pemasangan',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REKOMENDASI SISTEM',
                        style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue.shade800)),
                    const Divider(),
                    if (_cabangByGpsName != null)
                      Text('• Menurut Lokasi: $_cabangByGpsName',
                          style: GoogleFonts.manrope(fontSize: 13)),
                    if (_cabangByKecamatanName != null)
                      Text('• Menurut Kecamatan: $_cabangByKecamatanName',
                          style: GoogleFonts.manrope(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Pilih Cabang Manual:', style: GoogleFonts.manrope()),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allCabangs.length,
                  itemBuilder: (context, index) {
                    final cabang = _allCabangs[index];
                    return ListTile(
                      title:
                          Text(cabang.namaCabang, style: GoogleFonts.manrope()),
                      selected: cabang.id == _selectedCabangId,
                      selectedTileColor: Colors.blue.shade100,
                      onTap: () {
                        setState(() {
                          _selectedCabangId = cabang.id;
                          _cabangController.text = cabang.namaCabang;
                        });
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'))
        ],
      ),
    );
  }

  Widget _buildGpsStatusCard() {
    Color cardColor = _isLocationLoading
        ? Colors.amber.shade50
        : (_gpsCoordinates != null ? Colors.green.shade50 : Colors.red.shade50);
    Color borderColor = _isLocationLoading
        ? Colors.amber.shade200
        : (_gpsCoordinates != null
            ? Colors.green.shade200
            : Colors.red.shade200);
    Color iconColor = _isLocationLoading
        ? Colors.amber.shade700
        : (_gpsCoordinates != null
            ? Colors.green.shade700
            : Colors.red.shade700);
    IconData icon = _isLocationLoading
        ? Ionicons.location_sharp
        : (_gpsCoordinates != null
            ? Ionicons.checkmark_circle
            : Ionicons.warning);
    String title = _isLocationLoading
        ? "Mencari Lokasi..."
        : (_gpsCoordinates != null
            ? "Lokasi Ditemukan!"
            : "Lokasi Belum Ditemukan");
    String subtitle = _cabangByGpsName != null
        ? "Cabang terdekat: $_cabangByGpsName"
        : (_nearestBranchError ?? "Pastikan GPS Anda aktif");

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor)),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                Text(subtitle, style: GoogleFonts.manrope(fontSize: 13)),
              ],
            ),
          ),
          if (_isLocationLoading)
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }

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

  Widget _buildConfirmationRow(String label, String value,
      {bool isFile = false, File? file}) {
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
            child: isFile && file != null
                ? Row(children: [
                    Icon(Ionicons.checkmark_circle,
                        color: Colors.green.shade600, size: 18),
                    const SizedBox(width: 4),
                    Text(value,
                        style:
                            GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                  ])
                : Text(value,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
        ],
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

  void _showImageSourceActionSheet(BuildContext context,
      {required bool isKtp}) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Ionicons.image_outline),
            title: Text('Galeri', style: GoogleFonts.manrope()),
            onTap: () {
              _pickImage(ImageSource.gallery, isKtp: isKtp);
              Navigator.of(ctx).pop();
            },
          ),
          ListTile(
            leading: const Icon(Ionicons.camera_outline),
            title: Text('Kamera', style: GoogleFonts.manrope()),
            onTap: () {
              _pickImage(ImageSource.camera, isKtp: isKtp);
              Navigator.of(ctx).pop();
            },
          ),
        ]),
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

  // UPDATED WIDGET: Success dialog is now bigger and interactive
  // UPDATED WIDGET: Success dialog is now bigger and interactive
  void _showSuccessDialog(String? trackingCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // PINDAHKAN DEKLARASI VARIABEL KE SINI
        // Variabel ini akan "hidup" selama dialog ditampilkan dan tidak akan di-reset.
        bool isCodeCopied = false;

        // StatefulBuilder tetap digunakan untuk memperbarui UI di dalam dialog
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            // SEBELUMNYA ADA DI SINI (INI YANG SALAH)
            // bool isCodeCopied = false;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Pendaftaran Berhasil!',
                  style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold, fontSize: 22)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width *
                    0.8, // Make dialog wider
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terima kasih! Simpan KODE PELACAKAN ini untuk memeriksa status pendaftaran Anda.',
                      style: GoogleFonts.manrope(
                          fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    if (trackingCode != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                trackingCode,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    letterSpacing: 2),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Ionicons.copy_outline),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: trackingCode));
                                _showSnackbar('Kode disalin!', isError: false);
                                // Update state di dalam dialog untuk mengaktifkan tombol OK
                                stfSetState(() {
                                  isCodeCopied = true;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Salin kode di atas untuk mengaktifkan tombol OK.',
                      style: GoogleFonts.manrope(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  // Tombol akan aktif/nonaktif berdasarkan status isCodeCopied
                  onPressed: isCodeCopied
                      ? () {
                          Navigator.of(dialogContext).pop(); // Tutup dialog
                          Navigator.of(context)
                              .pop(); // Kembali dari halaman pendaftaran
                        }
                      : null,
                  child: Text('OK',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
