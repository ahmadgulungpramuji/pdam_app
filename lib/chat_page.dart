// lib/chat_page.dart
// ignore_for_file: use_build_context_synchronously

// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/services/chat_service.dart'; // <-- Gunakan service baru kita

class ChatPage extends StatefulWidget {
  // Menerima data pengguna dari halaman sebelumnya
  final Map<String, dynamic> userData;

  const ChatPage({super.key, required this.userData});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // --- Services & Controllers ---
  final TextEditingController _chatController = TextEditingController();
  final ApiService _apiService = ApiService(); // Untuk Wit.ai & token
  final ChatService _chatService = ChatService(); // Untuk Live Chat Firestore

  // --- State Management ---
  final List<Map<String, dynamic>> _botMessages = [
    {
      "sender": "bot",
      "text":
          "Selamat datang! Ketik pertanyaan Anda atau tekan tombol 'Bicara dengan Admin' untuk bantuan langsung.",
    },
  ];
  String? _liveChatThreadId; // Untuk menyimpan ID thread live chat
  bool _isLiveChatActive = false;
  bool _isLoading = false;

  // --- Logic ---
  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();

    if (_isLiveChatActive) {
      // Jika mode live chat aktif, kirim pesan ke Firestore
      _chatService.sendMessage(
        _liveChatThreadId!,
        widget.userData['firebase_uid'],
        widget.userData['nama'],
        text,
      );
    } else {
      // Jika masih mode bot, kirim ke Wit.ai
      _sendMessageToBot(text);
    }
  }

  void _sendMessageToBot(String text) {
    setState(() {
      _botMessages.insert(0, {"sender": "user", "text": text});
      _isLoading = true;
    });

    _apiService
        .sendMessage(text)
        .then((witResponse) {
          _handleWitAiResponse(witResponse);
        })
        .whenComplete(() => setState(() => _isLoading = false));
  }

  void _handleWitAiResponse(Map<String, dynamic>? response) {
    String botReply =
        "Maaf, saya tidak mengerti. Coba tanyakan hal lain atau hubungi admin.";
    // (Anda bisa masukkan kembali logika Wit.ai Anda yang lama di sini jika perlu)
    // Untuk sekarang, kita buat simpel.
    if (response != null && !response.containsKey("error")) {
      // Logika sederhana berdasarkan response
      botReply =
          "Ini adalah respons dari Bot. Jika butuh bantuan lebih lanjut, silakan hubungi admin.";
    }
    setState(() {
      _botMessages.insert(0, {"sender": "bot", "text": botReply});
    });
  }

  Future<void> _switchToLiveChat() async {
    setState(() => _isLoading = true);
    try {
      print('Memulai Live Chat dengan userData: ${widget.userData}');

      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception("Sesi berakhir. Silakan login kembali.");
      }

      final threadId = await _chatService.getOrCreateAdminChatThread(
        userData: widget.userData,
        apiToken: token,
      );

      setState(() {
        _isLiveChatActive = true;
        _liveChatThreadId = threadId;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal terhubung ke live chat: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Widgets ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLiveChatActive ? 'Live Chat dengan Admin' : 'Chat dengan PDAM Bot',
        ),
        actions: [
          if (!_isLiveChatActive)
            TextButton.icon(
              icon: const Icon(Icons.support_agent, color: Colors.white),
              label: const Text(
                'Bicara dengan Admin',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _isLoading ? null : _switchToLiveChat,
            ),
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

  // Di dalam file chat_page.dart

  Widget _buildLiveChatView() {
    return Expanded(
      // 1. Ubah tipe data StreamBuilder
      child: StreamBuilder<List<Message>>(
        // <-- DARI QuerySnapshot MENJADI List<Message>
        // 2. Gunakan method getMessages yang sudah diperbarui
        stream: _chatService.getMessages(_liveChatThreadId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error memuat pesan.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // 3. 'snapshot.data' sekarang adalah List<Message>, bukan QuerySnapshot
          final messages = snapshot.data ?? []; // <-- JAUH LEBIH SEDERHANA
          if (messages.isEmpty) {
            return const Center(
              child: Text('Kirim pesan pertama Anda ke admin!'),
            );
          }

          return ListView.builder(
            reverse: true,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              // 4. 'msg' sekarang adalah objek Message yang type-safe
              final msg = messages[index]; // <-- OBJEK MESSAGE
              final isMe = msg.senderId == widget.userData['firebase_uid'];
              return _buildMessageBubble(
                // 5. Akses properti secara langsung dan aman
                text: msg.text,
                sender: msg.senderName, // <-- LEBIH BERSIH
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
    // UI untuk satu bubble chat, bisa digunakan oleh bot dan live chat
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
