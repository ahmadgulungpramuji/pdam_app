// services/chat_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdam_app/api_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService();

  /// (TIDAK BERUBAH) Untuk chat Pelanggan <-> Admin
  Future<String?> getOrCreateAdminChatThreadForPelanggan({
    required Map<String, dynamic> userData,
    required String apiToken,
  }) async {
    // 1. Memulai fungsi dan mencatat data awal.
    print('[ChatService] Memulai fungsi untuk pelanggan: ${userData['nama']}');

    // 2. Validasi data pengguna yang masuk.
    final userLaravelId = userData['id'] as int?;
    final cabangId = userData['id_cabang'] as int?;
    final userFirebaseUid = userData['firebase_uid'] as String?;
    final userName = userData['nama'] as String?;

    if (userLaravelId == null ||
        userFirebaseUid == null ||
        userName == null ||
        cabangId == null) {
      print('[ChatService] ERROR: Data pengguna tidak lengkap.');
      throw Exception('Gagal memulai chat: Data pengguna tidak lengkap.');
    }

    // 3. Menyiapkan ID unik untuk thread chat.
    const String userType = 'pelanggan';
    final threadId = 'cabang_${cabangId}_${userType}_$userLaravelId';
    final threadRef = _firestore.collection('chat_threads').doc(threadId);

    // 4. Membungkus seluruh operasi dalam try-catch.
    try {
      print('[ChatService] Mengecek keberadaan dokumen: $threadId');

      final doc = await threadRef.get().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('[ChatService] GAGAL: Operasi get() timeout.');
          throw Exception('Timeout: Gagal terhubung ke server Firestore.');
        },
      );

      // 5. Jika dokumen thread belum ada, maka buat baru.
      if (!doc.exists) {
        print(
            '[ChatService] Thread belum ada. Mengambil info admin dari API...');
        final adminInfoResponse =
            await _apiService.getBranchAdminInfo(apiToken);

        if (adminInfoResponse.statusCode != 200) {
          throw Exception(
              'Gagal mendapatkan data admin cabang. Status: ${adminInfoResponse.statusCode}');
        }

        final adminInfo = jsonDecode(adminInfoResponse.body)['data'];
        print(
            '[ChatService] Info admin diterima. Mempersiapkan daftar peserta...');

        // --- PERUBAHAN DARI MAP KE LIST ---
        List<String> participantUids = [userFirebaseUid];
        Map<String, dynamic> participantNames = {userFirebaseUid: userName};

        for (var admin in adminInfo) {
          if (admin['firebase_uid'] != null) {
            if (!participantUids.contains(admin['firebase_uid'])) {
              participantUids.add(admin['firebase_uid']);
            }
            participantNames[admin['firebase_uid']] = admin['nama'] ?? 'Admin';
          }
        }
        print(
            '[ChatService] Daftar Peserta (Uids) yang akan dibuat: $participantUids');
        // --- AKHIR PERUBAHAN ---

        print('[ChatService] Menulis data ke Firestore...');
        await threadRef.set({
          'threadInfo': {
            'title': 'Chat dengan $userName ($userType)',
            'initiatorId': userLaravelId,
            'initiatorType': userType,
            'cabangId': cabangId,
          },
          // --- GUNAKAN FIELD BARU ---
          'participantUids': participantUids,
          'participantNames': participantNames,
          // ---
          'lastMessage': 'Percakapan live dimulai.',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });
        print('[ChatService] Berhasil menulis ke Firestore.');
      } else {
        print('[ChatService] Thread sudah ada, tidak perlu membuat baru.');
      }

      print('[ChatService] Proses selesai. Mengembalikan threadId: $threadId');
      return threadId;
    } catch (e, s) {
      print('[ChatService] TERJADI KESALAHAN FATAL: $e');
      print('[ChatService] STACK TRACE: $s');
      rethrow;
    }
  }

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

    // ID unik untuk chat internal antara semua petugas dan admin di satu cabang
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

      // --- PERUBAHAN DARI MAP KE LIST ---
      List<String> participantUids = [petugasFirebaseUid];
      Map<String, dynamic> participantNames = {petugasFirebaseUid: petugasName};

      for (var admin in adminInfo) {
        if (admin['firebase_uid'] != null) {
          if (!participantUids.contains(admin['firebase_uid'])) {
            participantUids.add(admin['firebase_uid']);
          }
          participantNames[admin['firebase_uid']] = admin['nama'] ?? 'Admin';
        }
      }
      // --- AKHIR PERUBAHAN ---

      await threadRef.set({
        'threadInfo': {
          'title': 'Chat Internal Cabang $cabangId',
          'initiatorId': petugasId,
          'initiatorType':
              'petugas', // Bisa juga 'internal' jika ingin dibedakan
          'cabangId': cabangId,
        },
        // --- GUNAKAN FIELD BARU ---
        'participantUids': participantUids,
        'participantNames': participantNames,
        // ---
        'lastMessage': 'Percakapan internal dimulai.',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }

    return threadId;
  }

  /// Untuk Chat 1-on-1 Pelanggan <-> Petugas
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
      final currentUserName = currentUser['nama'];

      // --- AWAL LOGIKA BARU ---
      // 1. Buat List<String> untuk menyimpan semua UID peserta.
      // Dimulai dengan UID pengguna saat ini.
      List<String> participantUids = [currentUserUid];

      // (Opsional, tapi bagus untuk UI) Simpan nama peserta.
      Map<String, dynamic> participantNames = {currentUserUid: currentUserName};

      // 2. Loop melalui daftar pengguna lain (misalnya, petugas atau admin).
      for (var user in otherUsers) {
        final userUid = user['firebase_uid'] as String?;
        if (userUid != null && userUid.isNotEmpty) {
          // 3. Tambahkan UID mereka ke dalam List jika belum ada.
          if (!participantUids.contains(userUid)) {
            participantUids.add(userUid);
          }
          participantNames[userUid] = user['nama'];
        }
      }
      // --- AKHIR LOGIKA BARU ---

      await threadRef.set({
        'threadInfo': {
          'title': 'Chat Laporan #$idTugas',
          'idTugas': idTugas,
          'tipeTugas': tipeTugas,
          'cabangId': cabangId,
          'initiatorId': currentUser['id'],
          'initiatorType': 'pelanggan',
        },
        // ===============================================
        // == SIMPAN SEBAGAI ARRAY, BUKAN MAP ==
        // ===============================================
        'participantUids': participantUids,
        // ===============================================
        'participantNames': participantNames,
        'lastMessage': 'Chat mengenai laporan #$idTugas dimulai.',
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

  Stream<QuerySnapshot> getPetugasChatThreadsStream(String petugasFirebaseUid) {
    return _firestore
        .collection('chat_threads')
        // --- PERBAIKAN SINTAKS ---
        // Di Dart, query 'array-contains' ditulis sebagai 'arrayContains' (camelCase).
        .where('participantUids', arrayContains: petugasFirebaseUid)
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
