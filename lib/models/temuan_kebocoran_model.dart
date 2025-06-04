// models/temuan_kebocoran_model.dart
import 'petugas_simple_model.dart'; // Impor model PetugasSimple

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
  final int? rating; // BARU: Rating yang diberikan
  final String? komentarRating; // BARU: Komentar rating
  final List<PetugasSimple>?
  petugasDitugaskan; // BARU: Daftar petugas yang menangani

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
    this.rating, // BARU
    this.komentarRating, // BARU
    this.petugasDitugaskan, // BARU
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
      rating: _tryParseInt(json['rating']), // BARU
      komentarRating: json['komentar_rating'] as String?, // BARU
      petugasDitugaskan:
          json['petugas_ditugaskan'] != null &&
                  json['petugas_ditugaskan'] is List
              ? List<PetugasSimple>.from(
                (json['petugas_ditugaskan'] as List<dynamic>).map(
                  (x) => PetugasSimple.fromJson(x),
                ),
              )
              : null, // BARU
    );
  }

  Map<String, dynamic> toJson() {
    // ... implementasi jika diperlukan ...
    return {
      // ... field lain ...
      'rating': rating,
      'komentar_rating': komentarRating,
      // ...
    };
  }

  // Helper functions (bisa diletakkan di file utilitas terpisah)
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

  // Getter untuk tampilan status (opsional, jika ingin konsisten seperti Pengaduan)
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

  get cabang => null;
}
