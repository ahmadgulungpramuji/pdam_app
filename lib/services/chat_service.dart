// lib/services/chat_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdam_app/api_service.dart';


class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService();

  String generateTugasThreadId({required String tipeTugas, required dynamic idTugas}) {
    return '${tipeTugas}_${idTugas.toString().trim()}';
  }

  // ==========================================================
  // 1. STREAM GLOBAL (HOME) - DENGAN SISTEM WHITELIST
  // ==========================================================
  Stream<int> getUnreadCountByPrefix(
    String currentUserUid, 
    String prefix, 
    {
      int? userLaravelId, 
      List<String>? allowedThreadIds // <--- FILTER BARU (WHITELIST)
    }
  ) {
    final String myUidClean = currentUserUid.toString().trim();

    return _firestore
        .collectionGroup('messages')
        .orderBy('timestamp', descending: true) 
        .limit(300) 
        .snapshots()
        .map((snapshot) {
      int count = 0;
      
      for (var doc in snapshot.docs) {
        final threadRef = doc.reference.parent.parent;
        if (threadRef != null && threadRef.id.startsWith(prefix)) {
          final String threadId = threadRef.id;

          // --- LOGIKA FILTER BARU (PENCEGAH LEAK) ---

          // A. Filter untuk Chat Admin (cabang_)
          // Pastikan ID thread mengandung ID saya
          if (prefix == 'cabang_' && userLaravelId != null) {
             if (!threadId.contains('_pelanggan_$userLaravelId')) {
               continue; // Skip punya orang lain
             }
          }

          // B. Filter untuk Pengaduan (pengaduan_)
          // Pastikan ID thread ada di daftar laporan saya
          if (prefix == 'pengaduan_' && allowedThreadIds != null) {
            if (!allowedThreadIds.contains(threadId)) {
              continue; // Skip pengaduan orang lain
            }
          }

          // ------------------------------------------

          final data = doc.data();
          final String senderIdClean = (data['senderId'] ?? '').toString().trim();
          final List<dynamic> rawReadBy = data['read_by'] ?? [];
          final List<String> readByClean = rawReadBy.map((e) => e.toString().trim()).toList();

          // Hitung jika: Bukan saya & Belum baca
          if (senderIdClean != myUidClean && !readByClean.contains(myUidClean)) {
            count++;
          }
        }
      }
      return count;
    }).handleError((e) => 0);
  }

  // ==========================================================
  // 2. STREAM PER ITEM (DETAIL)
  // ==========================================================
  Stream<int> getUnreadMessageCount(String threadId, String currentUserUid) {
    final String myUidClean = currentUserUid.toString().trim();

    return _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100) 
        .snapshots()
        .map((snapshot) {
      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String senderIdClean = (data['senderId'] ?? '').toString().trim();
        final List<dynamic> rawReadBy = data['read_by'] ?? [];
        final List<String> readByClean = rawReadBy.map((e) => e.toString().trim()).toList();

        if (senderIdClean != myUidClean && !readByClean.contains(myUidClean)) {
          unreadCount++;
        }
      }
      return unreadCount;
    }).handleError((e) => 0);
  }

  // 3. MARK AS READ
  Future<void> markMessagesAsRead(String threadId, String currentUserUid) async {
    if (currentUserUid.isEmpty) return;
    final String myUidClean = currentUserUid.toString().trim();

    try {
      final querySnapshot = await _firestore
          .collection('chat_threads')
          .doc(threadId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(100) 
          .get();

      final batch = _firestore.batch();
      bool needsCommit = false;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final String senderIdClean = (data['senderId'] ?? '').toString().trim();
        final List<dynamic> rawReadBy = data['read_by'] ?? [];
        final List<String> readByClean = rawReadBy.map((e) => e.toString().trim()).toList();

        if (senderIdClean != myUidClean && !readByClean.contains(myUidClean)) {
          batch.update(doc.reference, {
            'read_by': FieldValue.arrayUnion([myUidClean])
          });
          needsCommit = true;
        }
      }

      if (needsCommit) {
        await batch.commit();
      }
    } catch (e) {
      print("Error mark read: $e");
    }
  }

  // Standard Methods
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
    final String myUidClean = senderUid.toString().trim();
    
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    
    await threadRef.collection('messages').add({
      'senderId': myUidClean,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'read_by': [myUidClean], 
    });

    await threadRef.update({
      'lastMessage': text,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });
  }
 
  Future<String> getOrCreateTugasChatThread({
    required String tipeTugas,
    required int idTugas,
    required Map<String, dynamic> currentUser,
    required List<dynamic> otherUsers,
    required int cabangId,
  }) async {
    final threadId = generateTugasThreadId(tipeTugas: tipeTugas, idTugas: idTugas);
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    
    final currentUserUid = currentUser['firebase_uid'].toString().trim();

    // Variable untuk menyimpan snapshot jika berhasil dibaca
    DocumentSnapshot? doc;
    bool isReadSuccessful = false;

    // [LANGKAH 1] Coba BACA dokumen
    try {
      doc = await threadRef.get();
      isReadSuccessful = true;
    } catch (e) {
      // Jika Permission Denied, kemungkinan besar dokumen SUDAH ADA 
      // tapi kita (Anggota Tim) belum terdaftar sebagai peserta.
      // Kita abaikan error ini dan lanjut ke langkah "Force Join".
      print("Gagal membaca thread (kemungkinan permission denied): $e");
    }

    // [LANGKAH 2] Logika Percabangan
    // Jika berhasil dibaca DAN dokumen belum ada => BUAT BARU
    if (isReadSuccessful && (doc == null || !doc.exists)) {
      
      // --- LOGIKA PEMBUATAN CHAT BARU ---
      List<String> participantUids = [currentUserUid];
      Map<String, dynamic> participantNames = {currentUserUid: currentUser['nama']};

      for (var user in otherUsers) {
        final uid = user['firebase_uid']?.toString().trim();
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
          'initiatorType': 'petugas', // Diubah generic jadi petugas jika yg mulai petugas
        },
        'participantUids': participantUids,
        'participantNames': participantNames,
        'lastMessage': 'Chat dimulai.',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

    } else {
      // [LANGKAH 3] FORCE JOIN (Untuk Anggota Tim)
      // Masuk ke sini jika:
      // A. Dokumen ada (Read success, exists = true)
      // B. ATAU Read gagal (Permission denied) -> Kita asumsikan dokumen ada.
      
      // Gunakan set dengan SetOptions(merge: true) agar lebih kuat menembus permission 
      // dibanding .update() biasa jika rules-nya memperbolehkan create/write.
      
      await threadRef.set({
        'participantUids': FieldValue.arrayUnion([currentUserUid])
      }, SetOptions(merge: true));
    }

    return threadId;
  }
  
  Future<String?> getOrCreateAdminChatThreadForPelanggan({
    required Map<String, dynamic> userData,
    required String apiToken,
  }) async {
      final userLaravelId = userData['id'] as int?;
      final cabangId = userData['id_cabang'] as int?;
      final userFirebaseUid = userData['firebase_uid']?.toString().trim();
      final userName = userData['nama'] as String?;

      if (userLaravelId == null || userFirebaseUid == null || userName == null || cabangId == null) throw Exception('Data tidak lengkap.');

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
                   final adminUid = admin['firebase_uid'].toString().trim();
                   uids.add(adminUid);
                   names[adminUid] = admin['nama'] ?? 'Admin';
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
      .where('participantUids', arrayContains: uid.toString().trim())
      .orderBy('lastMessageTimestamp', descending: true)
      .snapshots();
  }

  Future<String> getOrCreateAdminChatThreadForSpecificReport({
    required Map<String, dynamic> userData,
    required String apiToken,
    required int idLaporan, // ID Pengaduan
  }) async {
    final userLaravelId = userData['id'] as int?;
    final cabangId = userData['id_cabang'] as int?;
    final userFirebaseUid = userData['firebase_uid']?.toString().trim();
    final userName = userData['nama'] as String?;

    if (userLaravelId == null || userFirebaseUid == null || userName == null || cabangId == null) {
      throw Exception('Data user tidak lengkap.');
    }

    // 1. FORMAT ID BARU (Agar terpisah dari chat umum)
    // Format: cabang_{idCabang}_pelanggan_{idUser}_pengaduan_{idLaporan}
    final threadId = 'cabang_${cabangId}_pelanggan_${userLaravelId}_pengaduan_$idLaporan';
    
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    final doc = await threadRef.get();

    // 2. CEK & BUAT DOKUMEN (Agar tidak Permission Denied)
    if (!doc.exists) {
      // Ambil daftar admin cabang dari API agar mereka bisa reply
      final adminInfoResponse = await _apiService.getBranchAdminInfo(apiToken);
      
      List<String> uids = [userFirebaseUid];
      Map<String, dynamic> names = {userFirebaseUid: userName};

      if (adminInfoResponse.statusCode == 200) {
        final adminData = jsonDecode(adminInfoResponse.body)['data'];
        for (var admin in adminData) {
          if (admin['firebase_uid'] != null) {
            final adminUid = admin['firebase_uid'].toString().trim();
            uids.add(adminUid);
            names[adminUid] = admin['nama'] ?? 'Admin';
          }
        }
      }

      // Buat Thread Baru
      await threadRef.set({
        'threadInfo': {
          'title': 'Chat Pengaduan #$idLaporan',
          'initiatorId': userLaravelId,
          'initiatorType': 'pelanggan',
          'cabangId': cabangId,
          'tipeTugas': 'pengaduan_admin', // Penanda khusus untuk Admin PHP (opsional)
          'idTugas': idLaporan,
        },
        'participantUids': uids,
        'participantNames': names,
        'lastMessage': 'Mulai diskusi laporan #$idLaporan',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'adminLastSeenAt': null,
      });
    } else {
      // (Opsional) Jika thread sudah ada, pastikan UID user saat ini tetap terdaftar
      // jaga-jaga jika ganti akun firebase tapi ID pelanggan sama
      final data = doc.data();
      final List currentUsers = data?['participantUids'] ?? [];
      if (!currentUsers.contains(userFirebaseUid)) {
         await threadRef.update({
          'participantUids': FieldValue.arrayUnion([userFirebaseUid])
        });
      }
    }
    
    return threadId;
  }
  
  Future<String> getOrCreateAdminChatThreadForPetugas({required Map<String, dynamic> petugasData}) async {
    // 1. Ambil data yang diperlukan
    final int cabangId = petugasData['id_cabang'];
    final int petugasId = petugasData['id']; // ID SQL Petugas
    final String myUid = petugasData['firebase_uid'].toString().trim();
    final String myName = petugasData['nama'];

    // 2. Gunakan format ID yang SAMA dengan Admin PHP (AdminChat.php)
    // Format: cabang_{cabangId}_petugas_{petugasId}
    final threadId = 'cabang_${cabangId}_petugas_$petugasId';

    final docRef = _firestore.collection('chat_threads').doc(threadId);
    final docSnap = await docRef.get();

    // 3. Cek apakah dokumen thread sudah ada
    if (!docSnap.exists) {
      // Jika belum ada, BUAT dokumennya agar Rules tidak error.
      // Kita masukkan UID kita sendiri ke participantUids agar isParentThreadParticipant() bernilai TRUE.
      await docRef.set({
        'threadInfo': {
          'title': 'Chat Internal Petugas',
          'initiatorId': petugasId,
          'initiatorType': 'petugas', // Sesuai PHP
          'cabangId': cabangId,
        },
        'participantUids': [myUid], // PENTING: Masukkan UID sendiri
        'participantNames': {myUid: myName},
        'lastMessage': 'Mulai percakapan internal',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'adminLastSeenAt': null, // Field tambahan admin
      });
    } else {
      // Jika sudah ada, pastikan UID kita terdaftar (jaga-jaga jika admin yang buat tapi UID belum masuk)
      final data = docSnap.data();
      final List users = data?['participantUids'] ?? [];
      if (!users.contains(myUid)) {
        await docRef.update({
          'participantUids': FieldValue.arrayUnion([myUid])
        });
      }
    }

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
      senderId: (data['senderId'] ?? '').toString().trim(),
      senderName: data['senderName'] ?? 'Anonim',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      readBy: (data['read_by'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .toList(),
    );
  }
}