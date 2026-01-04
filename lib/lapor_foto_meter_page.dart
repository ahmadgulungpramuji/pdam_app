import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // Pastikan package ini ada di pubspec.yaml
import 'package:permission_handler/permission_handler.dart'; // Pastikan package ini ada di pubspec.yaml
import 'package:pdam_app/api_service.dart'; // Sesuaikan path
import 'package:pdam_app/models/cabang_model.dart'; // Pastikan Anda punya model ini
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// --- DEFINISI TEMA WARNA ELEGAN ---
const Color elegantPrimaryColor = Color(0xFF2C3E50);
const Color elegantSecondaryColor = Color(0xFF3498DB);
const Color elegantBackgroundColor = Color(0xFFF8F9FA);
const Color elegantTextColor = Color(0xFF34495E);
const Color elegantBorderColor = Color(0xFFEAECEF);

class LaporFotoMeterPage extends StatefulWidget {
  const LaporFotoMeterPage({super.key});

  @override
  State<LaporFotoMeterPage> createState() => _LaporFotoMeterPageState();
}

class _LaporFotoMeterPageState extends State<LaporFotoMeterPage> {
  // --- Blok Variabel & Controller ---
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _komentarController = TextEditingController();
  final _cabangController = TextEditingController();
  double _scanBoxHeight = 100.0;
  double _scanBoxWidth = 300.0;

  List<String> _pdamIds = [];
  List<Cabang> _daftarCabang = [];
  String? _selectedPdamId;
  int? _selectedCabangId;
  File? _imageFile;

  bool _isLoading = false;
  bool _isFetchingInitialData = true;
  String? _fetchError;
  bool _isOcrLoading = false;

  // --- Variabel Kamera ---
  CameraController? _cameraController;
  Future<void>? _cameraInitializeFuture;
  bool _isCameraPermissionGranted = false;

  // --- PERUBAHAN KUNCI: Set default ke 'false' untuk 'Form Dulu' ---
  bool _isCameraViewActive = false;

  // --- Blok Logika & State Management ---
  @override
  void initState() {
    super.initState();
    // 1. Fetch data awal untuk form
    _fetchInitialData();

    // 2. Minta izin & inisialisasi kamera di latar belakang
    // Ini membuat kamera siap saat tombol 'Buka Kamera' ditekan
    _requestCameraPermission();
  }

