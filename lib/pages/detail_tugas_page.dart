// lib/pages/petugas/detail_tugas_page.dart

// ignore_for_file: unused_element

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdam_app/api_service.dart';
import 'package:pdam_app/models/tugas_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pdam_app/services/chat_service.dart';
import 'package:pdam_app/pages/shared/reusable_chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetailTugasPage extends StatefulWidget {
  final Tugas tugas;
  const DetailTugasPage({super.key, required this.tugas});

  @override
  State<DetailTugasPage> createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends State<DetailTugasPage> {
  late Tugas _tugasSaatIni;
  late Tugas _currentTugas;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final DateFormat _dateFormatter = DateFormat('EEEE, dd MMMM', 'id_ID');
  final DateFormat _timeFormatter = DateFormat('HH:mm', 'id_ID');

  final ChatService _chatService = ChatService();
  Map<String, dynamic>? _currentUserData;

  @override
  void initState() {
    super.initState();
    _tugasSaatIni = widget.tugas;
    _loadCurrentUser();
    _currentTugas = widget.tugas;
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_data');
    if (jsonString != null && mounted) {
      setState(() {
        _currentUserData = jsonDecode(jsonString);
      });
    }
  }

  void _setLoading(bool loading) {
    if (mounted) setState(() => _isLoading = loading);
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  String _formatPhoneNumberForWhatsApp(String phone) {
    // Hapus karakter yang tidak diperlukan (spasi, strip, plus)
    String cleanedPhone = phone.replaceAll(RegExp(r'[\s\-+]'), '');

    // Jika nomor dimulai dengan '0', ganti dengan '62'
    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '62${cleanedPhone.substring(1)}';
    }
    // Jika sudah dimulai dengan '62', biarkan saja.
    // Jika tidak, asumsikan sudah format internasional tanpa awalan.
    return cleanedPhone;
  }

  Future<void> _updateStatus(
    String targetNewStatus, {
    String? keterangan,
  }) async {
    _setLoading(true);
    try {
      final responseData = await _apiService.updateStatusTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        newStatus: targetNewStatus,
        keterangan: keterangan,
      );

      final Map<String, dynamic>? tugasTerbaruJson =
          responseData['tugas_terbaru'] as Map<String, dynamic>?;

      if (mounted) {
        if (targetNewStatus == 'dibatalkan') {
          await _showSuccessAndNavigateHome();
        } else if (tugasTerbaruJson != null) {
          setState(() {
            _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
          });
          _showSnackbar(
            'Status berhasil diubah ke: ${_tugasSaatIni.friendlyStatus}',
            isError: false,
          );
        } else {
          _showSnackbar(
            'Gagal memperbarui UI: Respons tidak lengkap dari server.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Gagal mengubah status: $e');
      }
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _pickAndUploadImage(
    String jenisFotoUntukUpload,
    String statusSetelahUpload,
  ) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1080,
    );

    if (pickedFile == null) return;

    _setLoading(true);
    try {
      final responseData = await _apiService.uploadFotoTugas(
        idTugas: _tugasSaatIni.idTugas,
        tipeTugas: _tugasSaatIni.tipeTugas,
        jenisFoto: jenisFotoUntukUpload,
        imagePath: pickedFile.path,
        newStatus: statusSetelahUpload,
      );

      final Map<String, dynamic>? tugasTerbaruJson =
          responseData['tugas_terbaru'] as Map<String, dynamic>?;

      if (mounted && tugasTerbaruJson != null) {
        setState(() {
          _tugasSaatIni = Tugas.fromJson(tugasTerbaruJson);
        });
        _showSnackbar(
          'Foto berhasil diupload & status diperbarui!',
          isError: false,
        );
      } else {
        _showSnackbar(
          'Gagal memperbarui UI: Respons tidak lengkap dari server.',
        );
      }
    } catch (e) {
      _showSnackbar('Gagal upload foto: $e');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Widget _buildKontakSection(KontakInfo kontak) {
    // Logika untuk menentukan apakah tombol chat harus ditampilkan
    final bool canChat = _tugasSaatIni.isPetugasPelapor &&
        _tugasSaatIni.tipeTugas == 'pengaduan' &&
        _currentUserData != null &&
        (kontak.firebaseUid != null && kontak.firebaseUid!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Ionicons.person_outline, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text:
                            '${_tugasSaatIni is PengaduanTugas ? 'Pelanggan' : 'Pelapor'}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: '${kontak.nama} (${kontak.nomorHp})'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Ionicons.call_outline, size: 18),
                label: const Text('Telepon'),
                onPressed: () {
                  final Uri phoneUri = Uri(scheme: 'tel', path: kontak.nomorHp);
                  _launchURL(phoneUri.toString());
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Ionicons.logo_whatsapp, size: 18),
                label: const Text('WhatsApp'),
                onPressed: () {
                  final formattedPhone =
                      _formatPhoneNumberForWhatsApp(kontak.nomorHp);
                  final Uri whatsappUri =
                      Uri.parse('https://wa.me/$formattedPhone');
                  _launchURL(whatsappUri.toString());
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade700),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(
                  Ionicons.chatbubble_ellipses_outline,
                  size: 18,
                ),
                label: const Text('Chat'),
                onPressed: !canChat || _isLoading
                    ? null
                    : () async {
                        // ====================== PERUBAHAN DI SINI ======================

                        // Cek apakah objek cabang dan ID-nya ada.
                        // Anda mungkin perlu menyesuaikan ini dengan struktur model Tugas Anda.
                        // Asumsi: _tugasSaatIni.cabang adalah Map<String, dynamic>
                        final cabangData =
                            _tugasSaatIni.cabang as Map<String, dynamic>?;
                        final int? cabangId = cabangData?['id'] as int?;

                        if (cabangId == null) {
                          _showSnackbar(
                              'Gagal memulai chat: Informasi cabang untuk tugas ini tidak ditemukan.');
                          return;
                        }
                        // ===============================================================

                        _setLoading(true);
                        try {
                          final pelangganInfo = {
                            'id': kontak.id,
                            'nama': kontak.nama,
                            'firebase_uid': kontak.firebaseUid,
                          };

                          final threadId =
                              await _chatService.getOrCreateTugasChatThread(
                            tipeTugas: _tugasSaatIni.tipeTugas,
                            idTugas: _tugasSaatIni.idTugas,
                            currentUser: _currentUserData!,
                            otherUsers: [pelangganInfo],
                            cabangId:
                                cabangId, // <-- Gunakan cabangId yang sudah divalidasi
                          );

                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReusableChatPage(
                                  threadId: threadId,
                                  chatTitle:
                                      "Chat Laporan #${_tugasSaatIni.idTugas}",
                                  currentUser: _currentUserData!,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          _showSnackbar("Gagal memulai chat: $e");
                        } finally {
                          _setLoading(false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Tugas',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (OverscrollIndicatorNotification notification) {
          notification.disallowIndicator();
          return true;
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(child: _buildInfoSection()),
                  const SizedBox(height: 20),
                  if (_tugasSaatIni.isPetugasPelapor)
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: _buildActionSection(),
                    ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _buildFotoProgresSection(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black
                    .withAlpha(128), // 128 adalah 50% dari 255 (alpha penuh)
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tugasSaatIni.kategoriDisplay,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Ionicons.calendar_outline,
              'Tgl Kejadian:',
              _formatDate(_tugasSaatIni.tanggalTugas),
            ),
            _buildInfoRow(
              Ionicons.time_outline,
              'Ditugaskan:',
              '${_formatDate(_tugasSaatIni.tanggalDibuatPenugasan.toIso8601String())}, ${_timeFormatter.format(_tugasSaatIni.tanggalDibuatPenugasan)}',
            ),
            _buildInfoRow(
              Ionicons.locate_outline,
              'Deskripsi Lokasi:',
              _tugasSaatIni.deskripsiLokasi,
              isMultiline: true,
            ),
            _buildInfoRow(
              Ionicons.map_outline,
              'Link Peta:',
              _tugasSaatIni.lokasiMaps,
              isLink: true,
            ),
            _buildInfoRow(
              Ionicons.document_text_outline,
              'Deskripsi Laporan:',
              _tugasSaatIni.deskripsi,
              isMultiline: true,
            ),
            if (_tugasSaatIni.infoKontakPelapor != null)
              _buildKontakSection(_tugasSaatIni.infoKontakPelapor!),
            const SizedBox(height: 12),
            _buildStatusRow(),
            if (_tugasSaatIni.status == 'dibatalkan' &&
                (_tugasSaatIni.alasanPembatalan ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alasan Pembatalan:',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tugasSaatIni.alasanPembatalan!,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            _buildPhotoViewer('Foto Bukti Awal:', _tugasSaatIni.fotoBuktiUrl),
            if (_tugasSaatIni is PengaduanTugas)
              _buildPhotoViewer(
                'Foto Rumah Pelanggan:',
                (_tugasSaatIni as PengaduanTugas)
                    .fotoRumahUrl, // Cast untuk akses fotoRumahUrl
              ),
          ],
        ),
      ),
    );
  }

  // Sisa file (semua widget helper lainnya) sama seperti sebelumnya...
  // Contoh: _buildActionSection, _showCancelDialog, _buildFotoProgresSection, dll.
  // ...
  Future<void> _showSuccessAndNavigateHome() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Ionicons.checkmark_circle, color: Colors.green[600]),
              const SizedBox(width: 10),
              Text(
                'Berhasil',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Tugas telah berhasil dibatalkan.',
            style: GoogleFonts.lato(),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'OK',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _batalkanTugas(String alasan) async {
    _setLoading(true);
    try {
      await _apiService.batalkanPenugasanMandiri(
        idTugas: _currentTugas.idTugas,
        tipeTugas: _currentTugas.tipeTugas,
        alasan: alasan,
      );

      // Jika berhasil, tampilkan dialog sukses dan kembali ke halaman utama
      if (mounted) {
        // Hapus panggilannya di sini, karena akan dipanggil di dalam _showSuccessAndNavigateHome
        // Navigator.of(context).pop();
        await _showSuccessAndNavigateHome();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Gagal membatalkan tugas: $e');
      }
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Widget _buildActionSection() {
    if (!_tugasSaatIni.isPetugasPelapor) return const SizedBox.shrink();

    List<Widget> actionButtons = [];
    switch (_tugasSaatIni.status) {
      case 'menunggu_konfirmasi':
        actionButtons.add(
          _buildActionButton(
            label: 'Terima Laporan',
            icon: Ionicons.checkmark_circle_outline,
            onPressed: () => _updateStatus('diterima'),
            color: Colors.green[600],
          ),
        );
        actionButtons.add(const SizedBox(height: 8));
        actionButtons.add(
          _buildActionButton(
            label: 'Batalkan Laporan',
            icon: Ionicons.close_circle_outline,
            onPressed: _showCancelDialog,
            color: Colors.red[600],
          ),
        );
        break;
      case 'diterima':
        actionButtons.add(
          _buildActionButton(
            label: 'Mulai Perjalanan',
            icon: Ionicons.paper_plane_outline,
            onPressed: () => _updateStatus('dalam_perjalanan'),
            color: Colors.blue[600],
          ),
        );
        break;
      case 'dalam_perjalanan':
        actionButtons.add(
          _buildActionButton(
            label: 'Ambil Foto Sebelum & Proses',
            icon: Ionicons.camera_outline,
            onPressed: () => _pickAndUploadImage('foto_sebelum', 'diproses'),
            color: Colors.orange[700],
          ),
        );
        break;
      case 'diproses':
        actionButtons.add(
          _buildActionButton(
            label: 'Ambil Foto Sesudah & Selesaikan',
            icon: Ionicons.cloud_upload_outline,
            onPressed: () => _pickAndUploadImage('foto_sesudah', 'selesai'),
            color: Colors.teal[600],
          ),
        );
        break;
      case 'selesai':
        actionButtons.add(
          _buildStatusDisplay(
            'Pekerjaan Telah Selesai',
            Ionicons.checkmark_done_circle,
            Colors.teal[600]!,
          ),
        );
        break;
      case 'dibatalkan':
        actionButtons.add(
          _buildStatusDisplay(
            'Tugas Dibatalkan',
            Ionicons.close_circle,
            Colors.red[700]!,
          ),
        );
        break;
    }

    if (actionButtons.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aksi Petugas',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const Divider(height: 24),
            ...actionButtons,
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Batalkan Laporan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: 'Masukkan alasan pembatalan...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
            minLines: 1,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final String reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  // Jangan tutup dialog, cukup tampilkan pesan
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Alasan pembatalan wajib diisi!'),
                      backgroundColor: Colors.orange[800],
                    ),
                  );
                } else {
                  Navigator.pop(dialogContext); // Tutup dialog dulu
                  _batalkanTugas(
                      reason); // Panggil fungsi pembatalan yang benar
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: Text('Konfirmasi Batalkan', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFotoProgresSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dokumentasi Progres',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressImage(
                  'Foto Sebelum',
                  _tugasSaatIni.fotoSebelumUrl,
                ),
                const SizedBox(width: 16),
                _buildProgressImage(
                  'Foto Sesudah',
                  _tugasSaatIni.fotoSesudahUrl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
    bool isMultiline = false,
  }) {
    final displayValue = value.isEmpty ? 'Data tidak tersedia' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.lato(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  isLink
                      ? WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: InkWell(
                            onTap: displayValue == 'Data tidak tersedia'
                                ? null
                                : () => _launchURL(displayValue),
                            child: Text(
                              displayValue,
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        )
                      : TextSpan(text: displayValue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Icon(Ionicons.cellular_outline, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Text(
          'Status: ',
          style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getColorForStatus(_tugasSaatIni.status),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _tugasSaatIni.friendlyStatus.toUpperCase(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoViewer(String title, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: Image.network(imageUrl),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 220,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                          height: 220,
                          alignment: Alignment.center,
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                  errorBuilder: (context, error, stack) => Container(
                    height: 180,
                    alignment: Alignment.center,
                    color: Colors.grey[200],
                    child: Icon(
                      Ionicons.warning_outline,
                      color: Colors.grey[400],
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressImage(String title, String? imageUrl) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 160,
                      errorBuilder: (c, e, s) => Icon(
                        Ionicons.image_outline,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                    ),
                  )
                : Icon(
                    Ionicons.image_outline,
                    size: 50,
                    color: Colors.grey[400],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDisplay(String label, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
        return Colors.teal.shade600;
      case 'dibatalkan':
        return Colors.red.shade700;
      case 'diproses':
        return Colors.green.shade700;
      case 'diterima':
        return Colors.blue.shade700;
      case 'dalam_perjalanan':
        return Colors.purple.shade600;
      default:
        return Colors.orange.shade700;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      return _dateFormatter.format(DateTime.parse(dateString));
    } catch (e) {
      return dateString;
    }
  }

  void _launchURL(String url) async {
    final Uri targetUri = Uri.parse(url);
    try {
      if (await canLaunchUrl(targetUri)) {
        await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackbar('Tidak bisa membuka tautan.');
      }
    } catch (e) {
      _showSnackbar('Error membuka tautan: $e');
    }
  }
}
