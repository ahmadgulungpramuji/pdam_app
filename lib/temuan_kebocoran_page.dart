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
import 'package:url_launcher/url_launcher.dart';
import 'package:pdam_app/models/cabang_model.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:geocoding/geocoding.dart';

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
  final _step3FormKey = GlobalKey<FormState>();

  final ApiService _apiService = ApiService();
  late String _apiUrlSubmit;

  final TextEditingController _deskripsiLokasiController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nomorHpController = TextEditingController();

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
  String? _imageError;
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
    super.dispose();
  }

  // --- Navigation ---
  void _nextPage() {
    bool isStepValid = false;
    if (_currentPage == 0) {
      isStepValid = _step1FormKey.currentState?.validate() ?? false;
    } else if (_currentPage == 1) {
      isStepValid = _step2FormKey.currentState?.validate() ?? false;
    } else {
      isStepValid = true;
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
      final List<Cabang> cabangList = await _apiService.getCabangList().timeout(
        const Duration(seconds: 20),
      );
      if (!mounted) return;
      setState(() => _cabangOptionsApi = cabangList);
      if (_currentPosition != null) _findNearestBranch();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _cabangError = 'Gagal memuat data cabang: ${e.toString()}',
      );
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

      // --- Perbaikan: Ambil dan isi alamat otomatis ---
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'id_ID',
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            // Format alamat dengan nama jalan, desa, kecamatan, kabupaten
            String formattedAddress = "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.subAdministrativeArea ?? ''}";
            _deskripsiLokasiController.text = formattedAddress;
          }
        });
        _showSnackbar('Lokasi berhasil didapatkan!', isError: false);
        _findNearestBranch();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          e.toString().replaceFirst("Exception: ", ""),
          isError: true,
        );
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
          cabang.longitude!,
        );

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
      _showSnackbar(
        'Cabang terdekat ($nearestBranchName) otomatis terdeteksi.',
        isError: false,
        backgroundColor: Colors.blue.shade700,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _imageError = null;
      _isImageProcessing = true;
    });
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        final originalImage = img.decodeImage(imageBytes);

        if (originalImage == null) {
          throw Exception('Gagal memproses gambar');
        }

        final watermarkedImage = img.copyResize(originalImage, width: 800);
        final now = DateTime.now();

        img.drawString(
          watermarkedImage,
          font: img.arial14,
          'Waktu: ${now.toIso8601String()}',
          x: 10,
          y: 10,
          color: img.ColorRgb8(255, 255, 255),
        );

        final directory = await getTemporaryDirectory();
        final fileName = 'watermarked_${path.basename(pickedFile.path)}';
        final newPath = path.join(directory.path, fileName);
        final newFile = File(newPath);
        await newFile.writeAsBytes(img.encodeJpg(watermarkedImage, quality: 90));

        setState(() {
          _imageFile = XFile(newPath);
          _isImageProcessing = false;
        });
      } else {
        // Handle jika pengguna membatalkan pengambilan gambar
        setState(() {
          _isImageProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _imageError = 'Gagal memproses gambar: $e';
        _isImageProcessing = false;
      });
    }
  }

  Future<void> _submitForm() async {
    // --- Perbaikan: Validasi foto bukti wajib ---
    if (_imageFile == null) {
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      _showSnackbar('Foto bukti wajib diisi.', isError: true);
      return;
    }

    if (!_step3FormKey.currentState!.validate()) {
      _showSnackbar('Harap periksa kembali semua data yang wajib diisi.');
      return;
    }
    if (_selectedCabangId == null) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      _showSnackbar('Cabang pelaporan wajib dipilih.', isError: true);
      return;
    }
    if (_currentPosition == null) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      _showSnackbar(
        'Lokasi GPS wajib diisi. Mohon aktifkan lokasi Anda.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrlSubmit));
      request.fields.addAll({
        'nama_pelapor': _namaController.text.trim(),
        'nomor_hp_pelapor': _nomorHpController.text.trim(),
        'id_cabang': _selectedCabangId.toString(),
        'lokasi_maps':
            '${_currentPosition!.latitude},${_currentPosition!.longitude}',
        'deskripsi_lokasi': _deskripsiLokasiController.text.trim(),
      });

      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('foto_bukti', _imageFile!.path),
        );
      }

      var res = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await res.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      if (res.statusCode == 201 || res.statusCode == 200) {
        _showSuccessDialog(
          responseData['data']?['tracking_code'] as String? ?? 'N/A',
        );
      } else {
        _showSnackbar(
          responseData['message'] ?? 'Gagal mengirim data',
          isError: true,
        );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Ionicons.arrow_back),
          onPressed: _previousPage,
        ),
        title: const Text('Lapor Temuan Kebocoran'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      _buildStep1_InfoPelapor(),
                      _buildStep2_Lokasi(),
                      _buildStep3_BuktiKirim(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / 3.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Langkah ${_currentPage + 1} dari 3',
            style: GoogleFonts.lato(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStepWrapper({
    required String title,
    required List<Widget> children,
    required GlobalKey<FormState> formKey,
    bool isLastStep = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.lato(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ...children,
            const SizedBox(height: 32),
            if (!isLastStep)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('LANJUT'),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- Step Widgets ---
  Widget _buildStep1_InfoPelapor() {
    return _buildStepWrapper(
      title: 'Informasi Pelapor',
      formKey: _step1FormKey,
      children: [
        TextFormField(
          controller: _namaController,
          decoration: const InputDecoration(labelText: 'Nama Lengkap Anda'),
          validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nomorHpController,
          decoration: const InputDecoration(labelText: 'Nomor HP Aktif'),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.isEmpty) return 'Nomor HP wajib diisi';
            if (v.length < 10) return 'Nomor HP minimal 10 digit';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStep2_Lokasi() {
    String staticMapUrl = '';
    if (_currentPosition != null) {
      final lat = _currentPosition!.latitude;
      final lng = _currentPosition!.longitude;
      const apiKey = 'aWxXDWpJ8Zo4ZasFgJ1VkKwFjdqBz6KB'; // API Key Anda
      staticMapUrl =
          'https://www.mapquestapi.com/staticmap/v5/map?key=$apiKey&center=$lat,$lng&zoom=15&size=600,300&markers=red-1,$lat,$lng';
    }

    return _buildStepWrapper(
      title: 'Detail Lokasi',
      formKey: _step2FormKey,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade200,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child:
              _currentPosition == null
                  ? Center(
                    child: Text(
                      _isLoading ? "Memuat..." : "Lokasi tidak ditemukan",
                    ),
                  )
                  : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      staticMapUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (c, e, s) =>
                              const Center(child: Text('Gagal muat peta')),
                    ),
                  ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text("Ambil Ulang Lokasi"),
            onPressed: _isLoading ? null : _getCurrentLocation,
          ),
        ),
        const SizedBox(height: 16),
        if (_isCabangLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SpinKitChasingDots(color: Colors.blue),
            ),
          )
        else if (_cabangError != null)
          Column(
            children: [
              Center(
                child: Text(
                  _cabangError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Coba Lagi"),
                onPressed: _fetchCabangOptions,
              ),
            ],
          )
        else if (_cabangOptionsApi.isEmpty)
          const Center(
            child: Text(
              "Tidak ada data cabang ditemukan.",
              style: TextStyle(color: Colors.red),
            ),
          )
        else
          DropdownButtonFormField<int>(
            value: _selectedCabangId,
            hint: const Text('Pilih Cabang'),
            decoration: InputDecoration(
              labelText:
                  _detectedCabangName != null
                      ? "Cabang Terdeteksi"
                      : 'Cabang Pelaporan',
            ),
            items:
                _cabangOptionsApi
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.namaCabang),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() {
              _selectedCabangId = value;
              _detectedCabangName = null;
            }),
            validator: (v) => v == null ? 'Pilih cabang pelaporan' : null,
          ),
        if (_detectedCabangName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "Otomatis: $_detectedCabangName",
              style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deskripsiLokasiController,
          decoration: const InputDecoration(
            labelText: 'Deskripsi Detail Lokasi',
            hintText: 'Misal: Depan toko X, dekat jembatan Y',
          ),
          maxLines: 3,
          validator:
              (v) =>
                  v == null || v.isEmpty
                      ? 'Deskripsi lokasi wajib diisi'
                      : null,
        ),
      ],
    );
  }

  Widget _buildStep3_BuktiKirim() {
    return _buildStepWrapper(
      title: 'Bukti & Kirim',
      formKey: _step3FormKey,
      isLastStep: true,
      children: [
        const Text(
          "Unggah Foto Bukti", // <--- Perbaikan: Hapus "(Opsional)"
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (_isImageProcessing)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          GestureDetector(
            onTap: () => _pickImage(ImageSource.camera),
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(
                  color: _imageError != null ? Colors.red : Colors.grey.shade300,
                  width: _imageError != null ? 2.0 : 1.0,
                ),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: _imageFile == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Ionicons.camera_outline,
                            size: 44,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text('Ketuk untuk ambil foto'),
                        ],
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(
                            File(_imageFile!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(
                                Ionicons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => setState(() {
                                _imageFile = null;
                                _imageError = 'Foto bukti wajib diisi.';
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        if (_imageError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _imageError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          icon: _isSubmitting
              ? const SizedBox.shrink()
              : const Icon(Ionicons.send, color: Colors.white),
          label: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('KIRIM LAPORAN'),
          onPressed: _isSubmitting ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            minimumSize: const Size(double.infinity, 50),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // --- Dialogs & Sheets ---
  void _showSuccessDialog(String trackingCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Laporan Terkirim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Terima kasih! Mohon simpan kode pelacakan ini:'),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SelectableText(
                      trackingCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Ionicons.copy_outline),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: trackingCode));
                      _showSnackbar('Kode disalin!', isError: false);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showSnackbar(
    String message, {
    bool isError = true,
    Color? backgroundColor,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            backgroundColor ?? (isError ? Colors.red.shade600 : Colors.green.shade600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}