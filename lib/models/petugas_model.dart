class Petugas {
  final int id;
  final String nama;
  final String email;
  final String nomorHp;
  final int idCabang;

  Petugas({
    required this.id,
    required this.nama,
    required this.email,
    required this.nomorHp,
    required this.idCabang,
  });

  factory Petugas.fromJson(Map<String, dynamic> json) {
    return Petugas(
      id: json['id'],
      nama: json['nama'],
      email: json['email'],
      nomorHp: json['nomor_hp'],
      idCabang: json['id_cabang'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'email': email,
      'nomor_hp': nomorHp,
      'id_cabang': idCabang,
    };
  }
}
