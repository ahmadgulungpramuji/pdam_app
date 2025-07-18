// lib/pages/petugas_chat_home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdam_app/services/chat_service.dart';
import 'package:pdam_app/pages/shared/reusable_chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class PetugasChatHomePage extends StatefulWidget {
  const PetugasChatHomePage({super.key});

  @override
  State<PetugasChatHomePage> createState() => _PetugasChatHomePageState();
}

class _PetugasChatHomePageState extends State<PetugasChatHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();
  Map<String, dynamic>? _currentUserData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_data');
    if (jsonString != null) {
      setState(() {
        _currentUserData = jsonDecode(jsonString);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal memuat data user.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Percakapan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tugas Pelanggan'),
            Tab(text: 'Internal Admin'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentUserData == null
              ? const Center(child: Text("Data user tidak valid."))
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildChatList(isInternal: false),
                  _buildChatList(isInternal: true),
                ],
              ),
    );
  }

  // --- PERUBAHAN UTAMA ADA DI DALAM METHOD INI ---
  Widget _buildChatList({required bool isInternal}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getPetugasChatThreadsStream(
        _currentUserData!['firebase_uid'],
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('STREAM ERROR: ${snapshot.error}');
          return const Center(child: Text('Terjadi error.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Logika untuk tab "Tugas Pelanggan" tetap sama
        if (!isInternal) {
          final filteredDocs =
              allDocs.where((doc) => !doc.id.contains('internal')).toList();
          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text('Tidak ada percakapan dengan pelanggan.'),
            );
          }
          return _buildListView(filteredDocs);
        }

        // --- LOGIKA BARU UNTUK TAB "INTERNAL ADMIN" ---
        final String internalThreadId =
            'cabang_${_currentUserData!['id_cabang']}_internal_petugas';
        final internalThreadExists = allDocs.any(
          (doc) => doc.id == internalThreadId,
        );
        final internalThreadData =
            internalThreadExists
                ? allDocs.firstWhere((doc) => doc.id == internalThreadId)
                : null;

        return ListView(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.group)),
              title: const Text(
                "Internal Admin",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                internalThreadData != null
                    ? (internalThreadData.data()
                            as Map<String, dynamic>)['lastMessage'] ??
                        'Mulai percakapan...'
                    : 'Mulai percakapan dengan admin',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                // Saat di-tap, panggil metode untuk membuat thread jika belum ada
                try {
                  final threadId = await _chatService
                      .getOrCreateAdminChatThreadForPetugas(
                        petugasData: _currentUserData!,
                      );
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ReusableChatPage(
                              threadId: threadId,
                              chatTitle: "Internal Admin",
                              currentUser: _currentUserData!,
                            ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gagal memulai chat: $e")),
                    );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- WIDGET HELPER BARU UNTUK MENGHINDARI DUPLIKASI KODE ---
  Widget _buildListView(List<DocumentSnapshot> docs) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final threadInfo = data['threadInfo'] as Map<String, dynamic>?;
        final lastMessage = data['lastMessage'] as String? ?? '...';

        final timestamp = data['lastMessageTimestamp'] as Timestamp?;
        String timeAgo = '';
        if (timestamp != null) {
          final dt = timestamp.toDate();
          timeAgo = DateFormat.jm().format(dt); // Contoh format: 5:08 PM
        }

        final participants = data['participantNames'] as Map<String, dynamic>?;
        String chatTitle = threadInfo?['title'] ?? 'Chat';
        if (participants != null) {
          final otherUserEntry = participants.entries.firstWhere(
            (entry) => entry.key != _currentUserData!['firebase_uid'],
            orElse: () => const MapEntry('', 'User'),
          );
          chatTitle = otherUserEntry.value;
        }

        return ListTile(
          leading: CircleAvatar(
            child: Text(
              chatTitle.isNotEmpty ? chatTitle[0].toUpperCase() : 'U',
            ),
          ),
          title: Text(
            chatTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            timeAgo,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ReusableChatPage(
                      threadId: doc.id,
                      chatTitle: chatTitle,
                      currentUser: _currentUserData!,
                    ),
              ),
            );
          },
        );
      },
    );
  }
}
