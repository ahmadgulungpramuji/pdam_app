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

  // You might want to add fields from 'petugas' or 'pelanggans' table if your API joins them
  // For example: final String? namaPelanggan;

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
      id: json['id'],
      idPdam: json['id_pdam'],
      idPelanggan: json['id_pelanggan'],
      idCabang: json['id_cabang'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      kategori: json['kategori'] ?? 'N/A',
      lokasiMaps: json['lokasi_maps'] ?? 'N/A',
      deskripsiLokasi: json['deskripsi_lokasi'] ?? 'N/A',
      deskripsi: json['deskripsi'] ?? 'N/A',
      tanggalPengaduan: json['tanggal_pengaduan'] ?? 'N/A',
      status: json['status'] ?? 'pending',
      fotoBukti: json['foto_bukti'],
      idPetugasPelapor: json['id_petugas_pelapor'],
      fotoRumah: json['foto_rumah'],
      fotoSebelum: json['foto_sebelum'],
      fotoSesudah: json['foto_sesudah'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // Helper to display category more friendly
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
      case 'water_meter_tidak_sesuai': // Assuming this is distinct from rusak
        return 'Water Meter Tidak Sesuai';
      case 'tagihan_membengkak':
        return 'Tagihan Membengkak';
      default:
        return kategori.replaceAll('_', ' ').toUpperCase();
    }
  }

  // Helper to display status more friendly
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
