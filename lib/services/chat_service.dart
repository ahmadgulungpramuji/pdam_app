// services/chat_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdam_app/api_service.dart'; // Kita butuh ini untuk memanggil ApiService

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService(); // Instance dari ApiService

  // Fungsi untuk mendapatkan atau membuat thread chat dengan grup Admin
  // Fungsi untuk mendapatkan atau membuat thread chat dengan grup Admin
  Future<String> getOrCreateAdminChatThread({
    required Map<String, dynamic> userData,
    required String apiToken,
  }) async {
    // --- BLOK VALIDASI DENGAN PERBAIKAN ---
    // Pastikan semua ID diambil sebagai Angka (int)
    final userLaravelId = userData['id'] as int?;
    final cabangId = userData['id_cabang'] as int?;

    final userFirebaseUid = userData['firebase_uid'] as String?;
    final userName = userData['nama'] as String?;

    // Jika salah satu data penting tidak ada, lempar error yang jelas.
    if (userLaravelId == null ||
        userFirebaseUid == null ||
        userName == null ||
        cabangId == null) {
      throw Exception(
        'Gagal memulai chat: Data pengguna tidak lengkap. Pastikan firebase_uid, nama, dan id_cabang ada.',
      );
    }
    // --- AKHIR BLOK VALIDASI ---

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

      // Tulis data ke Firestore dengan tipe data yang benar
      await threadRef.set({
        'threadInfo': {
          'title': 'Chat dengan $userName ($userType)',
          'initiatorId': userLaravelId, // Sekarang menjadi number
          'initiatorType': userType,
          'cabangId': cabangId, // Sekarang menjadi number
        },
        'participants': participants,
        'lastMessage': 'Percakapan live dimulai.',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }

    return threadId;
  }

  // Fungsi untuk mengambil stream pesan dari sebuah thread
  Stream<QuerySnapshot> getMessages(String threadId) {
    return _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Fungsi untuk mengirim pesan ke sebuah thread
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
