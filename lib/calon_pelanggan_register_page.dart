import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
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
    extends State<CalonPelangganRegisterPage> with SingleTickerProviderStateMixin { // Tambahkan SingleTickerProviderStateMixin
  // --- Keys & Controllers ---
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _namaController = TextEditingController();
  final _noKtpController = TextEditingController();
  final _alamatController = TextEditingController(); // Alamat pemasangan (GPS)
  final _alamatKtpController = TextEditingController();
  final _deskripsiAlamatController = TextEditingController();
  final _noWaController = TextEditingController();

  // --- State Variables ---
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLocationLoading = false;
  bool _isCabangLoading = true;
  // ignore: unused_field
  String? _cabangError;
  List<Cabang> _cabangOptions = [];
  int? _selectedCabangId;
  String? _detectedCabangName;
  Position? _currentPosition;
  File? _imageFileKtp;
  File? _imageFileRumah;
  final _picker = ImagePicker();

  // Animasi untuk tombol 'Dapatkan Lokasi'
  late AnimationController _locationButtonAnimationController;
  late Animation<double> _scaleAnimationLocation;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    _locationButtonAnimationController = AnimationController( // Inisialisasi controller animasi
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimationLocation = Tween<double>(begin: 1.0, end: 1.02).animate( // Animasi skala kecil
      CurvedAnimation(
        parent: _locationButtonAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noKtpController.dispose();
    _alamatController.dispose();
    _alamatKtpController.dispose();
    _deskripsiAlamatController.dispose();
    _noWaController.dispose();
    _locationButtonAnimationController.dispose(); // Dispose controller animasi
    super.dispose();
  }

  // --- CORE LOGIC METHODS ---

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

  Future<void> _submitRegistration() async {
    // --- Validations ---
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackbar('Harap periksa kembali semua data yang wajib diisi.');
      return;
    }
    if (_selectedCabangId == null) {
      _showSnackbar('Cabang pelaporan wajib dipilih.', isError: true);
      return;
    }
    if (_currentPosition == null) {
      _showSnackbar('Lokasi GPS wajib didapatkan sebelum mendaftar.');
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
        'id_cabang': _selectedCabangId.toString(),
        'nama_lengkap': _namaController.text,
        'no_ktp': _noKtpController.text,
        'alamat': _alamatController.text, // Mengirim Lat,Lng dari controller
        'alamat_ktp': _alamatKtpController.text,
        'deskripsi_alamat': _deskripsiAlamatController.text,
        'no_wa': _noWaController.text,
      };

      await _apiService.registerCalonPelanggan(
        data: data,
        imagePathKtp: _imageFileKtp!.path,
        imagePathRumah: _imageFileRumah!.path,
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

  // --- UI WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Daftar Pelanggan Baru',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white), // Font Poppins
        ),
        backgroundColor: Theme.of(context).colorScheme.primary, // Gunakan warna tema
        iconTheme: const IconThemeData(color: Colors.white), // Warna ikon kembali
        elevation: 0, // Tanpa shadow
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20.0), // Padding lebih besar
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
                    icon: Ionicons.card_outline,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Nomor KTP wajib diisi';
                      }
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
                      if (v == null || v.isEmpty) {
                        return 'Nomor WA wajib diisi';
                      }
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

                  _buildSectionTitle('Dokumen (Wajib)'),
                  _buildImageUploadCard(
                    title: 'Foto KTP',
                    imageFile: _imageFileKtp,
                    onTap: () => _showImageSourceActionSheet(context, isKtp: true),
                    placeholder: 'Ketuk untuk unggah foto KTP',
                  ),
                  const SizedBox(height: 24),
                  _buildImageUploadCard(
                    title: 'Foto Tampak Depan Rumah',
                    imageFile: _imageFileRumah,
                    onTap: () => _showImageSourceActionSheet(context, isKtp: false),
                    placeholder: 'Ketuk untuk unggah foto Rumah',
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Informasi Alamat Pemasangan'),
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
                    maxLines: 3, // Tambahkan maxLines untuk deskripsi
                  ),
                  const SizedBox(height: 32),

                  _buildSubmitButton(), // Pisahkan tombol submit ke widget terpisah
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
        style: GoogleFonts.poppins( // Gunakan Poppins
          fontSize: 20, // Lebih besar
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary, // Warna tema
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
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary), // Warna ikon
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), // Sudut membulat
        filled: true,
        fillColor: Colors.grey.shade50, // Latar belakang abu-abu muda
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
      style: GoogleFonts.poppins(), // Font Poppins untuk input
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
        prefixIcon: Icon(Ionicons.business_outline, color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: _cabangOptions
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.namaCabang, style: GoogleFonts.poppins()), // Font Poppins
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
        TextFormField(
          controller: _alamatController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Lokasi GPS Pemasangan',
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
            hintText: 'Latitude, Longitude akan muncul di sini',
            prefixIcon: Icon(Ionicons.navigate_circle_outline, color: Theme.of(context).colorScheme.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.blue.shade50, // Warna latar belakang berbeda
          ),
          validator: (value) {
            if (value == null || value.isEmpty || _currentPosition == null) {
              return 'Lokasi GPS wajib didapatkan';
            }
            return null;
          },
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue.shade900), // Font Poppins
        ),
        const SizedBox(height: 10), // Spasi lebih besar
        ScaleTransition( // Animasi skala pada tombol
          scale: _scaleAnimationLocation,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon( // Ganti TextButton dengan ElevatedButton
              onPressed: _isLocationLoading ? null : () {
                _locationButtonAnimationController.forward().then((_) {
                  _locationButtonAnimationController.reverse();
                });
                _getCurrentLocation();
              },
              icon: _isLocationLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Ionicons.locate_outline),
              label: Text(
                _isLocationLoading ? 'MENCARI LOKASI...' : 'DAPATKAN LOKASI SAAT INI',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold), // Font Poppins
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700, // Warna tombol
                foregroundColor: Colors.white, // Warna teks
                padding: const EdgeInsets.symmetric(vertical: 14), // Padding lebih
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Sudut membulat
                ),
                elevation: 4, // Efek shadow
              ),
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
                color: imageFile == null ? Colors.red.shade300 : Colors.green.shade400,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
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
                          style: GoogleFonts.poppins(color: Colors.grey.shade600),
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
        backgroundColor: Theme.of(context).colorScheme.secondary, // Warna tombol submit
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
          : const Icon(Ionicons.send_outline), // Icon kirim
      label: Text(
        _isSubmitting ? 'Mendaftar...' : 'DAFTAR SEKARANG',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- DIALOGS & HELPERS ---

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
        content: Text(message, style: GoogleFonts.poppins()), // Font Poppins
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
      builder: (dialogContext) => AlertDialog(
        title: Text('Pendaftaran Berhasil', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Terima kasih! Data Anda telah kami terima dan akan segera diproses. Informasi selanjutnya mengenai status pendaftaran akan diberitahukan melalui nomor WhatsApp yang Anda daftarkan.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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