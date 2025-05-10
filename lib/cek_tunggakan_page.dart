// cek_tunggakan_page.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart'; // Pastikan import

class CekTunggakanPage extends StatefulWidget {
  const CekTunggakanPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadSavedPdamIds();
  }

  Future<void> _loadSavedPdamIds() async {
    setState(() => _isLoadingIds = true);
    _savedPdamIds = await PdamIdManager.getPdamIds();
    if (_savedPdamIds.isNotEmpty) {
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
    if (_savedPdamIds.length >= 2 && !_savedPdamIds.contains(newId)) {
      // Batas contoh 2 ID, bisa lebih
      _showSnackbar(
        'Anda hanya dapat menyimpan maksimal ${_savedPdamIds.length} ID PDAM.',
      );
      // Atau tampilkan dialog untuk mengganti salah satu ID yang ada
      // return;
    }

    await PdamIdManager.addPdamId(newId);
    _pdamIdController.clear();
    await _loadSavedPdamIds(); // Reload list
    if (_savedPdamIds.contains(newId)) {
      setState(() => _selectedPdamId = newId);
      _fetchTunggakan(newId);
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
          _isLoadingIds
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
                    Text(
                      'Anda dapat menyimpan dan mengelola beberapa ID pelanggan PDAM (maksimal ${_savedPdamIds.length > 0 ? _savedPdamIds.length : 'beberapa'}).',
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
                    if (_savedPdamIds.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Pilih ID PDAM Tersimpan',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          prefixIcon: const Icon(Icons.bookmark_border),
                        ),
                        value: _selectedPdamId,
                        items:
                            _savedPdamIds.map((id) {
                              return DropdownMenuItem(
                                value: id,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(id),
                                    // IconButton( // Tombol hapus langsung di item bisa jadi UX yang kurang baik
                                    //   icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    //   onPressed: (e) {
                                    //     e.stopPropagation(); // Mencegah dropdown tertutup
                                    //     _removePdamId(id);
                                    //   },
                                    // )
                                  ],
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPdamId = value);
                            _fetchTunggakan(value);
                          }
                        },
                      ),
                    if (_savedPdamIds.isNotEmpty) const SizedBox(height: 8),
                    if (_savedPdamIds.isNotEmpty)
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children:
                            _savedPdamIds
                                .map(
                                  (id) => Chip(
                                    label: Text(id),
                                    backgroundColor:
                                        _selectedPdamId == id
                                            ? Theme.of(
                                              context,
                                            ).primaryColorLight
                                            : null,
                                    onDeleted: () {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (ctx) => AlertDialog(
                                              title: const Text(
                                                'Hapus ID PDAM',
                                              ),
                                              content: Text(
                                                'Anda yakin ingin menghapus ID "$id"?',
                                              ),
                                              actions: <Widget>[
                                                TextButton(
                                                  child: const Text('Batal'),
                                                  onPressed:
                                                      () =>
                                                          Navigator.of(
                                                            ctx,
                                                          ).pop(),
                                                ),
                                                TextButton(
                                                  child: const Text(
                                                    'Hapus',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
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
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                  ),
                                )
                                .toList(),
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
                                  icon: Icon(Icons.payment_outlined),
                                  label: Text("Bayar Tagihan"),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size(double.infinity, 45),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else if (_selectedPdamId !=
                        null) // Ada ID terpilih tapi tidak ada data/error
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
                    // Tombol untuk membuat laporan terkait ID PDAM yang dipilih
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
                          // Navigasi ke halaman buat laporan dengan ID PDAM yang sudah terisi
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
