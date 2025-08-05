// lib/models/notifikasi_model.dart

class Notifikasi {
  final int id;
  final String title;
  final String body;
  final String? referenceId;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? type;
  final String? status;

  Notifikasi({
    required this.id,
    required this.title,
    required this.body,
    this.referenceId,
    required this.createdAt,
    this.readAt,
    this.type,
    this.status,
  });

  factory Notifikasi.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;

    return Notifikasi(
      id: data['id'] as int,
      title: data['title'] as String,
      body: data['body'] as String,
      referenceId: data['reference_id']?.toString(),
      createdAt: DateTime.parse(data['created_at'] as String),
      readAt: data['read_at'] != null
          ? DateTime.parse(data['read_at'] as String)
          : null,
      // PERUBAHAN: Memetakan 'tipe_notifikasi' ke 'type'
      type: data['tipe_notifikasi'] as String?,
      // Kunci 'status' sudah benar, tidak perlu diubah
      status: data['status'] as String?,
    );
  }

  bool get isRead => readAt != null;
}
