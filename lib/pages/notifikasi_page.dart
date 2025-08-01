// lib/pages/notifikasi_page.dart

// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/notifikasi_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  final ApiService _apiService = ApiService();
  late Future<List<Notifikasi>> _notifikasiFuture;

  @override
  void initState() {
    super.initState();
    // Atur timeago untuk format bahasa Indonesia
    timeago.setLocaleMessages('id', timeago.IdMessages());
    _apiService.markNotifikasiAsRead();
    _notifikasiFuture = _loadNotifikasi();
  }

  Future<List<Notifikasi>> _loadNotifikasi() async {
    final List<dynamic> rawData = await _apiService.getNotifikasiSaya();
    return rawData.map((json) => Notifikasi.fromJson(json)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Notifikasi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<Notifikasi>>(
          future: _notifikasiFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text('Belum ada notifikasi', style: TextStyle(fontSize: 18)),
                  ],
                ),
              );
            }

            final notifikasiList = snapshot.data!;
            return AnimationLimiter(
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 100),
                itemCount: notifikasiList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notif = notifikasiList[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Slidable(
                            key: ValueKey(notif.createdAt),
                            endActionPane: ActionPane(
                              motion: const StretchMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (context) {
                                    // Tambahkan logika untuk menghapus notifikasi
                                    // Contoh: _apiService.deleteNotifikasi(notif.id);
                                    // Kemudian panggil setState atau refetch data
                                  },
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                  label: 'Hapus',
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                              ],
                            ),
                            child: Card(
                              elevation: 6, // Meningkatkan elevasi untuk shadow yang lebih jelas
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18.0), // Sudut yang lebih melengkung
                              ),
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100, // Warna latar belakang avatar yang lebih kalem
                                  child: Icon(
                                    Icons.notifications,
                                    color: Theme.of(context).primaryColor, // Warna ikon sesuai tema
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  notif.title,
                                  style: TextStyle(
                                    fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                                    color: Colors.grey.shade800, // Warna judul yang lebih gelap
                                  ),
                                ),
                                subtitle: Text(
                                  notif.body,
                                  style: TextStyle(
                                    color: Colors.grey.shade600, // Warna subtitle yang lebih kalem
                                  ),
                                ),
                                trailing: Text(
                                  timeago.format(notif.createdAt, locale: 'id'),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                onTap: () {
                                  if (notif.referenceId != null) {
                                    Navigator.pushNamed(
                                      context,
                                      '/lacak_laporan_saya',
                                      arguments: {'pengaduan_id': notif.referenceId},
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}