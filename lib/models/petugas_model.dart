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
  final String? nik;
  final String? email;   // Nullable
  final String? nomorHp; // Nullable
  final String? fotoProfil; 
  final CabangInfo? cabang; 

  Petugas({
    required this.id,
    required this.nama,
    this.nik,
    this.email,    // Hapus required
    this.nomorHp,  // Hapus required
    this.fotoProfil,
    this.cabang,
  });

  factory Petugas.fromJson(Map<String, dynamic> json) {
    return Petugas(
      id: json['id'] as int,
      nama: json['nama'] as String? ?? 'N/A',
      nik: json['nik'] as String?,
      
      // --- PERBAIKAN DI SINI ---
      // Hapus "?? 'N/A'" agar nilai tetap null jika database kosong
      email: json['email'] as String?, 
      nomorHp: json['nomor_hp'] as String?,
      // -------------------------
      
      fotoProfil: json['foto_profil'],
      cabang: json['cabang'] != null
              ? CabangInfo.fromJson(json['cabang'] as Map<String, dynamic>)
              : null,
    );
  }

  // Sesuaikan juga copyWith
  Petugas copyWith({String? nama, String? email, String? nomorHp, String? nik}) {
    return Petugas(
      id: id,
      nama: nama ?? this.nama,
      nik: nik ?? this.nik,
      email: email ?? this.email,
      nomorHp: nomorHp ?? this.nomorHp,
      cabang: cabang,
      fotoProfil: fotoProfil,
    );
  }
}