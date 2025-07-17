// services/chat_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdam_app/api_service.dart';

//________________________________________________________________
// BAGIAN 1: KELAS SERVICE UTAMA
//________________________________________________________________

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService();

  /// Fungsi untuk mendapatkan atau membuat thread chat dengan grup Admin.
  /// Logika di dalam method ini tidak diubah karena sudah sesuai.
  Future<String> getOrCreateAdminChatThread({
    required Map<String, dynamic> userData,
    required String apiToken,
  }) async {
    final userLaravelId = userData['id'] as int?;
    final cabangId = userData['id_cabang'] as int?;
    final userFirebaseUid = userData['firebase_uid'] as String?;
    final userName = userData['nama'] as String?;

    if (userLaravelId == null ||
        userFirebaseUid == null ||
        userName == null ||
        cabangId == null) {
      throw Exception('Gagal memulai chat: Data pengguna tidak lengkap.');
    }

    const String userType = 'pelanggan';
    final threadId = 'cabang_${cabangId}_${userType}_$userLaravelId';
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    final doc = await threadRef.get();

    if (!doc.exists) {
      final adminInfoResponse = await _apiService.getBranchAdminInfo(apiToken);

      if (adminInfoResponse.statusCode != 200) {
        throw Exception('Gagal mendapatkan data admin cabang.');
      }
      final adminInfo = jsonDecode(adminInfoResponse.body)['data'];

      Map<String, bool> participants = {userFirebaseUid: true};
      for (var admin in adminInfo) {
        if (admin['firebase_uid'] != null) {
          participants[admin['firebase_uid']] = true;
        }
      }

      await threadRef.set({
        'threadInfo': {
          'title': 'Chat dengan $userName ($userType)',
          'initiatorId': userLaravelId,
          'initiatorType': userType,
          'cabangId': cabangId,
        },
        'participants': participants,
        'lastMessage': 'Percakapan live dimulai.',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }

    return threadId;
  }

  // --- PEMBARUAN UTAMA DI SINI ---
  /// Fungsi untuk mengambil stream pesan dari sebuah thread.
  /// Sekarang mengembalikan Stream<List<Message>> untuk type safety.
  Stream<List<Message>> getMessages(String threadId) {
    return _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots() // Mendapatkan stream dari QuerySnapshot
        .map((snapshot) {
          // Mengubah stream QuerySnapshot menjadi List<Message>
          return snapshot.docs.map((doc) {
            // Menggunakan factory constructor untuk membuat objek Message
            return Message.fromFirestore(doc);
          }).toList();
        });
  }

  /// Fungsi untuk mengirim pesan ke sebuah thread.
  /// Logika di dalam method ini tidak diubah.
  Future<void> sendMessage(
    String threadId,
    String senderUid,
    String senderName,
    String text,
  ) async {
    if (text.trim().isEmpty) return;

    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    final messagesRef = threadRef.collection('messages');

    await messagesRef.add({
      'senderId': senderUid,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await threadRef.update({
      'lastMessage': text,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });
  }
}

//________________________________________________________________
// BAGIAN 2: MODEL DATA UNTUK PESAN
//________________________________________________________________

/// Model untuk merepresentasikan satu buah pesan dalam chat.
/// Penggunaan model ini membuat kode lebih bersih dan aman (type-safe).
class Message {
  final String senderId;
  final String senderName;
  final String text;
  final Timestamp timestamp;

  Message({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  /// Factory constructor untuk membuat instance `Message` dari
  /// sebuah dokumen Firestore.
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Message(
      senderId: data['senderId'] ?? 'unknown_id',
      senderName: data['senderName'] ?? 'Tanpa Nama',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
