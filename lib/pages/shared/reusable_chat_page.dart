// lib/pages/shared/reusable_chat_page.dart
import 'package:flutter/material.dart';
import 'package:pdam_app/services/chat_service.dart';

class ReusableChatPage extends StatefulWidget {
  final String threadId;
  final String chatTitle;
  final Map<String, dynamic> currentUser; // Data user yang sedang login

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

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });
    _chatController.clear();

    try {
      await _chatService.sendMessage(
        widget.threadId,
        widget.currentUser['firebase_uid'],
        widget.currentUser['nama'],
        text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim pesan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatTitle, style: const TextStyle(fontSize: 18)),
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
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Belum ada pesan. Mulai percakapan!'),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe =
                        msg.senderId == widget.currentUser['firebase_uid'];
                    return _buildMessageBubble(
                      text: msg.text,
                      sender: msg.senderName,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
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
            if (!isMe)
              Text(
                sender,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(color: Colors.black87, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
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
            icon:
                _isSending
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
