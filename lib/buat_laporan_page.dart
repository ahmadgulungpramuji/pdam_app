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
  final ApiService _apiService = ApiService();

  // --- PERBAIKAN: Menambahkan controller untuk kategori lainnya ---
  final _kategoriLainnyaController = TextEditingController();

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

  // --- PERBAIKAN: Menambahkan opsi 'Lain-lain...' ke dalam daftar ---
  final List<Map<String, String>> _jenisLaporanOptions = [
    {'value': 'air_tidak_mengalir', 'label': 'Air Tidak Mengalir'},
    {'value': 'air_keruh', 'label': 'Air Keruh'},
    {'value': 'water_meter_rusak', 'label': 'Meteran Rusak'},
    {'value': 'angka_meter_tidak_sesuai', 'label': 'Angka Meter Tidak Sesuai'},
    {'value': 'tagihan_membengkak', 'label': 'Tagihan Membengkak'},
    {'value': 'lain_lain', 'label': 'Lain-lain...'}, // <-- DITAMBAHKAN
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
    _kategoriLainnyaController.dispose(); // <-- PERBAIKAN: Hapus controller
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
      isStepValid = _step3FormKey.currentState?.validate() ?? false;
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

  // --- Data Loading and Processing ---
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
        if (pelangganId != null) {
          await _fetchPdamIds(pelangganId);
        }
      }
    } else {
      _showSnackbar('Data pengguna tidak ditemukan. Harap login kembali.');
    }
  }

  Future<void> _fetchPdamIds(String idPelanggan) async {
    try {
      final pdamNumbers = await _apiService.fetchPdamNumbersByPelanggan(
        idPelanggan,
      );
      if (mounted) setState(() => _pdamIdNumbersList = pdamNumbers);
    } catch (e) {
      _showSnackbar('Gagal mengambil daftar nomor PDAM: $e');
    }
  }

  Future<void> _getCurrentLocationAndAddress() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memperbarui lokasi...'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar('Layanan lokasi dinonaktifkan.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          _showSnackbar('Izin lokasi ditolak.');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = position;
      });

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty && mounted) {
          Placemark place = placemarks[0];
          final addressParts = <String>[];
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.subAdministrativeArea != null &&
              place.subAdministrativeArea!.isNotEmpty) {
            addressParts.add(place.subAdministrativeArea!);
          }
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            addressParts.add(place.postalCode!);
          }

          String address = addressParts.join(', ');

          setState(() {
            _deskripsiLokasiManualController.text = address;
          });
        }
      } catch (e) {
        _showSnackbar('Gagal mendapatkan nama alamat. Menggunakan koordinat.');
        setState(() {
          _deskripsiLokasiManualController.text =
              'Lat: ${position.latitude}, Lng: ${position.longitude}';
        });
      }
    } catch (e) {
      _showSnackbar('Gagal mendapatkan koordinat GPS: ${e.toString()}');
    }
  }

  Future<void> _openMapApp() async {
    if (_currentPosition == null) {
      _showSnackbar('Lokasi belum ditemukan, coba lagi.');
      return;
    }
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng?q=$lat,$lng');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackbar('Tidak dapat membuka aplikasi peta.');
    }
  }

  void _onPdamNumberChanged(String? value) {
    setState(() {
      _selectedPdamIdNumber = value;
      _selectedCabangId = null;
      if (value != null && value.length >= 2) {
        final duaDigit = value.substring(0, 2);
        switch (duaDigit) {
          case '10':
            _selectedCabangId = 1;
            break;
          case '12':
            _selectedCabangId = 2;
            break;
          case '15':
            _selectedCabangId = 3;
            break;
          case '20':
            _selectedCabangId = 4;
            break;
          case '30':
            _selectedCabangId = 5;
            break;
          case '40':
            _selectedCabangId = 6;
            break;
          case '50':
            _selectedCabangId = 7;
            break;
          case '60':
            _selectedCabangId = 8;
            break;
          default:
            _selectedCabangId = null;
        }
      }
    });
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        if (type == 'bukti') {
          _fotoBuktiFile = File(pickedFile.path);
        } else if (type == 'rumah') {
          _fotoRumahFile = File(pickedFile.path);
        }
      });
    }
  }

 // Ganti seluruh fungsi _submitLaporan Anda dengan yang ini

