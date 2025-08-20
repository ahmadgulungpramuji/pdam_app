// models/temuan_kebocoran_model.dart
import 'petugas_simple_model.dart';

class TemuanKebocoran {
  final int id;
  final String namaPelapor;
  final String nomorHpPelapor;
  final int idCabang;
  final String lokasiMaps;
  final String deskripsiLokasi;
  final String? fotoBukti;
  final String status;
  final DateTime tanggalTemuan;
  final String? fotoSebelum;
  final String? fotoSesudah;
  final String? trackingCode;
  final int? ratingKecepatan;
  final int? ratingPelayanan;
  final int? ratingHasil;
  final String? komentarRating;
  final List<PetugasSimple>? petugasDitugaskan;
  final dynamic cabang;
  final String? keteranganPenolakan; // <-- TAMBAHKAN INI

  TemuanKebocoran({
    required this.id,
    required this.namaPelapor,
    required this.nomorHpPelapor,
    required this.idCabang,
    required this.lokasiMaps,
    required this.deskripsiLokasi,
    this.fotoBukti,
    required this.status,
    required this.tanggalTemuan,
    this.fotoSebelum,
    this.fotoSesudah,
    this.trackingCode,
    this.ratingKecepatan,
    this.ratingPelayanan,
    this.ratingHasil,
    this.komentarRating,
    this.petugasDitugaskan,
    this.cabang,
    this.keteranganPenolakan, // <-- TAMBAHKAN INI
  });

  factory TemuanKebocoran.fromJson(Map<String, dynamic> json) {
    return TemuanKebocoran(
      id: _parseToInt(json['id'], 'id'),
      namaPelapor: json['nama_pelapor'] as String? ?? 'N/A',
      nomorHpPelapor: json['nomor_hp_pelapor'] as String? ?? 'N/A',
      idCabang: _parseToInt(json['id_cabang'], 'id_cabang'),
      lokasiMaps: json['lokasi_maps'] as String? ?? 'N/A',
      deskripsiLokasi: json['deskripsi_lokasi'] as String? ?? 'N/A',
      fotoBukti: json['foto_bukti'] as String?,
      status: json['status'] as String? ?? 'pending',
      tanggalTemuan: DateTime.parse(json['tanggal_temuan'] as String),
      fotoSebelum: json['foto_sebelum'] as String?,
      fotoSesudah: json['foto_sesudah'] as String?,
      trackingCode: json['tracking_code'] as String?,
      ratingKecepatan: _tryParseInt(json['rating_kecepatan']),
      ratingPelayanan: _tryParseInt(json['rating_pelayanan']),
      ratingHasil: _tryParseInt(json['rating_hasil']),
      komentarRating: json['komentar_rating'] as String?,
      petugasDitugaskan:
          json['petugas_ditugaskan'] != null && json['petugas_ditugaskan'] is List
              ? List<PetugasSimple>.from(
                  (json['petugas_ditugaskan'] as List<dynamic>).map(
                    (x) => PetugasSimple.fromJson(x),
                  ),
                )
              : null,
      cabang: json['cabang'],
      keteranganPenolakan: json['keterangan_penolakan'] as String?, // <-- TAMBAHKAN INI
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama_pelapor': namaPelapor,
      'nomor_hp_pelapor': nomorHpPelapor,
      'id_cabang': idCabang,
      'lokasi_maps': lokasiMaps,
      'deskripsi_lokasi': deskripsiLokasi,
      'foto_bukti': fotoBukti,
      'status': status,
      'tanggal_temuan': tanggalTemuan.toIso8601String(),
      'foto_sebelum': fotoSebelum,
      'foto_sesudah': fotoSesudah,
      'tracking_code': trackingCode,
      'rating_kecepatan': ratingKecepatan,
      'rating_pelayanan': ratingPelayanan,
      'rating_hasil': ratingHasil,
      'komentar_rating': komentarRating,
      'petugas_ditugaskan': petugasDitugaskan?.map((e) => e.toJson()).toList(),
      'cabang': cabang,
      'keterangan_penolakan': keteranganPenolakan, // <-- TAMBAHKAN INI
    };
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
      case 'ditolak': // <-- TAMBAHKAN INI
        return 'Ditolak';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }
}