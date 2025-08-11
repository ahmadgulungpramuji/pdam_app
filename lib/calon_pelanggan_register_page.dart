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
enum KtpValidationState { initial, invalidLength, checking, valid, taken }

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

  KtpValidationState _ktpState = KtpValidationState.initial;
  String? _ktpServerMessage;
  Timer? _debounce;
  bool _isLocationLoading =
      false; // DIKEMBALIKAN tapi hanya untuk internal loading state

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
        _selectedCabangId = nearestBranch.id;
        _selectedCabangDisplayName =
            '${nearestBranch.namaCabang} (${minDistance.toStringAsFixed(2)} km)';
        _nearestBranchError = null; // Reset error jika ditemukan cabang
      } else {
        _selectedCabangId = null;
        _selectedCabangDisplayName = 'Tidak ada cabang terdekat ditemukan.';
        _nearestBranchError =
            'Tidak ada cabang dengan koordinat valid di Indramayu.';
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

  Future<void> _onKtpChanged(String value) async {
    if (_ktpServerMessage != null) {
      setState(() => _ktpServerMessage = null);
    }

    _debounce?.cancel();

    if (value.isEmpty) {
      setState(() => _ktpState = KtpValidationState.initial);
      return;
    }

    if (value.length < 16) {
      setState(() => _ktpState = KtpValidationState.invalidLength);
      return;
    }

    if (value.length == 16) {
      setState(() => _ktpState = KtpValidationState.checking);
      _debounce = Timer(const Duration(milliseconds: 700), () async {
        try {
          final isTaken = await _apiService.checkKtpExists(value);
          if (mounted) {
            setState(() {
              _ktpState =
                  isTaken ? KtpValidationState.taken : KtpValidationState.valid;
              if (isTaken) _ktpServerMessage = 'No. KTP ini sudah terdaftar.';
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _ktpState = KtpValidationState.taken;
              _ktpServerMessage = 'Gagal memverifikasi No. KTP.';
            });
          }
        }
      });
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
          'Daftar Pelanggan Baru',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  _buildSectionTitle('Informasi Pribadi'),
                  _buildTextFormField(
                    controller: _namaController,
                    label: 'Nama Lengkap (sesuai KTP)',
                    icon: Ionicons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  _buildKtpFormField(),

                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _noWaController,
                    label: 'Nomor WhatsApp Aktif',
                    icon: Ionicons.logo_whatsapp,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(14),
                    ],
                    validator: (v) {
                      // Validator ini hanya untuk menampilkan pesan error saat user mengetik
                      // Validasi yang menghentikan form sudah ada di _submitRegistration
                      if (v == null || v.isEmpty) {
                        return 'Nomor WA wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _alamatKtpController,
                    label: 'Alamat Lengkap Sesuai KTP',
                    icon: Ionicons.home_outline,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Informasi Alamat Pemasangan'),

                  // Bagian untuk Provinsi (read-only)
                  _buildTextFormField(
                    controller: _provinsiController,
                    label: 'Provinsi',
                    icon: Ionicons.location_outline,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),

                  // Bagian untuk Kabupaten/Kota (read-only, dengan validasi lokasi Indramayu)
                  _buildTextFormField(
                    controller: _kabupatenKotaController,
                    label: 'Kabupaten/Kota',
                    icon: Ionicons.location_outline,
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kabupaten/Kota wajib diisi.';
                      }
                      // Pengecekan apakah terdeteksi di Indramayu
                      if (_detectedKabupatenKota != null &&
                          _detectedKabupatenKota!.toUpperCase() !=
                              'INDRAMAYU') {
                        return 'Pendaftaran hanya dapat dilakukan di Kabupaten Indramayu.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildLocationStatus(), // Menampilkan status pengambilan GPS
                  _buildKecamatanDropdown(),
                  const SizedBox(height: 16),
                  _buildDesaDropdown(),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller:
                        _deskripsiAlamatController, // Menggunakan deskripsi_alamat untuk alamat detail
                    label:
                        'Alamat Lengkap Pemasangan (Jalan, No. Rumah, RT/RW)', // Label diubah
                    icon: Ionicons.boat_outline,
                    hint: 'Contoh: Jl. Merdeka No. 12, RT 01/RW 02',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Cabang Pemasangan (Otomatis dari Lokasi Terdekat)
                  // Mengganti DropdownButtonFormField dengan TextFormField read-only
                  _buildTextFormField(
                    controller:
                        TextEditingController(text: _selectedCabangDisplayName),
                    label: 'Cabang Pemasangan Otomatis',
                    icon: Ionicons.business_outline,
                    readOnly: true,
                    validator: (value) {
                      if (_selectedCabangId == null) {
                        return _nearestBranchError ??
                            'Cabang pemasangan wajib ditentukan.';
                      }
                      return null;
                    },
                  ),
                  if (_nearestBranchError != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0, top: 4.0),
                      child: Text(
                        _nearestBranchError!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12.0),
                      ),
                    ),

                  const SizedBox(height: 32),
                  _buildSectionTitle('Dokumen (Wajib)'),
                  _buildImageUploadCard(
                    title: 'Foto KTP',
                    imageFile: _imageFileKtp,
                    onTap: () =>
                        _showImageSourceActionSheet(context, isKtp: true),
                    placeholder: 'Ketuk untuk unggah foto KTP',
                  ),
                  const SizedBox(height: 24),
                  _buildImageUploadCard(
                    title: 'Foto Tampak Depan lokasi pemasangan',
                    imageFile: _imageFileRumah,
                    onTap: () =>
                        _showImageSourceActionSheet(context, isKtp: false),
                    placeholder: 'Ketuk untuk unggah foto Rumah',
                  ),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool isRequired = true,
    int? maxLines = 1,
    bool readOnly = false, // BARU: Parameter readOnly
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly, // BARU: Terapkan readOnly
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ??
          (v) {
            if (isRequired && (v == null || v.isEmpty)) {
              return '$label wajib diisi';
            }
            return null;
          },
      maxLines: maxLines,
      style: GoogleFonts.poppins(),
    );
  }

  Widget _buildKtpFormField() {
    Widget? suffixIcon;
    Color inputColor = Colors.black87;

    switch (_ktpState) {
      case KtpValidationState.invalidLength:
        suffixIcon = const Icon(Icons.cancel, color: Colors.red);
        inputColor = Colors.red;
        break;
      case KtpValidationState.checking:
        suffixIcon = const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2));
        break;
      case KtpValidationState.valid:
        suffixIcon = const Icon(Icons.check_circle, color: Colors.green);
        inputColor = Colors.green.shade800;
        break;
      case KtpValidationState.taken:
        suffixIcon = const Icon(Icons.error, color: Colors.red);
        inputColor = Colors.red;
        break;
      case KtpValidationState.initial:
        suffixIcon = null;
        break;
    }

    return TextFormField(
      controller: _noKtpController,
      onChanged: _onKtpChanged,
      decoration: InputDecoration(
        labelText: 'Nomor KTP (16 digit)',
        prefixIcon: Icon(Ionicons.card_outline,
            color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
        suffixIcon: suffixIcon,
        helperText: _ktpState == KtpValidationState.checking
            ? 'Memeriksa ketersediaan...'
            : _ktpServerMessage,
        helperStyle: TextStyle(
            color: _ktpState == KtpValidationState.taken
                ? Colors.red
                : Colors.grey),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(16),
      ],
      style: GoogleFonts.poppins(
        color: inputColor,
        fontWeight: FontWeight.w600,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Nomor KTP wajib diisi';
        if (_ktpState == KtpValidationState.invalidLength) {
          return 'Nomor KTP harus 16 digit';
        }
        if (_ktpState == KtpValidationState.taken) {
          return _ktpServerMessage;
        }
        if (_ktpState != KtpValidationState.valid) {
          return 'Mohon pastikan No. KTP benar dan tersedia.';
        }
        return null;
      },
    );
  }

  Widget _buildKecamatanDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedKecamatanCode,
      hint:
          Text(_isKecamatanLoading ? 'Memuat kecamatan...' : 'Pilih Kecamatan'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Kecamatan',
        prefixIcon: Icon(Ionicons.map_outline,
            color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
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
    );
  }

  // BARU: Widget untuk menampilkan status pengambilan GPS
  Widget _buildLocationStatus() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: _gpsCoordinates != null
            ? Colors.green.shade100
            : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _gpsCoordinates != null
                ? Colors.green.shade600
                : Colors.blue.shade600,
            width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isLocationLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.blueAccent))
              : Icon(
                  _gpsCoordinates != null
                      ? Ionicons.checkmark_circle
                      : Ionicons.location_outline,
                  color: _gpsCoordinates != null
                      ? Colors.green.shade800
                      : Colors.blue.shade800,
                  size: 28,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isLocationLoading
                  ? 'Sedang mendapatkan lokasi GPS dan alamat otomatis...'
                  : (_gpsCoordinates != null
                      ? 'Lokasi GPS & Alamat berhasil didapatkan otomatis!'
                      : 'Pastikan izin lokasi diaktifkan. Lokasi akan diambil secara otomatis.'),
              style: GoogleFonts.poppins(
                color: _gpsCoordinates != null
                    ? Colors.green.shade800
                    : Colors.blue.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesaDropdown() {
    log('Membangun dropdown desa, kecamatan dipilih: ${_selectedKecamatanId != null}, loading desa: $_isDesaLoading');

    return DropdownButtonFormField<String>(
      value: _selectedDesaName,
      hint: Text(_isDesaLoading ? 'Memuat desa...' : 'Pilih Desa/Kelurahan'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Desa/Kelurahan',
        prefixIcon: Icon(Ionicons.location_outline,
            color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: _selectedKecamatanId == null
            ? Colors.grey.shade200
            : Colors.grey.shade50,
      ),
      onChanged: _selectedKecamatanId == null || _isDesaLoading
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  _selectedDesaName = value;
                });
              }
            },
      items: _desaOptions
          .where((item) => item is Map && item.containsKey('name'))
          .map<DropdownMenuItem<String>>((desa) {
        return DropdownMenuItem(
          value: desa['name'] as String,
          child: Text(
            desa['name'] as String,
            style: GoogleFonts.poppins(),
          ),
        );
      }).toList(),
      validator: (v) => v == null ? 'Desa/Kelurahan wajib dipilih' : null,
    );
  }

  // Metode _buildCabangDropdown lama dihapus
  // Sekarang digantikan dengan TextFormField read-only di build method

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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: imageFile == null
                    ? Colors.red.shade300
                    : Colors.green.shade400,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: imageFile == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Ionicons.camera_outline,
                          size: 60,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          placeholder,
                          style:
                              GoogleFonts.poppins(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(imageFile, fit: BoxFit.cover),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _isSubmitting ? null : _submitRegistration,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 8,
      ),
      icon: _isSubmitting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : const Icon(Ionicons.send_outline),
      label: Text(
        _isSubmitting ? 'Mendaftar...' : 'DAFTAR SEKARANG',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
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
