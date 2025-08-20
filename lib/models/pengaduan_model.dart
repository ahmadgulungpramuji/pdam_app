// lib/models/pengaduan_model.dart
import 'petugas_simple_model.dart';

class Pengaduan {
  final int id;
  final int idPdam;
  final int idPelanggan;
  final int idCabang;
  final double? latitude;
  final double? longitude;
  final String kategori;
  final String? kategoriLainnya;
  final String lokasiMaps;
  final String deskripsiLokasi;
  final String deskripsi;
  final String tanggalPengaduan;
  final String status;
  final String? fotoBukti;
  final int? idPetugasPelapor;
  final String? fotoRumah;
  final String? fotoSebelum;
  final String? fotoSesudah; // INI AKAN KITA GUNAKAN SEBAGAI FOTO HASIL
  final int? ratingKecepatan;
  final int? ratingPelayanan;
  final int? ratingHasil;
  final String? komentarRating;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PetugasSimple>? petugasDitugaskan;
  final String? keteranganPenolakan;

  factory Pengaduan.fallback() => Pengaduan(
        id: 0,
        idPdam: 0,
        idPelanggan: 0,
        idCabang: 0,
        kategori: 'N/A',
        lokasiMaps: 'N/A',
        deskripsiLokasi: 'N/A',
        deskripsi: 'Data tidak ditemukan.',
        tanggalPengaduan: DateTime.now().toIso8601String(),
        status: 'error',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Pengaduan({
    required this.id,
    required this.idPdam,
    required this.idPelanggan,
    required this.idCabang,
    this.latitude,
    this.longitude,
    required this.kategori,
    this.kategoriLainnya,
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
    this.ratingKecepatan,
    this.ratingPelayanan,
    this.ratingHasil,
    this.komentarRating,
    required this.createdAt,
    required this.updatedAt,
    this.petugasDitugaskan,
    this.keteranganPenolakan,
  });

  factory Pengaduan.fromJson(Map<String, dynamic> json) {
    return Pengaduan(
      id: _parseToInt(json['id'], 'id'),
      idPdam: _parseToInt(json['id_pdam'], 'id_pdam'),
      idPelanggan: _parseToInt(json['id_pelanggan'], 'id_pelanggan'),
      idCabang: _parseToInt(json['id_cabang'], 'id_cabang'),
      latitude: _tryParseDouble(json['latitude']),
      longitude: _tryParseDouble(json['longitude']),
      kategori: json['kategori'] as String? ?? 'N/A',
      kategoriLainnya: json['kategori_lainnya'] as String?,
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
      ratingKecepatan: _tryParseInt(json['rating_kecepatan']),
      ratingPelayanan: _tryParseInt(json['rating_pelayanan']),
      ratingHasil: _tryParseInt(json['rating_hasil']),
      komentarRating: json['komentar_rating'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      petugasDitugaskan: json['petugas_ditugaskan'] != null &&
              json['petugas_ditugaskan'] is List
          ? List<PetugasSimple>.from(
              (json['petugas_ditugaskan'] as List<dynamic>).map(
                (x) => PetugasSimple.fromJson(x),
              ),
            )
          : null,
      keteranganPenolakan: json['keterangan_penolakan'] as String?,
    );
  }

  Pengaduan copyWith({
    int? ratingKecepatan,
    int? ratingPelayanan,
    int? ratingHasil,
    String? komentarRating,
    DateTime? updatedAt,
    String? keteranganPenolakan,
  }) {
    return Pengaduan(
      id: id,
      idPdam: idPdam,
      idPelanggan: idPelanggan,
      idCabang: idCabang,
      latitude: latitude,
      longitude: longitude,
      kategori: kategori,
      lokasiMaps: lokasiMaps,
      deskripsiLokasi: deskripsiLokasi,
      deskripsi: deskripsi,
      tanggalPengaduan: tanggalPengaduan,
      status: status,
      fotoBukti: fotoBukti,
      idPetugasPelapor: idPetugasPelapor,
      fotoRumah: fotoRumah,
      fotoSebelum: fotoSebelum,
      fotoSesudah: fotoSesudah,
      ratingKecepatan: ratingKecepatan ?? this.ratingKecepatan,
      ratingPelayanan: ratingPelayanan ?? this.ratingPelayanan,
      ratingHasil: ratingHasil ?? this.ratingHasil,
      komentarRating: komentarRating ?? this.komentarRating,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      petugasDitugaskan: petugasDitugaskan,
      keteranganPenolakan: keteranganPenolakan ?? this.keteranganPenolakan,
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

  String get friendlyKategori {
    if (kategori == 'lain_lain' &&
        kategoriLainnya != null &&
        kategoriLainnya!.isNotEmpty) {
      return 'Lain-lain: $kategoriLainnya';
    }
    switch (kategori) {
      case 'air_tidak_mengalir':
        return 'Air Tidak Mengalir';
      case 'air_keruh':
        return 'Air Keruh';
      case 'water_meter_rusak':
        return 'Water Meter Rusak';
      case 'angka_meter_tidak_sesuai':
        return 'Angka Meter Tidak Sesuai';
      case 'water_meter_tidak_sesuai':
        return 'Water Meter Tidak Sesuai';
      case 'tagihan_membengkak':
        return 'Tagihan Membengkak';
      case 'lain_lain': // Fallback jika kategori_lainnya kosong
        return 'Lain-lain';
      default:
        return kategori.replaceAll('_', ' ').toUpperCase();
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
      case 'ditolak':
        return 'Ditolak';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }
}