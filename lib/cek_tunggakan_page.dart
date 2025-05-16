// lib/cek_tunggakan_page.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan import path sesuai dengan proyek Anda
// Import shared_preferences masih diperlukan untuk mengambil user_data jika disimpan di sana
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Diperlukan untuk jsonDecode

class CekTunggakanPage extends StatefulWidget {
  // registeredIdPdam tidak lagi digunakan karena kita hanya pakai ID dari API
  const CekTunggakanPage({super.key});

  @override
  State<CekTunggakanPage> createState() => _CekTunggakanPageState();
}

class _CekTunggakanPageState extends State<CekTunggakanPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _pdamIdController = TextEditingController();

  List<dynamic> _pdamIdsFromApi = []; // Akan menyimpan list ID dari API backend
  String? _selectedPdamId; // ID yang saat ini dipilih

  Map<String, dynamic>? _tunggakanData; // Data tunggakan untuk ID yang dipilih
  bool _isLoadingApiPdamIds = true; // Loading saat mengambil daftar ID dari API
  bool _isLoadingTunggakan = false; // Loading saat mengambil data tunggakan
  String? _errorMessage; // Pesan error saat mengambil data tunggakan

  @override
  void initState() {
    super.initState();
    _fetchUserPdamIdsFromApi(); // Hanya panggil fungsi untuk mengambil ID dari API
  }

  // Mengambil daftar ID PDAM dari API backend
  Future<void> _fetchUserPdamIdsFromApi() async {
    if (!mounted) return; // Pastikan widget masih ada

    setState(() {
      _isLoadingApiPdamIds = true;
      _pdamIdsFromApi = []; // Kosongkan list sebelumnya
      _selectedPdamId = null; // Reset selected ID
      _tunggakanData = null; // Clear data tunggakan lama
      _errorMessage = null;
    });

    final idsFromApi = await _apiService.getAllUserPdamIds();

    if (!mounted) return; // Pastikan widget masih ada setelah async call

    setState(() {
      _pdamIdsFromApi = idsFromApi;
      _isLoadingApiPdamIds = false;

      // Pilih ID pertama jika list tidak kosong
      if (_pdamIdsFromApi.isNotEmpty) {
        // Asumsikan setiap item di _pdamIdsFromApi punya key 'nomor'
        _selectedPdamId = _pdamIdsFromApi.first['nomor']?.toString();
        // Ambil tunggakan untuk ID yang baru dipilih
        if (_selectedPdamId != null) {
          _fetchTunggakan(_selectedPdamId!);
        }
      }
    });
  }

  // Mengambil data tunggakan untuk ID PDAM yang dipilih
  Future<void> _fetchTunggakan(String pdamId) async {
    if (pdamId.isEmpty) {
      _showSnackbar('ID PDAM tidak boleh kosong.', isError: true);
      return;
    }
    if (!mounted) return; // Pastikan widget masih ada

    setState(() {
      _isLoadingTunggakan = true;
      _errorMessage = null;
      _tunggakanData = null;
    });

    try {
      final data = await _apiService.getTunggakan(pdamId);

      if (!mounted) return; // Pastikan widget masih ada setelah async call

      setState(() {
        _tunggakanData = data;
        if (data.containsKey('error') && data['error'] != null) {
          _errorMessage = data['error'].toString();
        } else if (data.isEmpty) {
          // Jika API mengembalikan map kosong
          _errorMessage = "Data tunggakan tidak ditemukan untuk ID $pdamId.";
        }
      });
    } catch (e) {
      if (!mounted) return; // Pastikan widget masih ada

      setState(() {
        _errorMessage = 'Gagal mengambil data tunggakan: $e';
      });
    } finally {
      if (!mounted) return; // Pastikan widget masih ada
      setState(() => _isLoadingTunggakan = false);
    }
  }

  // Menambahkan ID PDAM baru via API dan me-reload daftar
  Future<void> _addAndSelectPdamId() async {
    if (_pdamIdController.text.trim().isEmpty) {
      _showSnackbar('Masukkan ID PDAM yang valid.', isError: true);
      return;
    }

    final newId = _pdamIdController.text.trim();

    // Cek apakah ID sudah ada di daftar dari API untuk menghindari duplikasi yang tidak perlu
    if (_pdamIdsFromApi.any((item) => item['nomor'].toString() == newId)) {
      _showSnackbar(
        'ID PDAM "$newId" sudah terdaftar di akun Anda.',
        isError: false,
      );
      _pdamIdController.clear();
      // Jika ID sudah ada tapi belum dipilih, pilih dan ambil datanya
      if (_selectedPdamId != newId) {
        setState(() => _selectedPdamId = newId);
        _fetchTunggakan(newId);
      }
      return;
    }

    // Ambil ID pengguna yang sedang login
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');

    if (userDataString == null) {
      _showSnackbar(
        'Gagal mendapatkan informasi pengguna. Silakan login kembali.',
        isError: true,
      );
      return;
    }

    final userData = jsonDecode(userDataString) as Map<String, dynamic>;
    final int? idPelanggan = userData['id']; // Sesuaikan key 'id'

    if (idPelanggan == null) {
      _showSnackbar(
        'ID Pengguna tidak ditemukan. Silakan login kembali.',
        isError: true,
      );
      return;
    }

    // Panggil API untuk menyimpan ID baru
    setState(
      () => _isLoadingTunggakan = true,
    ); // Tampilkan loading saat proses API post
    _pdamIdController.clear(); // Clear input field

    try {
      final response = await _apiService.postPdamId(
        newId,
        idPelanggan
            .toString(), // Kirim ID pengguna dalam format yang sesuai API
      );

      if (!mounted) return; // Pastikan widget masih ada setelah async call

      if (response.containsKey('data') && response['data'] != null) {
        _showSnackbar('ID PDAM berhasil disimpan ke akun.', isError: false);
        // Reload daftar ID dari API setelah berhasil menyimpan
        _fetchUserPdamIdsFromApi();
      } else if (response.containsKey('errors')) {
        // Tangani validasi error dari backend
        String errorMsg = 'Gagal menyimpan ID PDAM: ';
        if (response['errors'] is Map) {
          response['errors'].forEach((key, value) {
            if (value is List) {
              errorMsg += '${value.join(", ")} ';
            } else {
              errorMsg += '$value ';
            }
          });
        } else {
          errorMsg += response['errors'].toString();
        }
        _showSnackbar(errorMsg.trim(), isError: true);
        setState(
          () => _isLoadingTunggakan = false,
        ); // Sembunyikan loading jika ada error API
      } else {
        // Tangani error lain dari API yang tidak punya key 'errors'
        _showSnackbar(
          response['message'] ?? 'Gagal menyimpan ID PDAM ke akun.',
          isError: true,
        );
        setState(
          () => _isLoadingTunggakan = false,
        ); // Sembunyikan loading jika ada error API
      }
    } catch (e) {
      if (!mounted) return; // Pastikan widget masih ada
      _showSnackbar(
        'Terjadi kesalahan saat menyimpan ID PDAM ke server: $e',
        isError: true,
      );
      setState(() => _isLoadingTunggakan = false);
    }
  }

  // Method untuk menghapus ID PDAM dari akun via API (Anda perlu implementasi di ApiService)
  // Method ini tidak dipanggil dari UI saat ini, tapi bisa ditambahkan jika diperlukan

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _pdamIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cek Tagihan & Kelola ID')),
      body:
          _isLoadingApiPdamIds
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Kelola ID Pelanggan Anda (Akun)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID PDAM yang Anda tambahkan akan tersimpan di akun Anda (maksimal 3 ID per akun).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pdamIdController,
                            decoration: InputDecoration(
                              labelText: 'Masukkan ID PDAM Baru',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              prefixIcon: const Icon(Icons.perm_identity),
                            ),
                            keyboardType: TextInputType.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Nonaktifkan tombol jika sedang loading mengambil ID atau tunggakan
                        ElevatedButton(
                          onPressed:
                              (_isLoadingApiPdamIds || _isLoadingTunggakan)
                                  ? null
                                  : _addAndSelectPdamId,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tampilkan Dropdown jika ada ID dari API
                    if (_pdamIdsFromApi.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Pilih ID PDAM',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          prefixIcon: const Icon(Icons.bookmark_border),
                        ),
                        // value: _selectedPdamId,
                        // Set value DropdownButtonFormField
                        // Pastikan _selectedPdamId ada dalam daftar items
                        value:
                            _pdamIdsFromApi.any(
                                  (item) =>
                                      item['nomor'].toString() ==
                                      _selectedPdamId,
                                )
                                ? _selectedPdamId
                                : (_pdamIdsFromApi.isNotEmpty
                                    ? _pdamIdsFromApi.first['nomor']?.toString()
                                    : null),
                        items:
                            _pdamIdsFromApi.map((item) {
                              final id =
                                  item['nomor']?.toString() ??
                                  ''; // Ambil 'nomor' dari setiap item
                              return DropdownMenuItem(
                                value: id,
                                child: Text(
                                  'Akun: $id',
                                ), // Label menunjukkan dari Akun
                              );
                            }).toList(),
                        onChanged:
                            (_isLoadingTunggakan ||
                                    _isLoadingApiPdamIds) // Nonaktifkan saat loading
                                ? null
                                : (value) {
                                  if (value != null) {
                                    setState(() => _selectedPdamId = value);
                                    _fetchTunggakan(
                                      value,
                                    ); // Ambil data tunggakan untuk ID yang dipilih
                                  }
                                },
                      ),

                    if (_pdamIdsFromApi.isNotEmpty) const SizedBox(height: 8),

                    // Tampilkan Chips hanya dari API, tanpa opsi hapus lokal
                    if (_pdamIdsFromApi.isNotEmpty)
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children:
                            _pdamIdsFromApi.map((item) {
                              final id =
                                  item['nomor']?.toString() ??
                                  ''; // Ambil 'nomor'
                              return Chip(
                                label: Text('Akun: $id'),
                                backgroundColor:
                                    _selectedPdamId == id
                                        ? Theme.of(context).primaryColorLight
                                        : null,
                                // Tidak ada onDeleted karena penghapusan harus via API
                              );
                            }).toList(),
                      ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Bagian Informasi Tagihan
                    Text(
                      'Informasi Tagihan ${_selectedPdamId != null ? "untuk $_selectedPdamId" : ""}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    if (_isLoadingTunggakan) // Tampilkan loading untuk tunggakan
                      const Center(child: CircularProgressIndicator())
                    else if (_errorMessage != null) // Tampilkan error tunggakan
                      Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    else if (_tunggakanData != null &&
                        _tunggakanData!.isNotEmpty)
                      // Tampilkan data tunggakan jika ada dan tidak kosong
                      Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                Icons.confirmation_number_outlined,
                                'ID Pelanggan:',
                                _tunggakanData!['id_pdam']?.toString() ??
                                    '-', // Sesuaikan key
                              ),
                              _buildInfoRow(
                                Icons.calendar_month_outlined,
                                'Periode Tagihan:',
                                _tunggakanData!['bulan']?.toString() ??
                                    '-', // Sesuaikan key
                              ),
                              _buildInfoRow(
                                Icons.event_busy_outlined,
                                'Jatuh Tempo:',
                                _tunggakanData!['jatuh_tempo']?.toString() ??
                                    '-', // Sesuaikan key
                              ),
                              const Divider(height: 20, thickness: 1),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Tagihan:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Rp ${_tunggakanData!['jumlah']?.toString() ?? '0'}', // Sesuaikan key
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Tombol Bayar hanya jika ada tagihan > 0
                              if ((_tunggakanData!['jumlah'] ?? 0) > 0)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _showSnackbar(
                                      "Fitur pembayaran belum tersedia.",
                                      isError: false,
                                    );
                                  },
                                  icon: const Icon(Icons.payment_outlined),
                                  label: const Text("Bayar Tagihan"),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      45,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else if (_pdamIdsFromApi.isNotEmpty && !_isLoadingTunggakan)
                      // Tampilkan pesan jika tidak ada data tunggakan setelah load dan ada ID dipilih
                      Center(
                        child: Text(
                          'Tidak ada data tagihan yang ditampilkan untuk ID $_selectedPdamId. Pastikan ID valid dan memiliki tagihan.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      // Pesan saat tidak ada ID PDAM sama sekali
                      const Center(
                        child: Text(
                          'Tambahkan ID PDAM untuk melihat tagihan.',
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Tombol Buat Laporan, hanya jika ada ID PDAM yang dipilih
                    if (_selectedPdamId != null && !_isLoadingTunggakan)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.report_problem_outlined),
                        label: Text("Buat Laporan untuk ID: $_selectedPdamId"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                        ),
                        onPressed: () {
                          // Navigasi ke halaman buat laporan dengan ID yang dipilih
                          Navigator.pushNamed(
                            context,
                            '/buat_laporan', // Ganti dengan nama route halaman buat laporan Anda
                            arguments: {'pdam_id': _selectedPdamId},
                          );
                        },
                      ),
                  ],
                ),
              ),
    );
  }

  // Helper widget untuk menampilkan baris info tunggakan
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }
}
