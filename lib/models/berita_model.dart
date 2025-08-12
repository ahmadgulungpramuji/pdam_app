class Berita {
  final int id;
  final String judul;
  final String isi;
  final String? fotoBanner;
  final String? namaAdmin; // <-- Ganti dari 'dibuatOleh' ke 'namaAdmin'
  final DateTime tanggalTerbit;
  final DateTime? tanggalBerakhir;

  Berita({
    required this.id,
    required this.judul,
    required this.isi,
    this.fotoBanner,
    this.namaAdmin, // <-- Ganti dari 'dibuatOleh' ke 'namaAdmin'
    required this.tanggalTerbit,
    this.tanggalBerakhir,
  });

  factory Berita.fromJson(Map<String, dynamic> json) {
  print('Menerima JSON Berita: $json');
  String? namaAdmin;
  if (json['dibuat_oleh'] != null && json['dibuat_oleh'] is Map<String, dynamic>) {
    // --- UBAH BARIS INI ---
    namaAdmin = json['dibuat_oleh']['username'] as String?; // <-- Ganti 'nama' menjadi 'username'
    print('Nama Admin ditemukan: $namaAdmin');
  } else {
    print('Relasi dibuatOleh tidak ditemukan atau bukan Map.');
  }

  return Berita(
    id: json['id'] as int,
    judul: json['judul'] as String,
    isi: json['isi'] as String,
    fotoBanner: json['foto_banner'] as String?,
    namaAdmin: namaAdmin,
    tanggalTerbit: DateTime.parse(json['tanggal_terbit'] as String),
    tanggalBerakhir: json['tanggal_berakhir'] != null
        ? DateTime.parse(json['tanggal_berakhir'] as String)
        : null,
  );
}
}