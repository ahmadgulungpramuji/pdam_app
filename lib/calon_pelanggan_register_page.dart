// ignore_for_file: unused_field

import 'dart:async';
import 'dart:developer' show log;
import 'dart:math'
    show
        cos,
        sqrt,
        asin,
        pi,
        sin; // <-- Tambahkan 'sin' di sini// Tambahkan pi untuk perhitungan jarak
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; // DIKEMBALIKAN
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/cabang_model.dart'; // Pastikan ini mengacu pada model yang sudah diperbarui
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image/image.dart' as img;

// Enum untuk merepresentasikan semua kemungkinan status validasi KTP

class CalonPelangganRegisterPage extends StatefulWidget {
  const CalonPelangganRegisterPage({super.key});

  @override
  State<CalonPelangganRegisterPage> createState() =>
      _CalonPelangganRegisterPageState();
}

class _CalonPelangganRegisterPageState extends State<CalonPelangganRegisterPage>
    with SingleTickerProviderStateMixin {
  // --- Keys & Controllers ---
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService =
      ApiService(); // Gunakan _apiService, bukan _apiService.apiService
  final _namaController = TextEditingController();
  final _noKtpController = TextEditingController();
  final _alamatKtpController = TextEditingController();
  final _deskripsiAlamatController =
      TextEditingController(); // Ini akan dipakai untuk alamat detail manual
  final _noWaController = TextEditingController();

  // Tambahan Controller untuk Provinsi dan Kabupaten/Kota yang otomatis dan read-only
  final _provinsiController = TextEditingController(text: 'JAWA BARAT');
  final _kabupatenKotaController = TextEditingController(text: 'INDRAMAYU');
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
    'SINDANG': 3, // Di seeder, Sindang adalah cabang sendiri (ID 3)
    'SLIYEG': 10,
    'SUKAGUMIWANG': 10,
    'SUKRA': 6,
    'TERISI': 7,
    'TUKDANA': 9,
    'WIDASARI': 4,
  };

  // Variabel baru untuk menyimpan nama cabang dari berbagai sumber
  String? _cabangByKecamatanName; // Nama cabang dari pilihan kecamatan
  String? _cabangByGpsName; // Nama cabang dari saran GPS

  // Variabel internal untuk menyimpan koordinat
  String? _gpsCoordinates; // <-- Untuk menyimpan Lat,Long
  String?
      _detectedKabupatenKota; // BARU: Untuk menyimpan kabupaten/kota yang terdeteksi dari GPS

  // --- State Variables ---
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _kecamatanOptions = [];
  List<dynamic> _desaOptions = [];

  String? _selectedKecamatanId;
  String? _selectedKecamatanCode; // Kode kecamatan untuk fetch desa
  String? _selectedKecamatanName; // Nama kecamatan untuk dikirim ke backend
  String? _selectedDesaName;

  bool _isKecamatanLoading = true;
  bool _isDesaLoading = false;
  bool _isCabangLoading = true;

  String?
      _cabangError; // Tidak lagi digunakan untuk error dropdown, tapi untuk error cabang terdekat
  List<Cabang> _allCabangs = []; // Semua data cabang dari API
  int? _selectedCabangId; // ID cabang terdekat yang otomatis terpilih
  String _selectedCabangDisplayName =
      'Mencari Cabang Terdekat...'; // Nama cabang untuk ditampilkan
  String? _nearestBranchError; // Error spesifik untuk fitur cabang terdekat

  File? _imageFileKtp;
  File? _imageFileRumah;
  final _picker = ImagePicker();

  bool _isLocationLoading =
      false; // DIKEMBALIKAN tapi hanya untuk internal loading state

  Widget _buildBranchDropdown() {
    bool isDropdownDisabled = _selectedKecamatanName == null;

    return DropdownButtonFormField<int>(
      value: _selectedCabangId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Cabang Pemasangan',
        prefixIcon: Icon(Ionicons.business_outline,
            color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor:
            isDropdownDisabled ? Colors.grey.shade200 : Colors.grey.shade50,
        helperText: _cabangByKecamatanName == null
            ? 'Pilih kecamatan untuk menentukan cabang otomatis'
            : 'Otomatis: $_cabangByKecamatanName. Anda bisa mengubah jika yakin.',
        helperStyle:
            GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
      ),
      items: _allCabangs.map((Cabang cabang) {
        return DropdownMenuItem<int>(
          value: cabang.id,
          child: Text(cabang.namaCabang, style: GoogleFonts.poppins()),
        );
      }).toList(),
      onChanged: isDropdownDisabled
          ? null
          : (newValue) {
              if (newValue != null && newValue != _selectedCabangId) {
                _showBranchChangeConfirmationDialog(newValue);
              }
            },
      validator: (value) {
        if (value == null) {
          return 'Cabang pemasangan wajib ditentukan.';
        }
        return null;
      },
    );
  }

  Future<void> _showBranchChangeConfirmationDialog(int newCabangId) async {
    // Cari nama cabang baru yang dipilih dari daftar
    final selectedCabang = _allCabangs.firstWhere((c) => c.id == newCabangId);

    bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Perubahan Cabang',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            'Cabang yang kami sarankan berdasarkan kecamatan adalah "$_cabangByKecamatanName".\n\nAnda yakin ingin mengubahnya secara manual ke "${selectedCabang.namaCabang}"?',
            style: GoogleFonts.poppins(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Batal', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Ya, Saya Yakin', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );

    // Jika pengguna menekan "Ya, Saya Yakin", perbarui state
    if (isConfirmed == true) {
      setState(() {
        _selectedCabangId = newCabangId;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noKtpController.dispose();
    _alamatKtpController.dispose();
    _deskripsiAlamatController.dispose();
    _noWaController.dispose();
    _provinsiController.dispose();
    _kabupatenKotaController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchKecamatan(); // Fetch kecamatan duluan
    await _fetchCabangOptions(); // Fetch semua cabang
    await _getCurrentLocationAndAddress(); // Dapatkan lokasi dan alamat, lalu cari cabang terdekat
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCabangOptions() async {
    setState(() => _isCabangLoading = true);
    try {
      final options =
          await _apiService.getCabangList(); // Mengambil Cabang objects
      if (mounted) {
        setState(() {
          _allCabangs = options; // Simpan semua cabang
        });
      }
    } catch (e) {
      log('Error fetching cabang options: $e');
      _showSnackbar('Gagal memuat daftar cabang: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCabangLoading = false);
    }
  }

  Future<void> _fetchKecamatan() async {
    setState(() => _isKecamatanLoading = true);
    try {
      final List<dynamic> kecamatanData =
          await _apiService.getKecamatanIndramayu();
      log('Data Kecamatan Diterima: ${kecamatanData.length} item');
      if (mounted) {
        setState(() {
          _kecamatanOptions = kecamatanData;
          _isKecamatanLoading = false;
        });
      }
    } catch (e) {
      log('Error tertangkap di _fetchKecamatan: $e');
      if (mounted) {
        setState(() => _isKecamatanLoading = false);
        _showSnackbar('Gagal memuat data kecamatan: $e', isError: true);
      }
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
      if (mounted) {
        setState(() {
          _desaOptions = desaData;
          _isDesaLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDesaLoading = false);
        _showSnackbar('Gagal memuat data desa: $e', isError: true);
      }
    }
  }

  // BARU: Mendapatkan lokasi dan alamat lengkap dari GPS, lalu mencari cabang terdekat
  Future<void> _getCurrentLocationAndAddress() async {
    setState(() {
      _isLocationLoading = true;
      _deskripsiAlamatController.text = 'Mencari lokasi...';
      _selectedCabangDisplayName = 'Mencari Cabang Terdekat...';
      _nearestBranchError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar('Layanan lokasi tidak aktif. Mohon aktifkan GPS Anda.',
            isError: true);
        setState(() {
          _deskripsiAlamatController.text = 'Layanan lokasi tidak aktif.';
          _selectedCabangDisplayName = 'Tidak dapat menentukan cabang.';
          _nearestBranchError = 'GPS tidak aktif.';
          _gpsCoordinates = null;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar(
              'Izin lokasi ditolak. Aplikasi memerlukan izin lokasi untuk melanjutkan.',
              isError: true);
          setState(() {
            _deskripsiAlamatController.text = 'Izin lokasi ditolak.';
            _selectedCabangDisplayName = 'Tidak dapat menentukan cabang.';
            _nearestBranchError = 'Izin lokasi ditolak.';
            _gpsCoordinates = null;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackbar(
            'Izin lokasi ditolak permanen. Mohon berikan izin lokasi dari pengaturan aplikasi.',
            isError: true);
        setState(() {
          _deskripsiAlamatController.text = 'Izin lokasi ditolak permanen.';
          _selectedCabangDisplayName = 'Tidak dapat menentukan cabang.';
          _nearestBranchError = 'Izin lokasi ditolak permanen.';
          _gpsCoordinates = null;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _gpsCoordinates = '${position.latitude},${position.longitude}';
      });

      // Panggil API untuk mengubah koordinat menjadi alamat lengkap dan coba deteksi kabupaten/kota
      final String fullAddressString =
          await _apiService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Ini adalah bagian KRITIS untuk menentukan Kabupaten/Kota dari string alamat
      // Ini hanya contoh sederhana, implementasi sebenarnya mungkin butuh parsing yang lebih robust
      _detectedKabupatenKota = _extractKabupatenKota(fullAddressString);

      if (mounted) {
        setState(() {
          _deskripsiAlamatController.text =
              fullAddressString; // Isi otomatis ke field deskripsi_alamat
        });
        _showSnackbar('Lokasi dan Alamat berhasil didapatkan secara otomatis.',
            isError: false);
      }

      // Setelah mendapatkan lokasi dan alamat, baru cari cabang terdekat
      _findNearestBranch(
          position.latitude, position.longitude, _detectedKabupatenKota);
    } on TimeoutException {
      if (mounted) {
        _showSnackbar(
            'Waktu habis saat mendapatkan lokasi. Pastikan koneksi internet stabil.',
            isError: true);
        setState(() {
          _deskripsiAlamatController.text =
              'Waktu habis saat mendapatkan lokasi.';
          _selectedCabangDisplayName = 'Gagal menentukan cabang.';
          _nearestBranchError = 'Timeout lokasi.';
          _gpsCoordinates = null;
        });
      }
    } catch (e) {
      if (mounted) {
        log('Error getting location or finding nearest branch: $e');
        _showSnackbar(
            'Gagal mendapatkan lokasi & alamat: ${e.toString().replaceFirst("Exception: ", "")}',
            isError: true);
        setState(() {
          _deskripsiAlamatController.text = 'Gagal mendapatkan lokasi.';
          _selectedCabangDisplayName = 'Error menentukan cabang.';
          _nearestBranchError = 'Kesalahan sistem lokasi.';
          _gpsCoordinates = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  // Helper function untuk mengekstrak nama kabupaten/kota dari string alamat
  // Ini adalah implementasi yang sangat sederhana dan mungkin perlu disempurnakan
  String _extractKabupatenKota(String fullAddress) {
    // Contoh: "Jl. Raya Indramayu-Jatibarang, Sindang, Kec. Sindang, Kab. Indramayu, Jawa Barat 45223, Indonesia"
    // Coba cari "Kab. Indramayu" atau "Kabupaten Indramayu"
    final regex = RegExp(r'Kab\.?\s*([A-Za-z\s]+)', caseSensitive: false);
    final match = regex.firstMatch(fullAddress);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!.trim();
    }
    // Fallback jika tidak ditemukan, atau jika formatnya berbeda
    if (fullAddress.toLowerCase().contains('indramayu')) {
      return 'Indramayu'; // Asumsi jika ada kata 'indramayu' di alamat
    }
    return 'Tidak Diketahui'; // Atau nilai default lainnya
  }

  // Fungsi Haversine untuk menghitung jarak antara dua koordinat (dalam KM)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Radius bumi dalam kilometer
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  // Fungsi untuk menemukan cabang terdekat
  void _findNearestBranch(
      double currentLat, double currentLon, String? detectedKabupatenKota) {
    if (_allCabangs.isEmpty) {
      setState(() {
        _selectedCabangId = null;
        _selectedCabangDisplayName = 'Data cabang tidak tersedia.';
        _nearestBranchError = 'Tidak ada data cabang.';
      });
      return;
    }

    // --- LOGIKA PENGECUALIAN DI LUAR INDRAMAYU ---
    // Di sini kita asumsikan 'INDRAMAYU' adalah nama kabupaten yang konsisten
    if (detectedKabupatenKota == null ||
        detectedKabupatenKota.toUpperCase() != 'INDRAMAYU') {
      setState(() {
        _selectedCabangId = null;
        _selectedCabangDisplayName = 'Di luar wilayah Indramayu.';
        _nearestBranchError =
            'Pendaftaran hanya di wilayah Kabupaten Indramayu.';
      });
      return;
    }
    // --- AKHIR LOGIKA PENGECUALIAN ---

    Cabang? nearestBranch;
    double minDistance = double.infinity;

    for (var cabang in _allCabangs) {
      // Pastikan data latitude dan longitude cabang tidak null
      if (cabang.latitude != null && cabang.longitude != null) {
        double distance = _calculateDistance(
          currentLat,
          currentLon,
          cabang.latitude!,
          cabang.longitude!,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestBranch = cabang;
        }
      }
    }

    setState(() {
      if (nearestBranch != null) {
        _cabangByGpsName = nearestBranch.namaCabang;

        if (_selectedKecamatanName == null) {
          _selectedCabangDisplayName =
              'Saran Terdekat (GPS): ${nearestBranch.namaCabang}';
        }
      } else {
        if (_selectedKecamatanName == null) {
          _selectedCabangDisplayName = 'Tidak ada cabang terdekat ditemukan.';
        }
      }
    });
  }

  Future<File?> _compressAndGetFile(File file) async {
    final imageBytes = await file.readAsBytes();
    final originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) {
      return null;
    }

    img.Image resizedImage = originalImage;
    if (originalImage.width > 1280 || originalImage.height > 1280) {
      resizedImage = img.copyResize(originalImage,
          width: 1280, interpolation: img.Interpolation.average);
    }

    final compressedBytes = img.encodeJpg(resizedImage, quality: 85);

    final tempDir = Directory.systemTemp;
    final tempFile =
        File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg')
          ..writeAsBytesSync(compressedBytes);

    return tempFile;
  }

  void _updateCabangBasedOnKecamatan(String kecamatanName) {
    final kecamatanKey = kecamatanName.toUpperCase();
    if (_kecamatanToCabangMapping.containsKey(kecamatanKey)) {
      final cabangId = _kecamatanToCabangMapping[kecamatanKey];
      // Cari objek Cabang dari daftar _allCabangs berdasarkan ID yang didapat
      final selectedCabang = _allCabangs.firstWhere(
        (cabang) => cabang.id == cabangId,
        orElse: () => Cabang(id: 0, namaCabang: 'Cabang tidak terdaftar'),
      );

      setState(() {
        // Simpan nama cabang yang ditentukan oleh kecamatan
        _cabangByKecamatanName = selectedCabang.namaCabang;
        // Atur cabang yang terpilih secara otomatis
        _selectedCabangId = selectedCabang.id;
        _nearestBranchError = null; // Hapus pesan error jika ada
      });
    } else {
      // Jika kecamatan tidak ada di pemetaan, kosongkan pilihan
      setState(() {
        _cabangByKecamatanName = null;
        _selectedCabangId = null;
        _nearestBranchError =
            'Wilayah kerja cabang untuk kecamatan ini tidak ditemukan.';
      });
    }
  }

  Future<void> _pickImage(ImageSource source, {required bool isKtp}) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    // Tampilkan dialog loading
    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Memproses gambar..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      final compressedFile = await _compressAndGetFile(File(pickedFile.path));

      if (compressedFile != null) {
        setState(() {
          if (isKtp) {
            _imageFileKtp = compressedFile;
          } else {
            _imageFileRumah = compressedFile;
          }
        });
      } else {
        _showSnackbar('Format gambar tidak didukung atau file rusak.');
      }
    } catch (e) {
      _showSnackbar('Gagal memproses gambar: $e');
    } finally {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(); // Tutup dialog loading
    }
  }

  Future<void> _submitRegistration() async {
    // === VALIDASI NOMOR WHATSAPP SECARA MANUAL ===
    // Ini adalah baris KUNCI untuk memastikan validasi WA berjalan
    final noWa = _noWaController.text;
    if (noWa.isEmpty) {
      _showSnackbar('Nomor WA wajib diisi.', isError: true);
      return;
    }
    if (noWa.length < 10) {
      _showSnackbar('Nomor WA minimal 10 digit.', isError: true);
      return;
    }
    if (noWa.length > 14) {
      _showSnackbar('Nomor WA tidak valid/terlalu banyak.', isError: true);
      return;
    }

    // === Lanjutkan dengan validasi form dan validasi lainnya ===
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackbar('Harap lengkapi semua data yang wajib diisi.');
      return;
    }

    // === Lanjutkan dengan validasi form dan validasi lainnya ===
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackbar('Harap lengkapi semua data yang wajib diisi.');
      return;
    }
    if (_imageFileKtp == null) {
      _showSnackbar('Foto KTP wajib diunggah.');
      return;
    }
    if (_imageFileRumah == null) {
      _showSnackbar('Foto Rumah wajib diunggah.');
      return;
    }
    if (_gpsCoordinates == null) {
      _showSnackbar(
          'Lokasi GPS belum didapatkan. Pastikan izin lokasi diberikan dan coba lagi.',
          isError: true);
      return;
    }
    if (_selectedCabangId == null) {
      _showSnackbar(
          _nearestBranchError ??
              'Tidak dapat menentukan cabang terdekat. Mohon cek lokasi Anda.',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'id_cabang': _selectedCabangId?.toString() ?? '',
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
      };

      final responseData = await _apiService.registerCalonPelanggan(
        data: data,
        imagePathKtp: _imageFileKtp!.path,
        imagePathRumah: _imageFileRumah!.path,
      );

      final trackingCode = responseData['data']?['tracking_code'] as String?;
      _showSuccessDialog(trackingCode);
    } catch (e) {
      _showSnackbar(
        'Pendaftaran Gagal: ${e.toString().replaceFirst("Exception: ", "")}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pendaftaran Pelanggan Baru',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth > 600;
                return SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          if (isWideScreen)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  flex: 1,
                                  child: _buildPersonalDataCard(),
                                ),
                                const SizedBox(width: 24),
                                Flexible(
                                  flex: 1,
                                  child: Column(
                                    children: [
                                      _buildAddressInfoCard(),
                                      const SizedBox(height: 24),
                                      _buildDocumentCard(),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _buildPersonalDataCard(),
                                const SizedBox(height: 24),
                                _buildAddressInfoCard(),
                                const SizedBox(height: 24),
                                _buildDocumentCard(),
                              ],
                            ),
                          const SizedBox(height: 24),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPersonalDataCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Data Pribadi', Ionicons.person_outline),
            const SizedBox(height: 16),
            _buildTitledTextField(
              controller: _namaController,
              title: 'Nama Lengkap (sesuai KTP) *',
              hint: 'Masukkan nama lengkap sesuai KTP',
              prefixIcon: Ionicons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildKtpField(),
            const SizedBox(height: 16),
            _buildTitledTextField(
              controller: _noWaController,
              title: 'Nomor WhatsApp Aktif *',
              hint: 'Contoh: 08123456789',
              prefixIcon: Ionicons.logo_whatsapp,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTitledTextField(
              controller: _alamatKtpController,
              title: 'Alamat Lengkap Sesuai KTP *',
              hint: 'Masukkan alamat lengkap sesuai KTP',
              prefixIcon: Ionicons.home_outline,
              maxLines: 3,
              showCounter: true,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'Informasi Alamat Pemasangan', Ionicons.location_outline),
            const SizedBox(height: 16),
            if (_gpsCoordinates != null) _buildLocationStatus(),
            const SizedBox(height: 16),
            _buildTitledTextField(
              controller: _provinsiController,
              title: 'PROVINSI',
              prefixIcon: Ionicons.location_outline,
              readOnly: true,
              isReadOnlyField: true,
            ),
            const SizedBox(height: 16),
            _buildTitledTextField(
              controller: _kabupatenKotaController,
              title: 'KABUPATEN/KOTA',
              prefixIcon: Ionicons.location_outline,
              readOnly: true,
              isReadOnlyField: true,
            ),
            const SizedBox(height: 16),
            _buildKecamatanDropdown(),
            const SizedBox(height: 16),
            _buildDesaDropdown(),
            const SizedBox(height: 16),
            _buildAutomaticBranchCard(),
            const SizedBox(height: 16),
            _buildTitledTextField(
              controller: _deskripsiAlamatController,
              title: 'Alamat Lengkap Pemasangan (Jalan, No. Rumah, RT/RW) *',
              hint:
                  'Kepandean, Indramayu, Jawa Barat, Jawa, 45213, Indonesia',
              prefixIcon: Ionicons.location_outline,
              maxLines: 3,
              showCounter: true,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Dokumen', Ionicons.document_text_outline),
            const SizedBox(height: 16),
            _buildImageUploadCard(
              title: 'Foto KTP *',
              imageFile: _imageFileKtp,
              onTap: () =>
                  _showImageSourceActionSheet(context, isKtp: true),
              placeholder:
                  'Unggah Foto KTP\nKlik untuk memilih dari galeri atau kamera',
            ),
            const SizedBox(height: 16),
            _buildImageUploadCard(
              title: 'Foto Tampak Depan Lokasi Pemasangan *',
              imageFile: _imageFileRumah,
              onTap: () =>
                  _showImageSourceActionSheet(context, isKtp: false),
              placeholder:
                  'Unggah Foto Lokasi Pemasangan\nKlik untuk memilih dari galeri atau kamera',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[900]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTitledTextField({
    required TextEditingController controller,
    required String title,
    String? hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    int? maxLines = 1,
    bool readOnly = false,
    bool isReadOnlyField = false,
    bool showCounter = false,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          buildCounter: showCounter
              ? (context,
                  {required currentLength, required isFocused, maxLength}) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$currentLength/$maxLength',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                  );
                }
              : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.blue[900])
                : null,
            filled: true,
            fillColor: isReadOnlyField ? Colors.grey.shade100 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[900]!, width: 2.0),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 16.0,
            ),
          ),
          style: GoogleFonts.poppins(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '$title wajib diisi';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildKtpField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nomor KTP (16 digit) *',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _noKtpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
          ],
          decoration: InputDecoration(
            hintText: 'Masukkan 16 digit nomor KTP',
            prefixIcon: Icon(Ionicons.card_outline, color: Colors.blue[900]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[900]!, width: 2.0),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 16.0,
            ),
            counterText: '${_noKtpController.text.length}/16 digit',
            counterStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
          style: GoogleFonts.poppins(),
          onChanged: (value) {
            setState(() {});
          },
          validator: (v) {
            if (v == null || v.isEmpty) {
              return 'Nomor KTP wajib diisi';
            }
            if (v.length != 16) {
              return 'Nomor KTP harus 16 digit';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildKecamatanDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kecamatan (Wajib & Penentu Cabang)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedKecamatanCode,
          hint: Text(_isKecamatanLoading ? 'Memuat kecamatan...' : 'Pilih Kecamatan'),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Ionicons.map_outline, color: Colors.blue[900]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[900]!, width: 2.0),
            ),
          ),
          onChanged: _isKecamatanLoading
              ? null
              : (value) {
                  if (value != null) {
                    final selectedItem = _kecamatanOptions
                        .firstWhere((k) => k['code'] == value, orElse: () => {});

                    if (selectedItem.isNotEmpty) {
                      final String? kecamatanCode = selectedItem['code'] as String?;
                      setState(() {
                        _selectedKecamatanCode = selectedItem['code'];
                        _selectedKecamatanId = kecamatanCode;
                        _selectedKecamatanName = selectedItem['name'];
                        _updateCabangBasedOnKecamatan(selectedItem['name']);
                      });
                      if (kecamatanCode != null) {
                        _fetchDesa(kecamatanCode);
                      }
                    }
                  }
                },
          items: _kecamatanOptions
              .map((kecamatan) {
                if (kecamatan is Map &&
                    kecamatan['code'] != null &&
                    kecamatan['name'] != null) {
                  return DropdownMenuItem<String>(
                    value: kecamatan['code'].toString(),
                    child: Text(kecamatan['name'], style: GoogleFonts.poppins()),
                  );
                }
                return null;
              })
              .whereType<DropdownMenuItem<String>>()
              .toList(),
          validator: (v) => v == null ? 'Kecamatan wajib dipilih' : null,
        ),
      ],
    );
  }

  Widget _buildLocationStatus() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(Ionicons.checkmark_circle_outline, color: Colors.green.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Lokasi GPS & Alamat berhasil didapatkan otomatis!',
              style: GoogleFonts.poppins(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesaDropdown() {
    log('Membangun dropdown desa, kecamatan dipilih: ${_selectedKecamatanId != null}, loading desa: $_isDesaLoading');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Desa/Kelurahan',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDesaName,
          hint: Text('Pilih Kecamatan terlebih dahulu'),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Ionicons.location_outline, color: Colors.blue[900]),
            filled: true,
            fillColor: _selectedKecamatanCode == null
                ? Colors.grey.shade100
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[900]!, width: 2.0),
            ),
          ),
          onChanged: _selectedKecamatanCode == null || _isDesaLoading
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _selectedDesaName = value;
                    });
                  }
                },
          items: _desaOptions.where((item) => item is Map && item.containsKey('name')).map<DropdownMenuItem<String>>((desa) {
            return DropdownMenuItem(
              value: desa['name'] as String,
              child: Text(
                desa['name'] as String,
                style: GoogleFonts.poppins(),
              ),
            );
          }).toList(),
          validator: (v) => v == null ? 'Desa/Kelurahan wajib dipilih' : null,
        ),
      ],
    );
  }

  Widget _buildAutomaticBranchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CABANG PEMASANGAN OTOMATIS',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saran Terdekat (GPS): $_cabangByGpsName',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required File? imageFile,
    required VoidCallback onTap,
    required String placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.fromBorderSide(
                BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: imageFile == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Ionicons.camera_outline,
                          size: 48,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          placeholder,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(imageFile, fit: BoxFit.cover),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                'Daftar Sekarang',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _showImageSourceActionSheet(
    BuildContext context, {
    required bool isKtp,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Ionicons.image_outline),
              title: const Text('Galeri'),
              onTap: () {
                _pickImage(ImageSource.gallery, isKtp: isKtp);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Ionicons.camera_outline),
              title: const Text('Kamera'),
              onTap: () {
                _pickImage(ImageSource.camera, isKtp: isKtp);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
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
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: backgroundColor ??
            (isError ? Colors.red.shade700 : Colors.green.shade700),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(String? trackingCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Pendaftaran Berhasil',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terima kasih! Data Anda telah kami terima. Mohon simpan kode pendaftaran ini untuk melacak status pendaftaran Anda:',
            ),
            const SizedBox(height: 15),
            if (trackingCode != null)
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
            child: Text('OK',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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