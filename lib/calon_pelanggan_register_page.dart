import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/cabang_model.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class CalonPelangganRegisterPage extends StatefulWidget {
  const CalonPelangganRegisterPage({super.key});

  @override
  State<CalonPelangganRegisterPage> createState() =>
      _CalonPelangganRegisterPageState();
}

class _CalonPelangganRegisterPageState
    extends State<CalonPelangganRegisterPage> {
  // --- Keys & Controllers ---
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _namaController = TextEditingController();
  final _noKtpController = TextEditingController();
  final _alamatController =
      TextEditingController(); // Tetap digunakan untuk menampilkan Lat/Lng
  final _deskripsiAlamatController = TextEditingController();
  final _noWaController = TextEditingController();

  // --- State Variables ---
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLocationLoading = false; // Untuk status tombol lokasi
  String? _cabangError;
  bool _isCabangLoading = true;
  List<Cabang> _cabangOptions = [];
  int? _selectedCabangId;
  String? _detectedCabangName;
  Position? _currentPosition;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noKtpController.dispose();
    _alamatController.dispose();
    _deskripsiAlamatController.dispose();
    _noWaController.dispose();
    super.dispose();
  }

  // --- Core Logic ---
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchCabangOptions();
    await _getCurrentLocation();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCabangOptions() async {
    setState(() {
      _isCabangLoading = true;
      _cabangError = null;
    });
    try {
      final options = await _apiService.getCabangList();
      if (!mounted) return;
      setState(() => _cabangOptions = options);
      _findNearestBranch();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cabangError = 'Gagal memuat data cabang: $e');
    } finally {
      if (mounted) setState(() => _isCabangLoading = false);
    }
  }

  // === FUNGSI INI DIMODIFIKASI ===
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
      _alamatController.text = 'Mencari lokasi...';
    });
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
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          // Mengisi controller alamat dengan Latitude dan Longitude
          _alamatController.text =
              '${position.latitude}, ${position.longitude}';
        });
        _showSnackbar('Lokasi GPS berhasil didapatkan!', isError: false);
        _findNearestBranch();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPosition = null;
          _alamatController.text = '';
        });
        _showSnackbar(
          e.toString().replaceFirst("Exception: ", ""),
          isError: true,
        );
      }
    } finally {
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
        try {
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
        } catch (_) {}
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
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (pickedFile != null)
        setState(() => _imageFile = File(pickedFile.path));
    } catch (e) {
      _showSnackbar('Gagal memilih gambar: $e', isError: true);
    }
  }

  Future<void> _submitRegistration() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackbar('Harap periksa kembali semua data yang wajib diisi.');
      return;
    }
    if (_imageFile == null) {
      _showSnackbar('Foto KTP wajib diunggah.');
      return;
    }
    if (_selectedCabangId == null) {
      _showSnackbar('Cabang pelaporan wajib dipilih.', isError: true);
      return;
    }
    // Validasi tambahan untuk memastikan lokasi sudah didapatkan
    if (_currentPosition == null) {
      _showSnackbar('Lokasi GPS wajib didapatkan sebelum mendaftar.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'id_cabang': _selectedCabangId.toString(),
        'nama_lengkap': _namaController.text,
        'no_ktp': _noKtpController.text,
        'alamat': _alamatController.text, // Mengirim Lat,Lng dari controller
        'deskripsi_alamat': _deskripsiAlamatController.text,
        'no_wa': _noWaController.text,
      };

      await _apiService.registerCalonPelanggan(
        data: data,
        imagePath: _imageFile!.path,
      );

      _showSuccessDialog();
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

  // --- UI Widgets ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pelanggan Baru'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildSectionTitle('Informasi Pribadi'),
                    _buildTextFormField(
                      controller: _namaController,
                      label: 'Nama Lengkap (sesuai KTP)',
                      icon: Ionicons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: _noKtpController,
                      label: 'Nomor KTP (16 digit)',
                      icon: Ionicons.md_card_outline,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Nomor KTP wajib diisi';
                        if (v.length != 16) return 'Nomor KTP harus 16 digit';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: _noWaController,
                      label: 'Nomor WhatsApp Aktif',
                      icon: Ionicons.logo_whatsapp,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Nomor WA wajib diisi';
                        if (v.length < 10) return 'Nomor WA minimal 10 digit';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Foto KTP'),
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Informasi Alamat Pemasangan'),
                    _buildCabangDropdown(),
                    const SizedBox(height: 16),
                    // === BAGIAN ALAMAT DIUBAH DI SINI ===
                    _buildLocationField(),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: _deskripsiAlamatController,
                      label: 'Deskripsi Tambahan Alamat',
                      icon: Ionicons.map_outline,
                      hint: 'Contoh: Rumah cat biru, dekat masjid',
                      isRequired: false,
                    ), // Dibuat tidak wajib
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child:
                          _isSubmitting
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                              : const Text('DAFTAR SEKARANG'),
                    ),
                  ],
                ),
              ),
    );
  }

  // === WIDGET BARU UNTUK FIELD LOKASI ===
  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _alamatController,
          readOnly: true, // Field ini tidak bisa di-edit manual
          decoration: InputDecoration(
            labelText: 'Lokasi GPS Pemasangan',
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            hintText: 'Latitude, Longitude akan muncul di sini',
            prefixIcon: const Icon(Ionicons.navigate_circle_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
          validator: (value) {
            if (value == null || value.isEmpty || _currentPosition == null) {
              return 'Lokasi GPS wajib didapatkan';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _isLocationLoading ? null : _getCurrentLocation,
            icon:
                _isLocationLoading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Ionicons.locate_outline),
            label: Text(
              _isLocationLoading ? 'MENCARI...' : 'DAPATKAN LOKASI SAAT INI',
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.lato(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
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
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator:
          validator ??
          (v) {
            if (isRequired && (v == null || v.isEmpty)) {
              return '$label wajib diisi';
            }
            return null;
          },
    );
  }

  Widget _buildCabangDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedCabangId,
      hint: Text(_isCabangLoading ? 'Memuat cabang...' : 'Pilih Cabang'),
      decoration: InputDecoration(
        labelText:
            _detectedCabangName != null
                ? "Cabang Terdeteksi"
                : 'Cabang Pemasangan',
        prefixIcon: const Icon(Ionicons.business_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items:
          _cabangOptions
              .map(
                (c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang)),
              )
              .toList(),
      onChanged:
          (value) => setState(() {
            _selectedCabangId = value;
            _detectedCabangName = null;
          }),
      validator: (v) => v == null ? 'Pilih cabang pemasangan' : null,
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () => _showImageSourceActionSheet(context),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade400,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child:
            _imageFile == null
                ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Ionicons.camera_outline,
                        size: 50,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ketuk untuk unggah foto KTP',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
                : ClipRRect(
                  borderRadius: BorderRadius.circular(10.5),
                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                ),
      ),
    );
  }

  // --- Dialogs & Helpers ---
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Ionicons.image_outline),
                  title: const Text('Galeri'),
                  onTap: () {
                    _pickImage(ImageSource.gallery);
                    Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Ionicons.camera_outline),
                  title: const Text('Kamera'),
                  onTap: () {
                    _pickImage(ImageSource.camera);
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
        content: Text(message),
        backgroundColor:
            backgroundColor ??
            (isError ? Colors.red.shade700 : Colors.green.shade700),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Pendaftaran Berhasil'),
            content: const Text(
              'Terima kasih! Data Anda telah kami terima dan akan segera diproses. Informasi selanjutnya mengenai status pendaftaran akan diberitahukan melalui nomor WhatsApp yang Anda daftarkan.',
            ),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop(); // Kembali ke halaman login
                },
              ),
            ],
          ),
    );
  }
}
