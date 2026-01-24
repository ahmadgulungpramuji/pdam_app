// lib/pages/petugas_chat_home_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdam_app/services/chat_service.dart';
import 'package:pdam_app/pages/shared/reusable_chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class PetugasChatHomePage extends StatefulWidget {
  // [TAMBAHAN] Terima daftar ID tugas dimana user adalah Ketua
  final List<String> leaderThreadIds;

  const PetugasChatHomePage({
    super.key,
    this.leaderThreadIds = const [], // Default kosong biar aman
  });

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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Percakapan'), bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Tugas Pelanggan'), Tab(text: 'Internal Admin')])),
      body: _isLoading
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

  Widget _buildChatList({required bool isInternal}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getPetugasChatThreadsStream(
        _currentUserData!['firebase_uid'],
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Terjadi error memuat chat.'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final allDocs = snapshot.data?.docs ?? [];

        // --- TAB 1: CHAT PELANGGAN ---
        if (!isInternal) {
          final filteredDocs = allDocs.where((doc) => !doc.id.startsWith('cabang_')).toList();
          if (filteredDocs.isEmpty) return const Center(child: Text('Tidak ada percakapan dengan pelanggan.'));
          
          // Panggil fungsi build list view
          return _buildListView(filteredDocs);
        }

        // --- TAB 2: CHAT INTERNAL ---
        // (Logika internal admin tetap sama seperti file asli Anda, saya singkat agar fokus)
        final int cabangId = _currentUserData!['id_cabang'];
        final int petugasId = _currentUserData!['id'];
        final String expectedThreadId = 'cabang_${cabangId}_petugas_$petugasId';
        final internalThreadExists = allDocs.any((doc) => doc.id == expectedThreadId);
        final internalThreadData = internalThreadExists ? allDocs.firstWhere((doc) => doc.id == expectedThreadId) : null;
        String subtitleText = 'Hubungi admin kantor pusat...';
        if (internalThreadData != null) {
          final data = internalThreadData.data() as Map<String, dynamic>;
          subtitleText = data['lastMessage'] ?? subtitleText;
        }

        return ListView(
          children: [
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.blue[800], child: const Icon(Icons.admin_panel_settings, color: Colors.white)),
              title: const Text("Admin Internal", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitleText, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () async {
                  final threadId = await _chatService.getOrCreateAdminChatThreadForPetugas(petugasData: _currentUserData!);
                  if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReusableChatPage(threadId: threadId, chatTitle: "Admin Internal", currentUser: _currentUserData!)));
              },
            ),
          ],
        );
      },
    );
  }

  // --- FUNGSI LIST VIEW DENGAN LOGIKA READ ONLY ---
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
        if (timestamp != null) timeAgo = DateFormat.jm().format(timestamp.toDate());

        // Logika Nama & Judul
        final participants = data['participantNames'] as Map<String, dynamic>?;
        String customerName = 'Pelanggan';
        if (participants != null) {
          final otherUserEntry = participants.entries.firstWhere(
            (entry) => entry.key != _currentUserData!['firebase_uid'],
            orElse: () => const MapEntry('', 'Pelanggan'),
          );
          customerName = otherUserEntry.value;
        }

        final idTugas = threadInfo?['idTugas']?.toString() ?? '';
        String tipeTugas = (threadInfo?['tipeTugas'] as String? ?? 'Tugas').replaceAll('_', ' ');
        tipeTugas = "${tipeTugas[0].toUpperCase()}${tipeTugas.substring(1)}";
        final String chatTitle = '$customerName ($tipeTugas #$idTugas)';

        // [PERBAIKAN UTAMA DISINI]
        // Cek ID Thread ini ada di daftar "Leader" saya atau tidak?
        final String currentThreadId = doc.id;
        
        // Defaultnya FALSE (Anggota). Jadi ReadOnly = TRUE.
        bool isReadOnly = true; 

        // Jika ID Thread ada di daftar yang dikirim dari Home, maka saya KETUA -> ReadOnly = FALSE
        if (widget.leaderThreadIds.contains(currentThreadId)) {
          isReadOnly = false;
        }

        return ListTile(
          leading: CircleAvatar(child: Text(customerName.isNotEmpty ? customerName[0].toUpperCase() : 'P')),
          title: Text(chatTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeAgo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              // Indikator Visual kalau cuma View Only
              if (isReadOnly) 
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                  child: const Text("Anggota", style: TextStyle(fontSize: 9, color: Colors.grey)),
                )
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReusableChatPage(
                  threadId: doc.id,
                  chatTitle: chatTitle,
                  currentUser: _currentUserData!,
                  // [PENTING] Kirim status isReadOnly ini ke halaman chat
                  isReadOnly: isReadOnly, 
                ),
              ),
            );
          },
        );
      },
    );
  }
}