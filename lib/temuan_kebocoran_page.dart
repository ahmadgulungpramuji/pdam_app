// lib/pages/temuan_kebocoran_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdam_app/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdam_app/models/cabang_model.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class TemuanKebocoranPage extends StatefulWidget {
  const TemuanKebocoranPage({super.key});

  @override
  State<TemuanKebocoranPage> createState() => _TemuanKebocoranPageState();
}

class _TemuanKebocoranPageState extends State<TemuanKebocoranPage> {
  // --- Controllers & Keys ---
  final _pageController = PageController();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>(); // <-- Perubahan: Key untuk form langkah 3

  final ApiService _apiService = ApiService();
  late String _apiUrlSubmit;

  final TextEditingController _deskripsiLokasiController =
      TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nomorHpController = TextEditingController();
  final TextEditingController _deskripsiLaporanController =
      TextEditingController();

  // --- State Variables ---
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  int? _selectedCabangId;
  List<Cabang> _cabangOptionsApi = [];
  bool _isCabangLoading = true;
  String? _cabangError;
  String? _detectedCabangName;

  Position? _currentPosition;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isImageProcessing = false;

  @override
  void initState() {
    super.initState();
    _apiUrlSubmit = '${_apiService.baseUrl}/temuan-kebocoran';
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deskripsiLokasiController.dispose();
    _namaController.dispose();
    _nomorHpController.dispose();
    _deskripsiLaporanController.dispose();
    super.dispose();
  }

