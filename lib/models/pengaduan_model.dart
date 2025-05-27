class Pengaduan {
  final int id;
  final int idPdam;
  final int idPelanggan;
  final int idCabang;
  final String kategori;
  final String lokasiMaps;
  final String deskripsiLokasi;
  final String deskripsi;
  final DateTime tanggalPengaduan;
  final String status;
  final String? fotoBukti;
  final String? fotoRumah;
  final int? idPetugasPelapor;
  final String? fotoSebelum;
  final String? fotoSesudah;

  Pengaduan({
    required this.id,
    required this.idPdam,
    required this.idPelanggan,
    required this.idCabang,
    required this.kategori,
    required this.lokasiMaps,
    required this.deskripsiLokasi,
    required this.deskripsi,
    required this.tanggalPengaduan,
    required this.status,
    this.fotoBukti,
    this.fotoRumah,
    this.idPetugasPelapor,
    this.fotoSebelum,
    this.fotoSesudah,
  });

  factory Pengaduan.fromJson(Map<String, dynamic> json) {
    return Pengaduan(
      id: json['id'],
      idPdam: json['id_pdam'],
      idPelanggan: json['id_pelanggan'],
      idCabang: json['id_cabang'],
      kategori: json['kategori'],
      lokasiMaps: json['lokasi_maps'],
      deskripsiLokasi: json['deskripsi_lokasi'],
      deskripsi: json['deskripsi'],
      tanggalPengaduan: DateTime.parse(json['tanggal_pengaduan']),
      status: json['status'],
      fotoBukti: json['foto_bukti'],
      fotoRumah: json['foto_rumah'],
      idPetugasPelapor: json['id_petugas_pelapor'],
      fotoSebelum: json['foto_sebelum'],
      fotoSesudah: json['foto_sesudah'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_pdam': idPdam,
      'id_pelanggan': idPelanggan,
      'id_cabang': idCabang,
      'kategori': kategori,
      'lokasi_maps': lokasiMaps,
      'deskripsi_lokasi': deskripsiLokasi,
      'deskripsi': deskripsi,
      'tanggal_pengaduan': tanggalPengaduan.toIso8601String(),
      'status': status,
      'foto_bukti': fotoBukti,
      'foto_rumah': fotoRumah,
      'id_petugas_pelapor': idPetugasPelapor,
      'foto_sebelum': fotoSebelum,
      'foto_sesudah': fotoSesudah,
    };
  }
}