  Widget _buildInstructionRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline,
            color: Colors.greenAccent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
        ),
      ],
    );
  }

  // --- Fungsi Izin & Inisialisasi Kamera (TIDAK BERUBAH) ---
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _isCameraPermissionGranted = status == PermissionStatus.granted;
      });

      if (_isCameraPermissionGranted) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showSnackbar('Tidak ada kamera ditemukan.', isError: true);
        return;
      }

      final firstCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraInitializeFuture = _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      _showSnackbar('Gagal inisialisasi kamera: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _komentarController.dispose();
    _cabangController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    // ... (Implementasi _fetchInitialData tidak berubah)
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
        String errorMessage;
        if (e is SocketException) {
          errorMessage =
              'Periksa koneksi internet Anda. Gagal memuat data awal.';
        } else if (e is TimeoutException) {
          errorMessage = 'Koneksi timeout. Gagal memuat data awal.';
        } else {
          errorMessage =
              'Gagal memuat data awal: ${e.toString().replaceFirst("Exception: ", "")}';
        }
        setState(() {
          _fetchError = errorMessage;
          _isFetchingInitialData = false;
        });
      }
    }
  }

  void _updateCabangOtomatis(String? nomorPdam) {
    // 1. Validasi panjang karakter (Ubah dari < 2 menjadi < 3)
    if (nomorPdam == null || nomorPdam.length < 3) {
      setState(() {
        _selectedPdamId = null;
        _selectedCabangId = null;
        _cabangController.clear();
      });
      return;
    }

    // 2. Ambil 3 digit pertama (Sesuai register_page.dart)
    final tigaDigit = nomorPdam.substring(0, 3);
    
    // 3. Mapping baru sesuai register_page.dart
    const Map<String, int> cabangMapping = {
      '120': 1,
      '400': 2,
      '100': 3,
      '200': 4,
      '300': 5,
      '500': 6,
      '230': 7,
      '600': 8,
      '220': 9,
      '110': 10,
      '210': 11,
      '320': 12,
      '310': 13,
      '410': 14
    };

    // Ambil ID Cabang berdasarkan map
    final idCabang = cabangMapping[tigaDigit];

    setState(() {
      _selectedPdamId = nomorPdam;
      _selectedCabangId = idCabang;

      if (idCabang != null) {
        // Cari nama cabang di list yang sudah di-fetch dari API
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

  Future<void> _onCapturePressed() async {
    // 1. Cek Status Kamera
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showSnackbar('Kamera belum siap', isError: true);
      return;
    }
    if (_cameraController!.value.isTakingPicture) return;

    try {
      // 2. AMBIL FOTO ASLI (FULL)
      final XFile imageXFile = await _cameraController!.takePicture();
      final File originalFile = File(imageXFile.path);

      // Update UI: Tampilkan loading
      setState(() {
        _isCameraViewActive = false; // Tutup kamera
        _isOcrLoading = true;        // Mulai loading teks
        _komentarController.text = "Memproses gambar...";
      });

      // Variabel untuk file yang akan di-scan (bisa file crop, atau fallback ke asli)
      File fileForOcr = originalFile; 

      // 3. PROSES CROPPING (Hanya untuk OCR)
      try {
        final bytes = await originalFile.readAsBytes();
        final originalImage = img.decodeImage(bytes);

        if (originalImage != null) {
          // --- LOGIKA CROP (Sama seperti sebelumnya) ---
          final Size screenSize = MediaQuery.of(context).size;
          
          // Gunakan variabel slider (_scanBoxWidth & _scanBoxHeight)
          final double widthRatio = (_scanBoxWidth / screenSize.width);
          final double heightRatio = (_scanBoxHeight / screenSize.height);

          final int cropW = (originalImage.width * widthRatio).toInt();
          final int cropH = (originalImage.height * heightRatio).toInt();

          final int cropX = (originalImage.width - cropW) ~/ 2;
          final int cropY = (originalImage.height - cropH) ~/ 2;

          // Pastikan koordinat aman
          final safeCropX = cropX < 0 ? 0 : cropX;
          final safeCropY = cropY < 0 ? 0 : cropY;

          final croppedImage = img.copyCrop(
            originalImage,
            x: safeCropX,
            y: safeCropY,
            width: cropW,
            height: cropH,
          );

          // --- PERBEDAAN UTAMA DI SINI ---
          // Simpan hasil crop ke file BARU yang terpisah (Temporary)
          final String cropPath = '${originalFile.path}_temp_crop.jpg';
          final File tempCroppedFile = File(cropPath)
            ..writeAsBytesSync(img.encodeJpg(croppedImage));
          
          // Set fileForOcr menggunakan file crop ini
          fileForOcr = tempCroppedFile;
        }
      } catch (e) {
        print("Gagal crop gambar, menggunakan gambar asli untuk OCR: $e");
        // Jika gagal crop, fileForOcr tetap originalFile
      }

      // 4. UPDATE STATE UTAMA (Untuk Database & Tampilan UI)
      setState(() {
        // PENTING: Kita simpan originalFile (Foto Lengkap) ke _imageFile
        // Agar saat tombol "Kirim Laporan" ditekan, foto utuh yang terkirim.
        _imageFile = originalFile; 
      });

      // 5. JALANKAN OCR (Menggunakan File Crop)
      try {
        // Gunakan fileForOcr (yang sudah di-crop) untuk ML Kit
        final inputImage = InputImage.fromFilePath(fileForOcr.path);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        await textRecognizer.close();

        String resultText = _parseOcrResult(recognizedText.text);

        if (mounted) {
          setState(() {
            _komentarController.text = resultText;
            _isOcrLoading = false;
          });
          
          if (resultText.contains('Tidak ada')) {
             _showSnackbar('Angka tidak terdeteksi. Silakan koreksi manual.', isError: true);
          } else {
             _showSnackbar('Angka terdeteksi: $resultText', isError: false);
          }
        }
        
        // Opsional: Hapus file crop sementara agar tidak memenuhi memori
        if (fileForOcr.path.contains('_temp_crop')) {
          try {
            await fileForOcr.delete();
          } catch (_) {}
        }

      } catch (e) {
        if (mounted) {
          setState(() {
            _isOcrLoading = false;
            _komentarController.text = "";
          });
          _showSnackbar('Gagal membaca teks: $e', isError: true);
        }
      }

    } catch (e) {
      _showSnackbar('Gagal mengambil foto: $e', isError: true);
      setState(() => _isOcrLoading = false);
    }
  }

  // Fungsi Helper untuk menyaring hasil teks (Regex)
  String _parseOcrResult(String rawText) {
    // Hapus spasi dan baris baru
    String cleanText = rawText.replaceAll('\n', ' ').trim();

    // Regex: Ambil hanya angka, titik, atau koma
    RegExp regex = RegExp(r'[\d.,]+');
    final allMatches =
        regex.allMatches(cleanText).map((m) => m.group(0)!).toList();

    if (allMatches.isEmpty) {
      return 'Tidak ada angka';
    }

    // Urutkan dari yang terpanjang (biasanya angka meteran lebih panjang dari noise)
    allMatches.sort((a, b) => b.length.compareTo(a.length));

    // Ambil yang terpanjang
    return allMatches.first;
  }

  Future<void> _submitLaporan() async {
    // ... (Implementasi _submitLaporan tidak berubah)
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
      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'Periksa koneksi internet Anda. Laporan gagal dikirim.';
      } else if (e is TimeoutException) {
        errorMessage = 'Koneksi timeout. Laporan gagal dikirim.';
      } else {
        errorMessage =
            'Terjadi kesalahan: ${e.toString().replaceFirst("Exception: ", "")}';
      }
      _showSnackbar(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    // ... (Implementasi _showSnackbar tidak berubah)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor:
            isError ? Colors.red.shade800 : const Color(0xFF27AE60),
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
      // --- MODIFIKASI: AppBar dinamis (sudah benar) ---
      // Akan menampilkan _buildElegantAppBar() terlebih dahulu
      appBar: _isCameraViewActive
          ? _buildCameraAppBar() // AppBar untuk kamera
          : _buildElegantAppBar(), // AppBar untuk form
      body: _isFetchingInitialData
          ? const Center(
              child: CircularProgressIndicator(color: elegantPrimaryColor))
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
              // --- MODIFIKASI: Tampilan dinamis (sudah benar) ---
              // Akan menampilkan _buildForm() terlebih dahulu
              : _isCameraViewActive
                  ? _buildCameraView()
                  : _buildForm(),
    );
  }

  // --- MODIFIKASI: AppBar Kamera ---
  AppBar _buildCameraAppBar() {
    return AppBar(
      title: Text(
        'Posisikan Meteran',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.black,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      // --- MODIFIKASI: Tombol ini kembali ke FORM, bukan menutup halaman ---
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _isCameraViewActive = false; // Kembali ke Form
          });
        },
      ),
    );
  }

  // --- MODIFIKASI: AppBar Form ---
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
      elevation: 0,
      iconTheme: const IconThemeData(color: elegantTextColor),
      // --- MODIFIKASI: Hapus tombol 'leading' kustom ---
      // Biarkan Flutter yang menangani tombol 'kembali' standar
      // (akan muncul otomatis jika halaman ini didorong ke navigator)
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: elegantBorderColor,
          height: 1.0,
        ),
      ),
    );
  }

  // --- Widget Tampilan Kamera (TIDAK BERUBAH) ---
  // Tampilan ini sudah benar, termasuk 'FutureBuilder' dan 'overlay'
  Widget _buildCameraView() {
    if (!_isCameraPermissionGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Izin Kamera Dibutuhkan',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Aplikasi ini memerlukan izin kamera untuk mengambil foto meteran. Mohon aktifkan di pengaturan.',
                style: GoogleFonts.poppins(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: elegantPrimaryColor),
                onPressed: () => openAppSettings(),
                child: Text('Buka Pengaturan',
                    style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraInitializeFuture == null || _cameraController == null) {
      return const Center(
          child: CircularProgressIndicator(color: elegantPrimaryColor));
    }

    return FutureBuilder<void>(
      future: _cameraInitializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // Ambil lebar layar untuk batasan max slider
          final screenWidth = MediaQuery.of(context).size.width;

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_cameraController!),
              _buildScannerOverlay(),

              // --- PANEL KONTROL UKURAN (SLIDER) ---
              Positioned(
                bottom: 130, // Di atas tombol shutter
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label Kontrol
                    Center(
                      child: Text(
                        "Atur Area Scan (Geser Tombol)",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          shadows: [
                            const Shadow(blurRadius: 4, color: Colors.black)
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // SLIDER 1: LEBAR (WIDTH)
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz,
                            color: Colors.white, size: 20),
                        Expanded(
                          child: Slider(
                            value: _scanBoxWidth,
                            min: 50.0,
                            max: screenWidth -
                                40, // Maksimal selebar layar - margin
                            activeColor: Colors.white,
                            inactiveColor: Colors.white24,
                            onChanged: (val) =>
                                setState(() => _scanBoxWidth = val),
                          ),
                        ),
                      ],
                    ),

                    // SLIDER 2: TINGGI (HEIGHT)
                    Row(
                      children: [
                        const Icon(Icons.swap_vert,
                            color: Colors.white, size: 20),
                        Expanded(
                          child: Slider(
                            value: _scanBoxHeight,
                            min: 50.0,
                            max: 400.0, // Batas tinggi maksimal
                            activeColor: Colors.white,
                            inactiveColor: Colors.white24,
                            onChanged: (val) =>
                                setState(() => _scanBoxHeight = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _buildCaptureControl(),
            ],
          );
        }
        return const Center(
            child: CircularProgressIndicator(color: elegantPrimaryColor));
      },
    );
  }

  // Widget untuk overlay (kotak panduan)
  Widget _buildScannerOverlay() {
    final double scanWidth = _scanBoxWidth;
    final double scanHeight = _scanBoxHeight;
    final Radius scanRadius = const Radius.circular(16);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Background Gelap (Cutout)
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.7),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: scanWidth, // Dinamis
                  height: scanHeight, // Dinamis
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(scanRadius),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Layer 2: Instruksi Teks (Tampilan Keren)
        Align(
          alignment: Alignment.topCenter, // PERBAIKAN: Pindahkan ke atas
          child: Padding(
            padding: EdgeInsets.only(
              // PERBAIKAN: Beri jarak dari atas
              top: MediaQuery.of(context).size.height *
                  0.1, // 10% dari atas layar
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Agar column tidak terlalu besar
              children: [
                Text(
                  '📷 Pindai Angka Meteran Anda',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionRow(
                          'Posisikan hanya deretan angka meteran Anda di dalam kotak.'),
                      const SizedBox(height: 8),
                      _buildInstructionRow(
                          'Pastikan gambar jelas dan tidak buram.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Layer 3: Border/Garis di atas "Lubang"
        Align(
          alignment: Alignment.center,
          child: Container(
            width: scanWidth, // Dinamis
            height: scanHeight, // Dinamis
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.0),
              borderRadius: BorderRadius.all(scanRadius),
            ),
          ),
        ),
      ],
    );
  }

  // Widget untuk tombol ambil foto
  Widget _buildCaptureControl() {
    // ... (Implementasi _buildCaptureControl tidak berubah)
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 120,
        width: double.infinity,
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: InkWell(
            onTap: _onCapturePressed, // Panggil fungsi ini saat diklik
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget Tampilan Form (TIDAK BERUBAH) ---
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'Informasi Pelanggan',
          ),
          _buildDropdownPdamId(),
          const SizedBox(height: 16),
          _buildCabangDisplayField(),
          const SizedBox(height: 32),
          _buildSectionHeader(
            icon: Icons.camera_alt_outlined,
            title: 'Foto Water Meter',
          ),
          _buildImageUploadSection(), // <-- MODIFIKASI KUNCI DI SINI
          const SizedBox(height: 32),
          _buildSectionHeader(
            icon: Icons.edit_outlined,
            title: 'Catatan Angka Meter',
            subtitle: '(Hasil deteksi / manual)',
          ),
          _buildKomentarField(), // Ini adalah 'Input Manual' Anda
          const SizedBox(height: 40),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      {required IconData icon, required String title, String? subtitle}) {
    // ... (Implementasi _buildSectionHeader tidak berubah)
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: elegantPrimaryColor, size: 22),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: elegantTextColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle,
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

  Widget _buildDropdownPdamId() {
    // ... (Implementasi _buildDropdownPdamId tidak berubah)
    return DropdownButtonFormField<String>(
      value: _selectedPdamId,
      hint: Text('Pilih Nomor ID Pelanggan Anda', style: GoogleFonts.poppins()),
      items: _pdamIds
          .map((id) => DropdownMenuItem(
              value: id, child: Text(id, style: GoogleFonts.poppins())))
          .toList(),
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
    // ... (Implementasi _buildCabangDisplayField tidak berubah)
    return TextFormField(
      controller: _cabangController,
      readOnly: true,
      decoration: _elegantInputDecoration(
        labelText: 'Cabang Terdeteksi',
        prefixIcon: Icons.location_on_outlined,
      ).copyWith(
        fillColor: Colors.grey.shade100,
      ),
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: elegantPrimaryColor,
      ),
    );
  }

  // --- MODIFIKASI KUNCI: Widget Upload Foto ---
  Widget _buildImageUploadSection() {
    return Column(
      children: [
        // 1. Tampilan Foto (atau placeholder jika kosong)
        Container(
          height: 250,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: elegantBorderColor, width: 1.5),
          ),
          // --- Logika Kondisional BARU ---
          child: _imageFile != null
              ? Image.file(_imageFile!, fit: BoxFit.cover)
              : Center(
                  // Tampilan jika _imageFile masih null
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera_back_outlined,
                          size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('Belum ada foto yang diambil',
                          style:
                              GoogleFonts.poppins(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // 2. Tombol (dinamis)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            // --- Logika onPressed BARU ---
            onPressed: () {
              // Jika izin tidak diberikan, minta lagi atau buka pengaturan
              if (!_isCameraPermissionGranted) {
                _showSnackbar(
                    'Izin kamera dibutuhkan. Mohon izinkan di pengaturan.',
                    isError: true);
                openAppSettings();
                return;
              }

              // Jika izin ADA, buka kamera
              setState(() {
                _isCameraViewActive = true; // Pindah ke tampilan kamera
                // Jika foto ulang, bersihkan data lama
                if (_imageFile != null) {
                  _imageFile = null;
                  _komentarController.clear();
                }
              });
            },
            // --- Icon & Label dinamis BARU ---
            icon: Icon(_imageFile == null
                ? Icons.camera_alt_outlined
                : Icons.sync_outlined),
            label: Text(
              _imageFile == null ? 'Buka Kamera' : 'Ambil Foto Ulang',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: elegantPrimaryColor,
              side: const BorderSide(color: elegantPrimaryColor, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKomentarField() {
    // ... (Implementasi _buildKomentarField tidak berubah)
    // Ini adalah 'Input Manual' Anda
    return Stack(
      alignment: Alignment.center,
      children: [
        TextFormField(
          controller: _komentarController,
          decoration: _elegantInputDecoration(
            hintText: _isOcrLoading
                ? 'Membaca angka pada gambar...'
                : 'Tulis/Perbaiki angka meteran di sini...',
            prefixIcon: Icons.notes_outlined,
          ).copyWith(
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          keyboardType: TextInputType.number,
          style: GoogleFonts.poppins(),
          readOnly: _isOcrLoading,
        ),
        if (_isOcrLoading)
          const CircularProgressIndicator(color: elegantPrimaryColor),
      ],
    );
  }

  Widget _buildSubmitButton() {
    // ... (Implementasi _buildSubmitButton tidak berubah)
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
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
        label: Text(
          _isLoading ? 'Mengirim...' : 'Kirim Laporan',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  InputDecoration _elegantInputDecoration(
      {String? labelText, String? hintText, IconData? prefixIcon}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
      // --- PERBAIKAN: Mengganti shade4400 menjadi shade400 ---
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.grey.shade500)
          : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
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
