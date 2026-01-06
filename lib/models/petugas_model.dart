// lib/models/petugas_model.dart
class CabangInfo {
  final int id;
  final String namaCabang;

  CabangInfo({required this.id, required this.namaCabang});

  factory CabangInfo.fromJson(Map<String, dynamic> json) {
    return CabangInfo(
      id: json['id'] as int,
      namaCabang: json['nama_cabang'] as String? ?? 'N/A',
    );
  }
}

class Petugas {
  final int id;
  final String nama;
  final String? nik; // <--- TAMBAHKAN BARIS INI
  final String email;
  final String nomorHp;
  final String? fotoProfil; 
  final CabangInfo? cabang; 

  Petugas({
    required this.id,
    required this.nama,
    this.nik, // <--- TAMBAHKAN BARIS INI
    required this.email,
    required this.nomorHp,
    this.fotoProfil,
    this.cabang,
  });

  factory Petugas.fromJson(Map<String, dynamic> json) {
    return Petugas(
      id: json['id'] as int,
      nama: json['nama'] as String? ?? 'N/A',
      nik: json['nik'] as String?, // <--- TAMBAHKAN BARIS INI
      email: json['email'] as String? ?? 'N/A',
      nomorHp: json['nomor_hp'] as String? ?? 'N/A',
      fotoProfil: json['foto_profil'],
      cabang: json['cabang'] != null
              ? CabangInfo.fromJson(json['cabang'] as Map<String, dynamic>)
              : null,
    );
  }

  Petugas copyWith({String? nama, String? email, String? nomorHp, String? nik}) {
    return Petugas(
      id: id,
      nama: nama ?? this.nama,
      nik: nik ?? this.nik, // <--- TAMBAHKAN
      email: email ?? this.email,
      nomorHp: nomorHp ?? this.nomorHp,
      cabang: cabang,
      fotoProfil: fotoProfil,
    );
  }
}
