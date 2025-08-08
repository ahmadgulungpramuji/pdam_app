class Berita {
  final int id;
  final String judul;
  final String isi;
  final String? fotoBanner;
  final String? dibuatOleh;
  final DateTime tanggalTerbit;
  final DateTime? tanggalBerakhir;

  Berita({
    required this.id,
    required this.judul,
    required this.isi,
    this.fotoBanner,
    this.dibuatOleh,
    required this.tanggalTerbit,
    this.tanggalBerakhir,
  });

  factory Berita.fromJson(Map<String, dynamic> json) {
    return Berita(
      id: json['id'] as int,
      judul: json['judul'] as String,
      isi: json['isi'] as String,
      fotoBanner: json['foto_banner'] as String?,
      dibuatOleh: json['dibuat_oleh_type'] == 'App\\Models\\AdminPusat'
          ? 'Admin Pusat'
          : 'Admin Cabang',
      tanggalTerbit: DateTime.parse(json['tanggal_terbit'] as String),
      tanggalBerakhir: json['tanggal_berakhir'] != null
          ? DateTime.parse(json['tanggal_berakhir'] as String)
          : null,
    );
  }
}