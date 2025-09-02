// lib/models/pdam_id_model.dart
class PdamId {
  final int id;
  final String nomor;

  PdamId({required this.id, required this.nomor});

  factory PdamId.fromJson(Map<String, dynamic> json) {
    return PdamId(
      id: json['id'],
      nomor: json['nomor'],
    );
  }
}
