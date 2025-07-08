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
  final String email;
  final String nomorHp;
  final CabangInfo? cabang; // Menggunakan CabangInfo

  Petugas({
    required this.id,
    required this.nama,
    required this.email,
    required this.nomorHp,
    this.cabang,
  });

  factory Petugas.fromJson(Map<String, dynamic> json) {
    return Petugas(
      id: json['id'] as int,
      nama: json['nama'] as String? ?? 'N/A',
      email: json['email'] as String? ?? 'N/A',
      nomorHp: json['nomor_hp'] as String? ?? 'N/A',
      cabang:
          json['cabang'] != null
              ? CabangInfo.fromJson(json['cabang'] as Map<String, dynamic>)
              : null, // Asumsi API mengirim objek 'cabang'
    );
  }

  Petugas copyWith({String? nama, String? email, String? nomorHp}) {
    return Petugas(
      id: id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      nomorHp: nomorHp ?? this.nomorHp,
      cabang: cabang, // Cabang biasanya tidak diubah oleh petugas
    );
  }
}
