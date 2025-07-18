// services/chat_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdam_app/api_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService();

  /// (TIDAK BERUBAH) Untuk chat Pelanggan <-> Admin
  Future<String> getOrCreateAdminChatThreadForPelanggan({
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

  /// Untuk chat Petugas <-> Admin
  Future<String> getOrCreateAdminChatThreadForPetugas({
    required Map<String, dynamic> petugasData,
  }) async {
    final petugasId = petugasData['id'] as int?;
    final cabangId = petugasData['id_cabang'] as int?;
    final petugasFirebaseUid = petugasData['firebase_uid'] as String?;
    final petugasName = petugasData['nama'] as String?;

    if (petugasId == null ||
        petugasFirebaseUid == null ||
        petugasName == null ||
        cabangId == null) {
      throw Exception('Gagal memulai chat: Data petugas tidak lengkap.');
    }

    final threadId = 'cabang_${cabangId}_internal_petugas';
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    final doc = await threadRef.get();

    if (!doc.exists) {
      final token = await _apiService.getToken();
      if (token == null) throw Exception("Sesi berakhir");

      final adminInfoResponse = await _apiService.getBranchAdminInfo(token);
      if (adminInfoResponse.statusCode != 200) {
        throw Exception('Gagal mendapatkan data admin cabang.');
      }
      final adminInfo = jsonDecode(adminInfoResponse.body)['data'];

      Map<String, bool> participants = {petugasFirebaseUid: true};
      for (var admin in adminInfo) {
        if (admin['firebase_uid'] != null) {
          participants[admin['firebase_uid']] = true;
        }
      }

      await threadRef.set({
        'threadInfo': {
          'title': 'Chat Internal Cabang $cabangId',
          'initiatorId': petugasId,
          'initiatorType': 'petugas',
          'cabangId': cabangId,
        },
        'participants': participants,
        'lastMessage': 'Percakapan internal dimulai.',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }

    return threadId;
  }

  /// Untuk Chat 1-on-1 Pelanggan <-> Petugas
  Future<String> getOrCreateTugasChatThread({
    required String tipeTugas, // 'pengaduan' atau 'temuan'
    required int idTugas,
    required Map<String, dynamic> currentUser, // bisa pelanggan atau petugas
    required Map<String, dynamic> otherUser, // bisa pelanggan atau petugas
  }) async {
    final threadId = '${tipeTugas}_$idTugas';
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    final doc = await threadRef.get();

    if (!doc.exists) {
      final currentUserUid = currentUser['firebase_uid'];
      final otherUserUid = otherUser['firebase_uid'];
      final currentUserName = currentUser['nama'];

      await threadRef.set({
        'threadInfo': {
          'title': 'Chat Tugas #$idTugas',
          'idTugas': idTugas,
          'tipeTugas': tipeTugas,
        },
        'participants': {currentUserUid: true, otherUserUid: true},
        'participantNames': {
          currentUserUid: currentUserName,
          otherUserUid: otherUser['nama'],
        },
        'lastMessage': 'Chat mengenai tugas #$idTugas dimulai.',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }
    return threadId;
  }

  Stream<List<Message>> getMessages(String threadId) {
    return _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Message.fromFirestore(doc);
          }).toList();
        });
  }

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

  // =========================================================================
  // == PASTIKAN METODE INI ADA DI DALAM FILE `chat_service.dart` ANDA ==
  // =========================================================================
  Stream<QuerySnapshot> getPetugasChatThreadsStream(String petugasFirebaseUid) {
    return _firestore
        .collection('chat_threads')
        .where('participants.$petugasFirebaseUid', isEqualTo: true)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }
}

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
