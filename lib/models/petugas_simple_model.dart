// models/petugas_simple_model.dart
class PetugasSimple {
  final int id;
  final String nama;

  PetugasSimple({required this.id, required this.nama});

  factory PetugasSimple.fromJson(Map<String, dynamic> json) {
    return PetugasSimple(
      id: _parseToInt(json['id'], 'petugas_id'),
      nama: json['nama'] as String? ?? 'N/A',
    );
  }

  /// **BARU: Menambahkan metode toJson**
  /// Metode ini mengubah instance PetugasSimple menjadi Map.
  Map<String, dynamic> toJson() {
    return {'id': id, 'nama': nama};
  }

  // Helper function
  static int _parseToInt(dynamic value, String fieldName) {
    if (value == null) {
      throw FormatException("Field '$fieldName' is null, but expected an int.");
    }
    if (value is int) {
      return value;
    }
    if (value is String) {
      final parsedInt = int.tryParse(value);
      if (parsedInt != null) {
        return parsedInt;
      } else {
        throw FormatException(
          "Field '$fieldName' (value: '$value') is not a valid integer string.",
        );
      }
    }
    throw FormatException(
      "Field '$fieldName' (value: '$value') is not a parsable integer type.",
    );
  }
}
