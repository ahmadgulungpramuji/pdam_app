// lib/services/watermark_service.dart

import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class WatermarkService {

  // Fungsi utama untuk menambahkan watermark
  Future<XFile> addWatermark(XFile originalImage) async {
    // 1. Dapatkan informasi GPS, Alamat, dan Waktu
    final watermarkText = await _getWatermarkText();

    // 2. Baca file gambar
    final imageBytes = await originalImage.readAsBytes();
    final img.Image original = img.decodeImage(imageBytes)!;

    // 3. Tambahkan watermark
    // Menggunakan font bitmap bawaan yang sederhana. 
    // Untuk font custom, diperlukan langkah tambahan.
    img.drawString(
      original,
      watermarkText,
      font: img.arial24,
      x: 20, // Padding dari kiri
      y: original.height - 80, // Padding dari bawah
      color: img.ColorRgb8(255, 255, 255), // Warna teks putih
      wrap: true, // Otomatis wrap jika teks panjang
    );

    // 4. Simpan gambar yang sudah di-watermark ke file baru
    final Directory tempDir = await getTemporaryDirectory();
    final String targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File watermarkedFile = File(targetPath);
    await watermarkedFile.writeAsBytes(img.encodeJpg(original, quality: 85));

    return XFile(targetPath);
  }

  // Helper untuk mendapatkan teks watermark (Alamat & Waktu)
  Future<String> _getWatermarkText() async {
    // a. Dapatkan waktu saat ini dan format
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
    final String dateTimeStr = formatter.format(now);

    // b. Dapatkan lokasi GPS
    final Position position = await _determinePosition();
    
    // c. Ubah GPS menjadi alamat
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    
    final Placemark place = placemarks[0];
    final String addressStr = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.subAdministrativeArea}, ${place.administrativeArea}";

    return '$addressStr\n$dateTimeStr';
  }

  // Helper untuk menangani izin dan mendapatkan posisi GPS
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Layanan lokasi dimatikan.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Izin lokasi ditolak.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Izin lokasi ditolak secara permanen, kami tidak dapat meminta izin.');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }
}
