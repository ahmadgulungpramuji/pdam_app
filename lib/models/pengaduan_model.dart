// models/pengaduan_model.dart
class Pengaduan {
  final int id;
  final int idPdam;
  final int idPelanggan;
  final int idCabang;
  final double? latitude;
  final double? longitude;
  final String kategori;
  final String lokasiMaps; // misal sharelock WA
  final String deskripsiLokasi; // nama jalan atau gang
  final String deskripsi;
  final String tanggalPengaduan;
  final String status;
  final String? fotoBukti;
  final int? idPetugasPelapor;
  final String? fotoRumah;
  final String? fotoSebelum;
  final String? fotoSesudah;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pengaduan.fromJson(Map<String, dynamic> json) {
    return Pengaduan(
      // Handle fields that are int but might come as String from JSON
      id: _parseToInt(json['id'], 'id'),
      idPdam: _parseToInt(json['id_pdam'], 'id_pdam'),
      idPelanggan: _parseToInt(json['id_pelanggan'], 'id_pelanggan'),
      idCabang: _parseToInt(json['id_cabang'], 'id_cabang'),

      // Handle nullable double fields
      latitude: _tryParseDouble(json['latitude']),
      longitude: _tryParseDouble(json['longitude']),

      kategori: json['kategori'] as String? ?? 'N/A',
      lokasiMaps: json['lokasi_maps'] as String? ?? 'N/A',
      deskripsiLokasi: json['deskripsi_lokasi'] as String? ?? 'N/A',
      deskripsi: json['deskripsi'] as String? ?? 'N/A',
      tanggalPengaduan: json['tanggal_pengaduan'] as String? ?? 'N/A',
      status: json['status'] as String? ?? 'pending',
      fotoBukti: json['foto_bukti'] as String?,

      // Handle nullable int field
      idPetugasPelapor: _tryParseInt(json['id_petugas_pelapor']),

      fotoRumah: json['foto_rumah'] as String?,
      fotoSebelum: json['foto_sebelum'] as String?,
      fotoSesudah: json['foto_sesudah'] as String?,

      // Ensure DateTime fields are parsed from String
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Helper function to parse dynamic value to int (handles String or int)
  // Throws error if null or not parsable, for required fields.
  static int _parseToInt(dynamic value, String fieldName) {
    if (value == null) {
      throw FormatException("Field '$fieldName' is null, but expected an int.");
    }
    if (value is int) {
      return value;
    }
    if (value is String) {
      final parsedInt = int.tryParse(value);
      if (parsedInt != null) {
        return parsedInt;
      } else {
        throw FormatException(
          "Field '$fieldName' (value: '$value') is not a valid integer string.",
        );
      }
    }
    throw FormatException(
      "Field '$fieldName' (value: '$value') is not a parsable integer type.",
    );
  }

  // Helper function to try parsing dynamic value to int? (handles String or int)
  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null; // Or throw error if type is unexpected but not null
  }

  // Helper function to try parsing dynamic value to double? (handles String or num)
  static double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble(); // Convert int to double
    if (value is String) return double.tryParse(value);
    return null; // Or throw error if type is unexpected but not null
  }

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
      case 'water_meter_tidak_sesuai':
        return 'Water Meter Tidak Sesuai';
      case 'tagihan_membengkak':
        return 'Tagihan Membengkak';
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
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }
}
