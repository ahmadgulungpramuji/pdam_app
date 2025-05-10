// buat_laporan_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan import

class BuatLaporanPage extends StatefulWidget {
  const BuatLaporanPage({super.key});

  @override
  State<BuatLaporanPage> createState() => _BuatLaporanPageState();
}

class _BuatLaporanPageState extends State<BuatLaporanPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  // final TextEditingController _pdamIdController = TextEditingController(); // Jika perlu input PDAM ID spesifik

  String? _selectedJenisLaporan;
  final List<String> _jenisLaporanList = [
    'Kebocoran Pipa',
    'Air Keruh',
    'Meteran Rusak',
    'Lainnya',
  ];
  List<String> _pdamIdList = [];
  String? _selectedPdamId;

  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadPdamIds();
  }

  Future<void> _loadPdamIds() async {
    // Idealnya, PDAM ID yang terasosiasi dengan user diambil dari profil user
    // atau jika user bisa menambahkan sendiri, ambil dari PdamIdManager
    setState(() => _isLoading = true);
    _pdamIdList = await PdamIdManager.getPdamIds();
    if (_pdamIdList.isNotEmpty) {
      _selectedPdamId = _pdamIdList.first;
    } else {
      // Jika tidak ada PDAM ID, mungkin user perlu menambahkannya dulu
      // atau laporan tidak terikat PDAM ID (umum)
      // Untuk contoh ini, biarkan _selectedPdamId null jika list kosong
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    _lokasiController.dispose();
    // _pdamIdController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _submitLaporan() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Harap lengkapi semua field yang dibutuhkan.');
      return;
    }
    if (_selectedJenisLaporan == null) {
      _showSnackbar('Pilih jenis laporan terlebih dahulu.');
      return;
    }
    // Validasi jika laporan membutuhkan PDAM ID
    // if (_pdamIdList.isNotEmpty && _selectedPdamId == null) {
    //   _showSnackbar('Pilih ID Pelanggan untuk laporan ini.');
    //   return;
    // }

    setState(() => _isLoading = true);

    try {
      // Siapkan data untuk dikirim ke API
      Map<String, dynamic> dataLaporan = {
        'judul': _judulController.text,
        'deskripsi': _deskripsiController.text,
        'lokasi': _lokasiController.text,
        'jenis_laporan': _selectedJenisLaporan,
        // 'pdam_id': _selectedPdamId, // Kirim jika diperlukan backend
        // Tambahkan field lain jika ada, misal foto, dll.
      };

      // Panggil API service untuk mengirim laporan
      final response = await _apiService.buatLaporan(
        dataLaporan,
        _selectedPdamId,
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        _showSnackbar(
          'Laporan berhasil dikirim! Kode Laporan: ${responseData['kode_laporan'] ?? ''}',
          isError: false,
        );
        _formKey.currentState?.reset();
        _judulController.clear();
        _deskripsiController.clear();
        _lokasiController.clear();
        setState(() {
          _selectedJenisLaporan = null;
          // _selectedPdamId = _pdamIdList.isNotEmpty ? _pdamIdList.first : null;
        });
        // Pertimbangkan untuk navigasi kembali atau ke halaman tracking
        // Navigator.pop(context);
      } else {
        final responseData = jsonDecode(response.body);
        _showSnackbar(
          'Gagal mengirim laporan: ${responseData['message'] ?? response.reasonPhrase}',
        );
      }
    } catch (e) {
      _showSnackbar('Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Laporan Pengaduan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Formulir Pengaduan Pelanggan',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Dropdown untuk PDAM ID jika ada dan relevan untuk laporan
              if (_isLoading) const Center(child: CircularProgressIndicator()),
              if (!_isLoading && _pdamIdList.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Pilih ID Pelanggan (Opsional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    prefixIcon: const Icon(Icons.person_pin_outlined),
                  ),
                  value: _selectedPdamId,
                  items:
                      _pdamIdList.map((id) {
                        return DropdownMenuItem(value: id, child: Text(id));
                      }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedPdamId = value);
                  },
                  // Tidak wajib diisi, jadi validator tidak diperlukan di sini
                  // validator: (value) => value == null ? 'Pilih ID Pelanggan' : null,
                ),
              if (!_isLoading && _pdamIdList.isNotEmpty)
                const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Jenis Laporan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                value: _selectedJenisLaporan,
                items:
                    _jenisLaporanList.map((jenis) {
                      return DropdownMenuItem(value: jenis, child: Text(jenis));
                    }).toList(),
                onChanged: (value) {
                  setState(() => _selectedJenisLaporan = value);
                },
                validator:
                    (value) => value == null ? 'Pilih jenis laporan' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _judulController,
                decoration: InputDecoration(
                  labelText: 'Judul Laporan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Judul tidak boleh kosong'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deskripsiController,
                decoration: InputDecoration(
                  labelText: 'Deskripsi Lengkap',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Deskripsi tidak boleh kosong'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lokasiController,
                decoration: InputDecoration(
                  labelText: 'Detail Lokasi Kejadian',
                  hintText:
                      'Contoh: Jl. Mawar No. 1, RT 01 RW 02, Kelurahan, Kecamatan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                maxLines: 2,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Lokasi tidak boleh kosong'
                            : null,
              ),
              const SizedBox(height: 16),
              // Tambahkan field untuk upload foto jika perlu
              // ElevatedButton.icon(
              //   onPressed: () { /* Logika pilih gambar */ },
              //   icon: Icon(Icons.camera_alt_outlined),
              //   label: Text('Unggah Foto (Jika Ada)'),
              //   style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black87),
              // ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon:
                    _isLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.send_outlined),
                label:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Kirim Laporan'),
                onPressed: _isLoading ? null : _submitLaporan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
