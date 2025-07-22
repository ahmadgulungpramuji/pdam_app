// lib/models/notifikasi_model.dart

class Notifikasi {
  final int id;
  final String title;
  final String body;
  final int? referenceId;
  final DateTime createdAt;
  final DateTime? readAt;

  Notifikasi({
    required this.id,
    required this.title,
    required this.body,
    this.referenceId,
    required this.createdAt,
    this.readAt,
  });

  factory Notifikasi.fromJson(Map<String, dynamic> json) {
    return Notifikasi(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      referenceId: json['reference_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt:
          json['read_at'] != null
              ? DateTime.parse(json['read_at'] as String)
              : null,
    );
  }

  bool get isRead => readAt != null;
}
