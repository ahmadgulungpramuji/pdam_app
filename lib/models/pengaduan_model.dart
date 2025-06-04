// models/pengaduan_model.dart
import 'petugas_simple_model.dart';

class Pengaduan {
  // ... (properti lainnya seperti yang sudah Anda definisikan atau saya sarankan sebelumnya) ...
  final int id;
  final int idPdam;
  final int idPelanggan;
  final int idCabang;
  final double? latitude;
  final double? longitude;
  final String kategori;
  final String lokasiMaps;
  final String deskripsiLokasi;
  final String deskripsi;
  final String tanggalPengaduan;
  final String status;
  final String? fotoBukti;
  final int? idPetugasPelapor;
  final String? fotoRumah;
  final String? fotoSebelum;
  final String? fotoSesudah;
  final int? rating;
  final String? komentarRating;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PetugasSimple>? petugasDitugaskan;

  Pengaduan({
    required this.id,
    required this.idPdam,
    required this.idPelanggan,
    required this.idCabang,
    this.latitude,
    this.longitude,
    required this.kategori,
    required this.lokasiMaps,
    required this.deskripsiLokasi,
    required this.deskripsi,
    required this.tanggalPengaduan,
    required this.status,
    this.fotoBukti,
    this.idPetugasPelapor,
    this.fotoRumah,
    this.fotoSebelum,
    this.fotoSesudah,
    this.rating,
    this.komentarRating,
    required this.createdAt,
    required this.updatedAt,
    this.petugasDitugaskan,
  });

  factory Pengaduan.fromJson(Map<String, dynamic> json) {
    // ...(implementasi fromJson seperti yang sudah ada atau saya sarankan)...
    return Pengaduan(
      id: _parseToInt(json['id'], 'id'),
      idPdam: _parseToInt(json['id_pdam'], 'id_pdam'),
      idPelanggan: _parseToInt(json['id_pelanggan'], 'id_pelanggan'),
      idCabang: _parseToInt(json['id_cabang'], 'id_cabang'),
      latitude: _tryParseDouble(json['latitude']),
      longitude: _tryParseDouble(json['longitude']),
      kategori: json['kategori'] as String? ?? 'N/A',
      lokasiMaps: json['lokasi_maps'] as String? ?? 'N/A',
      deskripsiLokasi: json['deskripsi_lokasi'] as String? ?? 'N/A',
      deskripsi: json['deskripsi'] as String? ?? 'N/A',
      tanggalPengaduan: json['tanggal_pengaduan'] as String? ?? 'N/A',
      status: json['status'] as String? ?? 'pending',
      fotoBukti: json['foto_bukti'] as String?,
      idPetugasPelapor: _tryParseInt(json['id_petugas_pelapor']),
      fotoRumah: json['foto_rumah'] as String?,
      fotoSebelum: json['foto_sebelum'] as String?,
      fotoSesudah: json['foto_sesudah'] as String?,
      rating: _tryParseInt(json['rating']),
      komentarRating: json['komentar_rating'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      petugasDitugaskan:
          json['petugas_ditugaskan'] != null &&
                  json['petugas_ditugaskan'] is List
              ? List<PetugasSimple>.from(
                (json['petugas_ditugaskan'] as List<dynamic>).map(
                  (x) => PetugasSimple.fromJson(x),
                ),
              )
              : null,
    );
  }

  // Helper functions
  static int _parseToInt(dynamic value, String fieldName) {
    if (value == null) throw FormatException("Field '$fieldName' is null.");
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw FormatException("Field '$fieldName' is not a parsable int.");
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Getter yang diperbaiki
  String get friendlyKategori {
    switch (kategori) {
      case 'air_tidak_mengalir':
        return 'Air Tidak Mengalir';
      case 'air_keruh':
        return 'Air Keruh';
      case 'water_meter_rusak':
        return 'Water Meter Rusak';
      case 'angka_meter_tidak_sesuai':
        return 'Angka Meter Tidak Sesuai';
      case 'water_meter_tidak_sesuai': // Anda punya dua case mirip, pastikan ini disengaja
        return 'Water Meter Tidak Sesuai';
      case 'tagihan_membengkak':
        return 'Tagihan Membengkak';
      default: // Tambahkan default case
        return kategori
            .replaceAll('_', ' ')
            .toUpperCase(); // Atau nilai default lain
    }
  }

  String get friendlyStatus {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'menunggu_konfirmasi':
        return 'Menunggu Konfirmasi';
      case 'diterima':
        return 'Diterima';
      case 'dalam_perjalanan':
        return 'Dalam Perjalanan';
      case 'diproses':
        return 'Dalam Pengerjaan';
      case 'selesai':
        return 'Selesai';
      case 'dibatalkan':
        return 'Dibatalkan';
      default: // Tambahkan default case
        return status
            .replaceAll('_', ' ')
            .toUpperCase(); // Atau nilai default lain
    }
  }
}
