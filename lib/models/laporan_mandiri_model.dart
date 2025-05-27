class LaporanMandiri {
  final int id;
  final int idPetugas;
  final int? idCabang;
  final DateTime tanggalLaporan;
  final String status;
  final String deskripsi;
  final String? fotoSebelum;
  final String? fotoSesudah;

  LaporanMandiri({
    required this.id,
    required this.idPetugas,
    this.idCabang,
    required this.tanggalLaporan,
    required this.status,
    required this.deskripsi,
    this.fotoSebelum,
    this.fotoSesudah,
  });

  factory LaporanMandiri.fromJson(Map<String, dynamic> json) {
    return LaporanMandiri(
      id: json['id'],
      idPetugas: json['id_petugas'],
      idCabang: json['id_cabang'],
      tanggalLaporan: DateTime.parse(json['tanggal_laporan']),
      status: json['status'],
      deskripsi: json['deskripsi'],
      fotoSebelum: json['foto_sebelum'],
      fotoSesudah: json['foto_sesudah'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_petugas': idPetugas,
      'id_cabang': idCabang,
      'tanggal_laporan': tanggalLaporan.toIso8601String(),
      'status': status,
      'deskripsi': deskripsi,
      'foto_sebelum': fotoSebelum,
      'foto_sesudah': fotoSesudah,
    };
  }
}
