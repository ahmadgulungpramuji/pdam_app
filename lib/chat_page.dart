// lib/chat_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/pengaduan_model.dart';
import 'package:pdam_app/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ChatPage({super.key, required this.userData});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _chatController = TextEditingController();
  final ApiService _apiService = ApiService();
  final ChatService _chatService = ChatService();

  final List<Map<String, dynamic>> _botMessages = [
    {
      "sender": "bot",
      "text":
          "Selamat datang di PDAM Bot! Ada yang bisa saya bantu? Anda bisa bertanya cara lapor atau status laporan Anda.",
    },
  ];
  String? _liveChatThreadId;
  bool _isLiveChatActive = false;
  bool _isLoading = false;

  // --- TAMBAHAN BARU ---
  Stream<int>? _unreadAdminChatCountStream;
  late String _adminThreadId;

  @override
  void initState() {
    super.initState();
    // Secara proaktif mendengarkan unread count dari thread admin
    _initializeAdminChatStream();
  }

  void _initializeAdminChatStream() {
    try {
      // Kita susun ID thread admin yang BISA DIPREDIKSI
      // berdasarkan logika di chat_service.dart
      final int cabangId = widget.userData['id_cabang'];
      final int laravelId = widget.userData['id'];
      _adminThreadId = 'cabang_${cabangId}_pelanggan_$laravelId';

      setState(() {
        _unreadAdminChatCountStream = _chatService.getUnreadMessageCount(
          _adminThreadId,
          widget.userData['firebase_uid'],
        );
      });
    } catch (e) {
      print("Gagal inisialisasi stream admin: $e");
      // Gagal secara diam-diam, tidak menghentikan UI
    }
  }
  // --- AKHIR TAMBAHAN ---

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();

    if (_isLiveChatActive) {
      _chatService.sendMessage(
        _liveChatThreadId!,
        widget.userData['firebase_uid'],
        widget.userData['nama'],
        text,
      );
    } else {
      // --- MODIFIKASI ---
      // Tambahkan pesan pengguna ke UI sebelum dikirim ke bot
      setState(() {
        _botMessages.insert(0, {"sender": "user", "text": text});
      });
      _sendMessageToBot(text);
    }
  }

  void _sendMessageToBot(String text) {
    setState(() {
      _isLoading = true;
    });

    _apiService.sendMessage(text).then((witResponse) {
      // --- MODIFIKASI --- Memanggil handler Wit.ai yang sudah diperbarui
      _handleWitAiResponse(witResponse);
    }).catchError((e) {
      _addBotMessage(
          "Terjadi kesalahan saat menghubungi bot. Silakan coba lagi nanti.");
    }).whenComplete(() => setState(() => _isLoading = false));
  }

  // --- BARU --- Fungsi helper untuk menambahkan pesan dari bot ke UI
  void _addBotMessage(String text) {
    setState(() {
      _botMessages.insert(0, {"sender": "bot", "text": text});
    });
  }

  // --- MODIFIKASI TOTAL ---
  // Ini adalah logika utama yang telah dikembangkan untuk menangani respon dari Wit.ai
  void _handleWitAiResponse(Map<String, dynamic>? response) {
    // Penanganan jika response tidak valid atau intent tidak terdeteksi
    if (response == null ||
        response.containsKey("error") ||
        response['intents'] == null ||
        (response['intents'] as List).isEmpty) {
      _addBotMessage(
          "Maaf, saya tidak mengerti. Anda bisa coba 'cek laporan 1234' atau 'bagaimana cara lapor?'.");
      return;
    }

    final intent = (response['intents'] as List).first['name'];
    final confidence = (response['intents'] as List).first['confidence'];

    // Abaikan jika confidence (tingkat kepercayaan) bot terlalu rendah
    if (confidence < 0.8) {
      _addBotMessage(
          "Saya kurang yakin dengan maksud Anda. Bisa coba gunakan kalimat yang lebih spesifik?");
      return;
    }

    // Logika berdasarkan intent yang terdeteksi
    switch (intent) {
      case 'sapaan':
        _addBotMessage("Halo! Ada yang bisa saya bantu terkait layanan PDAM?");
        break;

      case 'terima_kasih':
        _addBotMessage("Sama-sama! Senang bisa membantu Anda.");
        break;

      case 'tanya_cara_lapor':
        _addBotMessage(
            "Anda dapat membuat laporan pengaduan melalui tombol 'Buat Laporan' di halaman utama aplikasi. Pastikan Anda menyiapkan detail keluhan dan foto bukti jika diperlukan.");
        break;

      case 'lacak_laporan':
        final entities = response['entities'] as Map<String, dynamic>?;
        // Mencari entity 'nomor_laporan' yang sudah kita latih di Wit.ai
        final nomorLaporanEntity =
            entities?['nomor_laporan:nomor_laporan'] as List?;
        if (nomorLaporanEntity != null && nomorLaporanEntity.isNotEmpty) {
          final nomorLaporan = nomorLaporanEntity.first['value'].toString();
          // Memanggil fungsi untuk mengambil detail dari API
          _fetchAndDisplayReportStatus(nomorLaporan);
        } else {
          _addBotMessage(
              "Tentu, mohon sebutkan nomor laporan yang ingin Anda lacak.");
        }
        break;

      case 'minta_bantuan_admin':
        _addBotMessage(
            "Baik, saya akan segera menghubungkan Anda dengan Admin kami.");
        Future.delayed(const Duration(milliseconds: 500), _switchToLiveChat);
        break;

      default:
        _addBotMessage(
            "Maaf, saya belum dapat memahami itu. Anda bisa bertanya tentang cara membuat laporan atau melacak status laporan Anda.");
        break;
    }
  }

  // --- BARU --- Fungsi untuk mengambil status laporan dari API dan menampilkannya
  Future<void> _fetchAndDisplayReportStatus(String nomorLaporan) async {
    setState(() => _isLoading = true);
    _addBotMessage("Baik, sedang saya periksa laporan nomor $nomorLaporan...");

    try {
      // Pastikan fungsi getDetailLaporan sudah ada di api_service.dart
      final Pengaduan laporan =
          await _apiService.getDetailLaporan(nomorLaporan);

      String statusText = "Status laporan Anda: **${laporan.friendlyStatus}**.";

      // Memberikan konteks tambahan berdasarkan status
      if (laporan.status == 'menunggu_pelanggan') {
        statusText +=
            "\n\nTim kami membutuhkan konfirmasi dari Anda. Silakan periksa detailnya di halaman 'Lacak Laporan Saya' untuk memberikan respon.";
      } else if (laporan.status == 'selesai') {
        statusText +=
            "\n\nTerima kasih atas kesabaran Anda. Jangan lupa berikan rating pelayanan kami di halaman 'Lacak Laporan Saya'.";
      } else if (laporan.status == 'ditolak') {
        statusText +=
            "\n\nMohon maaf, laporan Anda belum dapat kami proses. Silakan cek detail alasan penolakan di halaman 'Lacak Laporan Saya'.";
      }

      _addBotMessage(statusText);
    } catch (e) {
      _addBotMessage(
          "Maaf, laporan dengan nomor '$nomorLaporan' tidak ditemukan atau terjadi kesalahan. Mohon periksa kembali nomor Anda.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // (FUNGSI TIDAK BERUBAH)
  Future<void> reauthenticateWithFirebase() async {
    try {
      // Anda perlu membuat fungsi ini di ApiService yang mengembalikan custom token dari server Anda
      final String? customToken = await _apiService.getFirebaseCustomToken();

      if (customToken != null) {
        await FirebaseAuth.instance.signInWithCustomToken(customToken);
        print('Re-authentication to Firebase successful!');
      } else {
        throw Exception('Failed to get custom token from server.');
      }
    } catch (e) {
      print('Error re-authenticating with Firebase: $e');
      rethrow;
    }
  }

  // --- MODIFIKASI TOTAL ---
  // Fungsi ini sekarang beralih secara instan menggunakan ID yang sudah ada,
  // dan tidak lagi memanggil getOrCreate...
  Future<void> _switchToLiveChat() async {
    setState(() => _isLoading = true);
    try {
      // --- MODIFIKASI ---
      // Kita sekarang menggunakan _adminThreadId yang sudah ada
      // Ini membuat perpindahan ke live chat menjadi instan
      final threadId = _adminThreadId;
      // --- AKHIR MODIFIKASI ---

      setState(() {
        _isLiveChatActive = true;
        _liveChatThreadId = threadId;
      });

      // --- TAMBAHAN LOGIS ---
      // Saat kita beralih, tandai semua pesan sebagai terbaca
      // agar badge unread-nya hilang.
      _chatService.markMessagesAsRead(
        threadId,
        widget.userData['firebase_uid'],
      );

      // Kita juga *tetap* memanggil getOrCreate... di background
      // untuk memastikan dokumennya ada, kalau-kalau ini adalah
      // pertama kalinya user chat.
      try {
        await reauthenticateWithFirebase();
        final token = await _apiService.getToken();
        if (token != null) {
          await _chatService.getOrCreateAdminChatThreadForPelanggan(
            userData: widget.userData,
            apiToken: token,
          );
        }
      } catch (bgError) {
        // Gagal secara diam-diam, user sudah di dalam chat
        print("Gagal memastikan thread di background: $bgError");
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal terhubung ke live chat: $e')),
      );
      // Rollback jika gagal
      setState(() {
        _isLiveChatActive = false;
        _liveChatThreadId = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- AKHIR MODIFIKASI ---

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLiveChatActive ? 'Live Chat dengan Admin' : 'Chat dengan PDAM Bot',
        ),
        foregroundColor: Colors.white,
        backgroundColor: primaryColor,
        actions: [
          if (!_isLiveChatActive)
            // --- MODIFIKASI DI SINI ---
            StreamBuilder<int>(
              stream: _unreadAdminChatCountStream,
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;

                return Badge(
                  // Widget Badge
                  label: Text(unreadCount.toString()),
                  isLabelVisible: unreadCount > 0,
                  child: TextButton.icon(
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Bicara dengan Admin'),
                    onPressed: _isLoading ? null : _switchToLiveChat,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                );
              },
            ),
          // --- AKHIR MODIFIKASI ---
        ],
      ),
      body: Column(
        children: [
          if (_isLiveChatActive && _liveChatThreadId != null)
            _buildLiveChatView()
          else
            _buildBotChatView(),
          if (_isLoading) const LinearProgressIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildLiveChatView() {
    return Expanded(
      child: StreamBuilder<List<Message>>(
        stream: _chatService.getMessages(_liveChatThreadId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error memuat pesan.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final messages = snapshot.data ?? [];
          if (messages.isEmpty) {
            return const Center(
              child: Text('Kirim pesan pertama Anda ke admin!'),
            );
          }
          return ListView.builder(
            reverse: true,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isMe = msg.senderId == widget.userData['firebase_uid'];
              return _buildMessageBubble(
                text: msg.text,
                sender: msg.senderName,
                isMe: isMe,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBotChatView() {
    return Expanded(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.all(8.0),
        itemCount: _botMessages.length,
        itemBuilder: (context, index) {
          final msg = _botMessages[index];
          final isMe = msg['sender'] == 'user';
          return _buildMessageBubble(
            text: msg['text'],
            sender: isMe ? "Anda" : "PDAM Bot",
            isMe: isMe,
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required String sender,
    required bool isMe,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColorLight : Colors.grey[200],
          borderRadius: BorderRadius.circular(15.0).copyWith(
            bottomLeft: isMe ? const Radius.circular(15.0) : Radius.zero,
            bottomRight: !isMe ? const Radius.circular(15.0) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              sender,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            // TODO: Pertimbangkan untuk menggunakan widget
            // yang dapat mem-parsing Markdown jika 'text' mengandung **tebal**.
            Text(text, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Ketik pesan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
            onPressed: _isLoading ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}