// cek_tunggakan_page.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan import path sesuai dengan proyek Anda
import 'package:shared_preferences/shared_preferences.dart'; // Import untuk penyimpanan lokal
import 'dart:convert';

class CekTunggakanPage extends StatefulWidget {
  const CekTunggakanPage({super.key, this.registeredIdPdam});

  final String? registeredIdPdam;

  @override
  State<CekTunggakanPage> createState() => _CekTunggakanPageState();
}

class _CekTunggakanPageState extends State<CekTunggakanPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _pdamIdController = TextEditingController();
  List<String> _savedPdamIds = [];
  String? _selectedPdamId;
  Map<String, dynamic>? _tunggakanData;
  bool _isLoadingIds = true;
  bool _isLoadingTunggakan = false;
  String? _errorMessage;
  String? _registeredIdFromPrefs;
  List<dynamic> _pdamIdsFromApi = [];
  bool _isLoadingApiPdamIds = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPdamIds();
    _loadRegisteredIdFromPrefs();
    _fetchUserPdamIdsFromApi(); // Panggil fungsi untuk mengambil ID dari API
  }

  Future<void> _fetchUserPdamIdsFromApi() async {
    setState(() => _isLoadingApiPdamIds = true);
    _pdamIdsFromApi = await _apiService.getAllUserPdamIds();
    setState(() => _isLoadingApiPdamIds = false);
  }

  Future<void> _loadRegisteredIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _registeredIdFromPrefs = prefs.getString('registered_pdam_id');
      // Jika ada ID PDAM dari registrasi dan belum ada di daftar, tambahkan
      if (_registeredIdFromPrefs != null &&
          _registeredIdFromPrefs!.isNotEmpty &&
          !_savedPdamIds.contains(_registeredIdFromPrefs)) {
        _savedPdamIds.insert(0, _registeredIdFromPrefs!);
        if (_selectedPdamId == null) {
          _selectedPdamId = _registeredIdFromPrefs;
          _fetchTunggakan(_selectedPdamId!);
        }
      } else if (_savedPdamIds.isNotEmpty && _selectedPdamId == null) {
        _selectedPdamId = _savedPdamIds.first;
        _fetchTunggakan(_selectedPdamId!);
      }
    });
  }

  Future<void> _loadSavedPdamIds() async {
    setState(() => _isLoadingIds = true);
    _savedPdamIds = await PdamIdManager.getPdamIds();
    // Jika ID dari registrasi dikirimkan dan belum ada di saved IDs
    if (widget.registeredIdPdam != null &&
        widget.registeredIdPdam!.isNotEmpty &&
        !_savedPdamIds.contains(widget.registeredIdPdam)) {
      _savedPdamIds.insert(0, widget.registeredIdPdam!);
      _selectedPdamId = widget.registeredIdPdam;
      _fetchTunggakan(_selectedPdamId!);
    } else if (_savedPdamIds.isNotEmpty && _selectedPdamId == null) {
      _selectedPdamId = _savedPdamIds.first;
      _fetchTunggakan(_selectedPdamId!);
    }
    setState(() => _isLoadingIds = false);
  }

  Future<void> _fetchTunggakan(String pdamId) async {
    if (pdamId.isEmpty) {
      _showSnackbar('ID PDAM tidak boleh kosong.');
      return;
    }
    setState(() {
      _isLoadingTunggakan = true;
      _errorMessage = null;
      _tunggakanData = null;
    });
    try {
      final data = await _apiService.getTunggakan(
        pdamId,
      ); // Implementasi di ApiService
      if (mounted) {
        setState(() {
          _tunggakanData = data;
          if (data['error'] != null) {
            _errorMessage = data['error'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mengambil data tunggakan: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTunggakan = false);
      }
    }
  }

  Future<void> _addAndSelectPdamId() async {
    if (_pdamIdController.text.trim().isEmpty) {
      _showSnackbar('Masukkan ID PDAM yang valid.');
      return;
    }
    final newId = _pdamIdController.text.trim();
    const maxLocalPdamIds = 3; // Batas maksimal ID PDAM lokal

    // Periksa jumlah ID PDAM di database
    final pdamIdsFromApi = await _apiService.getAllUserPdamIds();

    if (pdamIdsFromApi.length >= 3 &&
        !_savedPdamIds.contains(newId) &&
        !pdamIdsFromApi.any((item) => item['nomor'].toString() == newId)) {
      _showSnackbar('Anda sudah memiliki maksimal 3 ID PDAM terdaftar.');
      return;
    }

    // Periksa juga batas ID lokal jika perlu (misalnya, jika ada alasan untuk membatasi penyimpanan lokal)
    if (_savedPdamIds.length >= maxLocalPdamIds &&
        !_savedPdamIds.contains(newId)) {
      _showSnackbar(
        'Anda hanya dapat menyimpan maksimal $maxLocalPdamIds ID PDAM secara lokal.',
      );
      return;
    }

    await PdamIdManager.addPdamId(newId);
    _pdamIdController.clear();
    await _loadSavedPdamIds(); // Reload list
    if (_savedPdamIds.contains(newId)) {
      setState(() => _selectedPdamId = newId);
      _fetchTunggakan(newId);

      try {
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('user_data');

        if (userDataString != null) {
          final userData = jsonDecode(userDataString) as Map<String, dynamic>;
          final int idPelanggan = userData['id']; 

          final response = await _apiService.postPdamId(
            newId,
            idPelanggan.toString(),
          );
          if (response['data'] != null) {
            _showSnackbar('ID PDAM berhasil disimpan ke akun.', isError: false);
          } else if (response['errors'] != null &&
              response['errors']['nomor'] != null) {
            _showSnackbar(
              'Gagal menyimpan ID PDAM ke akun: ${response['errors']['nomor'][0]}',
            );
          } else {
            _showSnackbar('Gagal menyimpan ID PDAM ke akun.');
          }
        } else {
          _showSnackbar(
            'Gagal mendapatkan informasi pengguna untuk menyimpan ID PDAM ke server.',
          );
        }
      } catch (e) {
        _showSnackbar('Terjadi kesalahan saat menyimpan ID PDAM ke server: $e');
      }
    }
  }

  Future<void> _removePdamId(String pdamIdToRemove) async {
    await PdamIdManager.removePdamId(pdamIdToRemove);
    await _loadSavedPdamIds();
    if (_selectedPdamId == pdamIdToRemove) {
      setState(() {
        _selectedPdamId = _savedPdamIds.isNotEmpty ? _savedPdamIds.first : null;
        _tunggakanData = null; // Clear data tunggakan lama
        _errorMessage = null;
      });
      if (_selectedPdamId != null) _fetchTunggakan(_selectedPdamId!);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cek Tagihan & Kelola ID')),
      body:
          _isLoadingIds ||
                  _isLoadingApiPdamIds // Tambahkan loading API IDs
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Kelola ID Pelanggan Anda',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (widget.registeredIdPdam != null &&
                        widget.registeredIdPdam!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'ID PDAM Terdaftar: ${widget.registeredIdPdam}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (_registeredIdFromPrefs != null &&
                        _registeredIdFromPrefs!.isNotEmpty &&
                        (widget.registeredIdPdam == null ||
                            widget.registeredIdPdam!.isEmpty ||
                            widget.registeredIdPdam != _registeredIdFromPrefs))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'ID PDAM Terdaftar: $_registeredIdFromPrefs',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    Text(
                      'Anda dapat menyimpan dan mengelola beberapa ID pelanggan PDAM (maksimal 3 ID lokal).',
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
                        ElevatedButton(
                          onPressed: _addAndSelectPdamId,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_savedPdamIds.isNotEmpty || _pdamIdsFromApi.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Pilih ID PDAM',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          prefixIcon: const Icon(Icons.bookmark_border),
                        ),
                        value: _selectedPdamId,
                        items: [
                          ..._savedPdamIds.map((id) {
                            return DropdownMenuItem(
                              value: id,
                              child: Text('Lokal: $id'),
                            );
                          }),
                          ..._pdamIdsFromApi.map((item) {
                            final id =
                                item['nomor']
                                    .toString(); // Ambil 'nomor' dari setiap item
                            return DropdownMenuItem(
                              value: id,
                              child: Text('Akun: $id'),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPdamId = value);
                            _fetchTunggakan(value);
                          }
                        },
                      ),
                    if (_savedPdamIds.isNotEmpty || _pdamIdsFromApi.isNotEmpty)
                      const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        ..._savedPdamIds.map(
                          (id) => Chip(
                            label: Text('Lokal: $id'),
                            backgroundColor:
                                _selectedPdamId == id
                                    ? Theme.of(context).primaryColorLight
                                    : null,
                            onDeleted: () {
                              showDialog(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: const Text('Hapus ID PDAM Lokal'),
                                      content: Text(
                                        'Anda yakin ingin menghapus ID "$id" dari penyimpanan lokal?',
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('Batal'),
                                          onPressed:
                                              () => Navigator.of(ctx).pop(),
                                        ),
                                        TextButton(
                                          child: const Text(
                                            'Hapus',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            _removePdamId(id);
                                          },
                                        ),
                                      ],
                                    ),
                              );
                            },
                            deleteIcon: const Icon(Icons.close, size: 18),
                          ),
                        ),
                        ..._pdamIdsFromApi.map((item) {
                          final id =
                              item['nomor']
                                  .toString(); // Ambil 'nomor' dari setiap item
                          return Chip(
                            label: Text('Akun: $id'),
                            backgroundColor:
                                _selectedPdamId == id
                                    ? Theme.of(context).primaryColorLight
                                    : null,
                            // Anda mungkin tidak ingin memberikan opsi hapus untuk ID dari API di sini
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Informasi Tagihan ${_selectedPdamId != null ? "untuk $_selectedPdamId" : ""}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingTunggakan)
                      const Center(child: CircularProgressIndicator())
                    else if (_errorMessage != null)
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
                        _tunggakanData!['jumlah'] != null)
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
                                _tunggakanData!['id_pdam']?.toString() ?? '-',
                              ),
                              _buildInfoRow(
                                Icons.calendar_month_outlined,
                                'Periode Tagihan:',
                                _tunggakanData!['bulan']?.toString() ?? '-',
                              ),
                              _buildInfoRow(
                                Icons.event_busy_outlined,
                                'Jatuh Tempo:',
                                _tunggakanData!['jatuh_tempo']?.toString() ??
                                    '-',
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
                                    'Rp ${_tunggakanData!['jumlah']?.toString() ?? '0'}',
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
                    else if (_selectedPdamId != null)
                      Center(
                        child: Text(
                          'Tidak ada data tagihan untuk ID $_selectedPdamId atau ID tidak valid.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      const Center(
                        child: Text(
                          'Pilih atau masukkan ID PDAM untuk melihat tagihan.',
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_selectedPdamId != null &&
                        _tunggakanData != null &&
                        _tunggakanData!['error'] == null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.report_problem_outlined),
                        label: Text("Buat Laporan untuk ID: $_selectedPdamId"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/buat_laporan',
                            arguments: {'pdam_id': _selectedPdamId},
                          );
                        },
                      ),
                  ],
                ),
              ),
    );
  }

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

class PdamIdManager {
  static const String _pdamIdsKey = 'pdam_ids';

  static Future<List<String>> getPdamIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pdamIdsKey) ?? [];
  }

  static Future<void> addPdamId(String pdamId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ids = await getPdamIds();
    if (!ids.contains(pdamId) && ids.length < 5) {
      // Batasi jumlah ID misal 5
      ids.add(pdamId);
      await prefs.setStringList(_pdamIdsKey, ids);
    }
  }

  static Future<void> removePdamId(String pdamId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ids = await getPdamIds();
    ids.remove(pdamId);
    await prefs.setStringList(_pdamIdsKey, ids);
  }
}
