import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class PengaduanFormPage extends StatefulWidget {
  const PengaduanFormPage({super.key});

  @override
  State<PengaduanFormPage> createState() => _PengaduanFormPageState();
}

class _PengaduanFormPageState extends State<PengaduanFormPage> {
  final _formKey = GlobalKey<FormState>();
  String selectedKategori = "air tidak mengalir";
  String? selectedIdPdam;
  TextEditingController lokasiController = TextEditingController();
  TextEditingController deskripsiController = TextEditingController();
  File? _fotoBukti;
  double? _latitude;
  double? _longitude;
  List<String> idPdamList = [];
  String? idCabang;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchIdPdamList();
  }

  Future<void> _fetchIdPdamList() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.164.160:8000/api/id-pdam/1'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          idPdamList = List<String>.from(
            data['data'].map((item) => item['nomor']),
          );
        });
      } else {
        throw Exception('Gagal memuat ID PDAM');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _fetchCabangByIdPdam(String idPdam) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Token tidak ditemukan")));
      return;
    }

    final response = await http.get(
      Uri.parse('http://10.0.168.221:8000/api/cabang-by-id-pdam/$idPdam'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        idCabang = data['id_cabang'];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mengambil data cabang")),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layanan lokasi tidak aktif')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Akses lokasi ditolak permanen. Aktifkan di pengaturan.',
          ),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null) {
      setState(() {
        _fotoBukti = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Lokasi belum tersedia.")));
      return;
    }

    if (selectedIdPdam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih ID PDAM terlebih dahulu")),
      );
      return;
    }

    await _fetchCabangByIdPdam(selectedIdPdam!);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final idPelanggan = prefs.getString('id_pelanggan');

    if (token == null || idPelanggan == null || idCabang == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data pengguna tidak lengkap")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final uri = Uri.parse('http://10.0.168.221:8000/api/pengaduans');
    final request =
        http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['kategori'] = selectedKategori
          ..fields['deskripsi_lokasi'] = lokasiController.text
          ..fields['deskripsi'] = deskripsiController.text
          ..fields['lokasi_maps'] =
              'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude'
          ..fields['latitude'] = _latitude.toString()
          ..fields['longitude'] = _longitude.toString()
          ..fields['status'] = 'pending'
          ..fields['id_pelanggan'] = idPelanggan
          ..fields['id_pdam'] = selectedIdPdam!
          ..fields['id_cabang'] = idCabang!
          ..fields['tanggal_pengaduan'] = DateTime.now().toIso8601String();

    if (_fotoBukti != null) {
      request.files.add(
        await http.MultipartFile.fromPath('foto_bukti', _fotoBukti!.path),
      );
    }

    final response = await request.send();
    Navigator.pop(context);

    if (response.statusCode == 201) {
      lokasiController.clear();
      deskripsiController.clear();
      setState(() {
        _fotoBukti = null;
        selectedKategori = "air tidak mengalir";
      });
      Navigator.pushNamed(context, '/lacak-status');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mengirim pengaduan.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Form Pengaduan")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: selectedIdPdam,
                decoration: const InputDecoration(labelText: "Pilih ID PDAM"),
                items:
                    idPdamList
                        .map(
                          (idPdam) => DropdownMenuItem(
                            value: idPdam,
                            child: Text(idPdam),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => selectedIdPdam = value),
                validator:
                    (value) => value == null ? 'ID PDAM harus dipilih' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lokasiController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Lokasi',
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: deskripsiController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Tambahan',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Ambil Foto"),
                  ),
                  const SizedBox(width: 10),
                  _fotoBukti != null
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.cancel, color: Colors.red),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Kirim Pengaduan"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
