// lib/pages/notifikasi_page.dart
// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/notifikasi_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// --- WIDGET ANIMASI (Untuk konsistensi) ---
class FadeInAnimationUI extends StatefulWidget {
  final int delay;
  final Widget child;

  const FadeInAnimationUI({super.key, this.delay = 0, required this.child});

  @override
  State<FadeInAnimationUI> createState() => _FadeInAnimationUIState();
}

class _FadeInAnimationUIState extends State<FadeInAnimationUI>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _position = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(curve);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _position,
        child: widget.child,
      ),
    );
  }
}
// --- END WIDGET ANIMASI ---

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  final ApiService _apiService = ApiService();

  List<Notifikasi> _notifikasiList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('id', timeago.IdMessages());
    _apiService.markNotifikasiAsRead();
    _loadNotifikasi();
  }

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Konfirmasi Hapus',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin menghapus notifikasi ini?',
              style: GoogleFonts.manrope()),
          actions: <Widget>[
            TextButton(
              child: Text('Batal', style: GoogleFonts.manrope()),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Hapus',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
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
          _showSnackbar('Notifikasi berhasil dihapus.', isError: false);
        }
      } catch (e) {
        if (mounted) {
          _showSnackbar('Gagal menghapus: ${e.toString()}', isError: true);
        }
      }
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.manrope()),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
    ));
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'lapor_foto_water_meter_status':
        return Ionicons.water_outline;
      case 'pengaduan_status_update':
        return Ionicons.megaphone_outline;
      case 'informasi_umum':
        return Ionicons.information_circle_outline;
      default:
        return Ionicons.notifications_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color textColor = Color(0xFF212529);
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Riwayat Notifikasi',
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_notifikasiList.isEmpty) {
      return _buildEmptyState();
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _notifikasiList.length,
        itemBuilder: (context, index) {
          final notif = _notifikasiList[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildNotificationItem(notif),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(Notifikasi notif) {
    const Color primaryColor = Color(0xFF0077B6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Slidable(
        key: ValueKey(notif.id),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          children: [
            SlidableAction(
              onPressed: (context) => _handleDelete(notif),
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              icon: Ionicons.trash_outline,
              label: 'Hapus',
              borderRadius: BorderRadius.circular(20.0),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            log('Notifikasi di-tap: ${notif.title}');
            if (notif.type == 'lapor_foto_water_meter_status' &&
                notif.status == 'ditolak') {
              Navigator.pushNamed(context, '/lapor_foto_meter');
            } else if (notif.referenceId != null) {
              final int? pengaduanId = int.tryParse(notif.referenceId!);
              if (pengaduanId != null) {
                Navigator.pushNamed(
                  context,
                  '/lacak_laporan_saya',
                  arguments: {'pengaduan_id': pengaduanId},
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: !notif.isRead
                  ? Border.all(color: primaryColor.withOpacity(0.5), width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: !notif.isRead
                      ? primaryColor.withOpacity(0.1)
                      : Colors.grey.shade100,
                  child: Icon(
                    _getNotificationIcon(notif.type),
                    color: !notif.isRead ? primaryColor : Colors.grey.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title,
                        style: GoogleFonts.manrope(
                          fontWeight:
                              !notif.isRead ? FontWeight.bold : FontWeight.w600,
                          color: !notif.isRead
                              ? const Color(0xFF212529)
                              : Colors.grey.shade700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.body,
                        style: GoogleFonts.manrope(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // --- PERBAIKAN LAYOUT TIMEAGO ---
                SizedBox(
                  width: 75,
                  child: Text(
                    timeago.format(notif.createdAt, locale: 'id'),
                    style: GoogleFonts.manrope(
                        fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.right,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeInAnimationUI(
      delay: 200,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                ),
                child: Icon(Ionicons.notifications_off_outline,
                    size: 60, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
              Text(
                'Kotak Masuk Kosong',
                style: GoogleFonts.manrope(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Semua notifikasi dan pembaruan penting akan muncul di sini.',
                style: GoogleFonts.manrope(
                    fontSize: 15, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return FadeInAnimationUI(
      delay: 200,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Ionicons.cloud_offline_outline,
                  size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              Text("Oops!",
                  style: GoogleFonts.manrope(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Gagal memuat data notifikasi.",
                  textAlign: TextAlign.center, style: GoogleFonts.manrope()),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                icon: const Icon(Ionicons.refresh_outline),
                label: const Text("Coba Lagi"),
                onPressed: _loadNotifikasi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0077B6),
                  foregroundColor: Colors.white,
                  textStyle: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
