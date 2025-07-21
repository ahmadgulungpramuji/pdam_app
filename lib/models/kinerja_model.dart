// lib/models/kinerja_model.dart

// Model utama yang menampung seluruh response dari API kinerja
class KinerjaResponse {
  final KpiUtama kpiUtama;
  final List<TrenKinerja> trenKinerja;
  final List<KomposisiTugas> komposisiTugas;
  final List<RincianPerTipe> rincianPerTipe;

  KinerjaResponse({
    required this.kpiUtama,
    required this.trenKinerja,
    required this.komposisiTugas,
    required this.rincianPerTipe,
  });

  // Factory constructor untuk membuat instance KinerjaResponse dari JSON
  factory KinerjaResponse.fromJson(Map<String, dynamic> json) {
    return KinerjaResponse(
      kpiUtama: KpiUtama.fromJson(json['kpi_utama']),
      trenKinerja:
          (json['tren_kinerja'] as List)
              .map((i) => TrenKinerja.fromJson(i))
              .toList(),
      komposisiTugas:
          (json['komposisi_tugas'] as List)
              .map((i) => KomposisiTugas.fromJson(i))
              .toList(),
      rincianPerTipe:
          (json['rincian_per_tipe'] as List)
              .map((i) => RincianPerTipe.fromJson(i))
              .toList(),
    );
  }
}

// Model untuk bagian KPI Utama (kartu-kartu di atas)
class KpiUtama {
  final double ratingRataRata;
  final int kecepatanRataRataMenit;
  final int totalTugasSelesai;
  final int totalTugasDibatalkan;
  final double ratingRataRataKecepatan;
  final double ratingRataRataPelayanan;
  final double ratingRataRataHasil;

  KpiUtama({
    required this.ratingRataRata,
    required this.kecepatanRataRataMenit,
    required this.totalTugasSelesai,
    required this.totalTugasDibatalkan,
    required this.ratingRataRataKecepatan,
    required this.ratingRataRataPelayanan,
    required this.ratingRataRataHasil,
  });

  // Factory constructor untuk membuat instance KpiUtama dari JSON
  factory KpiUtama.fromJson(Map<String, dynamic> json) {
    return KpiUtama(
      ratingRataRata: (json['rating_rata_rata'] as num).toDouble(),
      kecepatanRataRataMenit: json['kecepatan_rata_rata_menit'] as int,
      totalTugasSelesai: json['total_tugas_selesai'] as int,
      totalTugasDibatalkan: json['total_tugas_dibatalkan'] as int,
      ratingRataRataKecepatan: (json['rating_rata_rata_kecepatan'] as num? ?? 0).toDouble(),
      ratingRataRataPelayanan: (json['rating_rata_rata_pelayanan'] as num? ?? 0).toDouble(),
      ratingRataRataHasil: (json['rating_rata_rata_hasil'] as num? ?? 0).toDouble(),
    );
  }
}

// Model untuk data grafik tren (Bar Chart)
class TrenKinerja {
  final String label; // Contoh: "Sen", "Sel"
  final int selesai; // Jumlah tugas yang selesai pada hari itu

  TrenKinerja({required this.label, required this.selesai});

  // Factory constructor untuk membuat instance TrenKinerja dari JSON
  factory TrenKinerja.fromJson(Map<String, dynamic> json) {
    return TrenKinerja(label: json['label'], selesai: json['selesai']);
  }
}

// Model untuk data grafik komposisi (Pie Chart)
class KomposisiTugas {
  final String tipeTugas;
  final int total;

  KomposisiTugas({required this.tipeTugas, required this.total});

  // Factory constructor untuk membuat instance KomposisiTugas dari JSON
  factory KomposisiTugas.fromJson(Map<String, dynamic> json) {
    return KomposisiTugas(tipeTugas: json['tipe_tugas'], total: json['total']);
  }
}

// Model untuk daftar rincian di bagian bawah
class RincianPerTipe {
  final String tipeTugas;
  final int totalSelesai;
  final int kecepatanRataRataMenit;
  final double? ratingRataRata; // Bisa null jika tidak ada rating

  RincianPerTipe({
    required this.tipeTugas,
    required this.totalSelesai,
    required this.kecepatanRataRataMenit,
    this.ratingRataRata,
  });

  // Factory constructor untuk membuat instance RincianPerTipe dari JSON
  factory RincianPerTipe.fromJson(Map<String, dynamic> json) {
    return RincianPerTipe(
      tipeTugas: json['tipe_tugas'],
      totalSelesai: json['total_selesai'],
      kecepatanRataRataMenit: json['kecepatan_rata_rata_menit'],
      ratingRataRata: (json['rating_rata_rata'] as num?)?.toDouble(),
    );
  }
}
