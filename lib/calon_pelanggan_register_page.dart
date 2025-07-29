// ignore_for_file: unused_field

import 'dart:async'; // <-- Ditambahkan
import 'dart:developer' show log;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/cabang_model.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

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
  final _apiService = ApiService();
  final _namaController = TextEditingController();
  final _noKtpController = TextEditingController();
  final _alamatController = TextEditingController();
  final _alamatKtpController = TextEditingController();
  final _deskripsiAlamatController = TextEditingController();
  final _noWaController = TextEditingController();

  // --- State Variables ---
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _kecamatanOptions = [];
  List<dynamic> _desaOptions = [];

  // Variabel state yang sudah diperbaiki untuk wilayah
  String? _selectedKecamatanId;
  String? _selectedKecamatanCode;
  String? _selectedKecamatanName;
  String? _selectedDesaName;

  bool _isKecamatanLoading = true;
  bool _isDesaLoading = false;
  bool _isCabangLoading = true;

  String? _cabangError;
  List<Cabang> _cabangOptions = [];
  int? _selectedCabangId;
  String? _detectedCabangName;
  Position? _currentPosition;
  File? _imageFileKtp;
  File? _imageFileRumah;
  final _picker = ImagePicker();

  late AnimationController _locationButtonAnimationController;
  late Animation<double> _scaleAnimationLocation;

 
  KtpValidationState _ktpState = KtpValidationState.initial;
  String? _ktpServerMessage;
  Timer? _debounce;
  bool _isLocationLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _locationButtonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimationLocation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _locationButtonAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel(); // <-- Ditambahkan untuk mencegah memory leak
    _namaController.dispose();
    _noKtpController.dispose();
    _alamatController.dispose();
    _alamatKtpController.dispose();
    _deskripsiAlamatController.dispose();
    _noWaController.dispose();
    _locationButtonAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchCabangOptions();
    await _fetchKecamatan();
    await _getCurrentLocation();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCabangOptions() async {
    setState(() => _isCabangLoading = true);
    try {
      final options = await _apiService.getCabangList();
      if (mounted) {
        setState(() {
          _cabangOptions = options;
          _findNearestBranch();
        });
      }
    } catch (e) {
      // Error handling
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

  Future<void> _fetchDesa(String kecamatanId) async {
    setState(() {
      _isDesaLoading = true;
      _desaOptions = [];
      _selectedDesaName = null;
    });
    try {
      final List<dynamic> desaData = await _apiService.getDesa(kecamatanId);
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

  Future<void> _getCurrentLocation() async {
    // 1. Mulai state loading
    setState(() => _isLocationLoading = true); 

    try {
      // 2. Dapatkan izin dan koordinat GPS
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
      );

      // 3. Panggil API untuk mengubah koordinat menjadi alamat
      final String addressFromGps = await _apiService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // 4. Update state dengan data baru
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _alamatController.text = addressFromGps; // Isi detail alamat
        });
        _showSnackbar('Lokasi & Alamat berhasil didapatkan!', isError: false);
        _findNearestBranch(); // Cari cabang terdekat
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currentPosition = null);
        _showSnackbar(e.toString().replaceFirst("Exception: ", ""), isError: true);
      }
    } finally {
      // 5. Selalu hentikan state loading, baik berhasil maupun gagal
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

 void _findNearestBranch() {
    if (_cabangOptions.isEmpty || _currentPosition == null) return;

    int? nearestBranchId;
    String? nearestBranchName;
    double minDistance = double.infinity;

    for (var cabang in _cabangOptions) {
      final String? lokasiMaps = cabang.lokasiMaps;
      if (lokasiMaps != null && lokasiMaps.isNotEmpty) {
        try { // <- Kunci: Blok try-catch ada di dalam loop
          final List<String> latLng = lokasiMaps.split(',');
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
              nearestBranchId = cabang.id;
              nearestBranchName = cabang.namaCabang;
            }
          }
        } catch (e) {
          // JIKA ADA ERROR PADA 1 DATA, CETAK LOG & LANJUTKAN KE DATA BERIKUTNYA
          log('Error parsing lokasi_maps untuk cabang ID ${cabang.id}: $e');
        }
      }
    }

    if (mounted && nearestBranchId != null) {
      setState(() {
        _selectedCabangId = nearestBranchId;
        _detectedCabangName = nearestBranchName;
      });
      _showSnackbar(
        'Cabang terdekat ($nearestBranchName) otomatis terpilih.',
        isError: false,
        backgroundColor: Colors.blue.shade700,
      );
    }
  }

  Future<void> _pickImage(ImageSource source, {required bool isKtp}) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (pickedFile != null) {
        setState(() {
          if (isKtp) {
            _imageFileKtp = File(pickedFile.path);
          } else {
            _imageFileRumah = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      _showSnackbar('Gagal memilih gambar: $e', isError: true);
    }
  }

  /// Metode baru untuk menangani logika validasi KTP
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

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'id_cabang': _selectedCabangId?.toString() ?? '',
        'nama_lengkap': _namaController.text,
        'no_ktp': _noKtpController.text,
        'kecamatan': _selectedKecamatanName ?? '',
        'desa_kelurahan': _selectedDesaName ?? '',
        'alamat': _alamatController.text,
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
                  
                  // Pemanggilan widget KTP yang baru
                  _buildKtpFormField(),
                  
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _noWaController,
                    label: 'Nomor WhatsApp Aktif',
                    icon: Ionicons.logo_whatsapp,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nomor WA wajib diisi';
                      if (v.length < 10) return 'Nomor WA minimal 10 digit';
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
                   _buildLocationNote(), 
                  _buildKecamatanDropdown(),
                  const SizedBox(height: 16),
                  _buildDesaDropdown(),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _alamatController,
                    label: 'Detail Alamat (Nama Jalan, No. Rumah, RT/RW)',
                    icon: Ionicons.boat_outline,
                    hint: 'Contoh: Jl. Merdeka No. 12, RT 01/RW 02',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildCabangDropdown(),
                  const SizedBox(height: 16),
                  _buildLocationField(),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _deskripsiAlamatController,
                    label: 'Deskripsi Tambahan Alamat',
                    icon: Ionicons.map_outline,
                    hint: 'Contoh: Rumah cat biru, dekat masjid',
                    isRequired: false,
                    maxLines: 3,
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
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon,
            color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
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

  /// Widget baru yang didedikasikan untuk field KTP dengan validasi real-time.
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
            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
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
            color: _ktpState == KtpValidationState.taken ? Colors.red : Colors.grey),
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
        // Pastikan KTP sudah divalidasi dan benar sebelum submit
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


    Widget _buildLocationNote() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade600, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Ionicons.warning_outline,
            color: Colors.amber.shade800,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'PENTING: Pastikan Anda berada di lokasi rumah yang akan dipasang saat menekan tombol "CARI LOKASI SAYA" untuk akurasi alamat dan penentuan cabang.',
              style: GoogleFonts.poppins(
                color: Colors.brown.shade800,
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

  Widget _buildCabangDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedCabangId,
      hint: Text(_isCabangLoading ? 'Memuat cabang...' : 'Pilih Cabang'),
      decoration: InputDecoration(
        labelText: _detectedCabangName != null
            ? "Cabang Terdeteksi"
            : 'Cabang Pemasangan',
        prefixIcon: Icon(Ionicons.business_outline,
            color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: _cabangOptions
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.namaCabang, style: GoogleFonts.poppins()),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() {
        _selectedCabangId = value;
        _detectedCabangName = null;
      }),
      validator: (v) => v == null ? 'Pilih cabang pemasangan' : null,
    );
  }

 Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Text Field untuk menampilkan koordinat (BUKAN ALAMAT)
        TextFormField(
          // Gunakan Key untuk update nilai secara paksa saat _currentPosition berubah
          key: ValueKey(_currentPosition), 
          initialValue: _currentPosition != null
              ? '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}'
              : '',
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Koordinat GPS Pemasangan',
            hintText: 'Koordinat akan muncul di sini',
            prefixIcon: Icon(Ionicons.navigate_circle_outline,
                color: Theme.of(context).colorScheme.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.blue.shade50,
          ),
          validator: (value) {
            if (_currentPosition == null) return 'Lokasi GPS wajib didapatkan';
            return null;
          },
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.blue.shade900),
        ),
        const SizedBox(height: 10),
        // 2. Tombol dinamis
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLocationLoading ? null : _getCurrentLocation,
            icon: _isLocationLoading
                ? Container( // Tampilkan spinner jika loading
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Ionicons.location_sharp), // Icon normal
            label: Text(
              _isLocationLoading ? 'SEDANG MENCARI...' : 'CARI LOKASI SAYA',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ),
      ],
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
        backgroundColor:
            Theme.of(context).colorScheme.secondary,
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