Future<void> _submitLaporan() async {
  // Pengecekan data utama tetap diperlukan
  if (_loggedInPelangganId == null ||
      _selectedPdamIdNumber == null ||
      _selectedCabangId == null ||
      _currentPosition == null ||
      _selectedJenisLaporan == null) {
    _showSnackbar('Data esensial tidak lengkap. Mohon periksa kembali.');
    return;
  }
  if (_fotoBuktiFile == null) {
    _showSnackbar('Mohon unggah Foto Bukti.');
    return;
  }
  
  if (_fotoRumahFile == null) {
    _showSnackbar('Mohon unggah Foto Rumah.');
    return;
  }

  // BLOK VALIDASI FORM STATE YANG MENYEBABKAN ERROR SUDAH DIHAPUS DARI SINI

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
          'http://googleusercontent.com/maps.google.com/10${_currentPosition!.latitude},${_currentPosition!.longitude}',
      'deskripsi_lokasi': _deskripsiLokasiManualController.text,
      'deskripsi': _deskripsiController.text,
    };

    if (_selectedJenisLaporan == 'lain_lain') {
      dataLaporan['kategori_lainnya'] = _kategoriLainnyaController.text;
    }

    // Bagian ini memanggil ApiService Anda untuk mengirim data
    final response = await _apiService.buatPengaduan(
      dataLaporan,
      fotoBukti: _fotoBuktiFile,
      fotoRumah: _fotoRumahFile,
    );

    // Sisa dari kode tetap sama
    if (response.statusCode == 201 || response.statusCode == 200) {
      _showSnackbar('Laporan berhasil dikirim!', isError: false);
      Navigator.of(context).pop();
    } else {
      final responseData = jsonDecode(response.body);
      _showSnackbar(
        'Gagal mengirim laporan: ${responseData['message'] ?? 'Error tidak diketahui'}',
      );
    }
  } catch (e) {
    _showSnackbar('Terjadi kesalahan: $e');
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}

  // --- UI Helpers ---
  final ImagePicker _picker = ImagePicker();

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Build Methods ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Ionicons.arrow_back),
          onPressed: _previousPage,
        ),
        title: const Text('Buat Laporan'),
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
                      _buildStep1_InfoDasar(),
                      _buildStep2_Lokasi(),
                      _buildStep3_DeskripsiFoto(),
                      _buildStep4_Konfirmasi(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / 4.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Langkah ${_currentPage + 1} dari 4',
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
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStep1_InfoDasar() {
    return _buildStepWrapper(
      title: 'Informasi Dasar',
      formKey: _step1FormKey,
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Pilih Nomor PDAM'),
          items: _pdamIdNumbersList
              .map(
                (pdamNum) =>
                    DropdownMenuItem(value: pdamNum, child: Text(pdamNum)),
              )
              .toList(),
          value: _selectedPdamIdNumber,
          onChanged: _onPdamNumberChanged,
          validator: (value) => value == null ? 'Pilih Nomor PDAM' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Jenis Laporan'),
          items: _jenisLaporanOptions
              .map(
                (opt) => DropdownMenuItem(
                  value: opt['value'],
                  child: Text(opt['label']!),
                ),
              )
              .toList(),
          value: _selectedJenisLaporan,
          onChanged: (value) => setState(() => _selectedJenisLaporan = value),
          validator: (value) => value == null ? 'Pilih Jenis Laporan' : null,
        ),

        // --- PERBAIKAN: Widget baru yang muncul saat "Lain-lain" dipilih ---
        if (_selectedJenisLaporan == 'lain_lain')
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: TextFormField(
              controller: _kategoriLainnyaController,
              decoration: const InputDecoration(
                labelText: 'Sebutkan Jenis Laporan Anda',
                hintText: 'Contoh: Pipa bocor di depan rumah',
              ),
              validator: (value) {
                if (_selectedJenisLaporan == 'lain_lain' &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Wajib diisi jika memilih Lain-lain';
                }
                return null;
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStep2_Lokasi() {
    String staticMapUrl = '';
    if (_currentPosition != null) {
      final lat = _currentPosition!.latitude;
      final lng = _currentPosition!.longitude;
      const apiKey = 'aWxXDWpJ8Zo4ZasFgJ1VkKwFjdqBz6KB';
      staticMapUrl =
          'https://www.mapquestapi.com/staticmap/v5/map?key=$apiKey&center=$lat,$lng&zoom=15&size=600,300&markers=red-1,$lat,$lng';
    }

    return _buildStepWrapper(
      title: 'Detail Lokasi',
      formKey: _step2FormKey,
      children: [
        const Text(
          "Konfirmasi Lokasi Anda",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.grey.shade200,
          ),
          child: _currentPosition != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    staticMapUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      return progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          'Gagal memuat peta',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    },
                  ),
                )
              : const Center(child: Text('Mencari lokasi...')),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deskripsiLokasiManualController,
          decoration: const InputDecoration(
            labelText: 'Deskripsi Detail Lokasi (bisa diedit)',
          ),
          maxLines: 3,
          validator: (value) =>
              value == null || value.isEmpty ? 'Deskripsi lokasi wajib diisi' : null,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text("Ambil Ulang Lokasi"),
              onPressed: _getCurrentLocationAndAddress,
            ),
            TextButton.icon(
              icon: const Icon(Icons.map_outlined, size: 20),
              label: const Text("Buka di Peta"),
              onPressed: _openMapApp,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3_DeskripsiFoto() {
    return _buildStepWrapper(
      title: 'Deskripsi & Foto',
      formKey: _step3FormKey,
      children: [
        TextFormField(
          controller: _deskripsiController,
          decoration: const InputDecoration(
            labelText: 'Deskripsi Lengkap Laporan',
          ),
          maxLines: 5,
          validator: (value) =>
              value == null || value.isEmpty ? 'Deskripsi wajib diisi' : null,
        ),
        const SizedBox(height: 24),
        _buildPhotoPickerButton(
          label: 'Unggah Foto Bukti',
          file: _fotoBuktiFile,
          onPressed: () => _showImageSourceActionSheet(
            (source) => _pickImage(source, 'bukti'),
          ),
        ),
        if (_fotoBuktiFile != null) ...[
          const SizedBox(height: 8),
          Image.file(
            _fotoBuktiFile!,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        _buildPhotoPickerButton(
          label: 'Unggah Foto Rumah (Tampak Depan)',
          file: _fotoRumahFile,
          onPressed: () => _showImageSourceActionSheet(
            (source) => _pickImage(source, 'rumah'),
          ),
        ),
        if (_fotoRumahFile != null) ...[
          const SizedBox(height: 8),
          Image.file(
            _fotoRumahFile!,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ],
      ],
    );
  }

  Widget _buildStep4_Konfirmasi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konfirmasi Laporan',
            style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Harap periksa kembali semua data sebelum mengirim.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildConfirmationTile(
            Ionicons.water_outline,
            'Nomor PDAM',
            _selectedPdamIdNumber ?? '-',
          ),
          _buildConfirmationTile(
            Ionicons.list_outline,
            'Jenis Laporan',
            // --- PERBAIKAN: Logika untuk menampilkan kategori lainnya ---
            _selectedJenisLaporan == 'lain_lain'
                ? 'Lain-lain: ${_kategoriLainnyaController.text}'
                : _jenisLaporanOptions.firstWhere(
                    (e) => e['value'] == _selectedJenisLaporan,
                    orElse: () => {'label': '-'},
                  )['label']!,
          ),
          _buildConfirmationTile(
            Ionicons.location_outline,
            'Deskripsi Lokasi',
            _deskripsiLokasiManualController.text,
          ),
          _buildConfirmationTile(
            Ionicons.document_text_outline,
            'Deskripsi Laporan',
            _deskripsiController.text,
          ),
          _buildConfirmationTile(
            Ionicons.camera_outline,
            'Foto Bukti',
            _fotoBuktiFile != null ? 'Terlampir' : 'Tidak ada',
          ),
          _buildConfirmationTile(
            Ionicons.home_outline,
            'Foto Rumah',
            _fotoRumahFile != null ? 'Terlampir' : 'Tidak ada',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitLaporan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('KIRIM LAPORAN'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationTile(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.grey.shade100,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  Widget _buildPhotoPickerButton({
    required String label,
    required File? file,
    required VoidCallback onPressed,
  }) {
    bool isSelected = file != null;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isSelected ? Ionicons.checkmark_circle : Ionicons.camera_outline,
      ),
      label: Text(isSelected ? 'Foto Terpilih' : label),
      style: ElevatedButton.styleFrom(
        foregroundColor:
            isSelected ? Colors.green.shade800 : Colors.blue.shade800,
        backgroundColor:
            isSelected ? Colors.green.shade100 : Colors.blue.shade50,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  void _showImageSourceActionSheet(Function(ImageSource) onSelected) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Ionicons.camera_outline),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                onSelected(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Ionicons.image_outline),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                onSelected(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}