// lib/pages/shared/reusable_chat_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdam_app/services/chat_service.dart';

class ReusableChatPage extends StatefulWidget {
  final String threadId;
  final String chatTitle;
  final Map<String, dynamic> currentUser;
  final bool isReadOnly;

  const ReusableChatPage({
    super.key,
    required this.threadId,
    required this.chatTitle,
    required this.currentUser,
    this.isReadOnly = false,
  });

  @override
  State<ReusableChatPage> createState() => _ReusableChatPageState();
}

class _ReusableChatPageState extends State<ReusableChatPage> {
  final TextEditingController _chatController = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isSending = false;
  
  StreamSubscription? _activeChatMonitor;

  @override
  void initState() {
    super.initState();
    
    // 1. FORCE MARK READ SAAT HALAMAN DIBUKA
    final myUid = widget.currentUser['firebase_uid'];
    if (myUid != null) {
      print(">>> [ChatPage] Membuka chat thread: ${widget.threadId}. Menandai read...");
      _chatService.markMessagesAsRead(widget.threadId, myUid);
    }

    // 2. Mulai monitoring pesan baru secara real-time
    _startActiveChatMonitor();
  }

  @override
  void dispose() {
    _activeChatMonitor?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  void _startActiveChatMonitor() {
    final myUid = widget.currentUser['firebase_uid'];
    if (myUid == null) return;

    _activeChatMonitor = _chatService.getMessages(widget.threadId).listen((messages) {
      if (messages.isEmpty) return;

      // Cek apakah ada pesan dari ORANG LAIN yang BELUM SAYA BACA
      bool adaPesanBelumDibaca = messages.any((msg) {
        return msg.senderId != myUid && !msg.readBy.contains(myUid);
      });

      // Jika ada, segera tandai sebagai terbaca di database
      if (adaPesanBelumDibaca) {
        _chatService.markMessagesAsRead(widget.threadId, myUid);
      }
    });
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _chatController.clear();

    final myUid = widget.currentUser['firebase_uid'];
    
    try {
      await _chatService.sendMessage(
        widget.threadId,
        myUid,
        widget.currentUser['nama'] ?? 'User',
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
                    
                    // Pesan dianggap terbaca jika readBy > 1 (pengirim + penerima)
                    bool isRead = msg.readBy.length > 1; 

                    return _buildBubble(msg, isMe, isRead);
                  },
                );
              },
            ),
          ),
          
          // [PERUBAHAN DISINI]
          // Jika isReadOnly = true (Anggota Tim), Tampilkan teks saja.
          // Jika false (Ketua Tim), Tampilkan Input Chat.
          widget.isReadOnly 
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: const Text(
                  "Anda hanya dapat melihat percakapan ini (Mode Anggota).",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey, 
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic
                  ),
                ),
              )
            : _buildInput(),
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