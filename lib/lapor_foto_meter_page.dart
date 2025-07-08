import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdam_app/api_service.dart'; // Sesuaikan path
import 'package:pdam_app/models/cabang_model.dart'; // Pastikan Anda punya model ini

class LaporFotoMeterPage extends StatefulWidget {
  const LaporFotoMeterPage({super.key});

  @override
  State<LaporFotoMeterPage> createState() => _LaporFotoMeterPageState();
}

class _LaporFotoMeterPageState extends State<LaporFotoMeterPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _komentarController = TextEditingController();
  final _cabangController = TextEditingController();

  // State untuk data
  List<String> _pdamIds = [];
  List<Cabang> _daftarCabang = []; // Untuk menyimpan daftar semua cabang
  String? _selectedPdamId;
  int? _selectedCabangId; // ID cabang yang dipilih otomatis
  File? _imageFile;

  // State untuk UI
  bool _isLoading = false;
  bool _isFetchingInitialData = true;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _komentarController.dispose();
    _cabangController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isFetchingInitialData = true);
    try {
      // Ambil daftar ID PDAM dan daftar Cabang secara bersamaan
      final responses = await Future.wait([
        _apiService.getAllUserPdamIds(),
        _apiService
            .getCabangList(), // Gunakan method yang sudah ada di ApiService Anda
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
        // Cari nama cabang dari daftar yang sudah di-fetch
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
    // ... (fungsi ini tidak berubah dari kode sebelumnya)
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
        idCabang: _selectedCabangId!, // Kirim ID Cabang yang terpilih otomatis
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
        title: const Text('Lapor Foto Water Meter'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body:
          _isFetchingInitialData
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropdown untuk memilih ID PDAM
            DropdownButtonFormField<String>(
              value: _selectedPdamId,
              hint: const Text('Pilih nomor ID PDAM'),
              items:
                  _pdamIds
                      .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                      .toList(),
              onChanged:
                  _updateCabangOtomatis, // Panggil method otomatisasi di sini
              validator:
                  (value) => value == null ? 'Mohon pilih ID PDAM' : null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
              isExpanded: true,
            ),
            const SizedBox(height: 16),

            // Text field untuk menampilkan Cabang yang terpilih (read-only)
            TextFormField(
              controller: _cabangController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Cabang Terpilih (Otomatis)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Image Picker
            Text(
              'Upload Foto Meteran',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildImagePicker(),
            const SizedBox(height: 24),

            // Text field untuk komentar
            Text(
              'Catatan (Opsional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _komentarController,
              decoration: const InputDecoration(
                hintText: 'Contoh: Posisi meteran di belakang rumah...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Tombol Submit
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                  onPressed: _submitLaporan,
                  icon: const Icon(Icons.send),
                  label: const Text('Kirim Laporan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    // ... (Widget ini tidak berubah dari kode sebelumnya)
    return Column(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child:
              _imageFile != null
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                  )
                  : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera_back_outlined,
                          size: 50,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text('Pratinjau gambar akan muncul di sini'),
                      ],
                    ),
                  ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Dari Galeri'),
            ),
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Dari Kamera'),
            ),
          ],
        ),
      ],
    );
  }
}
