// lib/temuan_kebocoran_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Clipboard
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan path ini benar
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart'; // Untuk Ionicons

class TemuanKebocoranPage extends StatefulWidget {
  const TemuanKebocoranPage({super.key});

  @override
  State<TemuanKebocoranPage> createState() => _TemuanKebocoranPageState();
}

class _TemuanKebocoranPageState extends State<TemuanKebocoranPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  late String _apiUrlSubmit;

  final TextEditingController _lokasiMapsController = TextEditingController();
  final TextEditingController _deskripsiLokasiController =
      TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nomorHpController = TextEditingController();

  int? _selectedCabangId;
  List<Map<String, dynamic>> _cabangOptionsApi = [];
  bool _isCabangLoading = true;
  String? _cabangError;
  String? _detectedCabangName;

  Position? _currentPosition;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isLoadingSubmit = false;
  bool _isFetchingLocation = false; // Tetap digunakan untuk indikator loading

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _apiUrlSubmit = '${_apiService.baseUrl}/temuan-kebocoran';

    // Panggil kedua fungsi fetch di initState
    // _fetchCabangOptions akan berjalan, dan setelah selesai, jika _currentPosition sudah ada,
    // ia akan memanggil _findNearestBranch.
    _fetchCabangOptions();

    // _getCurrentLocation juga akan berjalan, dan setelah selesai,
    // ia akan memanggil _findNearestBranch jika _cabangOptionsApi sudah ada.
    _getCurrentLocation(); // <--- PANGGIL OTOMATIS DI SINI

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _lokasiMapsController.dispose();
    _deskripsiLokasiController.dispose();
    _namaController.dispose();
    _nomorHpController.dispose();
    super.dispose();
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
            backgroundColor ??
            (isError ? Colors.red.shade600 : Colors.green.shade600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        elevation: 6,
      ),
    );
  }

  Future<void> _fetchCabangOptions() async {
    if (!mounted) return;
    setState(() {
      _isCabangLoading = true;
      _cabangError = null;
    });
    try {
      final response = await _apiService.fetchCabangs().timeout(
        const Duration(seconds: 20),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Map<String, dynamic>> options =
            data
                .where(
                  (item) =>
                      item is Map<String, dynamic> &&
                      item.containsKey('id') &&
                      item.containsKey('nama_cabang'),
                )
                .map(
                  (item) => {
                    'id': item['id'] as int,
                    'nama_cabang': item['nama_cabang'] as String,
                    'lokasi_maps': item['lokasi_maps'] as String?,
                  },
                )
                .toList();
        setState(() => _cabangOptionsApi = options);
        // Coba cari cabang terdekat jika lokasi sudah ada
        if (_currentPosition != null) _findNearestBranch();
      } else {
        setState(
          () =>
              _cabangError =
                  'Gagal memuat cabang (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () =>
            _cabangError =
                'Terjadi kesalahan saat memuat data cabang: ${e.toString()}',
      );
    } finally {
      if (mounted) setState(() => _isCabangLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    // Hanya set _isFetchingLocation jika belum ada proses fetching lain atau jika ini panggilan manual
    // Untuk initState, kita anggap ini adalah fetch awal.
    if (!_isFetchingLocation) {
      setState(() {
        _isFetchingLocation = true;
        // Tidak perlu clear _lokasiMapsController di sini jika ini adalah fetch otomatis awal,
        // kecuali jika ini adalah panggilan dari tombol refresh.
        // _lokasiMapsController.clear();
        _selectedCabangId = null;
        _detectedCabangName = null;
      });
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar(
          'Layanan lokasi tidak aktif. Mohon aktifkan.',
          isError: true,
        );
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar('Izin lokasi ditolak oleh pengguna.', isError: true);
          if (mounted) setState(() => _isFetchingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackbar(
          'Izin lokasi ditolak permanen. Aktifkan dari pengaturan aplikasi.',
          isError: true,
        );
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(
          seconds: 20,
        ), // Timeout sedikit lebih lama untuk fetch awal
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _lokasiMapsController.text =
              '${position.latitude.toStringAsFixed(7)}, ${position.longitude.toStringAsFixed(7)}';
        });
        _showSnackbar('Lokasi otomatis berhasil didapatkan!', isError: false);
        // Coba cari cabang terdekat setelah lokasi didapat
        _findNearestBranch();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          'Gagal mendapatkan lokasi otomatis: ${e.toString()}',
          isError: true,
        );
        // Biarkan _lokasiMapsController kosong atau dengan nilai sebelumnya jika ada
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _findNearestBranch() {
    // Fungsi ini hanya berjalan jika kedua data (cabang dan posisi) sudah siap
    if (_cabangOptionsApi.isEmpty ||
        _currentPosition == null ||
        _isCabangLoading) {
      // Jika cabang masih loading, tunggu sampai selesai baru coba lagi (dipanggil dari _fetchCabangOptions.then)
      return;
    }

    int? nearestBranchId;
    String? nearestBranchName;
    double minDistance = double.infinity;

    for (var cabang in _cabangOptionsApi) {
      if (cabang['lokasi_maps'] != null &&
          (cabang['lokasi_maps'] as String).isNotEmpty) {
        try {
          final List<String> latLng = (cabang['lokasi_maps'] as String).split(
            ',',
          );
          if (latLng.length == 2) {
            final double branchLat = double.parse(latLng[0].trim());
            final double branchLng = double.parse(latLng[1].trim());
            final double distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              branchLat,
              branchLng,
            );
            if (distance < minDistance) {
              minDistance = distance;
              nearestBranchId = cabang['id'] as int;
              nearestBranchName = cabang['nama_cabang'] as String;
            }
          }
        } catch (e) {
          /* Abaikan cabang dengan format lokasi salah */
        }
      }
    }

    if (mounted && nearestBranchId != null) {
      setState(() {
        _selectedCabangId = nearestBranchId;
        _detectedCabangName = nearestBranchName;
      });
      _showSnackbar(
        'Cabang terdekat ($nearestBranchName) otomatis dipilih berdasarkan lokasi Anda.',
        isError: false,
        backgroundColor: Colors.blue.shade700,
      );
    } else if (mounted) {
      setState(() {
        _selectedCabangId = null; // Reset jika tidak ada yang cocok
        _detectedCabangName = null;
      });
      // Tidak perlu menampilkan snackbar error jika ini adalah hasil dari proses otomatis awal,
      // kecuali jika dipicu oleh tombol manual.
      // _showSnackbar('Tidak ada cabang terdekat yang dapat ditentukan dari lokasi Anda saat ini.', isError: true);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) _showSnackbar('Gagal memilih gambar: $e', isError: true);
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Ionicons.image_outline, size: 26),
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(fontSize: 16),
                ),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Ionicons.camera_outline, size: 26),
                title: const Text(
                  'Ambil Foto dari Kamera',
                  style: TextStyle(fontSize: 16),
                ),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Harap perbaiki semua error pada form.', isError: true);
      return;
    }
    if (_selectedCabangId == null) {
      _showSnackbar(
        'Silakan pilih cabang pelaporan, atau pastikan lokasi Anda terdeteksi untuk pemilihan otomatis.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoadingSubmit = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrlSubmit));
      request.headers['Accept'] = 'application/json';

      request.fields['nama_pelapor'] = _namaController.text.trim();
      request.fields['nomor_hp_pelapor'] = _nomorHpController.text.trim();
      request.fields['id_cabang'] = _selectedCabangId.toString();
      request.fields['lokasi_maps'] = _lokasiMapsController.text.trim();
      request.fields['deskripsi_lokasi'] =
          _deskripsiLokasiController.text.trim();

      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_bukti',
            _imageFile!.path,
            filename: _imageFile!.path.split('/').last,
          ),
        );
      }

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final String? trackingCode =
            responseData['data']?['tracking_code'] as String?;
        _showSnackbar(
          responseData['message'] ?? 'Laporan berhasil dikirim!',
          isError: false,
        );
        _formKey.currentState?.reset();
        setState(() {
          _namaController.clear();
          _nomorHpController.clear();
          _selectedCabangId = null;
          _imageFile = null;
          _lokasiMapsController.clear();
          _deskripsiLokasiController.clear();
          _currentPosition = null;
          _detectedCabangName = null;
        });

        if (trackingCode != null && trackingCode.isNotEmpty) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (BuildContext dialogContext) =>
                    _buildSuccessDialog(dialogContext, trackingCode),
          );
        } else {
          _showSnackbar(
            'Laporan terkirim, namun kode pelacakan tidak diterima.',
            isError: true,
          );
        }
      } else {
        String errorMessage =
            responseData['message'] ??
            'Gagal mengirim data (Status: ${response.statusCode})';
        if (responseData['errors'] != null && responseData['errors'] is Map) {
          (responseData['errors'] as Map<String, dynamic>).forEach((
            key,
            value,
          ) {
            if (value is List && value.isNotEmpty) {
              errorMessage += '\n- ${value[0]}';
            }
          });
        }
        _showSnackbar(errorMessage, isError: true);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Terjadi kesalahan.';
        if (e is TimeoutException) {
          errorMsg = 'Server tidak merespons. Periksa koneksi Anda.';
        } else if (e.toString().isNotEmpty)
          errorMsg = e.toString().replaceFirst("Exception: ", "");
        _showSnackbar(errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingSubmit = false);
    }
  }

  AlertDialog _buildSuccessDialog(
    BuildContext dialogContext,
    String trackingCode,
  ) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(
            Ionicons.checkmark_done_circle_outline,
            color: Colors.green,
            size: 28,
          ),
          SizedBox(width: 10),
          Text('Laporan Terkirim'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Terima kasih! Laporan Anda telah berhasil dikirim. Mohon simpan kode pelacakan ini:',
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Ionicons.copy_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  tooltip: 'Salin Kode',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: trackingCode));
                    ScaffoldMessenger.of(dialogContext).hideCurrentSnackBar();
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Kode Pelacakan disalin!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Gunakan kode ini untuk melacak progres laporan Anda melalui fitur "Lacak Laporan".',
            style: TextStyle(fontSize: 13.5),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text(
            'OK',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(icon, size: 22),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
          suffixIcon: suffixIcon,
        ),
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        readOnly: readOnly,
        style: TextStyle(
          color: readOnly ? Colors.grey.shade700 : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCabangDropdown() {
    if (_isCabangLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 12),
            Text("Memuat data cabang...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (_cabangError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          children: [
            Icon(
              Ionicons.warning_outline,
              color: Colors.red.shade400,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              _cabangError!,
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Ionicons.refresh_outline, size: 18),
              label: const Text("Coba Lagi Muat Cabang"),
              onPressed: _fetchCabangOptions,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<int>(
        value: _selectedCabangId,
        hint: const Text('Pilih Cabang Pelaporan'),
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Cabang Pelaporan',
          prefixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(Ionicons.business_outline, size: 22),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
        ),
        items:
            _cabangOptionsApi.isEmpty
                ? [
                  const DropdownMenuItem<int>(
                    value: null,
                    enabled: false,
                    child: Text(
                      "Tidak ada cabang",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ]
                : _cabangOptionsApi
                    .map(
                      (cabang) => DropdownMenuItem<int>(
                        value: cabang['id'] as int,
                        child: Text(
                          cabang['nama_cabang'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
        onChanged:
            _isCabangLoading || _cabangOptionsApi.isEmpty
                ? null
                : (value) {
                  setState(() {
                    _selectedCabangId = value;
                    _detectedCabangName = null;
                  });
                },
        validator:
            (value) =>
                value == null &&
                        !_isCabangLoading &&
                        _cabangError == null &&
                        _cabangOptionsApi.isNotEmpty
                    ? 'Cabang wajib dipilih'
                    : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Lapor Temuan Kebocoran',
          style: GoogleFonts.lato(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: theme.primaryColorDark,
        elevation: 1.0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Ionicons.arrow_back_circle_outline, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 16.0),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Ionicons.water_outline,
                      size: 48,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Formulir Laporan Kebocoran',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColorDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Laporkan temuan kebocoran pipa PDAM di sekitar Anda. Laporan Anda sangat berarti untuk perbaikan layanan.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    _buildTextField(
                      controller: _namaController,
                      labelText: 'Nama Pelapor',
                      hintText: 'Masukkan nama lengkap Anda',
                      icon: Ionicons.person_outline,
                      validator:
                          (v) =>
                              v == null || v.isEmpty
                                  ? 'Nama pelapor wajib diisi'
                                  : null,
                    ),
                    _buildTextField(
                      controller: _nomorHpController,
                      labelText: 'Nomor HP Pelapor',
                      hintText: 'Contoh: 08123456xxxx',
                      icon: Ionicons.call_outline,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Nomor HP wajib diisi';
                        }
                        if (v.length < 10 || v.length > 15) {
                          return 'Nomor HP 10-15 digit';
                        }
                        return null;
                      },
                    ),

                    _buildTextField(
                      controller: _lokasiMapsController,
                      labelText: 'Koordinat Lokasi (Lat,Lng)',
                      hintText:
                          _isFetchingLocation
                              ? 'Mencari lokasi...'
                              : 'Tekan ikon untuk lokasi otomatis',
                      icon: Ionicons.location_outline,
                      readOnly: true, // Selalu readonly, diisi oleh tombol
                      suffixIcon:
                          _isFetchingLocation
                              ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                              : IconButton(
                                icon: const Icon(
                                  Ionicons.locate_sharp,
                                ), // Ikon lebih jelas
                                tooltip: 'Dapatkan Lokasi & Cabang Terdekat',
                                onPressed:
                                    _isFetchingLocation || _isCabangLoading
                                        ? null
                                        : _getCurrentLocation,
                              ),
                      validator:
                          (v) =>
                              v == null || v.isEmpty
                                  ? 'Lokasi maps wajib diisi (gunakan tombol lokasi)'
                                  : null,
                    ),

                    _buildCabangDropdown(),

                    if (_detectedCabangName != null &&
                        _selectedCabangId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0, top: 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Ionicons.information_circle_outline,
                                color: Colors.blue.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Cabang terdekat terdeteksi: $_detectedCabangName",
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    _buildTextField(
                      controller: _deskripsiLokasiController,
                      labelText: 'Deskripsi Detail Lokasi',
                      hintText:
                          'Misal: Depan Toko ABC, dekat jembatan, pipa pecah di trotoar',
                      icon: Ionicons.map_outline,
                      maxLines: 3,
                      validator:
                          (v) =>
                              v == null || v.isEmpty
                                  ? 'Deskripsi lokasi wajib diisi'
                                  : null,
                    ),

                    const SizedBox(height: 12.0),
                    Text(
                      'Foto Bukti Kebocoran (Opsional)',
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    GestureDetector(
                      onTap: () => _showImageSourceActionSheet(context),
                      child: Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          border: Border.all(
                            color:
                                _imageFile == null
                                    ? Colors.grey.shade400
                                    : Colors.blue.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child:
                            _imageFile == null
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Ionicons.camera_reverse_outline,
                                        size: 44,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Ketuk untuk pilih/ambil foto',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ClipRRect(
                                  borderRadius: BorderRadius.circular(10.5),
                                  child: Image.file(
                                    _imageFile!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (ctx, err, st) => const Center(
                                          child: Text('Gagal muat pratinjau'),
                                        ),
                                  ),
                                ),
                      ),
                    ),
                    if (_imageFile != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(
                            Ionicons.trash_bin_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          label: const Text(
                            'Hapus Foto',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () => setState(() => _imageFile = null),
                        ),
                      ),
                    const SizedBox(height: 28.0),

                    ElevatedButton.icon(
                      icon:
                          _isLoadingSubmit
                              ? Container()
                              : const Icon(
                                Ionicons.send_sharp,
                                color: Colors.white,
                                size: 18,
                              ),
                      label:
                          _isLoadingSubmit
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text(
                                'KIRIM LAPORAN',
                                style: TextStyle(
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      onPressed:
                          _isLoadingSubmit ||
                                  _isCabangLoading ||
                                  _isFetchingLocation ||
                                  (_cabangOptionsApi.isEmpty &&
                                      _cabangError == null)
                              ? null
                              : _submitForm,
                      style: theme.elevatedButtonTheme.style?.copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Extension StringCapitalize sudah ada di file Anda sebelumnya
// extension StringCapitalize on String {
//   String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
// }
