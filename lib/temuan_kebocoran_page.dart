import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class TemuanKebocoranPage extends StatefulWidget {
  const TemuanKebocoranPage({super.key});

  @override
  State<TemuanKebocoranPage> createState() => _TemuanKebocoranPageState();
}

class _TemuanKebocoranPageState extends State<TemuanKebocoranPage> {
  final TextEditingController deskripsiController = TextEditingController();
  String? _location;
  double? _latitude;
  double? _longitude;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    // Memanggil fungsi untuk mendapatkan lokasi saat halaman pertama kali dibuka
    _getCurrentLocation();
  }

  // Fungsi untuk mendapatkan lokasi pengguna
  Future<void> _getCurrentLocation() async {
    // Meminta izin akses lokasi
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // Menangani jika izin ditolak
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Permission Denied")));
      return;
    }

    // Mengambil posisi pengguna
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Menampilkan latitude dan longitude
    print("Latitude: ${position.latitude}, Longitude: ${position.longitude}");

    // Mengonversi koordinat ke alamat menggunakan Geocoding
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    Placemark place = placemarks[0];

    setState(() {
      _location = "${place.locality}, ${place.country}";
      _latitude = position.latitude;
      _longitude = position.longitude;
    });

    // Menampilkan hasil di UI
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Lokasi: $_location")));
  }

  // Fungsi untuk mengambil foto dari kamera
  Future<void> _takePhoto() async {
    final ImagePicker _picker = ImagePicker();

    // Memilih dari kamera
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      // Menampilkan foto yang diambil
      setState(() {
        _imagePath = photo.path;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Foto diambil: $_imagePath")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada foto yang diambil")),
      );
    }
  }

  // Fungsi untuk mengirim data ke API
  Future<void> _submitData() async {
    if (_location == null ||
        _latitude == null ||
        _longitude == null ||
        _imagePath == null ||
        deskripsiController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Data tidak lengkap")));
      return;
    }

    var request = http.MultipartRequest('POST', Uri.parse('API_URL'));

    // Mengirimkan lokasi dan foto
    request.fields['lokasi'] = _location!;
    request.fields['latitude'] = _latitude!.toString();
    request.fields['longitude'] = _longitude!.toString();
    request.fields['deskripsi_lokasi'] = deskripsiController.text;

    var photo = await http.MultipartFile.fromPath('foto_bukti', _imagePath!);
    request.files.add(photo);

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Data berhasil dikirim")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Gagal mengirim data")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Terjadi kesalahan: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temuan Kebocoran')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: deskripsiController,
              decoration: const InputDecoration(labelText: 'Deskripsi Lokasi'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // Menampilkan lokasi otomatis tanpa tombol "Ambil Lokasi Sekarang"
            Text(
              _location != null ? "Lokasi: $_location" : "Mengambil lokasi...",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _takePhoto,
              child: const Text("Ambil Foto Sekarang"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitData,
              child: const Text("Kirim Data"),
            ),
          ],
        ),
      ),
    );
  }
}
