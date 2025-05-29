// lib/models/tugas_model.dart

// Helper class untuk info kontak
class KontakInfo {
  final String? nama;
  final String? nomorHp;

  KontakInfo({this.nama, this.nomorHp});

  factory KontakInfo.fromJson(Map<String, dynamic> json) {
    return KontakInfo(
      nama: json['nama'] as String?,
      nomorHp: json['nomor_hp'] as String?,
    );
  }
}

abstract class Tugas {
  final String idPenugasanInternal; // ID unik dari tabel pivot dengan prefix
  final String tipeTugas; // 'pengaduan' atau 'temuan_kebocoran'
  final bool isPetugasPelapor;
  final int idTugas; // ID asli dari pengaduan atau temuan_kebocoran
  final String deskripsi;
  final String deskripsiLokasi;
  final String lokasiMaps;
  final String status;
  final String tanggalTugas; // tanggal_pengaduan atau tanggal_temuan
  final String? fotoBukti;
  final DateTime tanggalDibuatPenugasan; // created_at dari tabel pivot
  final Map<String, dynamic>? detailTugasLengkap; // data JSON asli

  Tugas({
    required this.idPenugasanInternal,
    required this.tipeTugas,
    required this.isPetugasPelapor,
    required this.idTugas,
    required this.deskripsi,
    required this.deskripsiLokasi,
    required this.lokasiMaps,
    required this.status,
    required this.tanggalTugas,
    this.fotoBukti,
    required this.tanggalDibuatPenugasan,
    this.detailTugasLengkap,
  });

  String get kategoriDisplay; // Akan di-override oleh subclass
  KontakInfo? get infoKontakPelapor; // Akan di-override oleh subclass

  // Helper untuk status agar bisa di-override jika perlu, tapi defaultnya sama
  String get friendlyStatus {
    switch (status.toLowerCase()) {
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

  // Factory constructor untuk membuat instance yang tepat berdasarkan tipe_tugas
  factory Tugas.fromJson(Map<String, dynamic> json) {
    final String tipe = json['tipe_tugas'] as String;
    if (tipe == 'pengaduan') {
      return PengaduanTugas.fromJson(json);
    } else if (tipe == 'temuan_kebocoran') {
      return TemuanTugas.fromJson(json);
    } else {
      throw Exception('Tipe tugas tidak dikenal: $tipe');
    }
  }
}

class PengaduanTugas extends Tugas {
  final String
  _kategoriInternal; // kategori asli dari API (e.g., 'air_tidak_mengalir')
  final KontakInfo? pelanggan;

  PengaduanTugas({
    required super.idPenugasanInternal,
    required super.isPetugasPelapor,
    required super.idTugas,
    required String kategori, // Ini adalah kategori internal
    required super.deskripsi,
    required super.deskripsiLokasi,
    required super.lokasiMaps,
    required super.status,
    required super.tanggalTugas,
    super.fotoBukti,
    required super.tanggalDibuatPenugasan,
    super.detailTugasLengkap,
    this.pelanggan,
  }) : _kategoriInternal = kategori,
       super(tipeTugas: 'pengaduan');

  factory PengaduanTugas.fromJson(Map<String, dynamic> json) {
    return PengaduanTugas(
      idPenugasanInternal: json['id_penugasan_internal'] as String,
      isPetugasPelapor: json['is_petugas_pelapor'] as bool,
      idTugas: json['id_tugas'] as int,
      kategori: json['kategori'] as String, // Kategori internal
      deskripsi: json['deskripsi'] as String,
      deskripsiLokasi: json['deskripsi_lokasi'] as String,
      lokasiMaps: json['lokasi_maps'] as String,
      status: json['status'] as String,
      tanggalTugas: json['tanggal_tugas'] as String,
      fotoBukti: json['foto_bukti'] as String?,
      tanggalDibuatPenugasan: DateTime.parse(
        json['tanggal_dibuat_penugasan'] as String,
      ),
      detailTugasLengkap: json['detail_tugas_lengkap'] as Map<String, dynamic>?,
      pelanggan:
          json['pelanggan'] != null
              ? KontakInfo.fromJson(json['pelanggan'] as Map<String, dynamic>)
              : null,
    );
  }

  @override
  String get kategoriDisplay {
    // Mengubah kategori internal menjadi teks yang lebih ramah
    switch (_kategoriInternal) {
      case 'air_tidak_mengalir':
        return 'Air Tidak Mengalir';
      case 'air_keruh':
        return 'Air Keruh';
      case 'water_meter_rusak':
        return 'Water Meter Rusak';
      case 'angka_meter_tidak_sesuai':
        return 'Angka Meter Tdk Sesuai';
      case 'water_meter_tidak_sesuai':
        return 'Water Meter Tdk Sesuai';
      case 'tagihan_membengkak':
        return 'Tagihan Membengkak';
      default:
        return _kategoriInternal.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  KontakInfo? get infoKontakPelapor => pelanggan;
}

class TemuanTugas extends Tugas {
  final KontakInfo? pelaporTemuan;

  TemuanTugas({
    required super.idPenugasanInternal,
    required super.isPetugasPelapor,
    required super.idTugas,
    required super.deskripsi,
    required super.deskripsiLokasi,
    required super.lokasiMaps,
    required super.status,
    required super.tanggalTugas,
    super.fotoBukti,
    required super.tanggalDibuatPenugasan,
    super.detailTugasLengkap,
    this.pelaporTemuan,
  }) : super(tipeTugas: 'temuan_kebocoran');

  factory TemuanTugas.fromJson(Map<String, dynamic> json) {
    return TemuanTugas(
      idPenugasanInternal: json['id_penugasan_internal'] as String,
      isPetugasPelapor: json['is_petugas_pelapor'] as bool,
      idTugas: json['id_tugas'] as int,
      // Kategori untuk temuan sudah ditetapkan di API sebagai "Temuan Kebocoran"
      // dan akan diakses melalui getter 'kategoriDisplay' di bawah
      deskripsi: json['deskripsi'] as String,
      deskripsiLokasi: json['deskripsi_lokasi'] as String,
      lokasiMaps: json['lokasi_maps'] as String,
      status: json['status'] as String,
      tanggalTugas: json['tanggal_tugas'] as String,
      fotoBukti: json['foto_bukti'] as String?,
      tanggalDibuatPenugasan: DateTime.parse(
        json['tanggal_dibuat_penugasan'] as String,
      ),
      detailTugasLengkap: json['detail_tugas_lengkap'] as Map<String, dynamic>?,
      pelaporTemuan:
          json['pelapor_temuan'] != null
              ? KontakInfo.fromJson(
                json['pelapor_temuan'] as Map<String, dynamic>,
              )
              : null,
    );
  }

  @override
  String get kategoriDisplay => 'Temuan Kebocoran'; // Kategori display tetap untuk temuan

  @override
  KontakInfo? get infoKontakPelapor => pelaporTemuan;
}
