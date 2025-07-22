// lib/pages/notifikasi_page.dart

// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/notifikasi_model.dart';
import 'package:timeago/timeago.dart' as timeago;

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
      appBar: AppBar(title: const Text('Riwayat Notifikasi')),
      body: FutureBuilder<List<Notifikasi>>(
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
          return ListView.separated(
            itemCount: notifikasiList.length,
            separatorBuilder:
                (context, index) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final notif = notifikasiList[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      notif.isRead
                          ? Colors.grey.shade300
                          : Theme.of(context).primaryColor.withOpacity(0.2),
                  child: Icon(
                    Icons.notifications,
                    color:
                        notif.isRead
                            ? Colors.grey.shade600
                            : Theme.of(context).primaryColor,
                  ),
                ),
                title: Text(
                  notif.title,
                  style: TextStyle(
                    fontWeight:
                        notif.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(notif.body),
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
              );
            },
          );
        },
      ),
    );
  }
}
