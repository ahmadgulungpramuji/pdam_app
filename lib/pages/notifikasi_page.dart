// lib/pages/notifikasi_page.dart

// ignore_for_file: depend_on_referenced_packages, unused_local_variable

import 'dart:developer';

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

  // 1. Deklarasikan semua variabel state yang dibutuhkan
  List<Notifikasi> _notifikasiList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('id', timeago.IdMessages());

    // 2. Langsung panggil fungsi untuk memuat data
    _apiService.markNotifikasiAsRead();
    _loadNotifikasi();
  }

  // 3. Fungsi ini sekarang hanya bertugas mengisi variabel state
  Future<void> _loadNotifikasi() async {
    try {
      final List<dynamic> rawData = await _apiService.getNotifikasiSaya();
      if (mounted) {
        setState(() {
          _notifikasiList =
              rawData.map((json) => Notifikasi.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleDelete(Notifikasi notifikasi) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: const Text(
              'Apakah Anda yakin ingin menghapus notifikasi ini secara permanen?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        await _apiService.deleteNotifikasi(notifikasi.id);

        setState(() {
          _notifikasiList.removeWhere((item) => item.id == notifikasi.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifikasi berhasil dihapus.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Fungsi baru untuk mendapatkan ikon berdasarkan tipe notifikasi
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'lapor_foto_water_meter_status':
        return Icons.water_drop_outlined;
      case 'pengaduan_status_update':
        return Icons.campaign_outlined;
      case 'informasi_umum':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Notifikasi'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        // 4. Widget build utama hanya memanggil _buildBody
        child: _buildBody(),
      ),
    );
  }

  // 5. _buildBody berisi semua logika untuk menampilkan UI
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
          child: Text('Gagal memuat data: $_error',
              style: const TextStyle(color: Colors.red)));
    }

    if (_notifikasiList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada notifikasi',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    // Tampilkan list jika data sudah ada
    return AnimationLimiter(
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 100, bottom: 24),
        itemCount: _notifikasiList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notif = _notifikasiList[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Slidable(
                    key: ValueKey(notif.id),
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) => _handleDelete(notif),
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          icon: Icons.delete_forever,
                          label: 'Hapus',
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                      ],
                    ),
                    child: Card(
                      elevation: notif.isRead ? 2 : 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: notif.isRead
                                ? Colors.blue.shade50
                                : Colors.blue.shade200,
                            child: Icon(
                              _getNotificationIcon(notif.type),
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            notif.title,
                            style: TextStyle(
                              fontWeight: notif.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: notif.isRead
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade800,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            notif.body,
                            style: TextStyle(
                              color: notif.isRead
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            timeago.format(notif.createdAt, locale: 'id'),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          onTap: () {
                            // ... Logika onTap Anda tetap sama
                            log('Notifikasi di-tap: ${notif.title}');
                            final notifType = notif.type;
                            final notifStatus = notif.status;
                            final notifRefId = notif.referenceId;

                            if (notifType == 'lapor_foto_water_meter_status') {
                              if (notifStatus == 'ditolak') {
                                Navigator.pushNamed(
                                    context, '/lapor_foto_meter');
                              }
                            } else if (notif.referenceId != null) {
                              final int? pengaduanId =
                                  int.tryParse(notif.referenceId!);
                              if (pengaduanId != null) {
                                Navigator.pushNamed(
                                  context,
                                  '/lacak_laporan_saya',
                                  arguments: {'pengaduan_id': pengaduanId},
                                );
                              }
                            }
                          },
                        ),
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
  }
}