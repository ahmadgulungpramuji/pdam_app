// chat_page.dart
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, dynamic>> _messages = [
    {
      "sender": "bot",
      "text": "Selamat datang di layanan chat PDAM! Ada yang bisa saya bantu?",
    },
    {
      "sender": "bot",
      "text":
          "Anda bisa bertanya seputar tagihan, laporan, atau layanan lainnya.",
    },
  ];
  final TextEditingController _chatController = TextEditingController();

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({"sender": "user", "text": text.trim()});
      // Simulasi balasan dari bot/admin
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleBotResponse(text.trim().toLowerCase());
      });
    });
    _chatController.clear();
  }

  void _handleBotResponse(String userMessage) {
    String botReply;
    if (userMessage.contains("tagihan")) {
      botReply =
          "Untuk informasi tagihan, silakan cek menu 'Info Tagihan' atau sebutkan ID Pelanggan Anda.";
    } else if (userMessage.contains("laporan") ||
        userMessage.contains("kebocoran")) {
      botReply =
          "Anda dapat membuat laporan melalui menu 'Buat Laporan' atau 'Lapor Temuan Kebocoran'. Jika sudah, Anda bisa melacaknya di 'Lacak Laporan'.";
    } else if (userMessage.contains("halo") ||
        userMessage.contains("selamat pagi")) {
      botReply = "Halo! Ada yang bisa saya bantu hari ini?";
    } else if (userMessage.contains("admin")) {
      botReply =
          "Baik, saya akan mencoba menghubungkan Anda dengan admin. Mohon tunggu sebentar...";
      // Di sini bisa ditambahkan logika untuk notifikasi ke admin atau integrasi live chat
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _messages.add({
            "sender": "bot",
            "text":
                "Saat ini semua admin sedang sibuk. Silakan tinggalkan pesan Anda.",
          });
        });
      });
    } else {
      botReply =
          "Maaf, saya belum mengerti pertanyaan Anda. Bisa coba pertanyaan lain?";
    }

    setState(() {
      _messages.add({"sender": "bot", "text": botReply});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat dengan Admin/Bot'),
        actions: [
          IconButton(
            icon: Icon(Icons.support_agent_outlined),
            tooltip: "Hubungi Live Agent",
            onPressed: () {
              _sendMessage("Hubungkan ke admin");
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final bool isUserMessage = message['sender'] == 'user';
                return Align(
                  alignment:
                      isUserMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 5.0,
                      horizontal: 8.0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 14.0,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isUserMessage
                              ? Theme.of(context).primaryColorLight
                              : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15.0).copyWith(
                        bottomLeft:
                            isUserMessage
                                ? const Radius.circular(15.0)
                                : Radius.zero,
                        bottomRight:
                            !isUserMessage
                                ? const Radius.circular(15.0)
                                : Radius.zero,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isUserMessage
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['text'],
                          style: TextStyle(
                            color:
                                isUserMessage ? Colors.black87 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUserMessage ? "Anda" : "PDAM Bot",
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isUserMessage ? Colors.black54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            color: Theme.of(context).cardColor,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan Anda...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: () => _sendMessage(_chatController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
