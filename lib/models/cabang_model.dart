class Cabang {
  final int id;
  final String namaCabang;
  final String? lokasiMaps;

  Cabang({required this.id, required this.namaCabang, this.lokasiMaps});

  factory Cabang.fromJson(Map<String, dynamic> json) {
    return Cabang(
      id: json['id'] as int,
      namaCabang: json['nama_cabang'] as String,
      lokasiMaps: json['lokasi_maps'] as String?,
    );
  }
}
