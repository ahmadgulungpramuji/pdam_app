// lib/pages/shared/reusable_chat_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdam_app/services/chat_service.dart';

class ReusableChatPage extends StatefulWidget {
  final String threadId;
  final String chatTitle;
  final Map<String, dynamic> currentUser;

  const ReusableChatPage({
    super.key,
    required this.threadId,
    required this.chatTitle,
    required this.currentUser,
  });

  @override
  State<ReusableChatPage> createState() => _ReusableChatPageState();
}

class _ReusableChatPageState extends State<ReusableChatPage> {
  final TextEditingController _chatController = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isSending = false;
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    // 1. Paksa tandai baca saat halaman baru dibuka
    _markAsRead(); 
    
    // 2. Pasang listener yang lebih pintar
    _listenToMessages(); 
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  void _markAsRead() {
    // Memanggil fungsi di service untuk update database
    _chatService.markMessagesAsRead(
      widget.threadId,
      widget.currentUser['firebase_uid'],
    );
  }

  void _listenToMessages() {
    _msgSub = _chatService.getMessages(widget.threadId).listen((messages) {
      if (messages.isNotEmpty) {
        final myUid = widget.currentUser['firebase_uid'];
        
        // --- PERBAIKAN LOGIKA UTAMA DI SINI ---
        // Cek apakah ada pesan APAPUN dari orang lain yang belum saya baca.
        // Kita gunakan .any() untuk mengecek seluruh list pesan yang dimuat,
        // bukan hanya pesan pertama (.first).
        
        bool adaPesanBelumDibaca = messages.any((msg) {
          bool isDariOrangLain = msg.senderId != myUid;
          bool sayaBelumBaca = !msg.readBy.contains(myUid);
          return isDariOrangLain && sayaBelumBaca;
        });

        if (adaPesanBelumDibaca) {
          print(">>> [ChatPage] Ditemukan pesan belum dibaca. Menandai sekarang...");
          _markAsRead();
        }
      }
    });
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _chatController.clear();

    // Tips: Sebelum kirim, pastikan semua pesan sebelumnya ditandai baca
    _markAsRead();

    try {
      await _chatService.sendMessage(
        widget.threadId,
        widget.currentUser['firebase_uid'],
        widget.currentUser['nama'],
        text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal kirim: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatTitle, style: const TextStyle(fontSize: 16)),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getMessages(widget.threadId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error memuat pesan.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snapshot.data ?? [];
                if (msgs.isEmpty) {
                  return const Center(child: Text("Belum ada percakapan."));
                }
                
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final msg = msgs[index];
                    final isMe = msg.senderId == widget.currentUser['firebase_uid'];
                    
                    // Cek status baca untuk indikator (opsional)
                    // Pesan dianggap terbaca jika readBy memiliki lebih dari 1 ID (pengirim + penerima)
                    bool isRead = msg.readBy.length > 1; 

                    return _buildBubble(msg, isMe, isRead);
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(Message msg, bool isMe, bool isRead) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0077B6).withOpacity(0.1) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderName,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
              ),
            Text(msg.text, style: const TextStyle(fontSize: 15)),
            
            // Indikator Centang (Hanya muncul di pesan kita)
            if (isMe) ...[
               const SizedBox(height: 4),
               Icon(
                 isRead ? Icons.done_all : Icons.done,
                 size: 14,
                 color: isRead ? Colors.blue : Colors.grey,
               )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: "Tulis pesan...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: IconButton(
              icon: _isSending 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isSending ? null : _sendMessage,
            ),
          )
        ],
      ),
    );
  }
}