  // --- Navigation ---
  void _nextPage() {
    bool isStepValid = false;
    if (_currentPage == 0) {
      isStepValid = _step1FormKey.currentState?.validate() ?? false;
    } else if (_currentPage == 1) {
      isStepValid = _step2FormKey.currentState?.validate() ?? false;
      if (isStepValid && _currentPosition == null) {
        _showSnackbar('Lokasi GPS belum didapatkan.', isError: true);
        isStepValid = false;
      }
    } else if (_currentPage == 2) {
      // <-- Perubahan: Validasi untuk langkah 3
      isStepValid = _step3FormKey.currentState?.validate() ?? false;
      if (isStepValid && _imageFile == null) {
        _showSnackbar('Foto bukti wajib diunggah.', isError: true);
        isStepValid = false;
      }
    }

    if (isStepValid) {
      if (_currentPage < 3) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
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

  // --- Core Logic ---
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchCabangOptions();
    await _getCurrentLocation();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchCabangOptions() async {
    setState(() {
      _isCabangLoading = true;
      _cabangError = null;
    });
    try {
      final List<Cabang> cabangList = await _apiService
          .getCabangList()
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() => _cabangOptionsApi = cabangList);
      if (_currentPosition != null) _findNearestBranch();
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _cabangError = 'Gagal memuat data cabang: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isCabangLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Layanan lokasi tidak aktif.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak permanen.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude,
          localeIdentifier: 'id_ID');

      if (mounted) {
        setState(() {
          _currentPosition = position;
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            String formattedAddress =
                "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.subAdministrativeArea ?? ''}"
                    .trim();
            _deskripsiLokasiController.text = formattedAddress.startsWith(',')
                ? formattedAddress.substring(2)
                : formattedAddress;
          }
        });
        _showSnackbar('Lokasi berhasil didapatkan!', isError: false);
        _findNearestBranch();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(e.toString().replaceFirst("Exception: ", ""),
            isError: true);
      }
    }
  }

  void _findNearestBranch() {
    if (_cabangOptionsApi.isEmpty || _currentPosition == null) return;

    int? nearestBranchId;
    String? nearestBranchName;
    double minDistance = double.infinity;

    for (var cabang in _cabangOptionsApi) {
      if (cabang.latitude != null && cabang.longitude != null) {
        final double distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            cabang.latitude!,
            cabang.longitude!);
        if (distance < minDistance) {
          minDistance = distance;
          nearestBranchId = cabang.id;
          nearestBranchName = cabang.namaCabang;
        }
      }
    }

    if (mounted && nearestBranchId != null) {
      setState(() {
        _selectedCabangId = nearestBranchId;
        _detectedCabangName = nearestBranchName;
      });
      _showSnackbar('Cabang terdekat ($nearestBranchName) otomatis terdeteksi.',
          isError: false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isImageProcessing = true);
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        final originalImage = img.decodeImage(imageBytes);
        if (originalImage == null) throw Exception('Gagal memproses gambar');

        final watermarkedImage = img.copyResize(originalImage, width: 800);
        final now = DateTime.now();
        img.drawString(
            watermarkedImage,
            '${now.hour}:${now.minute} - ${now.day}/${now.month}/${now.year}',
            x: 10,
            y: 10,
            color: img.ColorRgb8(255, 255, 255),
            font: img.arial24);

        final directory = await getTemporaryDirectory();
        final newPath = path.join(
            directory.path, 'watermarked_${path.basename(pickedFile.path)}');
        await File(newPath)
            .writeAsBytes(img.encodeJpg(watermarkedImage, quality: 90));

        setState(() => _imageFile = XFile(newPath));
      }
    } catch (e) {
      if (mounted) _showSnackbar('Gagal memproses gambar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isImageProcessing = false);
    }
  }

  Future<void> _openGoogleMaps(double latitude, double longitude) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        _showSnackbar('Tidak dapat membuka Google Maps: $e', isError: true);
      }
    }
  }

  Future<void> _submitForm() async {
    if (_imageFile == null ||
        _currentPosition == null ||
        _selectedCabangId == null) {
      _showSnackbar('Pastikan semua data pada langkah sebelumnya sudah benar.',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrlSubmit));
      request.fields.addAll({
        'nama_pelapor': _namaController.text.trim(),
        'nomor_hp_pelapor': _nomorHpController.text.trim(),
        'deskripsi': _deskripsiLaporanController.text.trim(),
        'id_cabang': _selectedCabangId.toString(),
        'lokasi_maps':
            '${_currentPosition!.latitude},${_currentPosition!.longitude}',
        'deskripsi_lokasi': _deskripsiLokasiController.text.trim(),
      });

      request.files.add(
          await http.MultipartFile.fromPath('foto_bukti', _imageFile!.path));

      var res = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await res.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _showSuccessDialog(
            responseData['data']?['tracking_code'] as String? ?? 'N/A');
      } else {
        _showSnackbar(responseData['message'] ?? 'Gagal mengirim data',
            isError: true);
      }
    } catch (e) {
      _showSnackbar('Terjadi kesalahan: ${e.toString()}', isError: true);
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
        title: Text('Lapor Temuan Kebocoran',
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
                      _buildStep1InfoPelapor(),
                      _buildStep2Lokasi(),
                      _buildStep3Bukti(),
                      _buildStep4Confirmation(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildNavigationButtons(primaryColor),
    );
  }

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
                  : (_currentPage == 3 ? _submitForm : _nextPage),
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
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
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
              borderSide:
                  const BorderSide(color: Color(0xFF0077B6), width: 2)),
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
          borderSide:
              const BorderSide(color: Color(0xFF0077B6), width: 2)),
    );
  }

  Widget _buildStep1InfoPelapor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'Langkah 1: Informasi Pelapor', Ionicons.person_circle_outline),
            _buildTextField(
                controller: _namaController,
                label: 'Nama Lengkap Anda',
                hint: 'Masukkan nama lengkap',
                validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null),
            _buildTextField(
                controller: _nomorHpController,
                label: 'Nomor HP Aktif',
                hint: 'Contoh: 08123456789',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    v!.length < 10 ? 'Nomor HP minimal 10 digit' : null),
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
            SizedBox( // <-- Perubahan: Peta Statis Dihapus
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Ionicons.map, color: Colors.white, size: 20),
                label: Text(
                  'Buka Detail di Google Maps',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0077B6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _currentPosition == null
                    ? null
                    : () {
                        _openGoogleMaps(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        );
                      },
              ),
            ),
            Center(
                child: TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text("Ambil Ulang Lokasi"),
                    onPressed: _isLoading ? null : _getCurrentLocation)),
            if (_isCabangLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator()))
            else if (_cabangError != null)
              Center(
                  child: Text(_cabangError!,
                      style: const TextStyle(color: Colors.red)))
            else
              DropdownButtonFormField<int>(
                value: _selectedCabangId,
                hint: const Text('Pilih Cabang Pelaporan'),
                decoration: _dropdownDecoration(_detectedCabangName != null
                    ? "Cabang Terdeteksi Otomatis"
                    : 'Pilih Cabang Manual'),
                items: _cabangOptionsApi
                    .map((c) => DropdownMenuItem(
                        value: c.id,
                        child:
                            Text(c.namaCabang, style: GoogleFonts.manrope())))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedCabangId = value;
                  _detectedCabangName = null;
                }),
                validator: (v) => v == null ? 'Pilih cabang pelaporan' : null,
              ),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _deskripsiLokasiController,
                label: 'Deskripsi Detail Lokasi',
                hint: 'Misal: Depan toko X, dekat jembatan Y',
                maxLines: 3,
                validator: (v) =>
                    v!.isEmpty ? 'Deskripsi lokasi wajib diisi' : null),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3Bukti() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form( // <-- Perubahan: Dibungkus Form
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'Langkah 3: Bukti & Deskripsi', Ionicons.camera_outline), // <-- Judul diubah
            if (_isImageProcessing)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator()))
            else
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pickImage(ImageSource.camera),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 1.5),
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(File(_imageFile!.path)),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _imageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Ionicons.camera_outline,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('Ambil Foto Kebocoran',
                                  style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('Foto diperlukan sebagai bukti laporan',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                      color: Colors.grey.shade600)),
                            ],
                          )
                        : Align(
                            alignment: Alignment.topRight,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Ionicons.close,
                                    color: Colors.white, size: 20),
                                onPressed: () =>
                                    setState(() => _imageFile = null),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            const SizedBox(height: 24), // Spasi
            _buildTextField( // <-- Perubahan: TextField dipindahkan ke sini
                controller: _deskripsiLaporanController,
                label: 'Deskripsi Laporan',
                hint: 'Jelaskan secara singkat apa yang terjadi',
                maxLines: 4,
                validator: (v) =>
                    v!.isEmpty ? 'Deskripsi laporan wajib diisi' : null),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Confirmation() {
    String cabangName = _cabangOptionsApi
        .firstWhere((c) => c.id == _selectedCabangId,
            orElse: () => Cabang(id: 0, namaCabang: "Tidak Dipilih"))
        .namaCabang;

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
          _buildConfirmationSection("Data Laporan", [
            _buildConfirmationRow("Nama Lengkap", _namaController.text),
            _buildConfirmationRow("No. HP", _nomorHpController.text),
            _buildConfirmationRow(
                "Deskripsi Laporan", _deskripsiLaporanController.text),
          ]),
          const Divider(height: 32),
          _buildConfirmationSection("Detail Lokasi", [
            _buildConfirmationRow("Cabang Laporan", cabangName),
            _buildConfirmationRow(
                "Deskripsi Lokasi", _deskripsiLokasiController.text),
            _buildConfirmationRow("Koordinat GPS",
                "${_currentPosition?.latitude.toStringAsFixed(6)}, ${_currentPosition?.longitude.toStringAsFixed(6)}"),
          ]),
          const Divider(height: 32),
          _buildConfirmationSection("Bukti Laporan", [
            _buildConfirmationRow("Foto Bukti",
                _imageFile != null ? "Terunggah" : "Belum diunggah",
                isFile: true, file: _imageFile),
          ]),
        ],
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
      {bool isFile = false, XFile? file}) {
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

  void _showSuccessDialog(String trackingCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isCodeCopied = false;
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Laporan Terkirim!',
                  style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold, fontSize: 22)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Terima kasih! Simpan KODE PELACAKAN ini untuk memeriksa status laporan Anda.',
                        style: GoogleFonts.manrope(fontSize: 15)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(
                              child: SelectableText(trackingCode,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      letterSpacing: 2))),
                          IconButton(
                            icon: const Icon(Ionicons.copy_outline),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: trackingCode));
                              _showSnackbar('Kode disalin!', isError: false);
                              stfSetState(() => isCodeCopied = true);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Salin kode di atas untuk mengaktifkan tombol OK.',
                        style: GoogleFonts.manrope(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCodeCopied
                      ? () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(context).pop();
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
}