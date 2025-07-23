// lib/models/tugas_model.dart

// --- MODIFIKASI UTAMA: Menambahkan ID dan Firebase UID pada KontakInfo ---
class KontakInfo {
  final int? id; // Tambahkan ID, bisa null jika tidak ada (cth: temuan anonim)
  final String nama;
  final String nomorHp;
  final String? firebaseUid; // Tambahkan Firebase UID, bisa null

  KontakInfo({
    this.id,
    required this.nama,
    required this.nomorHp,
    this.firebaseUid,
  });

  factory KontakInfo.fromJson(Map<String, dynamic> json) {
    return KontakInfo(
      id: json['id'] as int?, // Parsing ID
      nama: json['nama'] ?? 'N/A',
      nomorHp: json['nomor_hp'] ?? 'N/A',
      firebaseUid: json['firebase_uid'] as String?, // Parsing Firebase UID
    );
  }
}
// --- AKHIR MODIFIKASI ---

abstract class Tugas {
  final String idPenugasanInternal;
  final String tipeTugas;
  final bool isPetugasPelapor;
  final int idTugas;
  final String deskripsi;
  final String deskripsiLokasi;
  final String lokasiMaps;
  final String status;
  final String tanggalTugas;

  final String? fotoRumahUrl;
  final String? fotoBuktiUrl;
  final String? fotoSebelumUrl;
  final String? fotoSesudahUrl;
  final String? alasanPembatalan;

  final DateTime tanggalDibuatPenugasan;
  final Map<String, dynamic>? detailTugasLengkap;
  final int? ratingKecepatan;
  final int? ratingPelayanan;
  final int? ratingHasil;
  final String? komentarRating;

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
    this.fotoRumahUrl,
    this.fotoBuktiUrl,
    this.fotoSebelumUrl,
    this.fotoSesudahUrl,
    this.alasanPembatalan,
    required this.tanggalDibuatPenugasan,
    this.detailTugasLengkap,
    this.ratingKecepatan,
    this.ratingPelayanan,
    this.ratingHasil,
    this.komentarRating,
  });

  String get kategoriDisplay;
  KontakInfo? get infoKontakPelapor;

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
      case 'ditolak':
        return 'Ditolak';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  factory Tugas.fromJson(Map<String, dynamic> json) {
    final String tipe = json['tipe_tugas'] as String;
    if (tipe == 'pengaduan') {
      return PengaduanTugas.fromJson(json);
    } else if (tipe == 'temuan_kebocoran') {
      return TemuanTugas.fromJson(json);
    } else if (tipe == 'calon_pelanggan') {
      return CalonPelangganTugas.fromJson(json);
    } else {
      throw Exception('Tipe tugas tidak dikenal: $tipe');
    }
  }
}

class CalonPelangganTugas extends Tugas {
  final KontakInfo pelanggan;
  final String jenisTugasInternal;

  CalonPelangganTugas({
    required super.idPenugasanInternal,
    required super.isPetugasPelapor,
    required super.idTugas,
    required super.deskripsi,
    required super.deskripsiLokasi,
    required super.status,
    required super.tanggalTugas,
    required super.tanggalDibuatPenugasan,
    required String kategori,
    required this.pelanggan,
    super.detailTugasLengkap,
  }) : jenisTugasInternal = kategori,
       super(
         tipeTugas: 'calon_pelanggan',
         lokasiMaps: '',
         fotoBuktiUrl: detailTugasLengkap?['foto_ktp_url'],
         fotoRumahUrl: detailTugasLengkap?['foto_rumah_url'],
         fotoSebelumUrl: detailTugasLengkap?['foto_survey_url'],
         fotoSesudahUrl: detailTugasLengkap?['foto_pemasangan_url'],
         alasanPembatalan: null,
       );

  factory CalonPelangganTugas.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? detailLengkap =
        json['detail_tugas_lengkap'] as Map<String, dynamic>?;
    return CalonPelangganTugas(
      idPenugasanInternal: json['id_penugasan_internal'] ?? '',
      isPetugasPelapor: json['is_petugas_pelapor'] ?? false,
      idTugas: json['id_tugas'] ?? 0,
      deskripsi: json['deskripsi'] ?? 'Tugas Pendaftaran Baru',
      deskripsiLokasi: json['deskripsi_lokasi'] ?? 'Alamat tidak tersedia',
      status: json['status'] ?? 'pending',
      tanggalTugas: json['tanggal_tugas'] ?? '',
      tanggalDibuatPenugasan:
          DateTime.tryParse(json['tanggal_dibuat_penugasan'] ?? '') ??
          DateTime.now(),
      kategori: json['kategori'] ?? 'Pendaftaran',
      // Menggunakan info_kontak_pelapor agar konsisten
      pelanggan: KontakInfo.fromJson(
        json['info_kontak_pelapor'] as Map<String, dynamic>,
      ),
      detailTugasLengkap: detailLengkap,
    );
  }

  @override
  String get kategoriDisplay => jenisTugasInternal;

  @override
  KontakInfo? get infoKontakPelapor => pelanggan;
}

