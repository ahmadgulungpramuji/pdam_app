import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdam_app/api_service.dart'; // Sesuaikan path
import 'package:pdam_app/models/cabang_model.dart'; // Pastikan Anda punya model ini
import 'package:google_fonts/google_fonts.dart'; // Tambahkan ini untuk font yang lebih modern

class LaporFotoMeterPage extends StatefulWidget {
  const LaporFotoMeterPage({super.key});

  @override
  State<LaporFotoMeterPage> createState() => _LaporFotoMeterPageState();
}

class _LaporFotoMeterPageState extends State<LaporFotoMeterPage> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _komentarController = TextEditingController();
  final _cabangController = TextEditingController();

  List<String> _pdamIds = [];
  List<Cabang> _daftarCabang = [];
  String? _selectedPdamId;
  int? _selectedCabangId;
  File? _imageFile;

  bool _isLoading = false;
  bool _isFetchingInitialData = true;
  String? _fetchError;

  // Animasi untuk tombol 'Ambil Foto'
  late AnimationController _cameraButtonAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();

    _cameraButtonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _cameraButtonAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _komentarController.dispose();
    _cabangController.dispose();
    _cameraButtonAnimationController.dispose(); // Dispose controller animasi
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
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
        setState(() {
          _fetchError = "Gagal memuat data awal: $e";
          _isFetchingInitialData = false;
        });
      }
    }
  }

  void _updateCabangOtomatis(String? nomorPdam) {
    if (nomorPdam == null || nomorPdam.length < 2) {
      setState(() {
        _selectedPdamId = null;
        _selectedCabangId = null;
        _cabangController.clear();
      });
      return;
    }

    final duaDigit = nomorPdam.substring(0, 2);
    int? idCabang;

    switch (duaDigit) {
      case '10':
        idCabang = 1;
        break;
      case '12':
        idCabang = 2;
        break;
      case '15':
        idCabang = 3;
        break;
      case '20':
        idCabang = 4;
        break;
      case '30':
        idCabang = 5;
        break;
      case '40':
        idCabang = 6;
        break;
      case '50':
        idCabang = 7;
        break;
      case '60':
        idCabang = 8;
        break;
      default:
        idCabang = null;
    }

    setState(() {
      _selectedPdamId = nomorPdam;
      _selectedCabangId = idCabang;
      if (idCabang != null) {
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackbar('Gagal mengambil gambar: $e', isError: true);
    }
  }

  Future<void> _submitLaporan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      _showSnackbar('Mohon pilih foto water meter.', isError: true);
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
      _showSnackbar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lapor Foto Water Meter',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        elevation: 0,
      ),
      body: _isFetchingInitialData
          ? const Center(child: CircularProgressIndicator())
          : _fetchError != null
              ? Center(child: Text(_fetchError!))
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0), // Padding lebih besar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Detail Pelaporan',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Dropdown untuk memilih ID PDAM
            _buildDropdownPdamId(),
            const SizedBox(height: 20),

            // Text field untuk menampilkan Cabang yang terpilih (read-only)
            _buildCabangDisplayField(),
            const SizedBox(height: 30),

            // Section: Upload Foto Meteran
            Text(
              'Foto Water Meter',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 15),
            _buildImageUploadSection(), // Bagian ini yang kita fokuskan
            const SizedBox(height: 30),

            // Section: Catatan
            Text(
              'Catatan Tambahan',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 15),
            _buildKomentarField(),
            const SizedBox(height: 40),

            // Tombol Submit
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders untuk Form yang Lebih Bersih ---

  Widget _buildDropdownPdamId() {
    return DropdownButtonFormField<String>(
      value: _selectedPdamId,
      hint: const Text('Pilih Nomor ID Pelanggan PDAM'),
      items: _pdamIds
          .map((id) => DropdownMenuItem(value: id, child: Text(id)))
          .toList(),
      onChanged: _updateCabangOtomatis,
      validator: (value) => value == null ? 'Mohon pilih ID PDAM' : null,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.confirmation_number_outlined),
        filled: true,
        fillColor: Colors.grey.shade50,
        labelText: 'Nomor ID Pelanggan PDAM',
      ),
      isExpanded: true,
    );
  }

  Widget _buildCabangDisplayField() {
    return TextFormField(
      controller: _cabangController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Cabang Terdeteksi',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.business_outlined),
        filled: true,
        fillColor: Colors.blue.shade50, // Warna latar belakang yang berbeda
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      children: [
        Container(
          height: 250, // Lebih tinggi
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _imageFile == null ? Colors.red.shade300 : Colors.green.shade400,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined, // Icon lebih spesifik
                        size: 70, // Lebih besar
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ketuk tombol di bawah untuk mengambil foto meteran',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 20),
        ScaleTransition(
          scale: _scaleAnimation,
          child: ElevatedButton.icon(
            onPressed: () {
              _cameraButtonAnimationController.forward().then((_) {
                _cameraButtonAnimationController.reverse();
              });
              _pickImage(ImageSource.camera); // Hanya dari kamera
            },
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(
              _imageFile == null ? 'Ambil Foto Meteran' : 'Ganti Foto Meteran',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKomentarField() {
    return TextFormField(
      controller: _komentarController,
      decoration: InputDecoration(
        hintText: 'Misalnya: Meteran di samping pintu belakang, terhalang tanaman.',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.notes),
        filled: true,
        fillColor: Colors.grey.shade50,
        alignLabelWithHint: true,
      ),
      maxLines: 4, // Lebih banyak baris
      keyboardType: TextInputType.multiline,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _submitLaporan,
      icon: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : const Icon(Icons.cloud_upload_outlined), // Icon yang lebih modern
      label: Text(
        _isLoading ? 'Mengirim Laporan...' : 'Kirim Laporan',
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 18), // Padding lebih besar
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Sudut lebih membulat
        ),
        elevation: 8, // Shadow lebih dalam
      ),
    );
  }
}