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
  String selectedKategori = "air_tidak_mengalir"; // Nilai default
  String? selectedIdPdam;
  TextEditingController lokasiController = TextEditingController();
  TextEditingController deskripsiController = TextEditingController();
  File? _fotoBukti;
  double? _latitude;
  double? _longitude;
  List<String> idPdamList = [];
  String? idCabang;

  // --- KODE BARU UNTUK KATEGORI LAINNYA ---
  final TextEditingController kategoriLainnyaController = TextEditingController();

  final Map<String, String> daftarKategori = {
    'air_tidak_mengalir': 'Air Tidak Mengalir',
    'air_keruh': 'Air Keruh',
    'water_meter_rusak': 'Water Meter Rusak',
    'angka_meter_tidak_sesuai': 'Angka Meter Tidak Sesuai',
    'tagihan_membengkak': 'Tagihan Membengkak',
    'lain_lain': 'Lain-lain...',
  };
  // --- AKHIR KODE BARU ---

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchIdPdamList();
  }

  Future<void> _fetchIdPdamList() async {
    try {
      // Ganti dengan URL API Anda yang benar
      final response = await http.get(
        Uri.parse('http://10.0.164.160:8000/api/id-pdam/1'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            idPdamList = List<String>.from(
              data['data'].map((item) => item['nomor']),
            );
          });
        }
      } else {
        throw Exception('Gagal memuat ID PDAM');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _fetchCabangByIdPdam(String idPdam) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Token tidak ditemukan")));
      }
      return;
    }

    try {
      // Ganti dengan URL API Anda yang benar
      final response = await http.get(
        Uri.parse('http://10.0.168.221:8000/api/cabang-by-id-pdam/$idPdam'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            idCabang = data['id_cabang'].toString();
          });
        }
      } else {
        throw Exception('Gagal mengambil data cabang');
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layanan lokasi tidak aktif')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akses lokasi ditolak permanen. Aktifkan di pengaturan.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mendapatkan lokasi: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _fotoBukti = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lokasi belum tersedia.")));
      return;
    }

    if (selectedIdPdam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih ID PDAM terlebih dahulu")),
      );
      return;
    }
    
    // Pastikan idCabang sudah didapatkan
    await _fetchCabangByIdPdam(selectedIdPdam!);
    if (idCabang == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal mendapatkan info cabang, tidak bisa mengirim.")));
        return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final idPelanggan = prefs.getString('id_pelanggan');

    if (token == null || idPelanggan == null) {
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

    try {
      // Ganti dengan URL API Anda yang benar
      final uri = Uri.parse('http://10.0.168.221:8000/api/pengaduans');
      final request = http.MultipartRequest('POST', uri)
            ..headers['Authorization'] = 'Bearer $token'
            ..headers['Accept'] = 'application/json'
            ..fields['kategori'] = selectedKategori
            ..fields['deskripsi_lokasi'] = lokasiController.text
            ..fields['deskripsi'] = deskripsiController.text
            ..fields['lokasi_maps'] = 'http://maps.google.com/maps?q=$_latitude,$_longitude'
            ..fields['latitude'] = _latitude.toString()
            ..fields['longitude'] = _longitude.toString()
            ..fields['id_pelanggan'] = idPelanggan
            ..fields['id_pdam'] = selectedIdPdam!
            ..fields['id_cabang'] = idCabang!;

      // --- KODE BARU UNTUK MENGIRIM KATEGORI LAINNYA ---
      if (selectedKategori == 'lain_lain') {
        request.fields['kategori_lainnya'] = kategoriLainnyaController.text;
      }
      // --- AKHIR KODE BARU ---

      if (_fotoBukti != null) {
        request.files.add(
          await http.MultipartFile.fromPath('foto_bukti', _fotoBukti!.path),
        );
      }

      final response = await request.send();
      Navigator.pop(context); // Tutup dialog loading

      if (response.statusCode == 201) {
        lokasiController.clear();
        deskripsiController.clear();
        kategoriLainnyaController.clear(); // Bersihkan juga controller ini
        if (mounted) {
            setState(() {
                _fotoBukti = null;
                selectedKategori = "air_tidak_mengalir";
                selectedIdPdam = null;
            });
            // Ganti dengan navigasi yang sesuai, misalnya kembali atau ke halaman sukses
            Navigator.pushNamed(context, '/lacak-status');
        }
      } else {
        final respStr = await response.stream.bytesToString();
        throw Exception('Gagal mengirim pengaduan. Status: ${response.statusCode}, Body: $respStr');
      }
    } catch (e) {
      // Pastikan dialog ditutup jika ada error sebelum navigasi
      if(Navigator.canPop(context)) {
          Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
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
                items: idPdamList.map((idPdam) => DropdownMenuItem(
                            value: idPdam,
                            child: Text(idPdam),
                          )).toList(),
                onChanged: (value) => setState(() => selectedIdPdam = value),
                validator: (value) => value == null ? 'ID PDAM harus dipilih' : null,
              ),
              const SizedBox(height: 16),

              // --- WIDGET BARU UNTUK MEMILIH JENIS LAPORAN ---
              DropdownButtonFormField<String>(
                value: selectedKategori,
                decoration: const InputDecoration(labelText: "Jenis Laporan"),
                items: daftarKategori.entries.map((entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        )).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedKategori = value!;
                  });
                },
                validator: (value) => value == null ? 'Jenis Laporan harus dipilih' : null,
              ),
              const SizedBox(height: 16),

              // --- WIDGET BARU YANG MUNCUL JIKA 'LAIN-LAIN' DIPILIH ---
              if (selectedKategori == 'lain_lain')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: kategoriLainnyaController,
                    decoration: const InputDecoration(
                      labelText: 'Sebutkan Jenis Laporan Anda',
                      hintText: 'Contoh: Pipa bocor di depan rumah',
                    ),
                    validator: (value) {
                      if (selectedKategori == 'lain_lain' && (value == null || value.isEmpty)) {
                        return 'Wajib diisi jika memilih Lain-lain';
                      }
                      return null;
                    },
                  ),
                ),
              // --- AKHIR WIDGET BARU ---

              TextFormField(
                controller: lokasiController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Detail Lokasi',
                  hintText: 'Contoh: Jl. Merdeka No. 5, seberang toko A',
                ),
                validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: deskripsiController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Tambahan Pengaduan',
                  hintText: 'Contoh: Air tidak mengalir sejak pagi hari',
                ),
                maxLines: 3,
                 validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Ambil Foto Bukti"),
                  ),
                  const SizedBox(width: 10),
                  if (_fotoBukti != null)
                    Icon(Icons.check_circle, color: Colors.green[600])
                  else
                    const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
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