class PengaduanTugas extends Tugas {
  final String _kategoriInternal;
  final KontakInfo? pelanggan;

  PengaduanTugas({
    required super.idPenugasanInternal,
    required super.isPetugasPelapor,
    required super.idTugas,
    required String kategori,
    required super.deskripsi,
    required super.deskripsiLokasi,
    required super.lokasiMaps,
    required super.status,
    required super.tanggalTugas,
    super.fotoRumahUrl,
    super.fotoBuktiUrl,
    super.fotoSebelumUrl,
    super.fotoSesudahUrl,
    super.alasanPembatalan,
    required super.tanggalDibuatPenugasan,
    super.detailTugasLengkap,
    this.pelanggan,
  }) : _kategoriInternal = kategori,
       super(tipeTugas: 'pengaduan');

  factory PengaduanTugas.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? detailLengkap =
        json['detail_tugas_lengkap'] as Map<String, dynamic>?;
    return PengaduanTugas(
      idPenugasanInternal: json['id_penugasan_internal'] ?? '',
      isPetugasPelapor: json['is_petugas_pelapor'] ?? false,
      idTugas: json['id_tugas'] ?? 0,
      kategori: json['kategori'] ?? 'Lainnya',
      deskripsi: json['deskripsi'] ?? '',
      deskripsiLokasi: json['deskripsi_lokasi'] ?? 'Lokasi tidak tersedia',
      lokasiMaps: json['lokasi_maps'] ?? '',
      status: json['status'] ?? 'pending',
      tanggalTugas: json['tanggal_tugas'] ?? '',
      fotoRumahUrl: detailLengkap?['foto_rumah_url'] as String?,
      fotoBuktiUrl: detailLengkap?['foto_bukti_url'] as String?,
      fotoSebelumUrl: detailLengkap?['foto_sebelum_url'] as String?,
      fotoSesudahUrl: detailLengkap?['foto_sesudah_url'] as String?,
      tanggalDibuatPenugasan:
          DateTime.tryParse(json['tanggal_dibuat_penugasan'] ?? '') ??
          DateTime.now(),
      detailTugasLengkap: detailLengkap,
      pelanggan:
          json['info_kontak_pelapor'] != null
              ? KontakInfo.fromJson(
                json['info_kontak_pelapor'] as Map<String, dynamic>,
              )
              : null,
      alasanPembatalan: detailLengkap?['alasan_pembatalan'] as String?,
    );
  }

  @override
  String get kategoriDisplay => _kategoriInternal
      .replaceAll('_', ' ')
      .split(' ')
      .map((str) => str[0].toUpperCase() + str.substring(1))
      .join(' ');
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
    super.fotoBuktiUrl,
    super.fotoSebelumUrl,
    super.fotoSesudahUrl,
    super.alasanPembatalan,
    required super.tanggalDibuatPenugasan,
    super.detailTugasLengkap,
    this.pelaporTemuan,
  }) : super(tipeTugas: 'temuan_kebocoran', fotoRumahUrl: null);

  factory TemuanTugas.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? detailLengkap =
        json['detail_tugas_lengkap'] as Map<String, dynamic>?;
    return TemuanTugas(
      idPenugasanInternal: json['id_penugasan_internal'] ?? '',
      isPetugasPelapor: json['is_petugas_pelapor'] ?? false,
      idTugas: json['id_tugas'] ?? 0,
      deskripsi: json['deskripsi'] ?? '',
      deskripsiLokasi: json['deskripsi_lokasi'] ?? 'Lokasi tidak tersedia',
      lokasiMaps: json['lokasi_maps'] ?? '',
      status: json['status'] ?? 'pending',
      tanggalTugas: json['tanggal_tugas'] ?? '',
      fotoBuktiUrl: detailLengkap?['foto_bukti_url'] as String?,
      fotoSebelumUrl: detailLengkap?['foto_sebelum_url'] as String?,
      fotoSesudahUrl: detailLengkap?['foto_sesudah_url'] as String?,
      tanggalDibuatPenugasan:
          DateTime.tryParse(json['tanggal_dibuat_penugasan'] ?? '') ??
          DateTime.now(),
      detailTugasLengkap: detailLengkap,
      // Menggunakan info_kontak_pelapor agar konsisten
      pelaporTemuan:
          json['info_kontak_pelapor'] != null
              ? KontakInfo.fromJson(
                json['info_kontak_pelapor'] as Map<String, dynamic>,
              )
              : null,
      alasanPembatalan: detailLengkap?['alasan_pembatalan'] as String?,
    );
  }

  @override
  String get kategoriDisplay => 'Temuan Kebocoran';
  @override
  KontakInfo? get infoKontakPelapor => pelaporTemuan;
}
