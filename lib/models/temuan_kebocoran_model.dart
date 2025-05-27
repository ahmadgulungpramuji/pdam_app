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
  });

  factory TemuanKebocoran.fromJson(Map<String, dynamic> json) {
    return TemuanKebocoran(
      id: json['id'],
      namaPelapor: json['nama_pelapor'],
      nomorHpPelapor: json['nomor_hp_pelapor'],
      idCabang: json['id_cabang'],
      lokasiMaps: json['lokasi_maps'],
      deskripsiLokasi: json['deskripsi_lokasi'],
      fotoBukti: json['foto_bukti'],
      status: json['status'],
      tanggalTemuan: DateTime.parse(json['tanggal_temuan']),
      fotoSebelum: json['foto_sebelum'],
      fotoSesudah: json['foto_sesudah'],
      trackingCode: json['tracking_code'],
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
    };
  }
}
