class Cabang {
  final int id;
  final String namaCabang;
  final String? lokasiMaps; // String lengkap "lat,long"
  final double? latitude;   // Hasil parsing dari lokasiMaps
  final double? longitude;  // Hasil parsing dari lokasiMaps

  Cabang({
    required this.id,
    required this.namaCabang,
    this.lokasiMaps,
    this.latitude,
    this.longitude,
  });

  factory Cabang.fromJson(Map<String, dynamic> json) {
    // Memparsing string lokasi_maps untuk mendapatkan latitude dan longitude
    double? lat;
    double? lon;
    String? rawLokasiMaps = json['lokasi_maps'] as String?;

    if (rawLokasiMaps != null && rawLokasiMaps.contains(',')) {
      try {
        List<String> coords = rawLokasiMaps.split(',');
        lat = double.tryParse(coords[0].trim());
        lon = double.tryParse(coords[1].trim());
      } catch (e) {
        print('Error parsing lokasi_maps: $e');
        // Biarkan lat/lon null jika parsing gagal
      }
    }

    // Jika backend sudah mengirim 'latitude' dan 'longitude' terpisah (dari accessor),
    // kita bisa langsung menggunakannya. Prioritaskan data yang sudah diparse dari backend.
    // Jika tidak ada dari backend, coba parse dari 'lokasi_maps'.
    return Cabang(
      id: json['id'] as int,
      namaCabang: json['nama_cabang'] as String,
      lokasiMaps: rawLokasiMaps,
      latitude: (json['latitude'] as num?)?.toDouble() ?? lat,
      longitude: (json['longitude'] as num?)?.toDouble() ?? lon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama_cabang': namaCabang,
      'lokasi_maps': lokasiMaps,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

