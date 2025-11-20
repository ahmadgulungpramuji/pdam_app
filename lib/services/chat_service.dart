// lib/services/chat_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdam_app/api_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService();

  // ==========================================================
  // 1. STREAM BADGE (VERSI MANUAL FILTER - LEBIH STABIL)
  // ==========================================================
  
  // Digunakan di Lacak Laporan Saya (Per-Item) dan Hubungi Kami
  Stream<int> getUnreadMessageCount(String threadId, String currentUserUid) {
    return _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: true) // Ambil yang terbaru
        .limit(50) // Batasi 50 pesan terakhir untuk efisiensi
        .snapshots()
        .map((snapshot) {
      
      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String senderId = data['senderId'] ?? '';
        final List<dynamic> readBy = data['read_by'] ?? [];

        // LOGIKA MANUAL (Sama persis dengan markAsRead)
        // Jika pengirim BUKAN saya, DAN saya BELUM baca
        if (senderId != currentUserUid && !readBy.contains(currentUserUid)) {
          unreadCount++;
        }
      }
      return unreadCount;
    }).handleError((e) {
      print("Error stream unread: $e");
      return 0;
    });
  }

  // Stream Global (Untuk Beranda - Total Titik Merah)
  Stream<int> getUnreadCountByPrefix(String currentUserUid, String prefix) {
    return _firestore
        .collectionGroup('messages')
        // Hapus whereNotIn di sini juga agar konsisten, tapi collectionGroup 
        // wajib pakai limit agar tidak boros biaya.
        .orderBy('timestamp', descending: true) 
        .limit(100)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final threadRef = doc.reference.parent.parent;
        // Cek Thread Prefix
        if (threadRef != null && threadRef.id.startsWith(prefix)) {
          final data = doc.data();
          final String senderId = data['senderId'] ?? '';
          final List<dynamic> readBy = data['read_by'] ?? [];

          // Filter Manual
          if (senderId != currentUserUid && !readBy.contains(currentUserUid)) {
            count++;
          }
        }
      }
      return count;
    }).handleError((e) {
      // Silent error jika permission/index bermasalah di awal
      return 0; 
    });
  }

  // ==========================================================
  // 2. FUNGSI TANDAI BACA
  // ==========================================================
  Future<void> markMessagesAsRead(String threadId, String currentUserUid) async {
    try {
      final querySnapshot = await _firestore
          .collection('chat_threads')
          .doc(threadId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final batch = _firestore.batch();
      bool needsCommit = false;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final String senderId = data['senderId'] ?? '';
        final List<dynamic> readBy = data['read_by'] ?? [];

        // Syarat: Pesan orang lain & Saya belum baca
        if (senderId != currentUserUid && !readBy.contains(currentUserUid)) {
          batch.update(doc.reference, {
            'read_by': FieldValue.arrayUnion([currentUserUid])
          });
          needsCommit = true;
        }
      }

      if (needsCommit) {
        await batch.commit();
        print(">>> [ChatService] Berhasil update status baca: $threadId");
      }
    } catch (e) {
      print(">>> [ChatService] Gagal mark read: $e");
    }
  }

  // ==========================================================
  // 3. FUNGSI MESSAGING STANDARD (TIDAK BERUBAH)
  // ==========================================================
  
  Stream<List<Message>> getMessages(String threadId) {
    return _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  Future<void> sendMessage(String threadId, String senderUid, String senderName, String text) async {
    if (text.trim().isEmpty) return;
    
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    
    await threadRef.collection('messages').add({
      'senderId': senderUid,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'read_by': [senderUid], 
    });

    await threadRef.update({
      'lastMessage': text,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });
  }

  // Helper Generators
  String generateTugasThreadId({required String tipeTugas, required int idTugas}) {
    return '${tipeTugas}_$idTugas';
  }
  
  // --- FUNGSI CREATE THREAD (Existing) ---
  Future<String> getOrCreateTugasChatThread({
    required String tipeTugas,
    required int idTugas,
    required Map<String, dynamic> currentUser,
    required List<dynamic> otherUsers,
    required int cabangId,
  }) async {
    final threadId = '${tipeTugas}_$idTugas';
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    final doc = await threadRef.get();

    if (!doc.exists) {
      final currentUserUid = currentUser['firebase_uid'];
      List<String> participantUids = [currentUserUid];
      Map<String, dynamic> participantNames = {currentUserUid: currentUser['nama']};

      for (var user in otherUsers) {
        final uid = user['firebase_uid'];
        if (uid != null) {
          participantUids.add(uid);
          participantNames[uid] = user['nama'];
        }
      }

      await threadRef.set({
        'threadInfo': {
          'title': 'Chat Laporan #$idTugas',
          'idTugas': idTugas,
          'tipeTugas': tipeTugas,
          'cabangId': cabangId,
          'initiatorId': currentUser['id'],
          'initiatorType': 'pelanggan',
        },
        'participantUids': participantUids,
        'participantNames': participantNames,
        'lastMessage': 'Chat dimulai.',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }
    return threadId;
  }
  
  Future<String?> getOrCreateAdminChatThreadForPelanggan({
    required Map<String, dynamic> userData,
    required String apiToken,
  }) async {
      final userLaravelId = userData['id'] as int?;
      final cabangId = userData['id_cabang'] as int?;
      final userFirebaseUid = userData['firebase_uid'] as String?;
      final userName = userData['nama'] as String?;

      if (userLaravelId == null || userFirebaseUid == null || userName == null || cabangId == null) {
        throw Exception('Data tidak lengkap.');
      }

      const String userType = 'pelanggan';
      final threadId = 'cabang_${cabangId}_${userType}_$userLaravelId';
      final threadRef = _firestore.collection('chat_threads').doc(threadId);
      final doc = await threadRef.get();

      if (!doc.exists) {
          final adminInfoResponse = await _apiService.getBranchAdminInfo(apiToken);
          if (adminInfoResponse.statusCode == 200) {
             final adminInfo = jsonDecode(adminInfoResponse.body)['data'];
             List<String> uids = [userFirebaseUid];
             Map<String, dynamic> names = {userFirebaseUid: userName};
             for (var admin in adminInfo) {
                if (admin['firebase_uid'] != null) {
                   uids.add(admin['firebase_uid']);
                   names[admin['firebase_uid']] = admin['nama'] ?? 'Admin';
                }
             }
             await threadRef.set({
                'threadInfo': {'title': 'Chat Admin', 'initiatorId': userLaravelId, 'initiatorType': userType, 'cabangId': cabangId},
                'participantUids': uids,
                'participantNames': names,
                'lastMessage': 'Mulai Chat',
                'lastMessageTimestamp': FieldValue.serverTimestamp(),
             });
          }
      }
      return threadId;
  }
  
  Stream<QuerySnapshot> getPetugasChatThreadsStream(String uid) {
    return _firestore.collection('chat_threads')
      .where('participantUids', arrayContains: uid)
      .orderBy('lastMessageTimestamp', descending: true)
      .snapshots();
  }
  
  Future<String> getOrCreateAdminChatThreadForPetugas({required Map<String, dynamic> petugasData}) async {
      final cabangId = petugasData['id_cabang'];
      final threadId = 'cabang_${cabangId}_internal_petugas';
      return threadId;
  }
}

class Message {
  final String senderId;
  final String senderName;
  final String text;
  final Timestamp timestamp;
  final List<String> readBy;

  Message({required this.senderId, required this.senderName, required this.text, required this.timestamp, required this.readBy});

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Message(
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Anonim',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      readBy: List<String>.from(data['read_by'] ?? []),
    );
  }
}