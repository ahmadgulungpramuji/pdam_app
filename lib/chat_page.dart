// lib/chat_page.dart
import 'package:flutter/material.dart';
import 'api_service.dart'; // Pastikan path ini benar

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
    {
      "sender": "bot",
      "text": "ketik hubungi admin untuk berinteraksi dengan admin terdekat.",
    },
  ];
  final TextEditingController _chatController = TextEditingController();
  final ApiService _witService = ApiService(); // Inisialisasi WitService
  bool _isLoading = false; // Untuk indikator loading

  void _sendMessage(String text) async {
    // Jadikan async
    if (text.trim().isEmpty) return;
    String messageText = text.trim();
    _chatController.clear();

    setState(() {
      _messages.insert(0, {
        "sender": "user",
        "text": messageText,
      }); // Tampilkan pesan user di awal list
      _isLoading = true; // Mulai loading
    });

    // Kirim pesan ke Wit.ai
    final witResponse = await _witService.sendMessage(messageText);

    setState(() {
      _isLoading = false; // Selesai loading
    });

    _handleWitAiResponse(
      witResponse,
      messageText,
    ); // Teruskan original messageText untuk fallback jika diperlukan
  }

  void _handleWitAiResponse(
    Map<String, dynamic>? response,
    String originalUserMessage,
  ) {
    String botReply;

    if (response == null) {
      botReply = "Maaf, terjadi kesalahan saat menghubungi layanan AI.";
    } else if (response.containsKey("error")) {
      botReply =
          response["message"] ?? "Terjadi kesalahan yang tidak diketahui.";
    } else {
      final List<dynamic>? intents = response['intents'] as List<dynamic>?;

      if (intents != null && intents.isNotEmpty) {
        final String intentName =
            intents[0]['name'] as String? ?? "unknown_intent";
        final double confidence =
            (intents[0]['confidence'] as num?)?.toDouble() ?? 0.0;

        print('Wit.ai - Intent: $intentName, Confidence: $confidence');

        // Anda bisa set batas confidence, misalnya 0.7
        if (confidence > 0.6) {
          // Sesuaikan threshold ini
          // --- Logika berdasarkan Intent dari Wit.ai ---
          // Pastikan nama intent ini SAMA PERSIS dengan yang Anda buat di Wit.ai
          if (intentName == 'tanya_tagihan' ||
              originalUserMessage.toLowerCase().contains("tagihan")) {
            // Fallback ke keyword jika intent belum spesifik
            botReply =
                "Untuk informasi tagihan, silakan cek menu 'Info Tagihan' atau sebutkan ID Pelanggan Anda.";
          } else if (intentName == 'buat_laporan' ||
              originalUserMessage.toLowerCase().contains("laporan") ||
              originalUserMessage.toLowerCase().contains("kebocoran")) {
            botReply =
                "Anda dapat membuat laporan melalui menu 'Buat Laporan' atau 'Lapor Temuan Kebocoran'. Jika sudah, Anda bisa melacaknya di 'Lacak Laporan'.";
          } else if (intentName == 'sapaan' ||
              originalUserMessage.toLowerCase().contains("halo") ||
              originalUserMessage.toLowerCase().contains("selamat pagi")) {
            botReply = "Halo! Ada yang bisa saya bantu hari ini?";
          } else if (intentName == 'minta_admin' ||
              originalUserMessage.toLowerCase().contains("admin")) {
            botReply =
                "Baik, saya akan mencoba menghubungkan Anda dengan admin. Mohon tunggu sebentar...";
            // Di sini bisa ditambahkan logika untuk notifikasi ke admin atau integrasi live chat
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                // Pastikan widget masih ada di tree
                setState(() {
                  _messages.insert(0, {
                    // Tampilkan pesan bot di awal list
                    "sender": "bot",
                    "text":
                        "Saat ini semua admin sedang sibuk. Silakan tinggalkan pesan Anda, atau coba beberapa saat lagi.",
                  });
                });
              }
            });
            // Jangan langsung tambahkan pesan "admin sibuk" di sini agar pesan pertama muncul dulu
            // Pesan kedua akan ditambahkan oleh Future.delayed di atas
            setState(() {
              _messages.insert(0, {"sender": "bot", "text": botReply});
            });
            return; // Keluar dari fungsi karena ada penanganan khusus
          }
          // Tambahkan intent lain yang sudah Anda latih di Wit.ai
          // else if (intentName == 'tanya_layanan') {
          //   botReply = "Kami menyediakan layanan A, B, dan C.";
          // }
          else {
            botReply =
                "Saya mengerti maksud Anda sebagai '$intentName', tapi saya belum dilatih untuk merespons ini secara spesifik. Bisa coba pertanyaan lain?";
          }
        } else {
          botReply =
              "Maaf, saya kurang yakin dengan maksud Anda. Bisa coba ulangi dengan kalimat yang lebih jelas?";
        }
      } else {
        botReply =
            "Maaf, saya belum bisa memahami pertanyaan Anda. Bisa coba pertanyaan lain?";
      }
    }

    if (mounted) {
      // Pastikan widget masih ada di tree
      setState(() {
        _messages.insert(0, {
          "sender": "bot",
          "text": botReply,
        }); // Tampilkan pesan bot di awal list
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat dengan PDAM'), // Ganti judul jika perlu
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_outlined),
            tooltip: "Hubungi Live Agent",
            onPressed:
                _isLoading
                    ? null
                    : () {
                      // Nonaktifkan tombol jika sedang loading
                      _sendMessage("Hubungkan ke admin");
                    },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              reverse: true, // Agar chat dimulai dari bawah dan scroll ke atas
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
                        topLeft: const Radius.circular(15.0),
                        topRight: const Radius.circular(15.0),
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
                          style: const TextStyle(color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUserMessage ? "Anda" : "PDAM Bot",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) // Tampilkan indikator loading
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(),
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
                    enabled:
                        !_isLoading, // Nonaktifkan input jika sedang loading
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
                    onSubmitted:
                        _isLoading ? null : _sendMessage, // Kirim saat enter
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed:
                      _isLoading
                          ? null
                          : () => _sendMessage(
                            _chatController.text,
                          ), // Nonaktifkan tombol jika sedang loading
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
